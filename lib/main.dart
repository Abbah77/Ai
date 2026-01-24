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
    _userIsScrolling = (_scrollController.position.maxScrollExtent - 
                        _scrollController.position.pixels) > 120;
  }

  void _scrollToBottom() {
    if (_userIsScrolling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
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
      final request = http.Request(
        'POST',
        Uri.parse("https://decodernet-servers.onrender.com/ReCore/chat"),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(_messages.map((e) => e.toJson()).toList());

      final response = await _client!.send(request);
      bool firstChunk = true;

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        if (!_isLoading) break;

        if (firstChunk) {
          setState(() {
            _showTypingIndicator = false;
            _messages.add(ChatMessage(role: 'assistant', content: ""));
          });
          firstChunk = false;
        }

        _messages.last.content += chunk;
        setState(() {});
        _scrollToBottom();
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

  Widget _typingDots() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (_) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }

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
      return s.messages.any((m) =>
          m.content.toLowerCase().contains(_search.toLowerCase()));
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
                              style:
                                  const TextStyle(color: Colors.white)),
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
                            _sessions.removeWhere(
                                (x) => x.id == s.id);
                            await prefs.setStringList(
                              ChatStorage.key,
                              _sessions
                                  .map((e) =>
                                      jsonEncode(e.toJson()))
                                  .toList(),
                            );
                            setState(() {});
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount:
                  _messages.length + (_showTypingIndicator ? 1 : 0),
              itemBuilder: (_, i) {
                if (_showTypingIndicator &&
                    i == _messages.length) {
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
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask anything…",
                      filled: true,
                      fillColor: const Color(0xFF1E1F23),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
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
