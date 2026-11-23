import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/data/repositories/item_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostItemScreen extends StatefulWidget {
  const PostItemScreen({super.key});

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _heldAtController = TextEditingController();
  late final _repository = ItemRepository();
  final _imagePicker = ImagePicker();

  String _selectedType = AppConstants.itemTypeLost;
  String _selectedCategory = AppConstants.categories[0];
  XFile? _imageFile;
  Uint8List? _imageBytes;
  DateTime _itemDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _heldAtController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _itemDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selectedDate != null) {
      setState(() => _itemDate = selectedDate);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
      );
      if (image != null && mounted) {
        final bytes = await _compressImage(await image.readAsBytes());
        setState(() {
          _imageFile = image;
          _imageBytes = bytes;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('PostItemScreen: Image selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final detail = error.toString().replaceFirst('Bad state: ', '');
        _showMessage('Could not prepare that photo. $detail');
      }
    }
  }

  Future<Uint8List> _compressImage(Uint8List originalBytes) async {
    var maxDimension = 1600;
    for (final quality in [85, 75, 65, 55, 45, 35, 25]) {
      final bytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (bytes.length < AppConstants.maxItemImageBytes) return bytes;
      maxDimension = (maxDimension * 0.8).round();
    }
    throw StateError(
        'Could not compress that photo below 300 KB. Choose another.');
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again before posting an item.');
      return;
    }

    setState(() => _isSubmitting = true);
    String? uploadedImagePath;
    var isUploadingImage = false;
    try {
      if (_imageFile != null) {
        isUploadingImage = true;
        uploadedImagePath = await _repository.uploadItemImage(
          userId: user.id,
          bytes: _imageBytes!,
        );
        isUploadingImage = false;
      }
      await _repository.createItem(
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        location: _locationController.text.trim(),
        date: _itemDate,
        postedBy: user.id,
        imagePath: uploadedImagePath,
        heldAt: _selectedType == AppConstants.itemTypeFound &&
                _heldAtController.text.trim().isNotEmpty
            ? _heldAtController.text.trim()
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint(
        'PostItemScreen: Failed to '
        '${isUploadingImage ? 'upload the photo' : 'post the item'}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _removeUploadedImage(uploadedImagePath);
      if (mounted) {
        final detail = error.toString().replaceFirst('Exception: ', '');
        final action = isUploadingImage ? 'upload the photo' : 'post your item';
        _showMessage('Could not $action. $detail');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _removeUploadedImage(String? imagePath) async {
    if (imagePath == null) return;
    try {
      await _repository.deleteItemImage(imagePath);
    } catch (error, stackTrace) {
      debugPrint(
          'PostItemScreen: Failed to remove orphaned item image: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'What would you like to post?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: AppConstants.itemTypeLost,
                  label: Text('Lost'),
                  icon: Icon(Icons.search),
                ),
                ButtonSegment(
                  value: AppConstants.itemTypeFound,
                  label: Text('Found'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: _isSubmitting
                  ? null
                  : (selection) =>
                      setState(() => _selectedType = selection.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g. Black backpack',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                counterText: '',
              ),
              maxLength: 100,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an item name.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: AppConstants.categories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickImage,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(_imageFile == null
                  ? 'Add a photo (optional)'
                  : 'Change photo'),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 200,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _imageFile = null;
                            _imageBytes = null;
                          }),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove photo'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Add details that can help identify the item',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLength: 2000,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Add a description.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _selectedType == AppConstants.itemTypeLost
                    ? 'Where was it last seen?'
                    : 'Where was it found?',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              maxLength: 300,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a location.'
                  : null,
            ),
            if (_selectedType == AppConstants.itemTypeFound) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _heldAtController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Where is it being held? (optional)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _selectDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                '${_selectedType == AppConstants.itemTypeLost ? 'Date lost' : 'Date found'}: '
                '${MaterialLocalizations.of(context).formatMediumDate(_itemDate)}',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish),
              label: Text(_isSubmitting ? 'Posting...' : 'Post Item'),
            ),
          ],
        ),
      ),
    );
  }
}
