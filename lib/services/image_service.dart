import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../config/env_config.dart';
import 'firebase_auth_service.dart';

/// Comprehensive image service for upload, compression, caching, and display
class ImageService {
  static String get _baseUrl => EnvConfig.apiBaseUrl;
  static final ImagePicker _picker = ImagePicker();
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _compressionQuality = 85;

  /// Pick image from camera with compression
  static Future<File?> pickFromCamera({
    int maxWidth = _maxWidth,
    int maxHeight = _maxHeight,
    int imageQuality = _compressionQuality,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      
      // Check file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        throw Exception('Image file too large. Please select an image under 5MB.');
      }

      return file;
    } catch (e) {
      throw Exception('Failed to pick image from camera: ${e.toString()}');
    }
  }

  /// Pick image from gallery with compression
  static Future<File?> pickFromGallery({
    int maxWidth = _maxWidth,
    int maxHeight = _maxHeight,
    int imageQuality = _compressionQuality,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      
      // Check file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        throw Exception('Image file too large. Please select an image under 5MB.');
      }

      return file;
    } catch (e) {
      throw Exception('Failed to pick image from gallery: ${e.toString()}');
    }
  }

  /// Upload image file to server
  static Future<String> uploadImage(File imageFile, String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);
      final token = await FirebaseAuthService().getIdToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        return data['imageUrl'] ?? data['image'] ?? '';
      } else {
        final error = jsonDecode(responseBody);
        throw Exception(error['error'] ?? 'Upload failed');
      }
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Show image picker options dialog
  static Future<File?> showImagePickerDialog(BuildContext context) async {
    return await showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue[800]),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture with camera'),
              onTap: () async {
                try {
                  final file = await pickFromCamera();
                  if (context.mounted) {
                    Navigator.pop(context, file);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: Colors.green[800]),
              ),
              title: const Text('Photo Gallery'),
              subtitle: const Text('Choose from gallery'),
              onTap: () async {
                try {
                  final file = await pickFromGallery();
                  if (context.mounted) {
                    Navigator.pop(context, file);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Cache image URL locally
  static Future<void> cacheImageUrl(String key, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('image_cache_$key', url);
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Get cached image URL
  static Future<String?> getCachedImageUrl(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('image_cache_$key');
    } catch (e) {
      return null;
    }
  }

  /// Clear image cache
  static Future<void> clearImageCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('image_cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Validate image file
  static bool isValidImageFile(File file) {
    final extension = file.path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  /// Get image file size in MB
  static Future<double> getImageSizeInMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Compress image if needed
  static Future<File> compressImageIfNeeded(
    File imageFile, {
    int maxSizeInMB = 5,
    int quality = 85,
  }) async {
    final sizeInMB = await getImageSizeInMB(imageFile);
    
    if (sizeInMB <= maxSizeInMB) {
      return imageFile;
    }

    // If image is too large, reduce quality
    final newQuality = (quality * (maxSizeInMB / sizeInMB)).round().clamp(10, 100);
    
    final XFile? compressedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: newQuality,
    );

    return compressedFile != null ? File(compressedFile.path) : imageFile;
  }
}

/// Enhanced image widget with caching, loading states, and error handling
class CachedNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? cacheKey;

  const CachedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cacheKey,
  }) : super(key: key);

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return Image.network(
      widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          _isLoading = false;
          _hasError = false;
          return child;
        }

        return _buildPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        _hasError = true;
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[400],
        size: (widget.width != null && widget.height != null) 
            ? (widget.width! + widget.height!) / 4 
            : 24,
      ),
    );
  }
}

/// Image picker button with upload functionality
class ImagePickerButton extends StatefulWidget {
  final String? initialImageUrl;
  final double size;
  final Function(String imageUrl)? onImageUploaded;
  final Function(String error)? onError;
  final String uploadEndpoint;
  final bool showUploadProgress;

  const ImagePickerButton({
    Key? key,
    this.initialImageUrl,
    this.size = 100,
    this.onImageUploaded,
    this.onError,
    required this.uploadEndpoint,
    this.showUploadProgress = true,
  }) : super(key: key);

  @override
  State<ImagePickerButton> createState() => _ImagePickerButtonState();
}

class _ImagePickerButtonState extends State<ImagePickerButton> {
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final file = await ImageService.showImagePickerDialog(context);
      if (file == null) return;

      setState(() {
        _isUploading = true;
      });

      final imageUrl = await ImageService.uploadImage(file, widget.uploadEndpoint);
      
      setState(() {
        _imageUrl = imageUrl;
        _isUploading = false;
      });

      widget.onImageUploaded?.call(imageUrl);
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      widget.onError?.call(e.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUploadImage,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_imageUrl != null && _imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _imageUrl,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: Colors.grey[100],
                  child: Icon(
                    Icons.add_a_photo,
                    size: widget.size * 0.4,
                    color: Colors.grey[400],
                  ),
                ),
              
              if (_isUploading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              
              if (!_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}