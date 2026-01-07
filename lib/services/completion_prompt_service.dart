import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import '../config/app_colors.dart';
import '../widgets/welcome_bonus_dialog.dart';

class CompletionPromptService {
  static bool _hasShownWelcomeBonus = false;
  static bool _hasShownProfileCompletion = false;

  // Show welcome bonus dialog for new users
  static Future<void> checkAndShowWelcomeBonus(BuildContext context) async {
    if (_hasShownWelcomeBonus) return;
    
    try {
      final uid = await SessionService.getUid();
      if (uid == null) return;
      
      // Check if user has collected welcome bonus
      final userResponse = await SimpleApiClient.get(
        '/user/profile',
        queryParams: {'uid': uid},
        requiresAuth: true,
      );
      
      final userData = userResponse;
      if (userData['welcomeBonusCollected'] != true) {
        _hasShownWelcomeBonus = true;
        
        if (context.mounted) {
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const WelcomeBonusDialog(),
          );
          
          if (result == true) {
            // Bonus was collected, refresh any relevant data
            _showSuccessMessage(context, 'Welcome bonus collected! +100 coins');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking welcome bonus: $e');
    }
  }

  // Show profile completion prompt for incomplete profiles
  static Future<void> checkAndShowProfileCompletion(BuildContext context) async {
    if (_hasShownProfileCompletion) return;
    
    try {
      final uid = await SessionService.getUid();
      if (uid == null) return;
      
      final userResponse = await SimpleApiClient.get(
        '/user/profile',
        queryParams: {'uid': uid},
        requiresAuth: true,
      );
      
      final userData = userResponse;
      final isIncomplete = (userData['college'] ?? '').isEmpty ||
                          (userData['bio'] ?? '').isEmpty ||
                          (userData['interests'] ?? []).isEmpty;
      
      if (isIncomplete) {
        _hasShownProfileCompletion = true;
        
        if (context.mounted) {
          _showProfileCompletionDialog(context);
        }
      }
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
    }
  }

  static void _showProfileCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.account_circle, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Complete Your Profile'),
          ],
        ),
        content: const Text(
          'Complete your profile to get better recommendations and connect with your campus community!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile-edit');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Now'),
          ),
        ],
      ),
    );
  }

  // Show daily login streak notification
  static Future<void> processAndShowDailyLogin(BuildContext context) async {
    try {
      final uid = await SessionService.getUid();
      if (uid == null) return;
      
      final response = await SimpleApiClient.post(
        '/rewards/daily-login/$uid',
        requiresAuth: true,
      );
      
      if (response['success'] && response['reward'] > 0) {
        final streak = response['streak'];
        final reward = response['reward'];
        final isNewStreak = response['isNewStreak'];
        
        if (context.mounted) {
          _showDailyLoginDialog(context, streak, reward, isNewStreak);
        }
      }
    } catch (e) {
      debugPrint('Error processing daily login: $e');
    }
  }

  static void _showDailyLoginDialog(BuildContext context, int streak, int reward, bool isNewStreak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.success.withValues(alpha: 0.1),
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              isNewStreak ? 'Welcome Back!' : 'Streak Continues!',
              style: TextStyle(color: AppColors.success),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Login Streak: $streak day${streak == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '+$reward coins',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep logging in daily to maintain your streak and earn more coins!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  static void _showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Reset flags (useful for testing or new sessions)
  static void resetFlags() {
    _hasShownWelcomeBonus = false;
    _hasShownProfileCompletion = false;
  }

  // Helper function to get daily streak data
  static Future<Map<String, dynamic>> getDailyStreakData() async {
    try {
      final uid = await SessionService.getUid();
      if (uid == null) return {};
      
      final response = await SimpleApiClient.get(
        '/rewards/daily-streak/$uid',
        requiresAuth: true,
      );
      
      return {
        'streak': response['streak'] ?? 0,
        'reward': response['reward'] ?? 10,
        'isActive': response['isActive'] ?? false,
      };
    } catch (e) {
      return {};
    }
  }
}