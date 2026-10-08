import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final String myUserId = Supabase.instance.client.auth.currentUser!.id;
  final Color primaryGreen = const Color(0xFF33D985);

  bool _pushNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await Supabase.instance.client
          .from('user_settings')
          .select()
          .eq('user_id', myUserId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _pushNotifications = data['push_notifications'] ?? true;
        });
        ref.read(darkModeProvider.notifier).state = data['dark_mode'] ?? false;
      } else {
        await Supabase.instance.client.from('user_settings').insert({
          'user_id': myUserId,
          'push_notifications': true,
          'dark_mode': false,
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (key == 'dark_mode') {
      ref.read(darkModeProvider.notifier).state = value;
    } else if (key == 'push_notifications') {
      setState(() => _pushNotifications = value);
    }

    try {
      await Supabase.instance.client
          .from('user_settings')
          .update({key: value, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', myUserId);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update setting: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(darkModeProvider);

    return Scaffold(
      // Removed hardcoded background color
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        // Removed hardcoded text and icon colors
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Receive alerts for messages and updates',
                  ),
                  value: _pushNotifications,
                  activeColor: primaryGreen,
                  onChanged: (val) => _updateSetting('push_notifications', val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Switch app theme to dark appearance'),
                  value: isDarkMode,
                  activeColor: primaryGreen,
                  onChanged: (val) => _updateSetting('dark_mode', val),
                ),
              ],
            ),
    );
  }
}
