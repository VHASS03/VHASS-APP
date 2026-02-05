import Groq from 'groq-sdk';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

class GroqService {
  private client: Groq;
  private model: string;
  private conversationHistory: Map<string, ChatMessage[]> = new Map();

  constructor() {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
      throw new Error('GROQ_API_KEY environment variable is not set');
    }
    this.client = new Groq({ apiKey });
    this.model = process.env.GROQ_MODEL || 'mixtral-8x7b-32768';
  }

  /**
   * Initialize or get conversation history for a user
   */
  private getConversationHistory(userId: string): ChatMessage[] {
    if (!this.conversationHistory.has(userId)) {
      this.conversationHistory.set(userId, []);
    }
    return this.conversationHistory.get(userId)!;
  }

  /**
   * Clear conversation history for a user
   */
  clearHistory(userId: string): void {
    this.conversationHistory.delete(userId);
  }

  /**
   * Get response from Groq with conversation context
   */
  async getResponse(userId: string, userMessage: string): Promise<string> {
    try {
      const history = this.getConversationHistory(userId);

      // Build messages array with system prompt
      const messages: any[] = [
        {
          role: 'system',
          content: this.getSystemPrompt(),
        },
        ...history.map((msg) => ({
          role: msg.role,
          content: msg.content,
        })),
        {
          role: 'user',
          content: userMessage,
        },
      ];

      // Call Groq API
      const response = await this.client.chat.completions.create({
        model: this.model,
        messages: messages,
        max_tokens: 1024,
        temperature: 0.7,
        top_p: 0.9,
      });

      const botResponse = response.choices[0]?.message?.content || 'No response generated';

      // Update conversation history
      history.push({ role: 'user', content: userMessage });
      history.push({ role: 'assistant', content: botResponse });

      // Keep only last 10 messages to manage memory
      if (history.length > 20) {
        this.conversationHistory.set(userId, history.slice(-20));
      }

      return botResponse;
    } catch (error: any) {
      console.error('Groq API Error:', error.message);
      throw new Error(`Failed to get response from Groq: ${error.message}`);
    }
  }

  /**
   * Get streaming response from Groq (for real-time streaming)
   */
  async *streamResponse(
    userId: string,
    userMessage: string
  ): AsyncGenerator<string, void, unknown> {
    try {
      const history = this.getConversationHistory(userId);

      // Build messages array with system prompt
      const messages: any[] = [
        {
          role: 'system',
          content: this.getSystemPrompt(),
        },
        ...history.map((msg) => ({
          role: msg.role,
          content: msg.content,
        })),
        {
          role: 'user',
          content: userMessage,
        },
      ];

      // Call Groq API with streaming
      const stream = (await this.client.chat.completions.create({
        model: this.model,
        messages: messages,
        max_tokens: 1024,
        temperature: 0.7,
        top_p: 0.9,
        stream: true,
      })) as any;

      let fullResponse = '';

      // Process stream
      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        if (content) {
          fullResponse += content;
          yield content;
        }
      }

      // Update conversation history after streaming completes
      history.push({ role: 'user', content: userMessage });
      history.push({ role: 'assistant', content: fullResponse });

      // Keep only last 10 messages to manage memory
      if (history.length > 20) {
        this.conversationHistory.set(userId, history.slice(-20));
      }
    } catch (error: any) {
      console.error('Groq Streaming Error:', error.message);
      throw new Error(`Failed to stream response from Groq: ${error.message}`);
    }
  }

  /**
   * Get system prompt for the chatbot
   */
  private getSystemPrompt(): string {
    return `You are a friendly and helpful safety assistant for the VHASS (Voice & Health Assistant Safety System) app. Your role is to provide:

1. **Safety Tips**: Practical advice for personal safety in various situations
2. **Health & Wellness**: General health tips and wellness recommendations
3. **Emergency Guidance**: Clear instructions for emergency situations
4. **Travel Safety**: Tips for safe travel, especially solo travel
5. **Security Advice**: Security best practices and awareness tips

Guidelines:
- Be concise and practical in your responses
- Use clear, easy-to-understand language
- When discussing emergencies, always emphasize calling 911 or local emergency services first
- For medical emergencies, always recommend consulting healthcare professionals
- Be empathetic and supportive in tone
- Provide actionable advice when possible
- If you're unsure about something, be honest about it
- Remember previous messages in the conversation for context

Important reminders:
- For immediate life-threatening emergencies, the user should use the SOS button in the app immediately
- This chat is for general safety advice, not professional medical diagnosis
- Always prioritize user safety and encourage seeking professional help when needed

Keep responses focused on safety, health, and wellness topics relevant to the VHASS app.`;
  }

  /**
   * Check if Groq is accessible
   */
  async checkConnection(): Promise<boolean> {
    try {
      const response = await this.client.chat.completions.create({
        model: this.model,
        messages: [
          {
            role: 'user',
            content: 'Hi',
          },
        ],
        max_tokens: 10,
      });
      console.log('✅ Groq connection successful');
      return true;
    } catch (error: any) {
      console.error('❌ Groq connection failed:', error.message);
      return false;
    }
  }

  /**
   * Get available models
   */
  getAvailableModels(): string[] {
    return [
      'mixtral-8x7b-32768',
      'llama2-70b-4096',
      'gemma-7b-it',
    ];
  }
}

// Export singleton instance
export default new GroqService();
