import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const MaterialApp(home: MyApp(), debugShowCheckedModeBanner: false));
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
          // GEMINI TRICK: Hide the website's own UI so it doesn't look "dirty"
          _webViewController.runJavaScript('''
            document.querySelector('header')?.style.setProperty('display', 'none', 'important');
            document.querySelector('.sidebar')?.style.setProperty('display', 'none', 'important');
            document.querySelector('nav')?.style.setProperty('display', 'none', 'important');
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

    // The "API" Call: Injects text into the hidden web engine
    _webViewController.runJavaScript('''
      (function() {
        var input = document.querySelector('textarea') || document.querySelector('input[type="text"]');
        var btn = document.querySelector('button[type="submit"]') || document.querySelector('.send-button');
        if(input) {
           input.value = ${jsonEncode(text)};
           input.dispatchEvent(new Event('input', { bubbles: true }));
        }
        if(btn) btn.click();
        
        // Listen for response (This needs to match ReCore's HTML structure)
        var checkResponse = setInterval(() => {
          var lastMsg = document.querySelector('.ai-message-content'); // REPLACE with actual class
          if(lastMsg && lastMsg.innerText.length > 0) {
            window.FlutterBridge.postMessage(lastMsg.innerText);
            clearInterval(checkResponse);
          }
        }, 2000);
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

  // UI - Chat Bubble Style
  Widget _buildMessage(ChatMessage msg) {
    bool isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF37393F) : const Color(0xFF1E1F23),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
        ),
        child: MarkdownBody(
          data: msg.content,
          styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314), // Gemini Dark Theme
      appBar: AppBar(
        title: const Text('ReCore AI', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // SIDEBAR (Drawer) - Stays hidden like Gemini until swiped or clicked
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1F23),
        child: Column(
          children: [
            const DrawerHeader(child: Center(child: Text("History", style: TextStyle(color: Colors.white, fontSize: 24)))),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text("New Chat", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => messages.clear());
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
              itemCount: messages.length,
              itemBuilder: (context, index) => _buildMessage(messages[index]),
            ),
          ),
          // NATIVE INPUT BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
                )
              ],
            ),
          ),
          // HIDDEN ENGINE
          const SizedBox(height: 1, width: 1, child: Opacity(opacity: 0, child: WebViewWidget(controller: _webViewController))),
        ],
      ),
    );
  }

  // Shared Prefs Helper Methods
  Future<void> _loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? stored = prefs.getStringList('chat_history');
    if (stored != null) setState(() => messages = stored.map((s) => ChatMessage.fromMap(jsonDecode(s))).toList());
  }

  Future<void> _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('chat_history', messages.map((m) => jsonEncode(m.toMap())).toList());
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }
}
