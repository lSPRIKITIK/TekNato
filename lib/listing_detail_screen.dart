import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_room_screen.dart';
import 'create_listing_screen.dart';
import 'public_profile_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ListingDetailScreen({super.key, required this.product});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<Map<String, dynamic>?> _sellerProfileFuture;

  @override
  void initState() {
    super.initState();
    _fetchSeller();
  }

  void _fetchSeller() {
    _sellerProfileFuture = Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', widget.product['seller_id'])
        .maybeSingle();
  }

  Future<void> _deleteListing(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('listings')
            .delete()
            .eq('id', widget.product['id']);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listing deleted.')));
        Navigator.pop(context, true);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF33D985);
    final String myUserId = Supabase.instance.client.auth.currentUser!.id;
    final bool isMyListing = widget.product['seller_id'] == myUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSold = widget.product['status'] == 'sold';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Listing Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 300,
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  child: widget.product['image_url'] != null
                      ? ColorFiltered(
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
                            widget.product['image_url'],
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: isDark ? Colors.grey.shade700 : Colors.grey,
                        ),
                ),
                if (isSold)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SOLD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₱${widget.product['price']}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product['title'] ?? 'Unknown Item',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildTag(
                        Icons.category_outlined,
                        widget.product['category'] ?? 'Uncategorized',
                        isDark,
                      ),
                      _buildTag(
                        Icons.info_outline,
                        widget.product['condition'] ?? 'Unknown',
                        isDark,
                      ),
                      _buildTag(
                        Icons.location_on_outlined,
                        widget.product['location'] ?? 'No location provided',
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Divider(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<Map<String, dynamic>?>(
                    future: _sellerProfileFuture,
                    builder: (context, snapshot) {
                      final seller = snapshot.data;
                      final sellerName = seller?['username'] ?? 'Seller';
                      final avatarUrl = seller?['avatar_url'];

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublicProfileScreen(
                                userId: widget.product['seller_id'],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Theme.of(context).cardColor
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Icon(
                                        Icons.person,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Listed by',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      sellerName,
                                      style: const TextStyle(
                                        fontSize: 16,
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
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product['description'] ?? 'No description provided.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isMyListing
              // Seller gets a Column of 3 buttons: Mark as Sold, Edit, and Delete
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                        final newStatus = isSold ? 'available' : 'sold';
                        try {
                          await Supabase.instance.client
                              .from('listings')
                              .update({'status': newStatus})
                              .eq('id', widget.product['id']);
                          if (!context.mounted) return;
                          Navigator.pop(context); // Close loading dialog
                          Navigator.pop(
                            context,
                            true,
                          ); // Go back and trigger refresh
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSold
                                    ? 'Item is now Available'
                                    : 'Item marked as Sold!',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSold
                            ? Colors.grey.shade600
                            : primaryGreen,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isSold ? 'Mark as Available' : 'Mark as Sold',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _deleteListing(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final shouldRefresh = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateListingScreen(
                                    existingListing: widget.product,
                                  ),
                                ),
                              );
                              if (shouldRefresh == true && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryGreen),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 16,
                                color: primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              // Buyer sees "Message Seller" or "Item Sold"
              : ElevatedButton(
                  onPressed: isSold
                      ? null
                      : () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          try {
                            final existingChat = await Supabase.instance.client
                                .from('chats')
                                .select('id')
                                .eq('listing_id', widget.product['id'])
                                .eq('buyer_id', myUserId)
                                .maybeSingle();

                            dynamic chatId = existingChat?['id'];
                            if (chatId == null) {
                              final newChat = await Supabase.instance.client
                                  .from('chats')
                                  .insert({
                                    'listing_id': widget.product['id'],
                                    'buyer_id': myUserId,
                                    'seller_id': widget.product['seller_id'],
                                  })
                                  .select('id')
                                  .single();
                              chatId = newChat['id'];
                            }

                            if (!context.mounted) return;
                            final sellerProfile = await Supabase.instance.client
                                .from('profiles')
                                .select('username')
                                .eq('id', widget.product['seller_id'])
                                .maybeSingle();
                            final sellerName =
                                sellerProfile?['username'] ?? 'Seller';

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomScreen(
                                  chatId: chatId.toString(),
                                  listing: widget.product,
                                  otherUserName: sellerName,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isSold ? 'Item Sold' : 'Message Seller',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey.shade400 : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
