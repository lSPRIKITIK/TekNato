import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> listing;
  final String otherUserName;
  final String? otherUserAvatar; // ADDED: To receive the avatar from Inbox

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.listing,
    required this.otherUserName,
    this.otherUserAvatar, // ADDED
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final String myUserId = Supabase.instance.client.auth.currentUser!.id;
  final Color primaryGreen = const Color(0xFF33D985);

  late Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at', ascending: true);

    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    await Supabase.instance.client
        .from('messages')
        .update({'is_read': true})
        .eq('chat_id', widget.chatId)
        .neq('sender_id', myUserId)
        .eq('is_read', false);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await Supabase.instance.client.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': myUserId,
        'content': text,
        'is_read': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasListingId = widget.listing['id'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.otherUserName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 1,
        shadowColor: isDark ? Colors.black : Colors.grey.shade200,
      ),
      body: Column(
        children: [
          if (hasListingId)
            Material(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ListingDetailScreen(product: widget.listing),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.listing['image_url'] != null
                            ? Image.network(
                                widget.listing['image_url'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                child: Icon(
                                  Icons.image,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.listing['title'] ?? 'Item',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.listing['price'] != null &&
                                widget.listing['price'].toString().isNotEmpty)
                              Text(
                                '₱${widget.listing['price']}',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == myUserId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        // Align my messages to the right, others to the left
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Show avatar ONLY if it's the other person's message
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              backgroundImage: widget.otherUserAvatar != null
                                  ? NetworkImage(widget.otherUserAvatar!)
                                  : null,
                              child: widget.otherUserAvatar == null
                                  ? Icon(
                                      Icons.person,
                                      size: 16,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                          ],

                          // The Message Bubble
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? primaryGreen
                                    : (isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(20)
                                    .copyWith(
                                      bottomRight: isMe
                                          ? const Radius.circular(0)
                                          : const Radius.circular(20),
                                      bottomLeft: !isMe
                                          ? const Radius.circular(0)
                                          : const Radius.circular(20),
                                    ),
                              ),
                              child: Text(
                                msg['content'],
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isMe
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: primaryGreen,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
