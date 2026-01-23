import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const ReCoreApp());

class ReCoreApp extends StatelessWidget {
  const ReCoreApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
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
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // THE API CALL: Directly to your Render server
  Future<void> _sendToApi() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("https://decodernet-servers.onrender.com/ReCore/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(_messages.map((m) => m.toMap()).toList()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: data['response']));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed. Check your internet.")),
      );
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      _saveHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314), // Deep Space Gray
      appBar: AppBar(
        title: Text("ReCore AI", style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      // MODERN SIDEBAR (Drawer)
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1F23),
        child: Column(
          children: [
            DrawerHeader(
              child: Center(child: Text("Chat History", style: GoogleFonts.raleway(fontSize: 22, color: Colors.blueAccent))),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text("Clear History"),
              onTap: () {
                setState(() => _messages.clear());
                _saveHistory();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == 'user';
                return _buildMessageBubble(msg, isUser);
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2D2E33) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: MarkdownBody(
          data: msg.content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: isUser ? Colors.white : const Color(0xFFE3E3E3), fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1F23),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendToApi(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: _sendToApi,
            ),
          ),
        ],
      ),
    );
  }

  // Persistence Helpers
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('chat_logs');
    if (data != null) {
      setState(() => _messages = (jsonDecode(data) as List).map((m) => ChatMessage.fromMap(m)).toList());
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_logs', jsonEncode(_messages.map((m) => m.toMap()).toList()));
  }
}
