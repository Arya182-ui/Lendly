import 'api_client.dart';

/// User profile service with caching
class UserService {
  /// Fetch public profile data with caching
  static Future<Map<String, dynamic>?> fetchPublicProfile(String uid) async {
    if (uid.isEmpty) return null;
    
    try {
      return await ApiClient.get(
        '/user/public-profile',
        queryParams: {'uid': uid},
        cacheDuration: const Duration(minutes: 5),
      );
    } on ApiException catch (e) {
      // Return null for 404 (user not found)
      if (e.statusCode == 404) return null;
      rethrow;
    } catch (_) {
      return null;
    }
  }
  
  /// Fetch multiple public profiles in parallel
  static Future<Map<String, Map<String, dynamic>?>> fetchMultipleProfiles(List<String> uids) async {
    if (uids.isEmpty) return {};
    
    final futures = uids.map((uid) async {
      final profile = await fetchPublicProfile(uid);
      return MapEntry(uid, profile);
    }).toList();
    
    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
  
  /// Clear user profile cache
  static void clearProfileCache(String uid) {
    ApiClient.invalidateUserCache(uid);
  }
}
