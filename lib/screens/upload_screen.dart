import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _api = ApiService();
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _tagsCtl = TextEditingController();
  Uint8List? _imageBytes;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _upload() async {
    if (_imageBytes == null || _titleCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image and title')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      await _api.createDesign(
        title: _titleCtl.text.trim(),
        description: _descCtl.text.trim(),
        imageBase64: base64Encode(_imageBytes!),
        tags: _tagsCtl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Design shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _titleCtl.clear();
        _descCtl.clear();
        _tagsCtl.clear();
        setState(() => _imageBytes = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _tagsCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share Design',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Share your embroidery design with the community',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),

            // Image picker area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Tap to select design image',
                              style: TextStyle(color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          Text('PNG, JPG up to 10MB',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _titleCtl,
              decoration: const InputDecoration(hintText: 'Design Title'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtl,
              decoration: const InputDecoration(hintText: 'Description (optional)'),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsCtl,
              decoration: const InputDecoration(
                hintText: 'Tags (comma separated)',
                helperText: 'e.g. floral, peacock, geometric',
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _upload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(_isUploading ? 'Sharing...' : 'Share Design'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
