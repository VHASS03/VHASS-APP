import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth';
import chatbotService from '../services/chatbotService';
import Chat from '../models/Chat';
import groqService from '../services/groqService';

const router = Router();

/**
 * Chat Routes
 * All routes require authentication (except health check)
 */

/**
 * GET /api/chat/health
 * Check if Groq service is healthy
 */
router.get('/health', async (req: Request, res: Response) => {
  try {
    const isHealthy = await groqService.checkConnection();
    
    if (isHealthy) {
      res.json({
        success: true,
        status: 'healthy',
        message: 'Groq service is operational',
      });
    } else {
      res.json({
        success: false,
        status: 'unhealthy',
        message: 'Groq API connection failed',
      });
    }
  } catch (error: any) {
    res.json({
      success: false,
      status: 'error',
      message: error.message,
    });
  }
});

/**
 * POST /api/chat/message
 * Send message to AI assistant powered by Groq
 */
router.post('/message', authenticate, async (req: Request, res: Response) => {
  try {
    const { message } = req.body;
    const userId = req.user?.userId;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message cannot be empty',
      });
    }

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    try {
      // Get response from Groq with conversation history
      const aiResponse = await groqService.getResponse(userId, message);

      // Store in database
      let chat = await chatbotService.getOrCreateChat(userId);
      chat = await chatbotService.addUserMessage(chat._id.toString(), message);
      chat = await chatbotService.addBotMessage(chat._id.toString(), aiResponse);

      return res.json({
        success: true,
        response: aiResponse,
        chatId: chat._id.toString(),
        timestamp: new Date().toISOString(),
      });
    } catch (groqError: any) {
      console.error('Groq API error:', groqError.message);
      return res.status(503).json({
        success: false,
        message: groqError.message || 'Failed to get AI response. Please try again.',
      });
    }
  } catch (error: any) {
    console.error('Chat error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * GET /api/chat/stream
 * Stream response from AI assistant (Server-Sent Events)
 */
router.get('/stream', authenticate, async (req: Request, res: Response) => {
  try {
    const { message } = req.query;
    const userId = req.user?.userId;

    if (!message || (message as string).trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message cannot be empty',
      });
    }

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Set up SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');

    try {
      let fullResponse = '';

      // Stream response from Groq
      for await (const chunk of groqService.streamResponse(userId, message as string)) {
        fullResponse += chunk;
        res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
      }

      // Store in database after streaming completes
      const chat = await chatbotService.getOrCreateChat(userId);
      await chatbotService.addUserMessage(chat._id.toString(), message as string);
      await chatbotService.addBotMessage(chat._id.toString(), fullResponse);

      res.write('data: [DONE]\n\n');
      res.end();
    } catch (error: any) {
      console.error('Streaming error:', error);
      res.write(`data: ${JSON.stringify({ error: 'Stream error', details: error.message })}\n\n`);
      res.end();
    }
  } catch (error: any) {
    console.error('Stream endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Streaming error',
    });
  }
});

/**
 * DELETE /api/chat/history/:userId
 * Clear conversation history for a user
 */
router.delete('/history/:userId', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.params.userId;
    const authUserId = req.user?.userId;

    // Users can only clear their own history
    if (authUserId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized',
      });
    }

    // Clear Groq conversation history
    groqService.clearHistory(userId);

    // Close active chat in database
    const activeChat = await Chat.findOne({ userId, isActive: true });
    if (activeChat) {
      activeChat.isActive = false;
      await activeChat.save();
    }

    res.json({
      success: true,
      message: 'Conversation history cleared',
    });
  } catch (error: any) {
    console.error('Clear history error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * GET /api/chat
 * Get active chat session or create one
 */
router.get('/', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'User not authenticated' });
    }

    const chat = await chatbotService.getOrCreateChat(userId);

    res.json({
      success: true,
      data: {
        chatId: chat._id.toString(),
        messageCount: chat.messages.length,
        startedAt: chat.startedAt,
        isActive: chat.isActive,
      },
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

/**
 * GET /api/chat/history
 * Get chat message history
 */
router.get('/history', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.userId;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);

    if (!userId) {
      return res.status(401).json({ success: false, message: 'User not authenticated' });
    }

    const chat = await chatbotService.getChatHistory(userId, limit);

    if (!chat) {
      return res.status(404).json({ success: false, message: 'No chat found' });
    }

    res.json({
      success: true,
      data: {
        chatId: chat._id.toString(),
        messages: chat.messages,
        messageCount: chat.messages.length,
      },
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

/**
 * POST /api/chat/archive
 * Close current chat session and archive old chats
 */
router.post('/archive', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.userId;
    const daysOld = req.body.daysOld || 30;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'User not authenticated' });
    }

    const archivedCount = await chatbotService.archiveOldChats(userId, daysOld);

    res.json({
      success: true,
      message: `Archived ${archivedCount} old chat(s)`,
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

/**
 * POST /api/chat/clear
 * Clear all messages from current chat (but keep session)
 */
router.post('/clear', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'User not authenticated' });
    }

    // Clear Groq history
    groqService.clearHistory(userId);

    // Get current chat
    let chat = await chatbotService.getOrCreateChat(userId);

    // Close current chat
    await chatbotService.closeChat(chat._id.toString());

    // Create new chat
    chat = await chatbotService.getOrCreateChat(userId);

    res.json({
      success: true,
      message: 'Chat cleared',
      data: {
        chatId: chat._id.toString(),
      },
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

/**
 * GET /api/chat/stats
 * Get chat statistics
 */
router.get('/stats', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'User not authenticated' });
    }

    // Get all chats (active and archived)
    const allChats = await Chat.find({ userId });
    const activeChat = await Chat.findOne({ userId, isActive: true });

    const totalMessages = allChats.reduce((sum, chat) => sum + chat.messages.length, 0);
    const totalChats = allChats.length;
    const activeChatMessages = activeChat?.messages.length || 0;

    res.json({
      success: true,
      data: {
        totalChats,
        activeChat: activeChat ? activeChat._id.toString() : null,
        totalMessages,
        activeChatMessages,
        messageSources: {
          user: activeChat?.messages.filter((m) => m.sender === 'user').length || 0,
          bot: activeChat?.messages.filter((m) => m.sender === 'bot').length || 0,
        },
      },
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

export default router;

