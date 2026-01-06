import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_auth_service.dart';
import '../config/env_config.dart';

class CoinsService {
  // Use environment configuration for base URL
  static String get baseUrl => EnvConfig.socketUrl;

  /// Get user's wallet details
  static Future<Map<String, dynamic>> getWallet(String uid) async {
    try {
      final authService = FirebaseAuthService();
      final token = await authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/$uid/wallet'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[COINS] Wallet Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'wallet': data['wallet'] ?? {},
          'opportunities': data['opportunities'] ?? {},
          'spendingOptions': data['spendingOptions'] ?? {},
        };
      } else {
        print('[COINS] Error: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to fetch wallet'
        };
      }
    } catch (e) {
      print('[COINS] Exception: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  /// Get coin transaction history
  static Future<Map<String, dynamic>> getTransactionHistory(String uid, {int limit = 50}) async {
    try {
      final authService = FirebaseAuthService();
      final token = await authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/$uid/coin-transactions?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[COINS] History Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'transactions': data['transactions'] ?? [],
        };
      } else {
        print('[COINS] Error: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to fetch transaction history'
        };
      }
    } catch (e) {
      print('[COINS] Exception: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  /// Check if user has sufficient coins
  static Future<bool> hasSufficientCoins(String uid, int requiredAmount) async {
    try {
      final walletData = await getWallet(uid);
      if (walletData['success'] == true) {
        final balance = walletData['wallet']?['balance'] ?? 0;
        return balance >= requiredAmount;
      }
      return false;
    } catch (e) {
      print('[COINS] Error checking balance: $e');
      return false;
    }
  }

  /// Format coin amount with commas
  static String formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Get icon for transaction type
  static String getTransactionIcon(String type) {
    switch (type) {
      case 'earned':
        return '💰';
      case 'spent':
        return '💸';
      default:
        return '🪙';
    }
  }

  /// Get color for transaction type
  static int getTransactionColor(String type) {
    switch (type) {
      case 'earned':
        return 0xFF4CAF50; // Green
      case 'spent':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Parse earning opportunities
  static Map<String, dynamic> parseEarningOpportunities(Map<String, dynamic> opportunities) {
    final List<Map<String, dynamic>> items = [];
    
    opportunities.forEach((category, data) {
      if (data is Map) {
        if (category == 'verification') {
          items.add({
            'category': 'One-Time',
            'title': data['description'] ?? 'ID Verification',
            'coins': data['coins'] ?? 0,
            'icon': '✅',
          });
        } else if (category == 'transactions' && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              items.add({
                'category': 'Transactions',
                'title': value['description'] ?? key,
                'coins': value['coins'] ?? 0,
                'icon': '🤝',
              });
            }
          });
        } else if (category == 'bonuses' && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              items.add({
                'category': 'Bonuses',
                'title': value['description'] ?? key,
                'coins': value['coins'] ?? 0,
                'icon': '🎁',
              });
            }
          });
        }
      }
    });
    
    return {'items': items};
  }

  /// Parse spending options
  static Map<String, dynamic> parseSpendingOptions(Map<String, dynamic> options) {
    final List<Map<String, dynamic>> items = [];
    
    options.forEach((category, data) {
      if (data is Map) {
        if (category == 'listings' && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              items.add({
                'category': 'Listings',
                'title': value['description'] ?? key,
                'coins': value['coins'] ?? 0,
                'icon': '📝',
              });
            }
          });
        } else if (category == 'premium' && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              items.add({
                'category': 'Premium',
                'title': value['description'] ?? key,
                'coins': value['coins'] ?? 0,
                'icon': '⭐',
              });
            }
          });
        }
      }
    });
    
    return {'items': items};
  }
}
