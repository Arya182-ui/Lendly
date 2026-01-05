import 'api_client.dart';

/// Advanced search service for items
class SearchService {
  /// Advanced search with multiple filters
  static Future<Map<String, dynamic>> searchItems({
    String? query,
    String? category,
    String? type,
    String? condition,
    double? minPrice,
    double? maxPrice,
    bool? availableOnly,
    String sortBy = 'newest',
    int limit = 50,
    String? excludeUid,
  }) async {
    final queryParams = <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null) 'category': category,
      if (type != null) 'type': type,
      if (condition != null) 'condition': condition,
      if (minPrice != null) 'minPrice': minPrice.toString(),
      if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      if (availableOnly != null) 'available': availableOnly.toString(),
      'sortBy': sortBy,
      'limit': limit.toString(),
      if (excludeUid != null) 'excludeUid': excludeUid,
    };

    return await SimpleApiClient.get(
      '/items/search',
      queryParams: queryParams,
      cacheDuration: const Duration(minutes: 1),
    );
  }

  /// Get items grouped by categories
  static Future<Map<String, dynamic>> getItemsByCategories({
    int limit = 5,
  }) async {
    return await SimpleApiClient.get(
      '/items/categories',
      queryParams: {'limit': limit.toString()},
      cacheDuration: const Duration(minutes: 5),
    );
  }

  /// Get trending items (mock implementation - could be enhanced with real metrics)
  static Future<List<dynamic>> getTrendingItems({int limit = 10}) async {
    // For now, get newest items as "trending"
    final result = await searchItems(
      sortBy: 'newest',
      limit: limit,
      availableOnly: true,
    );
    return result['items'] ?? [];
  }

  /// Get new arrivals
  static Future<List<dynamic>> getNewArrivals({int limit = 10}) async {
    final result = await searchItems(
      sortBy: 'newest',
      limit: limit,
      availableOnly: true,
    );
    return result['items'] ?? [];
  }

  /// Get items near user location (if available)
  static Future<List<dynamic>> getNearbyItems({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 10,
  }) async {
    // This would require location-based search in the backend
    // For now, return general search results
    final result = await searchItems(
      limit: limit,
      availableOnly: true,
    );
    return result['items'] ?? [];
  }

  /// Quick search suggestions based on query
  static Future<List<String>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];
    
    try {
      // This is a simple implementation - could be enhanced with a dedicated suggestions endpoint
      final result = await searchItems(
        query: query,
        limit: 5,
      );
      
      final items = result['items'] as List<dynamic>? ?? [];
      final suggestions = <String>{};
      
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        if (name.isNotEmpty) {
          suggestions.add(name);
        }
      }
      
      return suggestions.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get popular categories with item counts
  static Future<Map<String, int>> getPopularCategories() async {
    try {
      final categories = await getItemsByCategories();
      final Map<String, int> popularCategories = {};
      
      categories.forEach((key, value) {
        if (value is Map<String, dynamic> && value['count'] is int) {
          popularCategories[key] = value['count'];
        }
      });
      
      // Sort by count descending
      final sortedEntries = popularCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return Map.fromEntries(sortedEntries);
    } catch (e) {
      return {};
    }
  }
}