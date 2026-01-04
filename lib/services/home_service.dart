import 'api_client.dart';

/// Home screen data service with caching
/// Cache durations optimized to reduce server requests
class HomeService {
  final String baseUrl; // Kept for backwards compatibility
  HomeService(this.baseUrl);

  /// Get user summary data - cached for 2 minutes
  Future<Map<String, dynamic>> getSummary(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    return await ApiClient.get(
      '/home/summary',
      queryParams: {'uid': uid},
      cacheDuration: const Duration(minutes: 2),
    );
  }

  /// Get new arrivals - cached for 5 minutes
  Future<List<dynamic>> getNewArrivals() async {
    return await ApiClient.get(
      '/home/new-arrivals',
      cacheDuration: const Duration(minutes: 5),
    );
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
    
    return await ApiClient.get(
      '/home/items-near-you',
      queryParams: {
        'uid': uid,
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
      },
      cacheDuration: const Duration(minutes: 3),
    );
  }

  /// Get public groups - cached for 5 minutes
  Future<List<dynamic>> getGroups() async {
    return await ApiClient.get(
      '/home/groups',
      cacheDuration: const Duration(minutes: 5),
    );
  }
  
  /// Force refresh all home data (clears cache)
  void clearCache() {
    ApiClient.clearCacheEntry('/home/');
  }
}

