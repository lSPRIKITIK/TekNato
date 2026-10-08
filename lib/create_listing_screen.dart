import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CreateListingScreen extends StatefulWidget {
  final Map<String, dynamic>? existingListing;

  const CreateListingScreen({super.key, this.existingListing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedCategory = 'Laptops';
  String _selectedCondition = 'Used';
  bool _isLoading = false;
  File? _imageFile;

  final Color primaryGreen = const Color(0xFF33D985);
  final List<String> _categories = [
    'Laptops',
    'Phones',
    'Components',
    'Accessories',
  ];
  final List<String> _conditions = ['New', 'Like New', 'Used', 'For Parts'];

  @override
  void initState() {
    super.initState();
    if (widget.existingListing != null) {
      _titleController.text = widget.existingListing!['title'];
      _priceController.text = widget.existingListing!['price'].toString();
      _descController.text = widget.existingListing!['description'];
      _locationController.text = widget.existingListing!['location'] ?? '';

      if (_categories.contains(widget.existingListing!['category'])) {
        _selectedCategory = widget.existingListing!['category'];
      }
      if (_conditions.contains(widget.existingListing!['condition'])) {
        _selectedCondition = widget.existingListing!['condition'];
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null && widget.existingListing == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      String? finalImageUrl = widget.existingListing?['image_url'];

      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';

        await Supabase.instance.client.storage
            .from('listings')
            .upload(filePath, _imageFile!);
        finalImageUrl = Supabase.instance.client.storage
            .from('listings')
            .getPublicUrl(filePath);
      }

      final data = {
        'title': _titleController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'condition': _selectedCondition,
        'image_url': finalImageUrl,
      };

      if (widget.existingListing == null) {
        data['seller_id'] = user.id;
        await Supabase.instance.client.from('listings').insert(data);
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Item listed!')));
      } else {
        await Supabase.instance.client
            .from('listings')
            .update(data)
            .eq('id', widget.existingListing!['id']);
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Item updated!')));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingListing != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputDecoration = InputDecoration(
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
        ),
      ),
      labelStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Listing' : 'Sell an Item',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : (isEditing &&
                          widget.existingListing!['image_url'] != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.existingListing!['image_url'],
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 48,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: inputDecoration.copyWith(labelText: 'Listing Title'),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: inputDecoration.copyWith(
                labelText: 'Price (₱)',
                prefixText: '₱ ',
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                if (double.tryParse(val) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
              decoration: inputDecoration.copyWith(labelText: 'Category'),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCondition,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
              decoration: inputDecoration.copyWith(labelText: 'Condition'),
              items: _conditions
                  .map(
                    (cond) => DropdownMenuItem(value: cond, child: Text(cond)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCondition = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: inputDecoration.copyWith(
                labelText: 'Location',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: inputDecoration.copyWith(labelText: 'Description'),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEditing ? 'Save Changes' : 'Publish Listing',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
