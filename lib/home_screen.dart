import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_tab_screen.dart';
import 'marketplace_screen.dart';
import 'forum_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _hasUnreadMessages = false;

  late final RealtimeChannel _inboxChannel;
  final Color primaryGreen = const Color(0xFF33D985);
  final Color linkBlue = const Color(0xFF1877F2);
  final String myUserId = Supabase.instance.client.auth.currentUser!.id;

  final List<Widget> _screens = <Widget>[
    const MarketplaceScreen(),
    const ForumScreen(),
    const ChatTabScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUnreadMessages();

    // Listen globally for any new messages while using the app
    _inboxChannel = Supabase.instance.client.channel('global_inbox_badge')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => _checkUnreadMessages(),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Supabase.instance.client.removeChannel(_inboxChannel);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUnreadMessages(); // Re-check instantly when app wakes up
    }
  }

  Future<void> _checkUnreadMessages() async {
    try {
      // 1. Get all chats this user is a part of
      final chats = await Supabase.instance.client
          .from('chats')
          .select('id')
          .or('buyer_id.eq.$myUserId,seller_id.eq.$myUserId');

      if (chats.isEmpty) {
        if (mounted) setState(() => _hasUnreadMessages = false);
        return;
      }

      final chatIds = chats.map((c) => c['id']).toList();

      // 2. Check if ANY message in those chats is unread and sent by someone else
      final unreadResponse = await Supabase.instance.client
          .from('messages')
          .select('id')
          .inFilter('chat_id', chatIds)
          .neq('sender_id', myUserId)
          .eq('is_read', false)
          .limit(1);

      if (mounted) {
        setState(() {
          _hasUnreadMessages = unreadResponse.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Badge error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE0E0E0);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderColor, height: 1.0),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Image.asset(
            'assets/images/logo_icon.png',
            fit: BoxFit.contain,
          ),
        ),
        title: Text(
          'TekNato',
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: linkBlue, size: 28),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: primaryGreen,
        unselectedItemColor: isDark
            ? Colors.grey.shade500
            : Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Marketplace',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Forum',
          ),
          BottomNavigationBarItem(
            // Wrapped the chat icon in a Notification Badge
            icon: Badge(
              isLabelVisible: _hasUnreadMessages,
              backgroundColor: primaryGreen,
              smallSize: 12, // The green dot size
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: _hasUnreadMessages,
              backgroundColor: primaryGreen,
              smallSize: 12,
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
