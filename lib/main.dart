import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0E),
        primaryColor: const Color(0xFFA78BFA),
      ),
      home: const ChatScreen(),
    );
  }
}

/* ===================== MODELS ===================== */

class ChatMessage {
  final String role;
  String content;
  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      ChatMessage(role: json['role'], content: json['content']);
}

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((e) => e.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'],
        title: json['title'],
        messages: (json['messages'] as List)
            .map((e) => ChatMessage.fromJson(e))
            .toList(),
      );
}

/* ===================== STORAGE ===================== */

class ChatStorage {
  static const key = 'chat_sessions';

  static Future<List<ChatSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];
    return raw.map((e) => ChatSession.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> save(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await load();
    sessions.removeWhere((s) => s.id == session.id);
    sessions.insert(0, session);
    await prefs.setStringList(
      key,
      sessions.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

/* ===================== UI ===================== */

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];

  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isLoading = false;
  bool _userIsScrolling = false;

  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      _userIsScrolling = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 80;
    }
  }

  void _scrollToBottom() {
    if (_userIsScrolling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadSessions() async {
    _sessions = await ChatStorage.load();
    setState(() {});
  }

  Future<void> _saveSession() async {
    if (_messages.isEmpty) return;
    await ChatStorage.save(
      ChatSession(
        id: _sessionId,
        title: _messages.first.content.length > 30
            ? _messages.first.content.substring(0, 30)
            : _messages.first.content,
        messages: _messages,
      ),
    );
    _loadSessions();
  }

  void _newChat() {
    _saveSession();
    setState(() {
      _messages = [];
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    });
    Navigator.pop(context);
  }

  void _stopGenerating() {
    _client?.close();
    setState(() => _isLoading = false);
  }

  Future<void> _typeOutResponse(String text) async {
    final msg = ChatMessage(role: 'assistant', content: "");
    setState(() => _messages.add(msg));

    for (int i = 0; i < text.length; i++) {
      if (!_isLoading) break;
      await Future.delayed(const Duration(milliseconds: 10));
      msg.content += text[i];
      setState(() {});
      _scrollToBottom();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _controller.clear();
      _isLoading = true;
      _userIsScrolling = false;
    });

    _scrollToBottom();
    _client = http.Client();

    try {
      final res = await _client!.post(
        Uri.parse("https://decodernet-servers.onrender.com/ReCore/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
            _messages.map((e) => e.toJson()).toList()),
      );

      if (res.statusCode == 200) {
        await _typeOutResponse(jsonDecode(res.body)['response']);
      }
    } catch (_) {
      if (_isLoading) {
        _messages.add(ChatMessage(
            role: 'assistant',
            content: "⚠️ Connection error."));
      }
    } finally {
      _isLoading = false;
      _client?.close();
      setState(() {});
      _saveSession();
    }
  }

  /* ===================== WIDGETS ===================== */

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF3D5AFE)
              : const Color(0xFF1E1F23),
          borderRadius: BorderRadius.circular(16),
        ),
        child: MarkdownBody(
          data: m.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            code: GoogleFonts.firaCode(
                backgroundColor: Colors.black54),
            codeblockDecoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _starterCards() {
    final prompts = [
      "Explain quantum computing",
      "Write a Flutter app",
      "Create a workout plan"
    ];
    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: prompts
            .map((p) => ActionChip(
                  label: Text(p),
                  onPressed: () {
                    _controller.text = p;
                    _send();
                  },
                ))
            .toList(),
      ),
    );
  }

  /* ===================== BUILD ===================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ReCore AI",
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isLoading)
            TextButton(
              onPressed: _stopGenerating,
              child: const Text("STOP",
                  style: TextStyle(color: Colors.red)),
            )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1F23),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add),
                  label: const Text("New Chat"),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _sessions
                    .map((s) => ListTile(
                          title: Text(s.title,
                              style: const TextStyle(
                                  color: Colors.white)),
                          onTap: () {
                            setState(() {
                              _sessionId = s.id;
                              _messages = s.messages;
                            });
                            Navigator.pop(context);
                          },
                        ))
                    .toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.settings, color: Colors.grey),
              title: const Text("Settings",
                  style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _starterCards()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _bubble(_messages[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask anything…",
                      filled: true,
                      fillColor:
                          const Color(0xFF1E1F23),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFFA78BFA),
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.black),
                    onPressed: _send,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
