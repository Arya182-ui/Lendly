import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

/// Advanced image caching service with memory and disk caching
/// Optimized for Android performance
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Memory cache with LRU eviction
  final Map<String, _ImageCacheEntry> _memoryCache = {};
  static const int _maxMemoryCacheItems = 50;
  static const int _maxMemoryCacheSizeBytes = 50 * 1024 * 1024; // 50MB
  int _currentMemoryCacheSize = 0;

  // Disk cache directory
  Directory? _cacheDir;
  bool _initialized = false;

  /// Initialize the image cache
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final tempDir = Directory.systemTemp;
      _cacheDir = Directory('${tempDir.path}/lendly_image_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // Clean old cache files
      await _cleanOldCacheFiles();
      _initialized = true;
    } catch (e) {
      debugPrint('ImageCacheService: Failed to initialize cache directory: $e');
    }
  }

  /// Get image from cache or network
  Future<ImageProvider?> getImage(
    String url, {
    int? maxWidth,
    int? maxHeight,
    BoxFit fit = BoxFit.cover,
  }) async {
    if (url.isEmpty) return null;
    
    await initialize();
    
    final cacheKey = _generateCacheKey(url, maxWidth, maxHeight);
    
    // Check memory cache first
    final memoryCached = _memoryCache[cacheKey];
    if (memoryCached != null) {
      _updateLRU(cacheKey);
      return MemoryImage(memoryCached.bytes);
    }
    
    // Check disk cache
    final diskCached = await _getDiskCache(cacheKey);
    if (diskCached != null) {
      _addToMemoryCache(cacheKey, diskCached);
      return MemoryImage(diskCached);
    }
    
    // Fetch from network
    try {
      final bytes = await _fetchImage(url);
      if (bytes != null) {
        // Optionally resize
        final processedBytes = await _processImage(bytes, maxWidth, maxHeight);
        
        // Cache to memory and disk
        _addToMemoryCache(cacheKey, processedBytes);
        await _saveToDiskCache(cacheKey, processedBytes);
        
        return MemoryImage(processedBytes);
      }
    } catch (e) {
      debugPrint('ImageCacheService: Failed to fetch image: $e');
    }
    
    return null;
  }

  /// Preload images for better UX
  Future<void> preloadImages(List<String> urls) async {
    await initialize();
    
    for (final url in urls) {
      if (url.isNotEmpty && !_memoryCache.containsKey(_generateCacheKey(url, null, null))) {
        // Don't await - load in background
        getImage(url);
      }
    }
  }

  /// Get cached image widget with placeholder and error handling
  Widget getCachedImage(
    String? url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    if (url == null || url.isEmpty) {
      return errorWidget ?? _defaultErrorWidget(width, height);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: _CachedImageWidget(
        url: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder ?? _defaultPlaceholder(width, height),
        errorWidget: errorWidget ?? _defaultErrorWidget(width, height),
        cacheService: this,
      ),
    );
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _memoryCache.clear();
    _currentMemoryCacheSize = 0;
    
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    int size = _currentMemoryCacheSize;
    
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    }
    
    return size;
  }

  // Private methods
  
  String _generateCacheKey(String url, int? width, int? height) {
    final suffix = width != null || height != null ? '_${width}x$height' : '';
    return '${url.hashCode}$suffix';
  }

  void _addToMemoryCache(String key, Uint8List bytes) {
    // Evict if necessary
    while (_currentMemoryCacheSize + bytes.length > _maxMemoryCacheSizeBytes ||
           _memoryCache.length >= _maxMemoryCacheItems) {
      _evictOldest();
    }
    
    _memoryCache[key] = _ImageCacheEntry(bytes);
    _currentMemoryCacheSize += bytes.length;
  }

  void _evictOldest() {
    if (_memoryCache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.lastAccessed;
      }
    }
    
    if (oldestKey != null) {
      final removed = _memoryCache.remove(oldestKey);
      if (removed != null) {
        _currentMemoryCacheSize -= removed.bytes.length;
      }
    }
  }

  void _updateLRU(String key) {
    final entry = _memoryCache[key];
    if (entry != null) {
      entry.lastAccessed = DateTime.now();
    }
  }

  Future<Uint8List?> _getDiskCache(String key) async {
    if (_cacheDir == null) return null;
    
    try {
      final file = File('${_cacheDir!.path}/$key');
      if (await file.exists()) {
        // Check if not too old (7 days max)
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified).inDays < 7) {
          return await file.readAsBytes();
        } else {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('ImageCacheService: Disk cache read error: $e');
    }
    
    return null;
  }

  Future<void> _saveToDiskCache(String key, Uint8List bytes) async {
    if (_cacheDir == null) return;
    
    try {
      final file = File('${_cacheDir!.path}/$key');
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('ImageCacheService: Disk cache write error: $e');
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('ImageCacheService: Network fetch error: $e');
    }
    
    return null;
  }

  Future<Uint8List> _processImage(
    Uint8List bytes,
    int? maxWidth,
    int? maxHeight,
  ) async {
    if (!EnvConfig.enableImageCompression || (maxWidth == null && maxHeight == null)) {
      return bytes;
    }
    
    // Use compute for heavy processing
    return await compute(_resizeImage, _ResizeParams(bytes, maxWidth, maxHeight));
  }

  Future<void> _cleanOldCacheFiles() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) return;
    
    try {
      final now = DateTime.now();
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified).inDays > 7) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('ImageCacheService: Cache cleanup error: $e');
    }
  }

  Widget _defaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[400],
        size: 32,
      ),
    );
  }
}

/// Memory cache entry with LRU tracking
class _ImageCacheEntry {
  final Uint8List bytes;
  DateTime lastAccessed;
  
  _ImageCacheEntry(this.bytes) : lastAccessed = DateTime.now();
}

/// Params for image resize compute
class _ResizeParams {
  final Uint8List bytes;
  final int? maxWidth;
  final int? maxHeight;
  
  _ResizeParams(this.bytes, this.maxWidth, this.maxHeight);
}

/// Resize image in isolate
Future<Uint8List> _resizeImage(_ResizeParams params) async {
  try {
    final codec = await ui.instantiateImageCodec(
      params.bytes,
      targetWidth: params.maxWidth,
      targetHeight: params.maxHeight,
    );
    
    final frame = await codec.getNextFrame();
    final image = frame.image;
    
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    codec.dispose();
    
    if (byteData != null) {
      return byteData.buffer.asUint8List();
    }
  } catch (e) {
    debugPrint('Image resize error: $e');
  }
  
  return params.bytes;
}

/// Cached image widget with loading and error states
class _CachedImageWidget extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;
  final ImageCacheService cacheService;

  const _CachedImageWidget({
    required this.url,
    this.width,
    this.height,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
    required this.cacheService,
  });

  @override
  State<_CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<_CachedImageWidget> {
  ImageProvider? _imageProvider;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    final provider = await widget.cacheService.getImage(
      widget.url,
      maxWidth: widget.width?.toInt(),
      maxHeight: widget.height?.toInt(),
    );

    if (mounted) {
      setState(() {
        _imageProvider = provider;
        _loading = false;
        _hasError = provider == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder;
    }
    
    if (_hasError || _imageProvider == null) {
      return widget.errorWidget;
    }
    
    return Image(
      image: _imageProvider!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => widget.errorWidget,
    );
  }
}

/// Network image with caching - drop-in replacement
class CachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ImageCacheService().getCachedImage(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
    );
  }
}
