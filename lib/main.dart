import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const MaterialApp(
    home: MyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class ChatMessage {
  final String role;
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
  List<ChatMessage> messages = [];
  late final WebViewController _webViewController;
  bool _isEngineReady = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          // CLEANER: This hides the website UI elements you saw in the source code
          _webViewController.runJavaScript('''
            document.querySelector('header').style.display = 'none';
            document.querySelector('aside').style.display = 'none';
            document.querySelector('.loadingScreen').style.display = 'none';
            document.querySelector('.msgInputBlock').style.display = 'none';
            document.querySelector('main').style.padding = '0';
          ''');
          setState(() => _isEngineReady = true);
        },
      ))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) => _receiveAssistantMessage(message.message),
      )
      ..loadRequest(Uri.parse('https://decodernet.mywire.org/ReCore'));
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isEngineReady) return;

    setState(() {
      messages.add(ChatMessage(role: 'user', content: text));
      messages.add(ChatMessage(role: 'assistant', content: '...')); 
      _controller.clear();
    });

    _scrollToBottom();

    // BRIDGE: Targets .MessageInput and .sendBtn from your HTML
    _webViewController.runJavaScript('''
      (function() {
        var input = document.querySelector('.MessageInput');
        var btn = document.querySelector('.sendBtn');
        if(input) {
           input.value = ${jsonEncode(text)};
           input.dispatchEvent(new Event('input', { bubbles: true }));
        }
        if(btn) btn.click();

        // Observer looks for the AI response in .chatArea
        var observer = new MutationObserver((mutations) => {
          var chatArea = document.querySelector('.chatArea');
          if (chatArea && chatArea.lastElementChild) {
            var response = chatArea.lastElementChild.innerText;
            if (response && response !== ${jsonEncode(text)}) {
              window.FlutterBridge.postMessage(response);
              observer.disconnect();
            }
          }
        });
        observer.observe(document.querySelector('.chatArea'), { childList: true, subtree: true });
      })();
    ''');
  }

  void _receiveAssistantMessage(String content) {
    setState(() {
      if (messages.isNotEmpty && messages.last.content == '...') {
        messages.removeLast();
      }
      messages.add(ChatMessage(role: 'assistant', content: content));
    });
    _scrollToBottom();
    _saveChatHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314), // Gemini Dark
      appBar: AppBar(
        title: const Text('ReCore AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF131314),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Clean Sidebar (Drawer)
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1F23),
        child: Column(
          children: [
            const DrawerHeader(child: Center(child: Text("ReCore History", style: TextStyle(color: Colors.white, fontSize: 20)))),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: const Text("Clear Chat", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => messages.clear());
                _saveChatHistory();
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
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                bool isUser = msg.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2D2E33) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Native Gemini-style Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ask ReCore...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1F23),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF4B91F7),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
          
          // The Hidden Engine
          const SizedBox(
            height: 1, 
            width: 1, 
            child: Opacity(opacity: 0, child: WebViewWidget(controller: _webViewController))
          ),
        ],
      ),
    );
  }

  // --- Logic Helpers ---
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('chat_history');
    if (stored != null) {
      setState(() => messages = stored.map((s) => ChatMessage.fromMap(jsonDecode(s))).toList());
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('chat_history', messages.map((m) => jsonEncode(m.toMap())).toList());
  }
}
