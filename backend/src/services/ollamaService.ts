import axios from 'axios';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

class OllamaService {
  private ollamaUrl: string;
  private model: string;
  private conversationHistory: Map<string, ChatMessage[]> = new Map();

  constructor() {
    this.ollamaUrl = process.env.OLLAMA_URL || 'http://localhost:11434';
    this.model = process.env.OLLAMA_MODEL || 'mistral';
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
   * Get response from Ollama with conversation context
   */
  async getResponse(userId: string, userMessage: string): Promise<string> {
    try {
      const history = this.getConversationHistory(userId);

      // Build messages array
      const messages: ChatMessage[] = [
        ...history,
        { role: 'user', content: userMessage },
      ];

      // Call Ollama API
      const response = await axios.post(`${this.ollamaUrl}/api/chat`, {
        model: this.model,
        messages: messages,
        stream: false,
        options: {
          temperature: 0.7,
          top_p: 0.9,
          top_k: 40,
        },
      });

      const botResponse = response.data.message.content;

      // Update conversation history
      history.push({ role: 'user', content: userMessage });
      history.push({ role: 'assistant', content: botResponse });

      // Keep only last 10 messages to manage memory
      if (history.length > 20) {
        this.conversationHistory.set(userId, history.slice(-20));
      }

      return botResponse;
    } catch (error: any) {
      console.error('Ollama API Error:', error.message);
      if (error.code === 'ECONNREFUSED') {
        throw new Error('Ollama is not running. Start Ollama with: ollama serve');
      }
      throw new Error(`Failed to get response from Ollama: ${error.message}`);
    }
  }

  /**
   * Get streaming response from Ollama (for real-time streaming)
   */
  async *streamResponse(
    userId: string,
    userMessage: string
  ): AsyncGenerator<string, void, unknown> {
    try {
      const history = this.getConversationHistory(userId);

      // Build messages array
      const messages: ChatMessage[] = [
        ...history,
        { role: 'user', content: userMessage },
      ];

      // Call Ollama API with streaming
      const response = await axios.post(
        `${this.ollamaUrl}/api/chat`,
        {
          model: this.model,
          messages: messages,
          stream: true,
          options: {
            temperature: 0.7,
            top_p: 0.9,
            top_k: 40,
          },
        },
        {
          responseType: 'stream',
        }
      );

      let fullResponse = '';

      // Process stream
      return new Promise((resolve, reject) => {
        response.data.on('data', async (chunk: Buffer) => {
          try {
            const lines = chunk.toString().split('\n');
            for (const line of lines) {
              if (line.trim()) {
                const data = JSON.parse(line);
                if (data.message?.content) {
                  const content = data.message.content;
                  fullResponse += content;
                }
              }
            }
          } catch (e) {
            // Skip invalid JSON lines
          }
        });

        response.data.on('end', async () => {
          try {
            // Update conversation history after streaming completes
            history.push({ role: 'user', content: userMessage });
            history.push({ role: 'assistant', content: fullResponse });

            // Keep only last 10 messages to manage memory
            if (history.length > 20) {
              this.conversationHistory.set(userId, history.slice(-20));
            }

            resolve();
          } catch (e) {
            reject(e);
          }
        });

        response.data.on('error', (error: any) => {
          reject(error);
        });
      }).then(
        async function* () {
          // This is a workaround - we'll use a different approach
        }
      );
    } catch (error: any) {
      console.error('Ollama Streaming Error:', error.message);
      throw new Error(`Failed to stream response from Ollama: ${error.message}`);
    }
  }

  /**
   * Simplified streaming using line-by-line processing
   */
  async *streamResponseSimple(
    userId: string,
    userMessage: string
  ): AsyncGenerator<string, void, unknown> {
    try {
      const history = this.getConversationHistory(userId);

      // Build messages array
      const messages: ChatMessage[] = [
        ...history,
        { role: 'user', content: userMessage },
      ];

      // Call Ollama API with streaming
      const response = await axios.post(
        `${this.ollamaUrl}/api/chat`,
        {
          model: this.model,
          messages: messages,
          stream: true,
        },
        {
          responseType: 'stream',
        }
      );

      let fullResponse = '';

      // Process stream line by line
      for await (const chunk of response.data) {
        try {
          const lines = chunk.toString().split('\n');
          for (const line of lines) {
            if (line.trim()) {
              const data = JSON.parse(line);
              if (data.message?.content) {
                const content = data.message.content;
                fullResponse += content;
                yield content;
              }
            }
          }
        } catch (e) {
          // Skip invalid JSON lines
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
      console.error('Ollama Streaming Error:', error.message);
      if (error.code === 'ECONNREFUSED') {
        throw new Error('Ollama is not running. Start Ollama with: ollama serve');
      }
      throw new Error(`Failed to stream response from Ollama: ${error.message}`);
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
   * Check if Ollama is running
   */
  async checkConnection(): Promise<boolean> {
    try {
      const response = await axios.get(`${this.ollamaUrl}/api/tags`, {
        timeout: 5000,
      });
      console.log(`✅ Ollama connection successful. Available models:`, response.data.models?.map((m: any) => m.name));
      return true;
    } catch (error: any) {
      console.error('❌ Ollama connection failed:', error.message);
      if (error.code === 'ECONNREFUSED') {
        console.error('   Ollama is not running. Please start it with: ollama serve');
      }
      return false;
    }
  }

  /**
   * List available models
   */
  async getAvailableModels(): Promise<string[]> {
    try {
      const response = await axios.get(`${this.ollamaUrl}/api/tags`);
      return response.data.models?.map((m: any) => m.name) || [];
    } catch (error) {
      console.error('Failed to fetch models:', error);
      return [];
    }
  }
}

// Export singleton instance
export default new OllamaService();
