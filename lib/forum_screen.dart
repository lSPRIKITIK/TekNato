import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'public_profile_screen.dart'; // Added Import

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> with WidgetsBindingObserver {
  late Future<List<dynamic>> _postsFuture;
  final Color linkBlue = const Color(0xFF1877F2);
  final Color primaryGreen = const Color(0xFF33D985);
  final String myUserId = Supabase.instance.client.auth.currentUser!.id;

  late final RealtimeChannel _realtimeChannel;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _postsFuture = _fetchPosts();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });

    _realtimeChannel = Supabase.instance.client.channel('forum_updates')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'posts',
        callback: (_) => _refreshFeed(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'comments',
        callback: (_) => _refreshFeed(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'post_upvotes',
        callback: (_) => _refreshFeed(),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Supabase.instance.client.removeChannel(_realtimeChannel);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFeed();
    }
  }

  Future<List<dynamic>> _fetchPosts() async {
    return await Supabase.instance.client
        .from('posts')
        .select(
          '*, profiles!posts_user_id_fkey(username, avatar_url), post_upvotes(user_id), comments(id)',
        )
        .order('created_at', ascending: false);
  }

  Future<void> _refreshFeed() async {
    if (mounted) {
      setState(() {
        _postsFuture = _fetchPosts();
      });
    }
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
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
        await Supabase.instance.client.from('posts').delete().eq('id', postId);
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Post deleted.')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleUpvote(String postId, bool isCurrentlyUpvoted) async {
    try {
      if (isCurrentlyUpvoted) {
        await Supabase.instance.client.from('post_upvotes').delete().match({
          'post_id': postId,
          'user_id': myUserId,
        });
      } else {
        await Supabase.instance.client.from('post_upvotes').insert({
          'post_id': postId,
          'user_id': myUserId,
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString);
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey.shade100,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: linkBlue,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search discussions...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFeed,
              color: linkBlue,
              child: FutureBuilder<List<dynamic>>(
                future: _postsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(child: Text('Error: ${snapshot.error}'));

                  final posts = snapshot.data ?? [];
                  final filteredPosts = posts.where((post) {
                    final title = (post['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    return _searchQuery.isEmpty || title.contains(_searchQuery);
                  }).toList();

                  if (filteredPosts.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                        ),
                        Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No discussions found matching "$_searchQuery".'
                                : 'No posts yet. Be the first to start a discussion!',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = filteredPosts[index];
                      final author = post['profiles'];
                      final username = author?['username'] ?? 'Unknown User';
                      final avatarUrl = author?['avatar_url'];
                      final isMyPost = post['user_id'] == myUserId;

                      final upvotes =
                          post['post_upvotes'] as List<dynamic>? ?? [];
                      final comments = post['comments'] as List<dynamic>? ?? [];
                      final isUpvoted = upvotes.any(
                        (vote) => vote['user_id'] == myUserId,
                      );

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isDark
                            ? Theme.of(context).cardColor
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(
                                  post: post,
                                  author: author ?? {},
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Clickable User Profile Area
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PublicProfileScreen(
                                                  userId: post['user_id'],
                                                ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade200,
                                            backgroundImage: avatarUrl != null
                                                ? NetworkImage(avatarUrl)
                                                : null,
                                            child: avatarUrl == null
                                                ? Icon(
                                                    Icons.person,
                                                    size: 20,
                                                    color: isDark
                                                        ? Colors.grey.shade400
                                                        : Colors.grey,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            username,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(post['created_at']),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isMyPost) ...[
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.more_vert,
                                          size: 18,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'delete')
                                            _deletePost(post['id']);
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Delete Post',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  post['title'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post['content'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.black87,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _toggleUpvote(post['id'], isUpvoted),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isUpvoted
                                                ? Icons.thumb_up
                                                : Icons.thumb_up_alt_outlined,
                                            color: isUpvoted
                                                ? linkBlue
                                                : (isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${upvotes.length}',
                                            style: TextStyle(
                                              color: isUpvoted
                                                  ? linkBlue
                                                  : (isDark
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade700),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.mode_comment_outlined,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${comments.length}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
