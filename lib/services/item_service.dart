import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Item management service with validation and error handling
class ItemService {
  final String baseUrl;
  ItemService(this.baseUrl);

  static const _timeout = Duration(seconds: 30); // Longer for file uploads
  static const _maxImageSize = 10 * 1024 * 1024; // 10MB
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];

  /// Validate image file
  Future<void> _validateImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw ItemServiceException('Image file does not exist');
    }
    
    final fileSize = await imageFile.length();
    if (fileSize > _maxImageSize) {
      throw ItemServiceException('Image too large (max 10MB)');
    }
    
    final extension = imageFile.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw ItemServiceException('Invalid image format. Allowed: JPG, PNG, WebP, GIF');
    }
  }

  /// Update an existing item
  Future<Map<String, dynamic>> updateItem({
    required String id,
    required String ownerId,
    String? name,
    String? description,
    String? category,
    double? price,
    String? type,
    bool? available,
    File? imageFile,
  }) async {
    if (id.isEmpty || ownerId.isEmpty) {
      throw ItemServiceException('Item ID and Owner ID are required');
    }
    if (name != null && name.length > 100) {
      throw ItemServiceException('Name too long (max 100 characters)');
    }
    if (price != null && price < 0) {
      throw ItemServiceException('Price cannot be negative');
    }
    
    try {
      final uri = Uri.parse('$baseUrl/items/$id');
      
      if (imageFile != null) {
        await _validateImage(imageFile);
        
        var request = http.MultipartRequest('PUT', uri);
        request.fields['ownerId'] = ownerId;
        if (name != null) request.fields['name'] = name;
        if (description != null) request.fields['description'] = description;
        if (category != null) request.fields['category'] = category;
        if (price != null) request.fields['price'] = price.toString();
        if (type != null && type.isNotEmpty) request.fields['type'] = type;
        if (available != null) request.fields['available'] = available.toString();
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
        
        var streamed = await request.send().timeout(_timeout);
        var res = await http.Response.fromStream(streamed);
        
        if (res.statusCode == 200) return json.decode(res.body);
        throw ItemServiceException(_parseError(res.body, 'Failed to update item'));
      } else {
        final body = <String, dynamic>{
          'ownerId': ownerId,
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (category != null) 'category': category,
          if (price != null) 'price': price.toString(),
          if (type != null && type.isNotEmpty) 'type': type,
          if (available != null) 'available': available.toString(),
        };
        
        final res = await http.put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(_timeout);
        
        if (res.statusCode == 200) return json.decode(res.body);
        throw ItemServiceException(_parseError(res.body, 'Failed to update item'));
      }
    } on TimeoutException {
      throw ItemServiceException('Upload timed out. Please try again.');
    } on SocketException {
      throw ItemServiceException('No internet connection.');
    }
  }

  /// Delete an item
  Future<void> deleteItem({
    required String id,
    required String ownerId,
  }) async {
    if (id.isEmpty || ownerId.isEmpty) {
      throw ItemServiceException('Item ID and Owner ID are required');
    }
    
    try {
      final uri = Uri.parse('$baseUrl/items/$id?ownerId=$ownerId');
      final res = await http.delete(uri).timeout(const Duration(seconds: 15));
      
      if (res.statusCode == 200) return;
      throw ItemServiceException(_parseError(res.body, 'Failed to delete item'));
    } on TimeoutException {
      throw ItemServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw ItemServiceException('No internet connection.');
    }
  }

  /// Add a new item
  Future<Map<String, dynamic>> addItem({
    required String name,
    required String description,
    required String category,
    required double price,
    required String type,
    required String ownerId,
    File? imageFile,
    double? latitude,
    double? longitude,
  }) async {
    // Input validation
    if (name.trim().isEmpty) {
      throw ItemServiceException('Name is required');
    }
    if (name.length > 100) {
      throw ItemServiceException('Name too long (max 100 characters)');
    }
    if (description.length > 1000) {
      throw ItemServiceException('Description too long (max 1000 characters)');
    }
    if (price < 0) {
      throw ItemServiceException('Price cannot be negative');
    }
    if (ownerId.isEmpty) {
      throw ItemServiceException('Owner ID is required');
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw ItemServiceException('Invalid latitude');
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw ItemServiceException('Invalid longitude');
    }
    
    try {
      if (imageFile != null) {
        await _validateImage(imageFile);
      }
      
      var uri = Uri.parse('$baseUrl/items');
      var request = http.MultipartRequest('POST', uri);
      request.fields['name'] = name.trim();
      request.fields['description'] = description.trim();
      request.fields['category'] = category;
      request.fields['price'] = price.toString();
      request.fields['type'] = type;
      request.fields['ownerId'] = ownerId;
      if (latitude != null) request.fields['latitude'] = latitude.toStringAsFixed(6);
      if (longitude != null) request.fields['longitude'] = longitude.toStringAsFixed(6);
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }
      
      var streamed = await request.send().timeout(_timeout);
      var res = await http.Response.fromStream(streamed);
      
      if (res.statusCode == 201) return json.decode(res.body);
      throw ItemServiceException(_parseError(res.body, 'Failed to add item'));
    } on TimeoutException {
      throw ItemServiceException('Upload timed out. Please try again.');
    } on SocketException {
      throw ItemServiceException('No internet connection.');
    }
  }

  /// Get all items
  Future<List<dynamic>> getItems() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/items')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return json.decode(res.body);
      throw ItemServiceException(_parseError(res.body, 'Failed to fetch items'));
    } on TimeoutException {
      throw ItemServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw ItemServiceException('No internet connection.');
    }
  }

  /// Parse error message from response
  static String _parseError(String body, String defaultMsg) {
    try {
      return json.decode(body)['error'] ?? defaultMsg;
    } catch (_) {
      return defaultMsg;
    }
  }
}

/// Custom exception for item service errors
class ItemServiceException implements Exception {
  final String message;
  ItemServiceException(this.message);
  
  @override
  String toString() => message;
}

