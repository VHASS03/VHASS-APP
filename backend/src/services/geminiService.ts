import { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold } from '@google/generative-ai';

interface ChatMessage {
  role: 'user' | 'model';
  parts: { text: string }[];
}

class GeminiService {
  private client: GoogleGenerativeAI;
  private conversationHistory: Map<string, ChatMessage[]> = new Map();

  constructor() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY environment variable is not set');
    }
    this.client = new GoogleGenerativeAI(apiKey);
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
   * Get response from Gemini with conversation context
   */
  async getResponse(userId: string, userMessage: string): Promise<string> {
    try {
      const model = this.client.getGenerativeModel({
        model: 'gemini-pro',
        systemInstruction: this.getSystemPrompt(),
        safetySettings: [
          {
            category: HarmCategory.HARM_CATEGORY_HARASSMENT,
            threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
          },
          {
            category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
            threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
          },
          {
            category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
            threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
          },
          {
            category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
            threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
          },
        ],
      });

      // Get conversation history
      const history = this.getConversationHistory(userId);

      // Start chat session with history
      const chat = model.startChat({
        history: history.length > 0 ? history : undefined,
        generationConfig: {
          maxOutputTokens: 500,
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
        },
      });

      // Send user message and get response
      const result = await chat.sendMessage(userMessage);
      const response = await result.response.text();

      // Update conversation history
      history.push({
        role: 'user',
        parts: [{ text: userMessage }],
      });

      history.push({
        role: 'model',
        parts: [{ text: response }],
      });

      // Keep only last 10 messages to manage memory
      if (history.length > 20) {
        this.conversationHistory.set(userId, history.slice(-20));
      }

      return response;
    } catch (error: any) {
      console.error('Gemini API Error:', error);
      throw new Error(`Failed to get response from Gemini: ${error.message}`);
    }
  }

  /**
   * Get streaming response from Gemini (for real-time streaming)
   */
  async *streamResponse(userId: string, userMessage: string): AsyncGenerator<string, void, unknown> {
    try {
      const model = this.client.getGenerativeModel({
        model: 'gemini-pro',
        systemInstruction: this.getSystemPrompt(),
      });

      const history = this.getConversationHistory(userId);

      const chat = model.startChat({
        history: history.length > 0 ? history : undefined,
        generationConfig: {
          maxOutputTokens: 500,
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
        },
      });

      // Send message and get streaming response
      const result = await chat.sendMessageStream(userMessage);

      let fullResponse = '';

      for await (const chunk of result.stream) {
        const text = chunk.text();
        fullResponse += text;
        yield text;
      }

      // Update conversation history
      history.push({
        role: 'user',
        parts: [{ text: userMessage }],
      });

      history.push({
        role: 'model',
        parts: [{ text: fullResponse }],
      });

      // Keep only last 10 messages to manage memory
      if (history.length > 20) {
        this.conversationHistory.set(userId, history.slice(-20));
      }
    } catch (error: any) {
      console.error('Gemini Streaming Error:', error);
      throw new Error(`Failed to stream response from Gemini: ${error.message}`);
    }
  }

  /**
   * System prompt for the chatbot
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
   * Check API connection
   */
  async checkConnection(): Promise<boolean> {
    try {
      const model = this.client.getGenerativeModel({ model: 'gemini-pro' });
      const result = await model.generateContent('Hi');
      console.log('✅ Gemini connection successful');
      return true;
    } catch (error: any) {
      console.error('❌ Gemini connection check failed:', error.message);
      return false;
    }
  }
}

// Export singleton instance
export default new GeminiService();
