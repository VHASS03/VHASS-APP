import 'package:flutter/material.dart';
import '../../core/services/chat_service.dart';

class ChatMessage {
  final String text;
  final bool isAI;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isAI,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  final String token;
  final String serverUrl;

  const ChatScreen({required this.token, required this.serverUrl, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  late List<ChatMessage> _messages;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages = [];
    // Add welcome message
    _messages.add(ChatMessage(
      text: "Hi! I'm your personal safety assistant. How can I help you today?",
      isAI: true,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Add user message to UI
    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isAI: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    try {
      // Send to backend
      final response = await _chatService.sendMessage(
        message: userMessage,
        token: widget.token,
        serverUrl: widget.serverUrl,
      );

      if (response.success && response.data != null) {
        setState(() {
          _messages.add(ChatMessage(
            text: response.data!,
            isAI: true,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: "Sorry, I couldn't process that. Please try again.",
            isAI: true,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Error: ${e.toString()}",
          isAI: true,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access current theme data
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      // 1. Dynamic Background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            // 2. Dynamic Back Button color
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 18,
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor, // 3. Dynamic Title
                  ),
                ),
                Text(
                  'Always here to help',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.blueGrey : Colors.blueGrey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(
                  context,
                  message.text,
                  isAi: message.isAI,
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is not emergency support. For immediate danger, use the SOS button.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFE57373)
                                : Colors.red[800],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // AI MESSAGE
                _buildMessageBubble(
                  context,
                  "Hi! I'm your personal safety assistant. How can I help you today?",
                  isAi: true,
                ),

                // USER MESSAGE
                _buildMessageBubble(
                  context,
                  "What safety tips do you have for traveling alone?",
                  isAi: false,
                ),

                // AI RESPONSE
                _buildMessageBubble(
                  context,
                  "Here are some important safety tips for solo travel:\n\n1. Share your itinerary with trusted contacts\n2. Stay in well-lit, populated areas\n3. Keep emergency contacts handy\n4. Trust your instincts\n\nWould you like more specific advice?",
                  isAi: true,
                ),
              ],
            ),
          ),

          // --- CHAT INPUT AREA ---
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Ask about safety tips, health...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey[600],
                        fontSize: 14,
                      ),
                      filled: true,
                      // 5. Input field uses dynamic card color
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDark
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated Message Bubble with context for theme access
  Widget _buildMessageBubble(
    BuildContext context,
    String text, {
    required bool isAi,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          // 6. AI bubbles use card color; User bubbles use primary theme color
          color: isAi ? theme.cardColor : theme.colorScheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAi ? 4 : 20),
            bottomRight: Radius.circular(isAi ? 20 : 4),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            // 7. AI text follows theme color; User text stays white (contrast with primary)
            color: isAi ? theme.textTheme.bodyLarge?.color : Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
