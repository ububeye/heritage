import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;

  CloudinaryService({
    this.cloudName = 'dpmcnfbpb',
    this.uploadPreset = 'stone_town_unsigned',
  });

  /// Pick single image from gallery
  Future<XFile?> pickSingleImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    return picker.pickImage(source: source, imageQuality: 80);
  }

  /// Pick multiple images from gallery
  Future<List<XFile>> pickMultipleImages() async {
    final picker = ImagePicker();
    return picker.pickMultiImage(imageQuality: 80);
  }

  /// Upload single image to Cloudinary
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Upload multiple images to Cloudinary
  Future<List<String>> uploadImages(List<XFile> imageFiles) async {
    final urls = <String>[];

    for (final file in imageFiles) {
      final url = await uploadImage(file);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Upload image from file path (for network URLs or local files)
  Future<String?> uploadFromPath(String filePath) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final file = File(filePath);
      if (!await file.exists()) return null;

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Get transformed URL for image
  String getTransformedUrl(
    String publicId, {
    String transformation = 'w_500,c_fill,q_auto,f_auto',
  }) {
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformation/$publicId';
  }

  String getThumbnailUrl(String imageUrl) {
    return _applyTransformation(imageUrl, 'w_200,c_fill,q_auto,f_auto');
  }

  String getFullImageUrl(String imageUrl) {
    return _applyTransformation(imageUrl, 'w_1200,c_fill,q_auto,f_auto');
  }

  String getMediumImageUrl(String imageUrl) {
    return _applyTransformation(imageUrl, 'w_500,c_fill,q_auto,f_auto');
  }

  String _applyTransformation(String url, String transformation) {
    if (!url.contains('upload/')) return url;

    final parts = url.split('upload/');
    if (parts.length == 2) {
      return '${parts[0]}upload/$transformation/${parts[1]}';
    }
    return url;
  }

  String getPlaceholderUrl({int width = 500, int height = 300}) {
    return 'https://via.placeholder.com/${width}x$height/8B5E3C/FFFFFF?text=Loading';
  }
}
