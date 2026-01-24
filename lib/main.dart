import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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

/* ===================== CHAT SCREEN ===================== */

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isLoading = false;
  bool _userIsScrolling = false;
  bool _showTypingIndicator = false;
  String _search = "";
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    _userIsScrolling =
        (_scrollController.position.maxScrollExtent - _scrollController.position.pixels) > 120;
  }

  void _scrollToBottom() {
    if (_userIsScrolling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
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
    await ChatStorage.save(ChatSession(
      id: _sessionId,
      title: _messages.first.content.length > 30
          ? _messages.first.content.substring(0, 30)
          : _messages.first.content,
      messages: _messages,
    ));
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
    setState(() {
      _isLoading = false;
      _showTypingIndicator = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _controller.clear();
      _isLoading = true;
      _showTypingIndicator = true;
      _userIsScrolling = false;
    });
    _scrollToBottom();

    _client = http.Client();

    try {
      final res = await _client!.post(
        Uri.parse("https://decodernet-servers.onrender.com/ReCore/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(_messages.map((e) => e.toJson()).toList()),
      );

      final aiText = jsonDecode(res.body)['response'] ?? "";

      // Remove typing indicator, add empty assistant bubble
      setState(() {
        _showTypingIndicator = false;
        _messages.add(ChatMessage(role: 'assistant', content: ""));
      });

      // Fast typewriter effect
      for (int i = 0; i < aiText.length; i++) {
        if (!_isLoading) break;
        _messages.last.content += aiText[i];
        setState(() {});
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: 5));
      }
    } catch (_) {
      if (_isLoading) {
        _messages.add(ChatMessage(
            role: 'assistant', content: "⚠️ Connection error."));
      }
    } finally {
      _isLoading = false;
      _showTypingIndicator = false;
      _client?.close();
      setState(() {});
      _saveSession();
    }
  }

  Widget _typingDots() => const TypingIndicator();

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF3D5AFE) : const Color(0xFF1E1F23),
          borderRadius: BorderRadius.circular(16),
        ),
        child: MarkdownBody(
          data: m.content,
          selectable: true,
          builders: {'code': CodeCopyBuilder()},
          styleSheet: MarkdownStyleSheet(
            code: GoogleFonts.firaCode(),
            codeblockDecoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _sessions.where((s) {
      return s.messages.any(
          (m) => m.content.toLowerCase().contains(_search.toLowerCase()));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("HERE AI",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isLoading)
            TextButton(
              onPressed: _stopGenerating,
              child: const Text("STOP", style: TextStyle(color: Colors.red)),
            )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1F23),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _newChat,
                      icon: const Icon(Icons.add),
                      label: const Text("New Chat"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration:
                          const InputDecoration(hintText: "Search chats"),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: filteredSessions
                    .map((s) => ListTile(
                          title: Text(s.title,
                              style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            setState(() {
                              _sessionId = s.id;
                              _messages = s.messages;
                            });
                            Navigator.pop(context);
                          },
                          onLongPress: () async {
                            final prefs =
                                await SharedPreferences.getInstance();
                            _sessions.removeWhere((x) => x.id == s.id);
                            await prefs.setStringList(
                              ChatStorage.key,
                              _sessions
                                  .map((e) => jsonEncode(e.toJson()))
                                  .toList(),
                            );
                            setState(() {});
                          },
                        ))
                    .toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title:
                  const Text("Settings", style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_showTypingIndicator ? 1 : 0),
              itemBuilder: (_, i) {
                if (_showTypingIndicator && i == _messages.length) {
                  return _typingDots();
                }
                return _bubble(_messages[i]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      maxHeight: 150, // roughly 4-6 lines
                    ),
                    child: Scrollbar(
                      child: TextField(
                        controller: _controller,
                        maxLines: null, // allows expanding
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: "Ask anything…",
                          filled: true,
                          fillColor: const Color(0xFF1E1F23),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16), // more padding for multi-line
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFA78BFA),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
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

/* ===================== ANIMATED TYPING INDICATOR ===================== */

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dot1 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );
    _dot2 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.8, curve: Curves.easeInOut)),
    );
    _dot3 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(Animation<double> animation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(_dot1),
            _dot(_dot2),
            _dot(_dot3),
          ],
        ),
      ),
    );
  }
}

/* ===================== CODE COPY BUILDER ===================== */

class CodeCopyBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(element, preferredStyle) {
    final code = element.textContent;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(code,
              style: GoogleFonts.firaCode(color: Colors.white)),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
            },
          ),
        )
      ],
    );
  }
}
