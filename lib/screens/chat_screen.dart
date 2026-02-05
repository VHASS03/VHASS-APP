import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'emergency/emergency.dart';

/// Chat message model
class ChatMessage {
  final String sender; // 'user' or 'bot'
  final String text;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'],
    );
  }
}

/// Chat bubble widget for displaying individual messages
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[600] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main chat screen widget
class ChatScreen extends StatefulWidget {
  final String token;
  final String serverUrl;

  const ChatScreen({super.key, required this.token, required this.serverUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isBotTyping = false;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    // History is loaded in onConnect handler to avoid duplicate calls
  }

  void _connectSocket() {
    print('🔌 Chat: Connecting to socket at ${widget.serverUrl}');
    print('   Token: ${widget.token.substring(0, 20)}...');

    socket = io.io(
      widget.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': widget.token})
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(10)
          .build(),
    );

    socket.onConnect((_) {
      print('✅ Chat: Connected to chat server!');
      print('   Socket ID: ${socket.id}');
      _safeSetState(() => _isConnected = true);
      _loadChatHistory();
    });

    socket.onConnectError((error) {
      print('❌ Chat: Connection error: $error');
    });

    socket.onDisconnect((_) {
      print('⚠️  Chat: Disconnected from chat server');
      _safeSetState(() => _isConnected = false);
    });

    // Listen for incoming messages
    socket.on('chat:message', (data) {
      print('💬 Chat: Received message: ${data['text']}');
      final message = ChatMessage.fromJson(data);
      _safeSetState(() {
        _messages.add(message);
      });
    });

    // Listen for typing indicator
    socket.on('chat:typing', (data) {
      print('✍️  Chat: Typing indicator: ${data['isTyping']}');
      _safeSetState(() {
        _isBotTyping = data['isTyping'] ?? false;
      });
    });

    // Listen for errors
    socket.on('error', (data) {
      print('❌ Chat: Socket error: $data');
      if (!mounted || _isDisposing) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text('Error: ${data['message'] ?? data}')),
      );
    });

    socket.connect();
    print('🔌 Chat: Calling connect()...');
  }

  void _loadChatHistory() {
    print('📜 Chat: Loading chat history...');
    socket.emitWithAck(
      'chat:history',
      {'limit': 50},
      ack: (response) {
        print('📜 Chat: History response: $response');
        if (response is Map && response['success'] == true) {
          _safeSetState(() {
            _messages.clear();
            if (response['messages'] is List) {
              for (var msg in response['messages']) {
                try {
                  _messages.add(ChatMessage.fromJson(msg));
                } catch (e) {
                  print('❌ Chat: Failed to parse message: $e');
                }
              }
            }
          });
        }
      },
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty || !_isConnected) return;

    _messageController.clear();

    socket.emitWithAck(
      'chat:send',
      {'message': message},
      ack: (response) {
        if (response['success'] != true) {
          if (!mounted || _isDisposing) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send: ${response['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposing = true;
    _removeSocketListeners();
    _messageController.dispose();
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  void _removeSocketListeners() {
    socket.off('connect');
    socket.off('disconnect');
    socket.off('chat:message');
    socket.off('chat:typing');
    socket.off('error');
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposing) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
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
                    color: textColor,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Connected' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.blueGrey : Colors.blueGrey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet. Start a conversation!',
                          style: TextStyle(
                            color: isDark ? Colors.grey : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isBotTyping && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  'Bot is typing',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final messageIndex = _isBotTyping ? index - 1 : index;
                      if (messageIndex < 0) return const SizedBox.shrink();

                      final message =
                          _messages[_messages.length - 1 - messageIndex];
                      return _buildMessageBubble(
                        context,
                        message.text,
                        isAi: message.sender == 'bot',
                      );
                    },
                  ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _isConnected,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey[600],
                        fontSize: 14,
                      ),
                      filled: true,
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
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? theme.colorScheme.primary
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isConnected ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            color: isAi ? theme.textTheme.bodyLarge?.color : Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
