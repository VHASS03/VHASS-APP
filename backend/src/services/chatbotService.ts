import Chat, { IChat } from '../models/Chat';

/**
 * Chatbot Service
 * Handles chat persistence and bot response generation
 */
class ChatbotService {
  /**
   * Get or create an active chat session for a user
   */
  async getOrCreateChat(userId: string): Promise<IChat> {
    let chat = await Chat.findOne({
      userId,
      isActive: true,
    });

    if (!chat) {
      chat = new Chat({
        userId,
        isActive: true,
        topic: 'general',
        messages: [],
      });
      await chat.save();
    }

    return chat;
  }

  /**
   * Add a user message to chat history
   */
  async addUserMessage(chatId: string, text: string): Promise<IChat> {
    const chat = await Chat.findByIdAndUpdate(
      chatId,
      {
        $push: {
          messages: {
            sender: 'user',
            text,
            timestamp: new Date(),
          },
        },
      },
      { new: true }
    );

    if (!chat) {
      throw new Error('Chat not found');
    }

    return chat;
  }

  /**
   * Add a bot message to chat history
   */
  async addBotMessage(
    chatId: string,
    text: string,
    metadata?: { intent?: string; confidence?: number }
  ): Promise<IChat> {
    const chat = await Chat.findByIdAndUpdate(
      chatId,
      {
        $push: {
          messages: {
            sender: 'bot',
            text,
            timestamp: new Date(),
            metadata,
          },
        },
      },
      { new: true }
    );

    if (!chat) {
      throw new Error('Chat not found');
    }

    return chat;
  }

  /**
   * Generate bot response based on user message
   * This is a simple rule-based system. You can replace with NLP/ML models later.
   */
  generateBotResponse(userMessage: string): { text: string; intent: string; confidence: number } {
    const message = userMessage.toLowerCase().trim();

    // Emergency-related queries
    if (
      message.includes('sos') ||
      message.includes('emergency') ||
      message.includes('help') ||
      message.includes('danger')
    ) {
      return {
        text: 'I understand you might need emergency assistance. You can trigger SOS from the app. Would you like help navigating to the SOS feature?',
        intent: 'emergency',
        confidence: 0.9,
      };
    }

    // Health check queries
    if (
      message.includes('health') ||
      message.includes('how are you') ||
      message.includes('feeling') ||
      message.includes('okay')
    ) {
      return {
        text: 'Thanks for asking! I\'m here to help you with any questions about the VHASS app or your safety features. What can I help you with?',
        intent: 'general',
        confidence: 0.85,
      };
    }

    // Location-related queries
    if (
      message.includes('location') ||
      message.includes('where') ||
      message.includes('GPS') ||
      message.includes('track')
    ) {
      return {
        text: 'Your location is securely tracked during active SOS alerts. Location data is only shared with your emergency contacts. You can view your location history in the app settings.',
        intent: 'location',
        confidence: 0.88,
      };
    }

    // Contact-related queries
    if (
      message.includes('contact') ||
      message.includes('friend') ||
      message.includes('family') ||
      message.includes('emergency contact')
    ) {
      return {
        text: 'You can manage your emergency contacts in the app. These contacts will be notified when you trigger an SOS. You can add, edit, or remove contacts anytime.',
        intent: 'contacts',
        confidence: 0.87,
      };
    }

    // Voice feature queries
    if (
      message.includes('voice') ||
      message.includes('call') ||
      message.includes('audio') ||
      message.includes('microphone')
    ) {
      return {
        text: 'The voice feature lets you alert your contacts hands-free. Simply activate the voice trigger to send alerts even if you can\'t use the app directly.',
        intent: 'voice',
        confidence: 0.86,
      };
    }

    // Device/settings queries
    if (
      message.includes('device') ||
      message.includes('setting') ||
      message.includes('configuration') ||
      message.includes('permission')
    ) {
      return {
        text: 'Device settings allow you to manage notifications, location sharing, and app permissions. Visit Settings → Device in the app for more options.',
        intent: 'device',
        confidence: 0.84,
      };
    }

    // Gratitude
    if (
      message.includes('thank') ||
      message.includes('thanks') ||
      message.includes('appreciate') ||
      message.includes('grateful')
    ) {
      return {
        text: 'You\'re welcome! I\'m here to help. Is there anything else you\'d like to know about VHASS?',
        intent: 'general',
        confidence: 0.9,
      };
    }

    // Greeting
    if (
      message.includes('hello') ||
      message.includes('hi') ||
      message.includes('hey') ||
      message.includes('greet')
    ) {
      return {
        text: 'Hello! 👋 Welcome to VHASS Chat Support. I\'m here to help you with questions about the app. What would you like to know?',
        intent: 'greeting',
        confidence: 0.95,
      };
    }

    // Default response
    return {
      text: 'I understand your question. For detailed help, please check the app\'s Help section or contact our support team. Is there anything specific about VHASS I can help clarify?',
      intent: 'general',
      confidence: 0.5,
    };
  }

  /**
   * Get chat history for a user
   */
  async getChatHistory(userId: string, limit: number = 50): Promise<IChat | null> {
    return await Chat.findOne({ userId, isActive: true })
      .select({ messages: { $slice: -limit } })
      .exec();
  }

  /**
   * Close a chat session
   */
  async closeChat(chatId: string): Promise<IChat> {
    const chat = await Chat.findByIdAndUpdate(
      chatId,
      { isActive: false },
      { new: true }
    );

    if (!chat) {
      throw new Error('Chat not found');
    }

    return chat;
  }

  /**
   * Clear chat history (archive old conversations)
   */
  async archiveOldChats(userId: string, daysOld: number = 30): Promise<number> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);

    const result = await Chat.updateMany(
      {
        userId,
        isActive: true,
        startedAt: { $lt: cutoffDate },
      },
      { isActive: false }
    );

    return result.modifiedCount;
  }
}

export default new ChatbotService();
