import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:animations/animations.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:iconsax/iconsax.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          background: const Color(0xFF0A0A0F),
          surface: const Color(0xFF161622),
        ),
      ),
      home: const MainLayout(),
    );
  }
}

// ==================== DATA MODELS ====================
class Chat {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int messageCount;
  final String? lastMessage;

  Chat({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.messageCount = 0,
    this.lastMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'messageCount': messageCount,
    'lastMessage': lastMessage,
  };

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'],
    title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    messageCount: json['messageCount'] ?? 0,
    lastMessage: json['lastMessage'],
  );
}

class Message {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final String chatId;

  const Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.chatId,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'isError': isError,
    'chatId': chatId,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    chatId: json['chatId'],
    isError: json['isError'] ?? false,
  );
}

// ==================== MAIN LAYOUT ====================
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;
  bool _isSidebarVisible = false;
  int _currentPageIndex = 0;
  
  final List<Widget> _pages = [
    const AIChatScreen(),
    const SettingsScreen(),
    Container(color: Colors.blue), // Placeholder for other pages
  ];

  @override
  void initState() {
    super.initState();
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.fastEaseInToSlowEaseOut,
    );
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
      if (_isSidebarVisible) {
        _sidebarAnimationController.forward();
      } else {
        _sidebarAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Main Content
          Positioned.fill(
            child: _pages[_currentPageIndex],
          ),

          // Sidebar Overlay (when open on mobile)
          if (_isSidebarVisible && MediaQuery.of(context).size.width < 768)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Sidebar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastEaseInToSlowEaseOut,
            left: _isSidebarVisible ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child: Material(
              elevation: 16,
              color: const Color(0xFF161622),
              child: ChatHistorySidebar(
                onChatSelected: (chat) {
                  _toggleSidebar();
                  // Handle chat selection
                },
                onNewChat: () {
                  _toggleSidebar();
                  // Handle new chat
                },
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar (for mobile)
      bottomNavigationBar: MediaQuery.of(context).size.width < 768
          ? Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    _BottomNavItem(
                      icon: Iconsax.message_text,
                      label: 'Chat',
                      isActive: _currentPageIndex == 0,
                      onTap: () => setState(() => _currentPageIndex = 0),
                    ),
                    _BottomNavItem(
                      icon: Iconsax.setting,
                      label: 'Settings',
                      isActive: _currentPageIndex == 1,
                      onTap: () => setState(() => _currentPageIndex = 1),
                    ),
                    _BottomNavItem(
                      icon: Iconsax.user,
                      label: 'Profile',
                      isActive: _currentPageIndex == 2,
                      onTap: () => setState(() => _currentPageIndex = 2),
                    ),
                  ],
                ),
              ),
            )
          : null,

      // Floating Action Button for New Chat
      floatingActionButton: ScaleTransition(
        scale: _sidebarAnimation,
        child: FloatingActionButton(
          onPressed: () {
            Haptics.selectionClick();
            // Handle new chat
          },
          backgroundColor: const Color(0xFF6366F1),
          child: const Icon(Iconsax.add, size: 24),
        ),
      ),
    );
  }
}

// ==================== CHAT HISTORY SIDEBAR ====================
class ChatHistorySidebar extends StatefulWidget {
  final Function(Chat) onChatSelected;
  final Function() onNewChat;

  const ChatHistorySidebar({
    super.key,
    required this.onChatSelected,
    required this.onNewChat,
  });

  @override
  State<ChatHistorySidebar> createState() => _ChatHistorySidebarState();
}

class _ChatHistorySidebarState extends State<ChatHistorySidebar> {
  List<Chat> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate load
    setState(() {
      _chats = [
        Chat(
          id: '1',
          title: 'Flutter App Development',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now(),
          messageCount: 24,
          lastMessage: 'How to implement animations?',
        ),
        Chat(
          id: '2',
          title: 'AI Integration Ideas',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
          messageCount: 42,
          lastMessage: 'Let me explain the architecture...',
        ),
        Chat(
          id: '3',
          title: 'Web Development',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          messageCount: 18,
          lastMessage: 'React vs Vue comparison',
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    'AI',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assistant',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Online',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // New Chat Button
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Haptics.selectionClick();
                widget.onNewChat();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.add, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'New Chat',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat List Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Recent Chats',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Iconsax.search_normal,
                    color: Colors.white.withOpacity(0.6),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Chat List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      return Dismissible(
                        key: ValueKey(chat.id),
                        background: Container(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Iconsax.trash,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        onDismissed: (direction) {
                          Haptics.heavyImpact();
                          setState(() {
                            _chats.removeAt(index);
                          });
                        },
                        child: ChatListItem(
                          chat: chat,
                          onTap: () => widget.onChatSelected(chat),
                          isActive: index == 0,
                        ),
                      );
                    },
                  ),
          ),

          // Sidebar Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Iconsax.setting, color: Colors.white70),
                  title: Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Haptics.selectionClick();
                    // Navigate to settings
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Iconsax.help, color: Colors.white70),
                  title: Text(
                    'Help & Feedback',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Haptics.selectionClick();
                    // Show help
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CHAT LIST ITEM ====================
class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  final bool isActive;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isActive
            ? const Color(0xFF6366F1).withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF6366F1)
                            : Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        chat.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      _formatTime(chat.updatedAt ?? chat.createdAt),
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (chat.lastMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    chat.lastMessage!,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Iconsax.message,
                      size: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${chat.messageCount} messages',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

// ==================== SETTINGS SCREEN ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _hapticFeedback = true;
  bool _streamingResponses = true;
  double _temperature = 0.7;
  String _selectedModel = 'gemini-pro';

  final List<String> _models = [
    'gemini-pro',
    'gemini-pro-vision',
    'llama-3',
    'gpt-4',
    'claude-3',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customize your AI experience',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),

              // Settings Cards
              Expanded(
                child: ListView(
                  children: [
                    _SettingsCard(
                      icon: Iconsax.moon,
                      title: 'Appearance',
                      children: [
                        _SettingsSwitch(
                          title: 'Dark Mode',
                          value: _darkMode,
                          onChanged: (value) {
                            Haptics.selectionClick();
                            setState(() => _darkMode = value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _SettingsCard(
                      icon: Iconsax.cpu,
                      title: 'AI Settings',
                      children: [
                        _SettingsDropdown(
                          title: 'Model',
                          value: _selectedModel,
                          options: _models,
                          onChanged: (value) {
                            Haptics.selectionClick();
                            setState(() => _selectedModel = value!);
                          },
                        ),
                        const SizedBox(height: 16),
                        _SettingsSlider(
                          title: 'Temperature: ${_temperature.toStringAsFixed(1)}',
                          value: _temperature,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: (value) {
                            setState(() => _temperature = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _SettingsSwitch(
                          title: 'Streaming Responses',
                          value: _streamingResponses,
                          onChanged: (value) {
                            Haptics.selectionClick();
                            setState(() => _streamingResponses = value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _SettingsCard(
                      icon: Iconsax.vibrate,
                      title: 'Interaction',
                      children: [
                        _SettingsSwitch(
                          title: 'Haptic Feedback',
                          value: _hapticFeedback,
                          onChanged: (value) {
                            Haptics.selectionClick();
                            setState(() => _hapticFeedback = value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _SettingsCard(
                      icon: Iconsax.shield_tick,
                      title: 'Privacy',
                      children: [
                        ListTile(
                          leading: const Icon(Iconsax.trash, color: Colors.white70),
                          title: Text(
                            'Clear Chat History',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          trailing: const Icon(Iconsax.arrow_right_3, color: Colors.white30),
                          onTap: () {
                            Haptics.heavyImpact();
                            _showClearConfirmation();
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Logout Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Haptics.heavyImpact();
                          // Handle logout
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Iconsax.logout, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.warning_2,
                color: Color(0xFFEF4444),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Clear All Chats?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This will permanently delete all your chat history. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.white.withOpacity(0.1),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Haptics.heavyImpact();
                      Navigator.pop(context);
                      // Clear all chats
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SETTINGS COMPONENTS ====================
class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF6366F1), size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6366F1),
        ),
      ],
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _SettingsDropdown({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E2E),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                ),
                onChanged: onChanged,
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                icon: const Icon(
                  Iconsax.arrow_down_1,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SettingsSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              disabledThumbRadius: 6,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 16,
            ),
            activeTrackColor: const Color(0xFF6366F1),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: const Color(0xFF6366F1),
            overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ==================== AI CHAT SCREEN (From previous code) ====================
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  // Keep your existing chat screen implementation here
  // Just replace with your WebView integration from previous code
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Column(
        children: [
          // App bar
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161622).withOpacity(0.8),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Your existing chat UI
                Text(
                  'AI Chat',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Chat implementation from previous code goes here',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== BOTTOM NAV ITEM ====================
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? const Color(0xFF6366F1) : Colors.white70,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isActive ? const Color(0xFF6366F1) : Colors.white70,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
