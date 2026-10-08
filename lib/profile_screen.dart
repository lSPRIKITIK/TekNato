import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_gate.dart';
import 'setting_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  final TextEditingController _usernameController = TextEditingController();
  DateTime? _selectedDate;
  String? _avatarUrl;
  File? _imageFile;
  bool _isLoading = true;
  bool _isSaving = false;

  final Color primaryGreen = const Color(0xFF33D985);

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, date_of_birth, avatar_url')
          .eq('id', user!.id)
          .maybeSingle();

      if (data != null) {
        _usernameController.text = data['username'] ?? '';
        _avatarUrl = data['avatar_url'];
        if (data['date_of_birth'] != null) {
          _selectedDate = DateTime.parse(data['date_of_birth']);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryGreen,
                    onPrimary: Colors.white,
                    surface: Colors.grey.shade900,
                  )
                : ColorScheme.light(
                    primary: primaryGreen,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate)
      setState(() => _selectedDate = picked);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String? finalAvatarUrl = _avatarUrl;

      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user!.id}/$fileName';

        await Supabase.instance.client.storage
            .from('avatars')
            .upload(filePath, _imageFile!);
        finalAvatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(filePath);
      }

      final updateData = {
        'username': _usernameController.text.trim(),
        if (_selectedDate != null)
          'date_of_birth': _selectedDate!.toIso8601String().split('T')[0],
        if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
      };

      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', user!.id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine current theme state
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic colors based on theme
    final fieldFillColor = isDark ? Colors.grey.shade900 : Colors.white;
    final readOnlyFillColor = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade100;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!) as ImageProvider
                              : null,
                          child:
                              (_imageFile == null &&
                                  (_avatarUrl == null || _avatarUrl!.isEmpty))
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade900
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: false,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: user?.email ?? 'No email found',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                      filled: true,
                      fillColor: readOnlyFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryGreen, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: fieldFillColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate != null
                                ? _selectedDate!.toIso8601String().split('T')[0]
                                : 'Select your birthdate',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedDate != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  Divider(height: 48, color: borderColor),

                  ListTile(
                    leading: Icon(
                      Icons.settings_outlined,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    title: const Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade700,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
    );
  }
}
