import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyApp());

/* ===================== APP ===================== */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF131314),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

/* ===================== MODELS ===================== */

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      ChatMessage(role: json['role'], content: json['content']);
}

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;

  ChatSession({required this.id, required this.title, required this.messages});

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
  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

  List<ChatMessage> messages = [];
  List<ChatSession> sessions = [];
  String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    sessions = await ChatStorage.load();
    setState(() {});
  }

  Future<void> _saveSession() async {
    if (messages.isEmpty) return;
    await ChatStorage.save(
      ChatSession(
        id: sessionId,
        title: messages.first.content.substring(
          0,
          messages.first.content.length.clamp(0, 25),
        ),
        messages: messages,
      ),
    );
    _loadSessions();
  }

  Future<void> send() async {
    final String text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(role: 'user', content: text));
      controller.clear();
      loading = true;
    });

    scroll.jumpTo(scroll.position.maxScrollExtent + 100);

    try {
      final http.Response res = await http.post(
        Uri.parse("https://decodernet-servers.onrender.com/ReCore/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(messages.map((e) => e.toJson()).toList()),
      );

      if (res.statusCode == 200) {
        messages.add(ChatMessage(
          role: 'assistant',
          content: jsonDecode(res.body)['response'],
        ));
      }
    } finally {
      loading = false;
      setState(() {});
      _saveSession();
    }
  }

  Widget bubble(ChatMessage m) {
    final bool isUser = m.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => Clipboard.setData(ClipboardData(text: m.content)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: isUser
                ? const Color(0xFFA78BFA)
                : const Color(0xFF1E1F23),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            m.content,
            style: TextStyle(
              color: isUser ? Colors.black : Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
        backgroundColor: Colors.transparent,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1F23),
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Chat History",
                  style: TextStyle(color: Colors.grey)),
            ),
            ...sessions.map(
              (s) => ListTile(
                title: Text(s.title,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    sessionId = s.id;
                    messages = s.messages;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                ...messages.map(bubble),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("Typing...",
                        style: TextStyle(color: Colors.grey)),
                  )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F23),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "Message…",
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded),
                    onPressed: send,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
