import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/home_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/lendly_cards.dart';
import '../../widgets/lendly_buttons.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../wallet/wallet_screen.dart';
import '../chat/messages_screen.dart';
import 'widgets/home_header.dart';
import 'widgets/home_stats.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_content_sections.dart';

/// Optimized Home Screen - Clean Architecture & Performance
/// Broken into manageable components with proper state management
class HomeScreenOptimized extends StatefulWidget {
  const HomeScreenOptimized({super.key});

  @override
  State<HomeScreenOptimized> createState() => _HomeScreenOptimizedState();
}

class _HomeScreenOptimizedState extends State<HomeScreenOptimized>
    with AutomaticKeepAliveClientMixin {
  
  // Core state
  String? _userId;
  bool _isLoading = true;
  String? _error;
  
  // User data
  Map<String, dynamic> _userProfile = {};
  
  // Home data
  List<dynamic> _recentItems = [];
  List<dynamic> _nearbyItems = [];
  List<dynamic> _activeGroups = [];
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeHomeScreen();
  }

  Future<void> _initializeHomeScreen() async {
    try {
      _userId = await SessionService.getUserId();
      if (_userId != null) {
        await _loadHomeData();
      }
    } catch (e) {
      _setError('Failed to initialize home screen');
    }
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final homeService = HomeService('');
      
      // Load data in parallel for better performance
      final results = await Future.wait([
        homeService.getUserData(_userId!),
        homeService.getNewArrivals(_userId!),
        homeService.getPublicGroups(_userId!),
      ]);
      
      if (!mounted) return;
      
      setState(() {
        _userProfile = results[0] as Map<String, dynamic>;
        _recentItems = results[1] as List<dynamic>;
        _activeGroups = results[2] as List<dynamic>;
        _isLoading = false;
      });
      
    } catch (e) {
      _setError('Failed to load home data');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_error != null) {
      return _buildErrorState();
    }
    
    return _buildHomeContent();
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              AppSpacing.gapMd,
              Text(
                'Oops! Something went wrong',
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                _error ?? 'Please try again later',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapLg,
              LendlyPrimaryButton(
                text: 'Try Again',
                icon: Icons.refresh,
                onPressed: _loadHomeData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header with user info and notifications
            HomeHeader(
              userProfile: _userProfile,
              onProfileTap: () => _navigateToProfile(),
              onNotificationsTap: () => _navigateToNotifications(),
            ),
            
            // Stats section (trust score, coins, impact)
            HomeStats(userProfile: _userProfile),
            
            // Quick actions (add item, browse, messages, groups)
            const HomeQuickActions(),
            
            // Content sections (recent items, groups, etc.)
            HomeContentSections(
              recentItems: _recentItems,
              activeGroups: _activeGroups,
              nearbyItems: _nearbyItems,
            ),
            
            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Account for bottom nav
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _navigateToNotifications() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}
