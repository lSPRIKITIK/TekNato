import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_room_screen.dart';

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  late Future<List<dynamic>> _chatsFuture;
  late final RealtimeChannel _realtimeChannel;

  final String myUserId = Supabase.instance.client.auth.currentUser!.id;
  final Color primaryGreen = const Color(0xFF33D985);

  @override
  void initState() {
    super.initState();
    _chatsFuture = _fetchChats();

    _realtimeChannel = Supabase.instance.client.channel('inbox_updates')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chats',
        callback: (_) => _refreshInbox(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => _refreshInbox(),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_realtimeChannel);
    super.dispose();
  }

  Future<List<dynamic>> _fetchChats() async {
    return await Supabase.instance.client
        .from('chats')
        .select('''
          id,
          updated_at,
          listing_id,
          buyer_id,
          seller_id,
          listings (id, title, image_url, price, seller_id),
          buyer:profiles!buyer_id (username, avatar_url),
          seller:profiles!seller_id (username, avatar_url),
          messages (id, content, sender_id, is_read, created_at)
        ''')
        .or('buyer_id.eq.$myUserId,seller_id.eq.$myUserId')
        .order('updated_at', ascending: false);
  }

  Future<void> _refreshInbox() async {
    if (mounted) {
      setState(() {
        _chatsFuture = _fetchChats();
      });
    }
  }

  Future<void> _markAsReadAndNavigate(
    Map<String, dynamic> chat,
    Map<String, dynamic> otherUser,
  ) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chat['id'])
          .neq('sender_id', myUserId);
    } catch (e) {
      debugPrint('Read receipt update failed: $e');
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatId: chat['id'].toString(),
          listing: chat['listings'] ?? {},
          otherUserName: otherUser['username'] ?? 'User',
          otherUserAvatar:
              otherUser['avatar_url'], // Passes the avatar to the chat room
        ),
      ),
    );

    _refreshInbox();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inbox',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshInbox();
          await Future.delayed(const Duration(milliseconds: 600));
        },
        color: primaryGreen,
        child: FutureBuilder<List<dynamic>>(
          future: _chatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final chats = snapshot.data ?? [];
            if (chats.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  const Center(
                    child: Text(
                      'No messages yet. Start shopping!',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];

                // 1. Properly identify the other user
                final bool amIBuyer = chat['buyer_id'] == myUserId;
                final otherUser = amIBuyer ? chat['seller'] : chat['buyer'];

                // 2. Setup the Inbox Avatar (Listing image if market chat, Profile image if direct)
                final bool isListingChat =
                    chat['listing_id'] != null && chat['listings'] != null;
                final String? avatarUrl = isListingChat
                    ? chat['listings']['image_url']
                    : otherUser['avatar_url'];
                final String username = otherUser['username'] ?? 'Unknown User';

                final messages = (chat['messages'] as List<dynamic>? ?? []);
                messages.sort(
                  (a, b) => b['created_at'].compareTo(a['created_at']),
                );

                final lastMessage = messages.isNotEmpty ? messages.first : null;
                final lastMessageText = lastMessage != null
                    ? lastMessage['content']
                    : 'No messages yet';

                final hasUnread =
                    lastMessage != null &&
                    lastMessage['sender_id'] != myUserId &&
                    lastMessage['is_read'] == false;

                final titleStyle = TextStyle(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                );

                final subtitleStyle = TextStyle(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  color: hasUnread
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                );

                return InkWell(
                  onTap: () => _markAsReadAndNavigate(chat, otherUser),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: hasUnread
                          ? (isDark
                                ? Colors.grey.shade900
                                : Colors.blue.shade50.withOpacity(0.3))
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Icon(
                                  isListingChat
                                      ? Icons.shopping_bag_outlined
                                      : Icons.person,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username, style: titleStyle),
                              const SizedBox(height: 4),
                              Text(
                                lastMessageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                            ],
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
