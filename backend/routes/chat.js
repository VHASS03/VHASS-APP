const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');

// Import Gemini service
let geminiService;
try {
  geminiService = require('../services/geminiService').default;
} catch (error) {
  console.warn('⚠️  Gemini service not available. Ensure dependencies are installed with: npm install');
  geminiService = null;
}

// @route   POST /api/chat/message
// @desc    Send message to AI assistant powered by Google Gemini
// @access  Private
router.post('/message', authMiddleware, async (req, res) => {
  try {
    const { message } = req.body;
    const userId = req.user.id; // From auth middleware

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message cannot be empty'
      });
    }

    // Check if Gemini service is available
    if (!geminiService || !process.env.GEMINI_API_KEY) {
      return res.status(503).json({
        success: false,
        message: 'AI chat service is not configured. Please set GEMINI_API_KEY in environment variables.'
      });
    }

    try {
      // Get response from Gemini with conversation history
      const aiResponse = await geminiService.getResponse(userId, message);

      return res.json({
        success: true,
        response: aiResponse,
        timestamp: new Date().toISOString()
      });
    } catch (geminiError) {
      console.error('Gemini API error:', geminiError.message);
      return res.status(500).json({
        success: false,
        message: 'Failed to get AI response. Please try again.'
      });
    }
  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   GET /api/chat/stream
// @desc    Stream response from AI assistant (Server-Sent Events)
// @access  Private
router.get('/stream', authMiddleware, async (req, res) => {
  try {
    const { message } = req.query;
    const userId = req.user.id;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message cannot be empty'
      });
    }

    if (!geminiService || !process.env.GEMINI_API_KEY) {
      return res.status(503).json({
        success: false,
        message: 'AI chat service is not configured.'
      });
    }

    // Set up SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    try {
      // Stream response from Gemini
      for await (const chunk of geminiService.streamResponse(userId, message)) {
        res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
      }
      res.write('data: [DONE]\n\n');
      res.end();
    } catch (error) {
      console.error('Streaming error:', error);
      res.write(`data: ${JSON.stringify({ error: 'Stream error' })}\n\n`);
      res.end();
    }
  } catch (error) {
    console.error('Stream endpoint error:', error);
    res.status(500).json({ success: false, message: 'Streaming error' });
  }
});

// @route   DELETE /api/chat/history/:userId
// @desc    Clear conversation history for a user
// @access  Private
router.delete('/history/:userId', authMiddleware, (req, res) => {
  try {
    const userId = req.params.userId;

    // Users can only clear their own history
    if (req.user.id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    if (!geminiService) {
      return res.status(503).json({
        success: false,
        message: 'AI chat service is not available'
      });
    }

    geminiService.clearHistory(userId);

    res.json({
      success: true,
      message: 'Conversation history cleared'
    });
  } catch (error) {
    console.error('Clear history error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   GET /api/chat/health
// @desc    Check if Gemini service is healthy
// @access  Public
router.get('/health', async (req, res) => {
  try {
    if (!geminiService || !process.env.GEMINI_API_KEY) {
      return res.json({
        success: false,
        message: 'Gemini service not configured',
        status: 'unavailable'
      });
    }

    const isHealthy = await geminiService.checkConnection();
    res.json({
      success: isHealthy,
      status: isHealthy ? 'healthy' : 'unhealthy',
      message: isHealthy ? 'Gemini service is operational' : 'Gemini service connection failed'
    });
  } catch (error) {
    console.error('Health check error:', error);
    res.json({
      success: false,
      status: 'error',
      message: error.message
    });
  }
});

module.exports = router;


