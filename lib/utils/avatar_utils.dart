import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Utility class for handling avatar display with support for SVG, assets, and network images
class AvatarUtils {
  /// Decode HTML entities in avatar paths
  static String cleanPath(String path) {
    return path.trim()
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#x5C;', '\\')
        .replaceAll('&amp;', '&');
  }

  /// Check if path is an SVG file
  static bool isSvg(String path) {
    return path.toLowerCase().endsWith('.svg');
  }

  /// Get image provider for non-SVG images
  static ImageProvider? getImageProvider(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    
    final cleanedPath = cleanPath(avatarPath);
    
    // SVG files need special handling - return null
    if (isSvg(cleanedPath)) {
      return null;
    }
    
    // Check if it's a local asset path
    if (cleanedPath.startsWith('assets/') || cleanedPath.startsWith('/assets/')) {
      return AssetImage(cleanedPath.replaceFirst(RegExp(r'^/'), ''));
    }
    
    // Check if it's a valid URL
    if (cleanedPath.startsWith('https://')) {
      return NetworkImage(cleanedPath);
    }
    
    return null;
  }

  /// Build a complete avatar widget that handles all image types
  static Widget buildAvatar({
    required String? avatarPath,
    required String fallbackText,
    double size = 48,
    Color? backgroundColor,
    Color? textColor,
  }) {
    backgroundColor ??= Colors.white;
    textColor ??= const Color(0xFF1DBF73);

    if (avatarPath == null || avatarPath.isEmpty) {
      return _buildFallbackAvatar(fallbackText, size, backgroundColor, textColor);
    }

    final cleanedPath = cleanPath(avatarPath);

    // Handle SVG files
    if (isSvg(cleanedPath)) {
      if (cleanedPath.startsWith('assets/') || cleanedPath.startsWith('/assets/')) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: SvgPicture.asset(
              cleanedPath.replaceFirst(RegExp(r'^/'), ''),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      // For network SVG or other cases, use fallback
      return _buildFallbackAvatar(fallbackText, size, backgroundColor, textColor);
    }

    // Handle regular images
    final imageProvider = getImageProvider(cleanedPath);
    if (imageProvider != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image(
            image: imageProvider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackAvatar(fallbackText, size, backgroundColor, textColor);
            },
          ),
        ),
      );
    }

    // Fallback
    return _buildFallbackAvatar(fallbackText, size, backgroundColor, textColor);
  }

  /// Build CircleAvatar with proper image provider (for backwards compatibility)
  static Widget buildCircleAvatar({
    required String? avatarPath,
    required String fallbackText,
    double radius = 24,
    Color? backgroundColor,
    Color? textColor,
  }) {
    backgroundColor ??= Colors.white;
    textColor ??= const Color(0xFF1DBF73);

    if (avatarPath == null || avatarPath.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(
          fallbackText.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
            color: textColor,
          ),
        ),
      );
    }

    final cleanedPath = cleanPath(avatarPath);

    // Handle SVG files - use custom widget
    if (isSvg(cleanedPath)) {
      return buildAvatar(
        avatarPath: cleanedPath,
        fallbackText: fallbackText,
        size: radius * 2,
        backgroundColor: backgroundColor,
        textColor: textColor,
      );
    }

    // Handle regular images with CircleAvatar
    final imageProvider = getImageProvider(cleanedPath);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              fallbackText.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
                color: textColor,
              ),
            )
          : null,
    );
  }

  static Widget _buildFallbackAvatar(
    String fallbackText,
    double size,
    Color? backgroundColor,
    Color? textColor,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          fallbackText.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
            color: textColor ?? const Color(0xFF1DBF73),
          ),
        ),
      ),
    );
  }
}
