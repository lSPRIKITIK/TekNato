import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_screen.dart';
import 'chat_room_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final String myUserId = Supabase.instance.client.auth.currentUser!.id;
  final Color primaryGreen = const Color(0xFF33D985);

  late Future<Map<String, dynamic>?> _profileFuture;
  late Future<List<dynamic>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    _profileFuture = Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', widget.userId)
        .maybeSingle();

    _listingsFuture = Supabase.instance.client
        .from('listings')
        .select()
        .eq('seller_id', widget.userId)
        .order('created_at', ascending: false);
  }

  Future<void> _startGeneralChat(String username) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Find existing chat without a listing_id between these two users
      final existingChat = await Supabase.instance.client
          .from('chats')
          .select('id')
          .filter('listing_id', 'is', 'null')
          .or(
            'and(buyer_id.eq.$myUserId,seller_id.eq.${widget.userId}),and(buyer_id.eq.${widget.userId},seller_id.eq.$myUserId)',
          )
          .maybeSingle();

      dynamic chatId = existingChat?['id'];

      if (chatId == null) {
        final newChat = await Supabase.instance.client
            .from('chats')
            .insert({
              'buyer_id': myUserId,
              'seller_id': widget.userId,
              'listing_id': null,
            })
            .select('id')
            .single();
        chatId = newChat['id'];
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatId: chatId.toString(),
            listing: const {'title': 'Direct Conversation', 'price': ''},
            otherUserName: username,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = widget.userId == myUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = profileSnapshot.data;
          final username = profile?['username'] ?? 'User';
          final avatarUrl = profile?['avatar_url'];

          return Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).cardColor : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: 48,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isMe)
                      ElevatedButton.icon(
                        onPressed: () => _startGeneralChat(username),
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Message',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Listings Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Listings",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),

              // Listings Grid
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _listingsFuture,
                  builder: (context, listingsSnapshot) {
                    if (listingsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final listings = listingsSnapshot.data ?? [];
                    if (listings.isEmpty) {
                      return const Center(
                        child: Text(
                          'No listings published yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: listings.length,
                      itemBuilder: (context, index) {
                        final item = listings[index];
                        final bool isSold = item['status'] == 'sold';

                        return InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ListingDetailScreen(product: item),
                              ),
                            );
                            setState(() => _fetchUserData());
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Theme.of(context).cardColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey.shade900
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                        ),
                                        child: item['image_url'] != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(12),
                                                    ),
                                                child: ColorFiltered(
                                                  colorFilter: isSold
                                                      ? const ColorFilter.mode(
                                                          Colors.grey,
                                                          BlendMode.saturation,
                                                        )
                                                      : const ColorFilter.mode(
                                                          Colors.transparent,
                                                          BlendMode.multiply,
                                                        ),
                                                  child: Image.network(
                                                    item['image_url'],
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.image_not_supported,
                                                size: 48,
                                                color: isDark
                                                    ? Colors.grey.shade700
                                                    : Colors.grey.shade400,
                                              ),
                                      ),
                                      if (isSold)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(12),
                                                ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'SOLD',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₱${item['price']}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isSold
                                              ? Colors.grey
                                              : (isDark
                                                    ? Colors.white
                                                    : Colors.black),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['title'] ?? 'Unknown Item',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSold
                                              ? Colors.grey
                                              : (isDark
                                                    ? Colors.grey.shade300
                                                    : Colors.black87),
                                        ),
                                      ),
                                    ],
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
            ],
          );
        },
      ),
    );
  }
}
