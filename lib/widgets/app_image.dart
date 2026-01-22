import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Enhanced image widgets for consistent image display throughout the app
class AppImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl == null || imageUrl!.isEmpty) {
      imageWidget = errorWidget ?? AppImagePlaceholders.profilePlaceholder(size: width ?? height ?? 50);
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? AppImagePlaceholders.loading(size: width ?? height),
        errorWidget: (context, url, error) => errorWidget ?? AppImagePlaceholders.profilePlaceholder(size: width ?? height),
      );
    }

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// App-specific image placeholders and error widgets
class AppImagePlaceholders {
  static Widget loading({double? size}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
        ),
      ),
    );
  }

  static Widget error({double? size, IconData? icon}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Icon(
        icon ?? Icons.image_not_supported,
        color: Colors.grey[400],
        size: size != null ? size * 0.4 : 24,
      ),
    );
  }

  static Widget itemPlaceholder({double? size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Glassmorphism effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.image,
              size: size != null ? size * 0.4 : 32,
              color: Colors.grey[350],
            ),
          ),
        ],
      ),
    );
  }

  static Widget profilePlaceholder({double? size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size != null ? size * 0.6 : 24,
        color: Colors.grey[600],
      ),
    );
  }
}

/// Item image widget with app-specific styling
class ItemImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ItemImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      placeholder: AppImagePlaceholders.loading(size: height ?? width),
      errorWidget: AppImagePlaceholders.itemPlaceholder(size: height ?? width),
    );
  }
}

/// User avatar widget with fallback to app avatars
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final bool isOnline;

  const UserAvatar({
    Key? key,
    required this.avatarUrl,
    this.radius = 20,
    this.isOnline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    // Add timestamp to force cache invalidation
    final cacheKey = avatarUrl != null ? '${avatarUrl}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}' : 'default';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      if (avatarUrl!.startsWith('assets/')) {
        // Handle SVG avatars properly
        if (avatarUrl!.endsWith('.svg')) {
          avatar = Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: SvgPicture.asset(
                avatarUrl!,
                key: ValueKey(cacheKey),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholderBuilder: (context) =>
                    AppImagePlaceholders.profilePlaceholder(size: radius * 2),
              ),
            ),
          );
        } else {
          // Regular asset image
          avatar = Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: Image.asset(
                avatarUrl!,
                key: ValueKey(cacheKey),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    AppImagePlaceholders.profilePlaceholder(size: radius * 2),
              ),
            ),
          );
        }
      } else if (avatarUrl!.startsWith('http')) {
        // Network image
        avatar = AppImage(
          imageUrl: avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(radius),
          placeholder: AppImagePlaceholders.loading(size: radius * 2),
          errorWidget: AppImagePlaceholders.profilePlaceholder(size: radius * 2),
        );
      } else {
        avatar = AppImagePlaceholders.profilePlaceholder(size: radius * 2);
      }
    } else {
      avatar = AppImagePlaceholders.profilePlaceholder(size: radius * 2);
    }

    if (isOnline) {
      return Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}