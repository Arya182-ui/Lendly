import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

// Reward models
class Reward {
  final String id;
  final String uid;
  final String type;
  final String title;
  final String description;
  final int points;
  final String? icon;
  final String? category;
  final bool claimed;
  final DateTime earnedAt;
  final DateTime? claimedAt;
  final Map<String, dynamic>? metadata;

  Reward({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.description,
    required this.points,
    this.icon,
    this.category,
    required this.claimed,
    required this.earnedAt,
    this.claimedAt,
    this.metadata,
  });

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] ?? '',
      uid: json['uid'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      points: json['points'] ?? 0,
      icon: json['icon'],
      category: json['category'],
      claimed: json['claimed'] ?? false,
      earnedAt: DateTime.tryParse(json['earnedAt'] ?? '') ?? DateTime.now(),
      claimedAt: json['claimedAt'] != null 
        ? DateTime.tryParse(json['claimedAt'])
        : null,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'type': type,
      'title': title,
      'description': description,
      'points': points,
      'icon': icon,
      'category': category,
      'claimed': claimed,
      'earnedAt': earnedAt.toIso8601String(),
      'claimedAt': claimedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class Achievement {
  final String id;
  final String uid;
  final String achievementId;
  final String title;
  final String description;
  final String badge;
  final String category;
  final int points;
  final DateTime unlockedAt;
  final Map<String, dynamic>? criteria;
  final Map<String, dynamic>? metadata;

  Achievement({
    required this.id,
    required this.uid,
    required this.achievementId,
    required this.title,
    required this.description,
    required this.badge,
    required this.category,
    required this.points,
    required this.unlockedAt,
    this.criteria,
    this.metadata,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      uid: json['uid'] ?? '',
      achievementId: json['achievementId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      badge: json['badge'] ?? '',
      category: json['category'] ?? '',
      points: json['points'] ?? 0,
      unlockedAt: DateTime.tryParse(json['unlockedAt'] ?? '') ?? DateTime.now(),
      criteria: json['criteria'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'achievementId': achievementId,
      'title': title,
      'description': description,
      'badge': badge,
      'category': category,
      'points': points,
      'unlockedAt': unlockedAt.toIso8601String(),
      'criteria': criteria,
      'metadata': metadata,
    };
  }
}

class LeaderboardEntry {
  final int rank;
  final String uid;
  final String displayName;
  final String? profilePicture;
  final int value;
  final String? badge;

  LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    this.profilePicture,
    required this.value,
    this.badge,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      uid: json['uid'] ?? '',
      displayName: json['displayName'] ?? 'Anonymous',
      profilePicture: json['profilePicture'],
      value: json['value'] ?? 0,
      badge: json['badge'],
    );
  }
}

class RewardSummary {
  final int totalRewards;
  final int totalAchievements;
  final int pointsEarned;
  final int unclaimedRewards;
  final String currentLevel;
  final int pointsToNextLevel;

  RewardSummary({
    required this.totalRewards,
    required this.totalAchievements,
    required this.pointsEarned,
    required this.unclaimedRewards,
    required this.currentLevel,
    required this.pointsToNextLevel,
  });

  factory RewardSummary.fromJson(Map<String, dynamic> json) {
    return RewardSummary(
      totalRewards: json['totalRewards'] ?? 0,
      totalAchievements: json['totalAchievements'] ?? 0,
      pointsEarned: json['pointsEarned'] ?? 0,
      unclaimedRewards: json['unclaimedRewards'] ?? 0,
      currentLevel: json['currentLevel'] ?? 'Bronze',
      pointsToNextLevel: json['pointsToNextLevel'] ?? 0,
    );
  }
}

enum LeaderboardType { points, transactions, lending, borrowing }

class RewardService extends ChangeNotifier {
  static const String _rewardsCacheKey = 'rewards_cache';
  static const String _achievementsCacheKey = 'achievements_cache';
  static const Duration _cacheValidityDuration = Duration(hours: 1);

  List<Reward> _rewards = [];
  List<Achievement> _achievements = [];
  RewardSummary? _summary;
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  // Getters
  List<Reward> get rewards => List.unmodifiable(_rewards);
  List<Achievement> get achievements => List.unmodifiable(_achievements);
  RewardSummary? get summary => _summary;
  List<LeaderboardEntry> get leaderboard => List.unmodifiable(_leaderboard);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filtered rewards
  List<Reward> get unclaimedRewards => _rewards.where((r) => !r.claimed).toList();
  List<Reward> get claimedRewards => _rewards.where((r) => r.claimed).toList();
  List<Reward> getRewardsByCategory(String category) => 
    _rewards.where((r) => r.category == category).toList();

  // Filtered achievements
  List<Achievement> getAchievementsByCategory(String category) => 
    _achievements.where((a) => a.category == category).toList();

  // Initialize service
  Future<void> initialize(String uid) async {
    await _loadCachedData();
    await loadRewards(uid);
    _startPeriodicRefresh(uid);
  }

  // Load rewards and achievements
  Future<void> loadRewards(String uid) async {
    if (_isLoading) return;

    _setLoading(true);
    _setError(null);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/user/rewards?uid=$uid');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _rewards = (data['rewards'] as List)
              .map((reward) => Reward.fromJson(reward))
              .toList();
          
          _achievements = (data['achievements'] as List)
              .map((achievement) => Achievement.fromJson(achievement))
              .toList();
          
          _summary = RewardSummary.fromJson(data['summary']);
          
          await _cacheData();
          notifyListeners();
        } else {
          _setError(data['error'] ?? 'Failed to load rewards');
        }
      } else {
        _setError('Failed to load rewards');
      }
    } catch (e) {
      _setError('Network error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Claim a reward
  Future<bool> claimReward(String uid, String rewardId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/user/rewards/claim');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': uid,
          'rewardId': rewardId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _updateRewardClaimStatus(rewardId, true);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error claiming reward: $e');
      return false;
    }
  }

  // Load leaderboard
  Future<void> loadLeaderboard({
    LeaderboardType type = LeaderboardType.points,
    int limit = 10,
  }) async {
    try {
      final typeParam = type.name;
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/user/leaderboard?type=$typeParam&limit=$limit'
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _leaderboard = (data['leaderboard'] as List)
              .map((entry) => LeaderboardEntry.fromJson(entry))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    }
  }

  // Get user's rank in leaderboard
  int? getUserRank(String uid) {
    final entry = _leaderboard.firstWhere(
      (e) => e.uid == uid,
      orElse: () => LeaderboardEntry(rank: -1, uid: '', displayName: '', value: 0),
    );
    return entry.rank > 0 ? entry.rank : null;
  }

  // Calculate level from points
  String calculateLevel(int points) {
    if (points < 100) return 'Bronze';
    if (points < 500) return 'Silver';
    if (points < 1000) return 'Gold';
    if (points < 2500) return 'Platinum';
    if (points < 5000) return 'Diamond';
    return 'Legend';
  }

  // Calculate points needed for next level
  int calculatePointsToNextLevel(int currentPoints) {
    if (currentPoints < 100) return 100 - currentPoints;
    if (currentPoints < 500) return 500 - currentPoints;
    if (currentPoints < 1000) return 1000 - currentPoints;
    if (currentPoints < 2500) return 2500 - currentPoints;
    if (currentPoints < 5000) return 5000 - currentPoints;
    return 0; // Already at max level
  }

  // Get level progress (0.0 to 1.0)
  double getLevelProgress(int points) {
    if (points < 100) return points / 100.0;
    if (points < 500) return (points - 100) / 400.0;
    if (points < 1000) return (points - 500) / 500.0;
    if (points < 2500) return (points - 1000) / 1500.0;
    if (points < 5000) return (points - 2500) / 2500.0;
    return 1.0; // Max level
  }

  // Get achievement categories
  List<String> get achievementCategories {
    return _achievements
        .map((a) => a.category)
        .toSet()
        .toList()
        ..sort();
  }

  // Get reward categories
  List<String> get rewardCategories {
    return _rewards
        .map((r) => r.category)
        .where((c) => c != null)
        .cast<String>()
        .toSet()
        .toList()
        ..sort();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _updateRewardClaimStatus(String rewardId, bool claimed) {
    final index = _rewards.indexWhere((r) => r.id == rewardId);
    if (index != -1) {
      final reward = _rewards[index];
      final updatedReward = Reward(
        id: reward.id,
        uid: reward.uid,
        type: reward.type,
        title: reward.title,
        description: reward.description,
        points: reward.points,
        icon: reward.icon,
        category: reward.category,
        claimed: claimed,
        earnedAt: reward.earnedAt,
        claimedAt: claimed ? DateTime.now() : null,
        metadata: reward.metadata,
      );
      
      _rewards[index] = updatedReward;
      
      // Update summary
      if (_summary != null) {
        final unclaimedCount = claimed 
          ? _summary!.unclaimedRewards - 1 
          : _summary!.unclaimedRewards + 1;
        
        _summary = RewardSummary(
          totalRewards: _summary!.totalRewards,
          totalAchievements: _summary!.totalAchievements,
          pointsEarned: _summary!.pointsEarned,
          unclaimedRewards: unclaimedCount.clamp(0, _summary!.totalRewards),
          currentLevel: _summary!.currentLevel,
          pointsToNextLevel: _summary!.pointsToNextLevel,
        );
      }
      
      notifyListeners();
      _cacheData();
    }
  }

  void _startPeriodicRefresh(String uid) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      loadRewards(uid);
    });
  }

  // Cache management
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load rewards
      final cachedRewards = prefs.getString(_rewardsCacheKey);
      if (cachedRewards != null) {
        final rewardData = json.decode(cachedRewards);
        _rewards = (rewardData['rewards'] as List)
            .map((reward) => Reward.fromJson(reward))
            .toList();
      }
      
      // Load achievements
      final cachedAchievements = prefs.getString(_achievementsCacheKey);
      if (cachedAchievements != null) {
        final achievementData = json.decode(cachedAchievements);
        _achievements = (achievementData['achievements'] as List)
            .map((achievement) => Achievement.fromJson(achievement))
            .toList();
      }
      
      if (_rewards.isNotEmpty || _achievements.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached rewards: $e');
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache rewards
      final rewardData = {
        'rewards': _rewards.map((r) => r.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_rewardsCacheKey, json.encode(rewardData));
      
      // Cache achievements
      final achievementData = {
        'achievements': _achievements.map((a) => a.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_achievementsCacheKey, json.encode(achievementData));
    } catch (e) {
      debugPrint('Error caching rewards: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Static helper methods
  static IconData getIconForRewardType(String type) {
    switch (type) {
      case 'transaction_bonus':
        return Icons.account_balance_wallet;
      case 'friendship_bonus':
        return Icons.people;
      case 'daily_login':
        return Icons.calendar_today;
      case 'achievement_reward':
        return Icons.emoji_events;
      case 'referral_bonus':
        return Icons.share;
      case 'verification_bonus':
        return Icons.verified;
      case 'milestone_reward':
        return Icons.flag;
      default:
        return Icons.star;
    }
  }

  static Color getColorForRewardType(String type) {
    switch (type) {
      case 'transaction_bonus':
        return Colors.green;
      case 'friendship_bonus':
        return Colors.blue;
      case 'daily_login':
        return Colors.orange;
      case 'achievement_reward':
        return Colors.amber;
      case 'referral_bonus':
        return Colors.purple;
      case 'verification_bonus':
        return Colors.teal;
      case 'milestone_reward':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String formatPoints(int points) {
    if (points < 1000) return points.toString();
    if (points < 1000000) return '${(points / 1000).toStringAsFixed(1)}K';
    return '${(points / 1000000).toStringAsFixed(1)}M';
  }
}