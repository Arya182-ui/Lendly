import 'api_client.dart';

/// Home screen data service with caching
/// Cache durations optimized to reduce server requests
class HomeService {
  final String baseUrl; // Kept for backwards compatibility
  HomeService(this.baseUrl);

  /// Get user summary data - cached for 2 minutes
  Future<Map<String, dynamic>> getSummary(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    return await SimpleApiClient.get(
      '/home/summary',
      queryParams: {'uid': uid},
      cacheDuration: const Duration(minutes: 2),
      requiresAuth: true,
    );
  }

  /// Get user data for profile display
  Future<Map<String, dynamic>> getUserData(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    return await SimpleApiClient.get(
      '/user/profile',
      queryParams: {'uid': uid},
      cacheDuration: const Duration(minutes: 5),
      requiresAuth: true,
    );
  }

  /// Get new arrivals - cached for 5 minutes
  Future<List<dynamic>> getNewArrivals(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    final dynamic data = await SimpleApiClient.get(
      '/home/new-arrivals',
      queryParams: {'uid': uid},
      cacheDuration: const Duration(minutes: 5),
      requiresAuth: true,
    );
    // API returns a top-level list of items
    if (data is List) return List<dynamic>.from(data);
    final items = data['items'];
    return (items is List) ? List<dynamic>.from(items) : <dynamic>[];
  }

  /// Get public groups for display
  Future<List<dynamic>> getPublicGroups(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    final dynamic data = await SimpleApiClient.get(
      '/groups/public',
      queryParams: {'uid': uid},
      cacheDuration: const Duration(minutes: 10),
      requiresAuth: true,
    );
    
    if (data is List) return List<dynamic>.from(data);
    final groups = data['groups'];
    return (groups is List) ? List<dynamic>.from(groups) : <dynamic>[];
  }

  /// Get items near user location - cached for 3 minutes
  Future<List<dynamic>> getItemsNearYou({
    required String uid,
    required double latitude,
    required double longitude,
  }) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    if (latitude < -90 || latitude > 90) throw ArgumentError('Invalid latitude');
    if (longitude < -180 || longitude > 180) throw ArgumentError('Invalid longitude');
    
    final dynamic data = await SimpleApiClient.get(
      '/home/items-near-you',
      queryParams: {
        'uid': uid,
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
      },
      cacheDuration: const Duration(minutes: 3),
      requiresAuth: true,
    );
    // API returns a top-level list of items
    if (data is List) return List<dynamic>.from(data);
    final items = data['items'];
    return (items is List) ? List<dynamic>.from(items) : <dynamic>[];
  }

  /// Alias for getItemsNearYou for backward compatibility
  Future<List<dynamic>> getItemsNearLocation(
    String uid,
    double latitude,
    double longitude,
  ) async {
    return getItemsNearYou(
      uid: uid,
      latitude: latitude,
      longitude: longitude,
    );
  }


  /// Get public groups - cached for 5 minutes
  Future<List<dynamic>> getGroups() async {
    final dynamic data = await SimpleApiClient.get(
      '/home/groups',
      cacheDuration: const Duration(minutes: 5),
      requiresAuth: false, // Home routes are public
    );
    // API returns a top-level list of groups
    if (data is List) return List<dynamic>.from(data);
    final groups = data['groups'];
    return (groups is List) ? List<dynamic>.from(groups) : <dynamic>[];
  }
  
  /// Force refresh all home data (clears cache)
  void clearCache() {
    SimpleApiClient.clearCacheEntry('/home/');
  }
}

