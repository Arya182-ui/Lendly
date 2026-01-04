import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../widgets/app_image.dart';

/// Enhanced profile picture widget with upload functionality
class ProfilePictureWidget extends StatefulWidget {
  final String? currentImageUrl;
  final double size;
  final Function(String imageUrl)? onImageChanged;
  final bool canEdit;
  final String uploadEndpoint;

  const ProfilePictureWidget({
    Key? key,
    this.currentImageUrl,
    this.size = 100,
    this.onImageChanged,
    this.canEdit = false,
    this.uploadEndpoint = '/user/avatar',
  }) : super(key: key);

  @override
  State<ProfilePictureWidget> createState() => _ProfilePictureWidgetState();
}

class _ProfilePictureWidgetState extends State<ProfilePictureWidget> {
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.currentImageUrl;
  }

  @override
  void didUpdateWidget(ProfilePictureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentImageUrl != oldWidget.currentImageUrl) {
      _imageUrl = widget.currentImageUrl;
    }
  }

  Future<void> _changeProfilePicture() async {
    if (!widget.canEdit) return;

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

      widget.onImageChanged?.call(imageUrl);
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canEdit ? _changeProfilePicture : null,
      child: Stack(
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _isUploading
                  ? Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : UserAvatar(
                      avatarUrl: _imageUrl,
                      radius: widget.size / 2,
                    ),
            ),
          ),
          
          if (widget.canEdit && !_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DBF73),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}