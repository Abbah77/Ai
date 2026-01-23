import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'here',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA78BFA),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.ralewayTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, String> toMap() => {'role': role, 'content': content};
  factory ChatMessage.fromMap(Map<String, dynamic> map) =>
      ChatMessage(role: map['role'], content: map['content']);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start with fresh chat on entry (per your request)
  }

  // --- LOGIC: API & STORAGE ---

  Future<void> _saveCurrentToHistory() async {
    if (messages.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('all_sessions') ?? [];
    
    Map<String, dynamic> session = {
      'title': messages.first.content.split('\n').first.substring(0, 20),
      'date': DateTime.now().toIso8601String(),
      'chat': messages.map((m) => m.toMap()).toList(),
    };
    
    stored.insert(0, jsonEncode(session));
    await prefs.setStringList('all_sessions', stored);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(role: 'user', content: text));
      isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("https://decodernet-servers.onrender.com/ReCore/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(messages.map((m) => m.toMap()).toList()),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          messages.add(ChatMessage(role: 'assistant', content: data['response']));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed. Check Internet or Server.")),
      );
    } finally {
      setState(() => isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        title: const Text('here', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      drawer: _buildModernDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SelectionArea( // ALLOWS LONG-PRESS COPY LIKE GEMINI
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: messages.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) return const TypingIndicator();
                  
                  final msg = messages[index];
                  final isUser = msg.role == 'user';
                  return _buildMessageTile(msg, isUser);
                },
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageTile(ChatMessage msg, bool isUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isUser ? Colors.transparent : const Color(0xFF1E1F23).withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isUser ? Icons.account_circle_outlined : Icons.auto_awesome, 
                   color: isUser ? Colors.grey : const Color(0xFFA78BFA), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: MarkdownBody(
                  data: msg.content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                    code: GoogleFonts.firaCode(backgroundColor: const Color(0xFF2D2E33)),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!isUser)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy_all_rounded, size: 18, color: Colors.grey),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
                },
              ),
            )
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1F23),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Enter your message...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            GestureDetector(
              onTap: _sendMessage,
              child: const CircleAvatar(
                backgroundColor: Color(0xFFA78BFA),
                radius: 22,
                child: Icon(Icons.arrow_upward_rounded, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E1F23),
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ActionChip(
                backgroundColor: const Color(0xFFA78BFA),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.add, color: Colors.black), Text(" New Chat", style: TextStyle(color: Colors.black))],
                ),
                onPressed: () {
                  _saveCurrentToHistory();
                  setState(() => messages.clear());
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          const Expanded(child: Center(child: Text("Chat History", style: TextStyle(color: Colors.grey)))),
          const Divider(color: Colors.white10),
          // SETTINGS AT THE BOTTOM AS PER YOUR SCREENSHOT
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white70),
            title: const Text("Settings", style: TextStyle(color: Colors.white70)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// MODERN TYPING INDICATOR (DOTS)
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)));
    _startAnimations();
  }

  void _startAnimations() async {
    for (var controller in _controllers) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) controller.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
      child: Row(
        children: _controllers.map((c) => AnimatedBuilder(
          animation: c,
          builder: (context, _) => Container(
            margin: const EdgeInsets.only(right: 4),
            height: 8, width: 8,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3 + (c.value * 0.7)), shape: BoxShape.circle),
          ),
        )).toList(),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _controllers) { c.dispose(); }
    super.dispose();
  }
}
