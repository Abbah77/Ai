import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  ChatMessage({required this.role, required this.content});

  Map<String, String> toMap() => {'role': role, 'content': content};
  factory ChatMessage.fromMap(Map<String, dynamic> map) =>
      ChatMessage(role: map['role'], content: map['content']);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String storageKey = 'chat_history';
  List<ChatMessage> messages = [];
  bool sidebarOpen = true;

  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? stored = prefs.getStringList(storageKey);
    if (stored != null) {
      setState(() {
        messages =
            stored.map((s) => ChatMessage.fromMap(jsonDecode(s))).toList();
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> stored = messages.map((m) => jsonEncode(m.toMap())).toList();
    await prefs.setStringList(storageKey, stored);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(role: 'user', content: text));
      _controller.clear();
    });
    _scrollToBottom();
    _saveChatHistory();

    // Send message to iframe via JS
    _webViewController.runJavaScript(
      "window.postMessage(${jsonEncode({'role': 'user', 'content': text})}, '*');",
    );

    // Add placeholder assistant message
    setState(() {
      messages.add(ChatMessage(role: 'assistant', content: '...'));
    });
    _scrollToBottom();
  }

  void _receiveAssistantMessage(String content) {
    setState(() {
      for (int i = messages.length - 1; i >= 0; i--) {
        if (messages[i].role == 'assistant' && messages[i].content == '...') {
          messages[i] = ChatMessage(role: 'assistant', content: content);
          break;
        }
      }
    });
    _scrollToBottom();
    _saveChatHistory();
  }

  void _newChat() {
    setState(() {
      messages.clear();
    });
    _saveChatHistory();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Row(
          children: [
            // Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: sidebarOpen ? 250 : 0,
              color: const Color(0xFF24242A),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        ElevatedButton.icon(
                          onPressed: _newChat,
                          icon: const Icon(Icons.add),
                          label: const Text('New Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA78BFA),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...messages
                            .asMap()
                            .entries
                            .where((e) => e.value.role == 'user')
                            .map(
                              (e) => ListTile(
                                title: Text(
                                  e.value.content,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white70),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {},
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      // Settings action
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // Main chat area
            Expanded(
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 60,
                    color: const Color(0xFF24242A),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                              sidebarOpen ? Icons.menu_open : Icons.menu),
                          onPressed: () {
                            setState(() {
                              sidebarOpen = !sidebarOpen;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('AI',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  // Messages
                  Expanded(
                    child: Container(
                      color: const Color(0xFF16161A),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.isEmpty ? 1 : messages.length,
                        itemBuilder: (context, index) {
                          if (messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 50),
                                child: Text(
                                  'How can I help you?',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 18),
                                ),
                              ),
                            );
                          }
                          final msg = messages[index];
                          bool isUser = msg.role == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              constraints: const BoxConstraints(maxWidth: 600),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF2D2D33)
                                    : const Color(0xFF24242A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg.content,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Input + iframe
                  Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: WebView(
                          initialUrl:
                              'https://decodernet.mywire.org/ReCore',
                          javascriptMode: JavascriptMode.unrestricted,
                          onWebViewCreated: (controller) {
                            _webViewController = controller;
                          },
                          javascriptChannels: {
                            JavascriptChannel(
                              name: 'Flutter',
                              onMessageReceived: (msg) {
                                _receiveAssistantMessage(msg.message);
                              },
                            ),
                          },
                        ),
                      ),
                      Container(
                        color: const Color(0xFF16161A),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 5,
                                style:
                                    const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter your message...',
                                  hintStyle: const TextStyle(
                                      color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF1F1F25),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send),
                              color: const Color(0xFFA78BFA),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
