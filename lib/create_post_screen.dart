import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  final Color linkBlue = const Color(0xFF1877F2);

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out both fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final myUserId = Supabase.instance.client.auth.currentUser!.id;

      await Supabase.instance.client.from('posts').insert({
        'user_id': myUserId,
        'title': title,
        'content': content,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check Dark Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Removed hardcoded backgroundColor: Colors.white
      appBar: AppBar(
        elevation: 0,
        // Removed hardcoded iconTheme and text colors
        title: const Text(
          'Create a Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Post',
                    style: TextStyle(
                      color: linkBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.white
                    : Colors.black, // Dynamic text color
              ),
              decoration: InputDecoration(
                hintText: 'An interesting title',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                ),
              ),
            ),
            Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ), // Dynamic divider
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDark
                      ? Colors.white
                      : Colors.black, // Dynamic text color
                ),
                decoration: InputDecoration(
                  hintText: 'What are your thoughts?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
