import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class WalletService {
  static const String baseUrl = '${ApiConfig.baseUrl}/wallet';

  // Transaction types
  static const String TRANSACTION_EARNED = 'earned_transaction';
  static const String TRANSACTION_BONUS_SIGNUP = 'bonus_signup';
  static const String TRANSACTION_BONUS_REFERRAL = 'bonus_referral';
  static const String TRANSACTION_BONUS_VERIFICATION = 'bonus_verification';
  static const String TRANSACTION_SPENT = 'spent_transaction';
  static const String TRANSACTION_SPENT_LISTING = 'spent_listing';
  static const String TRANSACTION_ADMIN_ADJUSTMENT = 'admin_adjustment';

  // Wallet configuration
  static const Map<String, int> walletConfig = {
    'SIGNUP_BONUS': 100,
    'REFERRAL_BONUS': 50,
    'VERIFICATION_BONUS': 25,
    'TRANSACTION_REWARD': 10,
    'LISTING_COST': 5,
    'INITIAL_BALANCE': 100,
  };

  // Get user wallet
  static Future<Map<String, dynamic>> getWallet(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$uid'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'wallet': data['wallet'],
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Failed to get wallet',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get transaction history
  static Future<Map<String, dynamic>> getTransactions(
    String uid, {
    int limit = 20,
    int offset = 0,
    String? type,
  }) async {
    try {
      String url = '$baseUrl/$uid/transactions?limit=$limit&offset=$offset';
      if (type != null && type.isNotEmpty && type != 'all') {
        url += '&type=$type';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'transactions': data['transactions'],
            'hasMore': data['hasMore'] ?? false,
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Failed to get transactions',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Award points to user
  static Future<Map<String, dynamic>> awardPoints(
    String uid,
    int amount,
    String type,
    String description, {
    String? relatedId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$uid/award'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': amount,
          'type': type,
          'description': description,
          if (relatedId != null) 'relatedId': relatedId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'transaction': data['transaction'],
            'newBalance': data['newBalance'],
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Failed to award points',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Spend points
  static Future<Map<String, dynamic>> spendPoints(
    String uid,
    int amount,
    String type,
    String description, {
    String? relatedId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$uid/spend'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': amount,
          'type': type,
          'description': description,
          if (relatedId != null) 'relatedId': relatedId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'transaction': data['transaction'],
            'newBalance': data['newBalance'],
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Failed to spend points',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get wallet statistics
  static Future<Map<String, dynamic>> getWalletStats(
    String uid, {
    String period = '30d',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$uid/stats?period=$period'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'stats': data['stats'],
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Failed to get wallet statistics',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Check if user has sufficient balance
  static Future<bool> hasSufficientBalance(String uid, int requiredAmount) async {
    try {
      final result = await getWallet(uid);
      if (result['success'] == true) {
        final wallet = result['wallet'];
        return wallet['balance'] >= requiredAmount;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get transaction type display name
  static String getTransactionTypeDisplayName(String type) {
    switch (type) {
      case TRANSACTION_EARNED:
        return 'Transaction Reward';
      case TRANSACTION_BONUS_SIGNUP:
        return 'Welcome Bonus';
      case TRANSACTION_BONUS_REFERRAL:
        return 'Referral Bonus';
      case TRANSACTION_BONUS_VERIFICATION:
        return 'Verification Bonus';
      case TRANSACTION_SPENT:
        return 'Transaction Payment';
      case TRANSACTION_SPENT_LISTING:
        return 'Item Listing';
      case TRANSACTION_ADMIN_ADJUSTMENT:
        return 'Admin Adjustment';
      default:
        return type.replaceAll('_', ' ').toLowerCase();
    }
  }

  // Get transaction type icon
  static String getTransactionTypeIcon(String type) {
    switch (type) {
      case TRANSACTION_EARNED:
        return '💰';
      case TRANSACTION_BONUS_SIGNUP:
        return '🎉';
      case TRANSACTION_BONUS_REFERRAL:
        return '👥';
      case TRANSACTION_BONUS_VERIFICATION:
        return '✅';
      case TRANSACTION_SPENT:
        return '💸';
      case TRANSACTION_SPENT_LISTING:
        return '📝';
      case TRANSACTION_ADMIN_ADJUSTMENT:
        return '⚙️';
      default:
        return '💳';
    }
  }

  // Format amount with currency
  static String formatAmount(int amount) {
    return '$amount pts';
  }

  // Format balance for display
  static String formatBalance(int balance) {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(1)}M pts';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(1)}K pts';
    } else {
      return '$balance pts';
    }
  }
}