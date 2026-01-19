import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0A0A14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A14),
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54),
          brightness: Brightness.dark,
          background: const Color(0xFF0A0A14),
        ),
      ),
      home: const AIChatScreen(),
    );
  }
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _backgroundAnimationController;
  bool _isLoading = false;
  final String _apiUrl = 'http://localhost:8080/chat';

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat(reverse: true);

    _messages.add(Message(
      text: "Hello! I'm your AI assistant powered by llama.cpp. How can I help you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = Message(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, userMessage);
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': text,
          'temperature': 0.7,
          'max_tokens': 512,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiMessage = Message(
          text: data['reply'],
          isUser: false,
          timestamp: DateTime.now(),
        );
        setState(() {
          _messages.insert(0, aiMessage);
        });
      } else {
        throw Exception('Server responded with ${response.statusCode}');
      }
    } on TimeoutException {
      setState(() {
        _messages.insert(0, Message(
          text: "Request timed out. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, Message(
          text: "Connection error: ${e.toString()}",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2C34),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white54,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Clear all messages?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Divider(
                color: Colors.white.withOpacity(0.1),
                height: 0,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF008069),
                        padding: const EdgeInsets.all(16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _messages.clear();
                          _messages.add(Message(
                            text: "Hello! I'm your AI assistant powered by llama.cpp. How can I help you today?",
                            isUser: false,
                            timestamp: DateTime.now(),
                          ));
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF4212E),
                        padding: const EdgeInsets.all(16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button (optional)
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white54),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                    // Title and status
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'AI Assistant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00A884),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8696A0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.search_rounded,
                              color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: _clearChat,
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Messages Area
            Expanded(
              child: Stack(
                children: [
                  // Subtle background pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ChatBackgroundPainter(
                        controller: _backgroundAnimationController,
                      ),
                    ),
                  ),

                  // Messages List
                  ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 16,
                      bottom: 16,
                    ),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == 0) {
                        return _buildTypingIndicator();
                      }
                      final messageIndex = _isLoading ? index - 1 : index;
                      final message = _messages[messageIndex];
                      return MessageBubble(
                        message: message,
                        index: messageIndex,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Input Area
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Attachment button
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white54, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  // Text field
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 100,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3942),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              maxLines: null,
                              minLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(
                                  color: Color(0xFF8696A0),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                          ),
                          if (_textController.text.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                onPressed: _sendMessage,
                                icon: Icon(
                                  _isLoading
                                      ? Icons.more_horiz_rounded
                                      : Icons.send_rounded,
                                  color: const Color(0xFF008069),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Mic button (when no text) or voice message indicator
                  if (_textController.text.trim().isEmpty)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.mic_rounded,
                            color: Colors.white54, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 80, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3942),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI is typing',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF8696A0),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  const Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class _ChatBackgroundPainter extends CustomPainter {
  final AnimationController controller;

  _ChatBackgroundPainter({required this.controller})
      : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1F2C).withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final time = controller.value * 2 * pi;

    for (int i = 0; i < 15; i++) {
      final x = size.width * (0.1 + 0.8 * sin(time * 0.5 + i * 0.5));
      final y = size.height * (0.1 + 0.8 * cos(time * 0.7 + i * 0.3));
      final radius = 1 + sin(time + i) * 0.8;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) => true;
}

class MessageBubble extends StatefulWidget {
  final Message message;
  final int index;

  const MessageBubble({super.key, required this.message, required this.index});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showTimestamp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + widget.index * 30),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isError = widget.message.isError;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showTimestamp = !_showTimestamp;
        });
      },
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 60 : 8,
          right: isUser ? 8 : 60,
          top: 4,
          bottom: 4,
        ),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFFF4212E).withOpacity(0.15)
                        : isUser
                            ? const Color(0xFF005C4B)
                            : const Color(0xFF2A3942),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 18),
                    ),
                    boxShadow: [
                      if (!isError)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message text
                      Text(
                        widget.message.text,
                        style: TextStyle(
                          color: isError
                              ? const Color(0xFFF4212E)
                              : Colors.white,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),

                      // Timestamp and status
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showTimestamp)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                _formatTime(widget.message.timestamp),
                                style: TextStyle(
                                  color: (isError
                                          ? const Color(0xFFF4212E)
                                          : Colors.white)
                                      .withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (isUser && !isError)
                            Icon(
                              Icons.done_all,
                              size: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          if (isError)
                            Icon(
                              Icons.error_outline_rounded,
                              size: 12,
                              color: const Color(0xFFF4212E).withOpacity(0.7),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Full timestamp when tapped
                if (_showTimestamp)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatFullTime(widget.message.timestamp),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    return '${hour > 12 ? hour - 12 : hour}:$minute ${hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatFullTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final day = time.day;
    final month = _getMonthAbbreviation(time.month);
    return '${hour > 12 ? hour - 12 : hour}:$minute ${hour >= 12 ? 'PM' : 'AM'}, $month $day';
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
