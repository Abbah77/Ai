import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const MyApp());
}

// Chat message model
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

  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _initWebView();
  }

  // Initialize hidden WebView bridge
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          _receiveAssistantMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse('https://decodernet.mywire.org/ReCore'));
  }

  // Load chat history from shared_preferences
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

  // Save chat history
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

  // Send user message
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(role: 'user', content: text));
      messages
          .add(ChatMessage(role: 'assistant', content: '...')); // placeholder
      _controller.clear();
    });

    _scrollToBottom();
    _saveChatHistory();

    // Send message to WebView bridge
    final js = '''
      var input = document.querySelector('textarea');
      if(input){input.value = ${jsonEncode(text)};}
      var btn = document.querySelector('button[type="submit"]');
      if(btn){btn.click();}
    ''';
    _webViewController.runJavaScript(js);
  }

  // Receive assistant message from WebView
  void _receiveAssistantMessage(String content) {
    setState(() {
      // Replace last assistant placeholder
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

  // Start new chat
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
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Row(
          children: [
            // Sidebar
            AnimatedContainer(
              width: sidebarOpen ? 250 : 0,
              duration: const Duration(milliseconds: 200),
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
                            .map((e) => ListTile(
                                  title: Text(
                                    e.value.content,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {},
                                )),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      // Settings button placeholder
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
                          icon:
                              Icon(sidebarOpen ? Icons.menu_open : Icons.menu),
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
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 50),
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
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: MarkdownBody(
                                data: msg.content,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Input + hidden WebView
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
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter your message...',
                              hintStyle: const TextStyle(color: Colors.white54),
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

                  // Hidden engine WebView (1x1 pixel)
                  SizedBox(
                    height: 1,
                    width: 1,
                    child: WebViewWidget(controller: _webViewController),
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
