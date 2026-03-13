import { Socket } from 'socket.io';
import chatbotService from '../services/chatbotService';
import geminiService from '../services/geminiService';

/**
 * Chat Socket Handler
 * Handles real-time chat events between user and chatbot
 */

export const setupChatHandlers = (socket: Socket): void => {
  const { userId } = socket.data;

  if (!userId) {
    socket.emit('error', { message: 'User not authenticated' });
    return;
  }

  // Join user's chat room
  const chatRoomName = `chat:${userId}`;
  socket.join(chatRoomName);
  console.log(`[Chat] User ${userId} (${socket.id}) joined chat room`);

  /**
   * Handle incoming messages from user
   */
  socket.on('chat:send', async (data: { message: string }, callback) => {
    try {
      const { message } = data;

      if (!message || message.trim().length === 0) {
        callback({ success: false, error: 'Message cannot be empty' });
        return;
      }

      if (message.length > 1000) {
        callback({ success: false, error: 'Message is too long (max 1000 chars)' });
        return;
      }

      // Get or create chat session
      let chat = await chatbotService.getOrCreateChat(userId);

      // Add user message
      chat = await chatbotService.addUserMessage(chat._id.toString(), message);

      // Emit user message to client
      socket.emit('chat:message', {
        sender: 'user',
        text: message,
        timestamp: new Date(),
      });

      // Emit typing indicator
      socket.emit('chat:typing', { isTyping: true });

      // Simulate bot thinking (250-750ms delay)
      const delay = Math.random() * 500 + 250;
      await new Promise((resolve) => setTimeout(resolve, delay));

      // Generate bot response using Gemini AI with fallback
      let botResponse: string;
      
      // Check if Gemini is available, otherwise use fallback directly
      if (geminiService.isServiceAvailable()) {
        try {
          botResponse = await geminiService.getResponse(userId, message);
        } catch (geminiError: any) {
          console.warn('Gemini API error, using fallback response:', geminiError.message);
          // Fallback to rule-based response if Gemini quota exceeded or API error
          const fallbackResponse = chatbotService.generateBotResponse(message);
          botResponse = fallbackResponse.text;
        }
      } else {
        // Gemini not configured, use rule-based fallback
        console.log('[Chat] Using fallback response (Gemini not configured)');
        const fallbackResponse = chatbotService.generateBotResponse(message);
        botResponse = fallbackResponse.text;
      }

      // Add bot message to database
      chat = await chatbotService.addBotMessage(
        chat._id.toString(),
        botResponse
      );

      // Stop typing indicator
      socket.emit('chat:typing', { isTyping: false });

      // Emit bot message to client
      socket.emit('chat:message', {
        sender: 'bot',
        text: botResponse,
        timestamp: new Date(),
      });

      // Acknowledge receipt
      callback({ success: true });
    } catch (error: any) {
      console.error('[Chat] Error sending message:', error.message);
      callback({ success: false, error: error.message });
    }
  });

  /**
   * Handle chat history request
   */
  socket.on('chat:history', async (data: { limit?: number }, callback) => {
    try {
      const limit = Math.min(data.limit || 50, 100); // Max 100 messages
      const chat = await chatbotService.getChatHistory(userId, limit);

      if (!chat) {
        callback({ success: false, error: 'No chat history found' });
        return;
      }

      callback({
        success: true,
        chatId: chat._id.toString(),
        messages: chat.messages,
      });
    } catch (error: any) {
      console.error('[Chat] Error fetching history:', error.message);
      callback({ success: false, error: error.message });
    }
  });

  /**
   * Handle chat closure
   */
  socket.on('chat:close', async (data: { chatId: string }, callback) => {
    try {
      await chatbotService.closeChat(data.chatId);
      callback({ success: true });
    } catch (error: any) {
      console.error('[Chat] Error closing chat:', error.message);
      callback({ success: false, error: error.message });
    }
  });

  /**
   * Handle disconnect
   */
  socket.on('disconnect', () => {
    console.log(`[Chat] User ${userId} (${socket.id}) disconnected from chat`);
  });
};
