import 'api_client.dart';

/// Impact tracking service with caching
/// Cache durations are increased to reduce server load
class ImpactService {
  final String baseUrl; // Kept for backwards compatibility
  ImpactService(this.baseUrl);

  /// Get personal impact data - cached for 10 minutes
  Future<Map<String, dynamic>> getPersonalImpact(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    
    return await ApiClient.get(
      '/impact/personal/$userId',
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get environmental impact data - cached for 10 minutes
  Future<Map<String, dynamic>> getEnvironmentalImpact(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    
    return await ApiClient.get(
      '/impact/environmental/$userId',
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get community impact data - cached for 10 minutes
  Future<Map<String, dynamic>> getCommunityImpact(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    
    return await ApiClient.get(
      '/impact/community/$userId',
      cacheDuration: const Duration(minutes: 10),
    );
  }

  /// Get leaderboard data - cached for 15 minutes
  Future<List<dynamic>> getLeaderboard() async {
    final result = await ApiClient.get(
      '/impact/leaderboard',
      cacheDuration: const Duration(minutes: 15),
    );
    if (result is List) return result;
    if (result is Map) {
      final message = result['error'] ?? result['message'] ?? 'Failed to load leaderboard';
      throw Exception(message);
    }
    throw Exception('Failed to load leaderboard');
  }

  /// Get user badges - cached for 15 minutes
  Future<List<dynamic>> getBadges(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    final result = await ApiClient.get(
      '/impact/badges/$userId',
      cacheDuration: const Duration(minutes: 15),
    );
    if (result is List) return result;
    if (result is Map) {
      if (result.containsKey('badges') && result['badges'] is List) {
        return result['badges'] as List;
      }
      final message = result['error'] ?? result['message'] ?? 'Failed to load badges';
      throw Exception(message);
    }
    throw Exception('Failed to load badges');
  }
  
  /// Fetch all impact data in parallel
  Future<Map<String, dynamic>> getAllImpactData(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    
    final results = await Future.wait([
      getPersonalImpact(userId),
      getEnvironmentalImpact(userId),
      getCommunityImpact(userId),
      getLeaderboard(),
      getBadges(userId),
    ]);
    
    return {
      'personal': results[0],
      'environmental': results[1],
      'community': results[2],
      'leaderboard': results[3],
      'badges': results[4],
    };
  }
}
