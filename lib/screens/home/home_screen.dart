import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'dart:async';
import 'dart:io';
import 'item_detail_screen.dart';
import 'search_screen.dart';
import 'add_item_screen.dart';
import '../../services/home_service.dart';
import '../../services/session_service.dart';
import '../../services/impact_service.dart';
import '../../services/enhanced_chat_service.dart';
import '../../services/challenges_service.dart';
import '../../services/activities_service.dart';
import '../../config/api_config.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/app_logger.dart';
import '../notifications/notifications_screen.dart';
import '../groups/groups_screen.dart';
import '../impact/impact_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/messages_screen.dart';
import '../../widgets/trust_score_widgets.dart';
import '../../widgets/completion_widgets.dart';
import '../../services/coins_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // User Data
  String? userName;
  String? userCollege;
  String? userAvatar;
  String? uid;
  int notifications = 0;
  int trustScore = 50;
  String verificationStatus = 'unknown';
  int coinBalance = 0;
  
  // Home Data
  List<dynamic>? newArrivals = [];
  List<dynamic>? itemsNearYou = [];
  List<dynamic>? activeGroups = [];
  List<dynamic>? recentChats = [];
  Map<String, dynamic>? impactData;
  
  // Gamification Data
  Map<String, dynamic>? dailyChallenge;
  List<dynamic>? campusActivities = [];
  bool loadingChallenge = false;
  bool loadingActivities = false;
  
  // State
  bool isLoading = true;
  bool hasLocationPermission = false;
  bool _locationPermissionAsked = false;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Categories for quick access
  final List<Map<String, dynamic>> categories = [
    {'name': 'Books', 'icon': Icons.menu_book_rounded, 'color': Color(0xFF6366F1), 'query': 'books'},
    {'name': 'Electronics', 'icon': Icons.devices_rounded, 'color': Color(0xFF10B981), 'query': 'electronics'},
    {'name': 'Sports', 'icon': Icons.sports_soccer_rounded, 'color': Color(0xFFF59E0B), 'query': 'sports'},
    {'name': 'Tools', 'icon': Icons.build_rounded, 'color': Color(0xFFEF4444), 'query': 'tools'},
    {'name': 'Gaming', 'icon': Icons.sports_esports_rounded, 'color': Color(0xFF8B5CF6), 'query': 'gaming'},
    {'name': 'Music', 'icon': Icons.music_note_rounded, 'color': Color(0xFFEC4899), 'query': 'music'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _initData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// **OPTIMIZED** - Load all data in a single API call
  /// Reduces 6-8 separate API calls to just 1 consolidated request
  Future<void> _initData() async {
    final stopwatch = Stopwatch()..start();
    try {
      debugPrint('HomeScreen: Starting _initData...');
      
      // Add timeout to the entire operation
      await _initDataWithTimeout().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('HomeScreen: _initData timed out after 10 seconds');
          throw TimeoutException('Data loading timed out', const Duration(seconds: 10));
        },
      );
    } catch (e) {
      debugPrint('HomeScreen: Exception in _initData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request timed out. Please try again.')),
        );
      }
    } finally {
      debugPrint('HomeScreen: Setting isLoading = false');
      if (mounted) {
        setState(() => isLoading = false);
        _fadeController.forward();
      }
      stopwatch.stop();
      logger.logPerformance('Total home screen load', stopwatch.elapsed);
    }
  }

  Future<void> _initDataWithTimeout() async {
    debugPrint('HomeScreen: Calling SessionService.getUserId()...');
    uid = await SessionService.getUserId();
    debugPrint('HomeScreen: Got uid = ' + (uid?.toString() ?? 'null'));
    
    if (uid != null) {
      // Check location permission first (non-blocking)
      debugPrint('HomeScreen: Checking location permission...');
      final locationWatch = Stopwatch()..start();
      await _checkLocationPermission();
      locationWatch.stop();
      logger.logPerformance('Location permission + fetch', locationWatch.elapsed);
      
      // Get location if available for nearby items
      double? latitude;
      double? longitude;
      if (hasLocationPermission) {
        try {
          debugPrint('HomeScreen: Getting GPS location...');
          final gpsWatch = Stopwatch()..start();
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
          ).timeout(const Duration(seconds: 5));
          gpsWatch.stop();
          logger.logPerformance('GPS fetch', gpsWatch.elapsed);
          latitude = position.latitude;
          longitude = position.longitude;
          debugPrint('HomeScreen: Got location: $latitude, $longitude');
        } catch (e) {
          debugPrint('HomeScreen: Location fetch failed, continuing without it: $e');
        }
      } else {
        debugPrint('HomeScreen: No location permission, skipping GPS');
      }
      
      // **SINGLE API CALL** - Replaces multiple separate calls
      debugPrint('HomeScreen: Starting API call...');
      final apiWatch = Stopwatch()..start();
      try {
        await _loadAllHomeData(latitude: latitude, longitude: longitude);
        debugPrint('HomeScreen: API call completed successfully');
      } catch (e) {
        debugPrint('HomeScreen: Exception in _loadAllHomeData: $e');
        rethrow; // Let the timeout handler catch this
      }
      apiWatch.stop();
      logger.logPerformance('Home API call', apiWatch.elapsed);
    } else {
      debugPrint('HomeScreen: uid is null, not loading home data.');
    }
  }
  
  /// Load all home screen data in a single optimized API call
  Future<void> _loadAllHomeData({double? latitude, double? longitude}) async {
    debugPrint('HomeScreen: _loadAllHomeData called with uid=$uid, lat=$latitude, lon=$longitude');
    
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      debugPrint('HomeScreen: Created HomeService, calling getAllHomeData...');
      
      // Add timeout to the API call itself
      final data = await homeService.getAllHomeData(
        uid: uid!,
        latitude: latitude,
        longitude: longitude,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('HomeScreen: getAllHomeData timed out after 8 seconds');
          throw TimeoutException('API call timed out', const Duration(seconds: 8));
        },
      );
      
      debugPrint('HomeScreen: getAllHomeData completed, data keys: ${data.keys.toList()}');
      debugPrint('HomeScreen: Data summary - user: ${data['user'] != null}, wallet: ${data['wallet'] != null}, lists: ${data.length}');
      
      // Defensive: log if data is null or missing keys
      if (data.isEmpty) {
        debugPrint('HomeScreen: getAllHomeData returned empty data!');
        return;
      }
      
      // Extract user data
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
      final impact = data['impact'] as Map<String, dynamic>? ?? {};
      
      debugPrint('HomeScreen: Extracted data - user: ${user.keys.toList()}, wallet: ${wallet.keys.toList()}');
      
      if (mounted) {
        setState(() {
          // User info
          userName = user['first_name'] ?? user['name'] ?? 'Student';
          userCollege = user['college'] ?? 'Invertis University';
          userAvatar = user['avatar_url'] ?? user['avatar'];
          trustScore = (user['trustScore'] ?? 50).toInt();
          verificationStatus = user['verification_status'] ?? 'pending';
          notifications = user['notifications'] ?? 0;
          // Wallet
          coinBalance = wallet['balance'] ?? 0;
          // Impact
          impactData = impact;
          // Lists
          newArrivals = (data['newArrivals'] as List<dynamic>?) ?? [];
          itemsNearYou = (data['nearbyItems'] as List<dynamic>?) ?? [];
          activeGroups = (data['groups'] as List<dynamic>?) ?? [];
          recentChats = (data['recentChats'] as List<dynamic>?) ?? [];
          // Gamification
          dailyChallenge = data['dailyChallenge'] as Map<String, dynamic>?;
          campusActivities = (data['campusActivities'] as List<dynamic>?) ?? [];
          loadingChallenge = false;
          loadingActivities = false;
        });
        debugPrint('HomeScreen: State updated successfully');
      }
    } catch (e) {
      debugPrint('HomeScreen: Failed to load consolidated home data: $e');
      // Fallback to individual calls if consolidated fails
      try {
        debugPrint('HomeScreen: Attempting fallback...');
        await _loadDataFallback();
        debugPrint('HomeScreen: Fallback completed');
      } catch (fallbackError) {
        debugPrint('HomeScreen: Fallback also failed: $fallbackError');
      }
    }
  }
  
  /// Fallback method using individual API calls if consolidated fails
  Future<void> _loadDataFallback() async {
    await Future.wait([
      _loadUserData(),
      _loadHomeData(),
      _loadImpactData(),
      _loadRecentChats(),
      _loadGamificationData(),
    ]);
    if (hasLocationPermission) {
      await _loadNearbyItems();
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      debugPrint('HomeScreen: Checking location permission with timeout...');
      
      // Add timeout to location permission check
      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('HomeScreen: Location permission check timed out, assuming denied');
          return LocationPermission.denied;
        },
      );
      
      debugPrint('HomeScreen: Initial permission: $permission');
      
      if (permission == LocationPermission.denied && !_locationPermissionAsked) {
        _locationPermissionAsked = true;
        debugPrint('HomeScreen: Requesting location permission...');
        
        // Add timeout to permission request
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('HomeScreen: Location permission request timed out, assuming denied');
            return LocationPermission.denied;
          },
        );
        
        debugPrint('HomeScreen: Permission after request: $permission');
      }
      
      hasLocationPermission = permission == LocationPermission.always || 
                             permission == LocationPermission.whileInUse;
      
      debugPrint('HomeScreen: hasLocationPermission = $hasLocationPermission');
      
      if (hasLocationPermission) {
        debugPrint('HomeScreen: Loading nearby items...');
        await _loadNearbyItems().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('HomeScreen: _loadNearbyItems timed out');
          },
        );
      }
    } catch (e) {
      // Location permission check failed - continue without location features
      debugPrint('HomeScreen: Location permission error: $e');
      hasLocationPermission = false;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      final userData = await homeService.getUserData(uid!);
      
      setState(() {
        userName = userData['first_name'] ?? userData['name'] ?? 'Student';
        userCollege = userData['college'] ?? 'Invertis University';
        userAvatar = userData['avatar_url'] ?? userData['avatar'];
        trustScore = (userData['trustScore'] ?? 50).toInt();
        verificationStatus = userData['verification_status'] ?? 'pending';
        notifications = userData['notifications'] ?? 0;
      });
      
      // Load coin balance separately
      if (uid != null) {
        _loadCoinBalance();
      }
    } catch (e) {
      // Set defaults on error
      setState(() {
        userName = 'Student';
        userCollege = 'Invertis University';
        trustScore = 50;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data.')),
        );
      }
    }
  }
  
  Future<void> _loadCoinBalance() async {
    try {
      final walletData = await CoinsService.getWallet(uid!);
      if (walletData['success'] == true) {
        setState(() {
          coinBalance = walletData['wallet']?['balance'] ?? 0;
        });
      }
    } catch (e) {
      // Coin balance load failed - use default value
      debugPrint('Failed to load coin balance: $e');
    }
  }

  Future<void> _loadHomeData() async {
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      
      final results = await Future.wait([
        homeService.getNewArrivals(uid!),
        homeService.getPublicGroups(uid!),
      ]);
      
      setState(() {
        newArrivals = results[0];
        activeGroups = results[1];
      });
    } catch (e) {
      debugPrint('Failed to load home data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load home data.')),
        );
      }
    }
  }

  Future<void> _loadImpactData() async {
    try {
      final impactService = ImpactService(ApiConfig.baseUrl);
      final data = await impactService.getPersonalImpact(uid!);
      setState(() => impactData = data);
    } catch (e) {
      debugPrint('Failed to load impact data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load impact data.')),
        );
      }
    }
  }

  Future<void> _loadRecentChats() async {
    try {
      final chatService = ChatService();
      final chats = await chatService.getChatList(uid!, limit: 5);
      setState(() => recentChats = chats);
    } catch (e) {
      debugPrint('Failed to load recent chats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load recent chats.')),
        );
      }
    }
  }

  Future<void> _loadGamificationData() async {
    try {
      final token = await SessionService.getToken();
      if (token != null) {
        setState(() {
          loadingChallenge = true;
          loadingActivities = true;
        });

        // Load daily challenge and campus activities in parallel
        final results = await Future.wait([
          ChallengesService.getDailyChallenge(token).catchError((e) {
            return <String, dynamic>{};
          }),
          ActivitiesService.getCampusActivities(token, limit: 10).catchError((e) {
            return <String, dynamic>{'activities': []};
          }),
        ]);

        final challengeResponse = results[0] as Map<String, dynamic>;
        final activitiesResponse = results[1] as Map<String, dynamic>;

        setState(() {
          if (challengeResponse['success'] == true) {
            dailyChallenge = ChallengesService.parseChallengeForUI(challengeResponse);
          }
          
          if (activitiesResponse['success'] == true) {
            final activities = activitiesResponse['activities'] as List<dynamic>;
            campusActivities = activities.map((activity) => 
              ActivitiesService.parseActivityForUI(activity)
            ).toList();
          }
          
          loadingChallenge = false;
          loadingActivities = false;
        });
      }
    } catch (e) {
      setState(() {
        loadingChallenge = false;
        loadingActivities = false;
      });
    }
  }

  Future<void> _loadNearbyItems() async {
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      
      final nearbyData = await homeService.getItemsNearLocation(
        uid!,
        position.latitude,
        position.longitude,
      );
      
      setState(() => itemsNearYou = nearbyData);
    } catch (e) {
      debugPrint('Failed to load nearby items: $e');
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.mediumImpact();
    await _initData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Get proper image provider for avatar (checks if local asset or network URL)
  ImageProvider? _getAvatarImage(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    
    // Decode HTML entities (e.g., &#x2F; to /)
    String cleanPath = avatarPath.trim()
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#x5C;', '\\')
        .replaceAll('&amp;', '&');
    
    // SVG files need special handling - return null so we can use a different widget
    if (cleanPath.endsWith('.svg')) {
      return null;
    }
    
    // Check if it's a local asset path
    if (cleanPath.startsWith('assets/') || cleanPath.startsWith('/assets/')) {
      return AssetImage(cleanPath.replaceFirst(RegExp(r'^/'), ''));
    }
    
    // Check if it's a valid URL
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return NetworkImage(cleanPath);
    }
    
    // Default to null for invalid paths
    return null;
  }

  /// Build avatar widget (handles SVG, assets, and network images)
  Widget _buildAvatarWidget(String? avatarPath, String fallbackText) {
    // Add cache key to force refresh when avatar changes
    final cacheKey = avatarPath != null ? '${avatarPath}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}' : 'default';
    
    if (avatarPath == null || avatarPath.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          fallbackText.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1DBF73),
          ),
        ),
      );
    }

    // Decode HTML entities
    String cleanPath = avatarPath.trim()
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#x5C;', '\\')
        .replaceAll('&amp;', '&');

    // Handle SVG files
    if (cleanPath.endsWith('.svg')) {
      if (cleanPath.startsWith('assets/') || cleanPath.startsWith('/assets/')) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: SvgPicture.asset(
              cleanPath.replaceFirst(RegExp(r'^/'), ''),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      // Network SVG would need flutter_svg NetworkSvg widget
      return CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          fallbackText.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1DBF73),
          ),
        ),
      );
    }

    // Handle regular images
    final imageProvider = _getAvatarImage(cleanPath);
    if (imageProvider != null) {
      return CircleAvatar(
        backgroundColor: Colors.white,
        backgroundImage: imageProvider,
      );
    }

    // Fallback
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: Text(
        fallbackText.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Color(0xFF1DBF73),
        ),
      ),
    );
  }

  /// Build small avatar widget for items and chats
  Widget _buildSmallAvatar(String? avatarPath, String fallbackText) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return Center(
        child: Text(
          fallbackText.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    // Decode HTML entities
    String cleanPath = avatarPath.trim()
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#x5C;', '\\')
        .replaceAll('&amp;', '&');

    // Handle SVG files
    if (cleanPath.endsWith('.svg') && cleanPath.startsWith('assets/')) {
      return SvgPicture.asset(
        cleanPath.replaceFirst(RegExp(r'^/'), ''),
        fit: BoxFit.cover,
      );
    }

    // Handle regular images
    final imageProvider = _getAvatarImage(cleanPath);
    if (imageProvider != null) {
      return Image(
        image: imageProvider,
        fit: BoxFit.cover,
      );
    }

    // Fallback
    return Center(
      child: Text(
        fallbackText.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo with subtle pulse effect
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DBF73), Color(0xFF10B981), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DBF73).withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/app-icon.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.handshake_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Lendly',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Share. Save. Sustain.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: const Color(0xFF1DBF73),
                  strokeWidth: 3.5,
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error or empty state handling
    final bool isAllDataEmpty =
        (newArrivals == null || newArrivals!.isEmpty) &&
        (itemsNearYou == null || itemsNearYou!.isEmpty) &&
        (activeGroups == null || activeGroups!.isEmpty) &&
        (recentChats == null || recentChats!.isEmpty) &&
        (campusActivities == null || campusActivities!.isEmpty);

    if (isAllDataEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 64, color: Color(0xFF1DBF73)),
              const SizedBox(height: 24),
              const Text(
                'Nothing to show yet!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No data found. Try refreshing or check back later.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DBF73),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF1DBF73),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom App Bar with Greeting
              _buildCustomAppBar(),
              
              // Profile Completion Banner (if applicable)
              SliverToBoxAdapter(child: ProfileCompletionBanner()),
              
              // Search Bar
              SliverToBoxAdapter(child: _buildSearchBar()),
              
              // Welcome/Promo Banner
              SliverToBoxAdapter(child: _buildPromoBanner()),
              
              // Quick Stats Cards
              SliverToBoxAdapter(child: _buildQuickStats()),
              
              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions()),
              
              // Daily Challenge Card
              SliverToBoxAdapter(child: _buildDailyChallenge()),
              
              // Categories
              SliverToBoxAdapter(child: _buildCategories()),
              
              // Activity Feed - Your Network
              SliverToBoxAdapter(child: _buildActivityFeed()),
              
              // New Arrivals
              if (newArrivals?.isNotEmpty ?? false)
                SliverToBoxAdapter(child: _buildNewArrivals()),
              
              // Items Near You - moved up for better positioning
              SliverToBoxAdapter(child: _buildNearbyItems()),
              
              // Active Groups
              if (activeGroups?.isNotEmpty ?? false)
                SliverToBoxAdapter(child: _buildActiveGroups()),
              
              // Impact Summary - moved to bottom for better flow
              SliverToBoxAdapter(child: _buildImpactSummary()),
              
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1DBF73),
      surfaceTintColor: const Color(0xFF1DBF73),
      elevation: 0,
      actions: [
        // Messages Icon
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesScreen()),
              );
            },
            icon: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                ),
                if ((recentChats?.length ?? 0) > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${(recentChats?.length ?? 0).clamp(0, 9)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Notification Bell
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _buildNotificationBell(),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1DBF73),
                const Color(0xFF10B981),
                const Color(0xFF0D9488),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1DBF73).withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Enhanced User Avatar
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        child: Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Consumer<UserProvider>(
                              builder: (context, userProvider, child) {
                                // Use provider avatar if available, fallback to local userAvatar
                                final avatarToShow = userProvider.avatar ?? userAvatar;
                                return _buildAvatarWidget(avatarToShow, userName ?? 'U');
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Enhanced Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userName ?? 'Student',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Enhanced College Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          userCollege ?? 'Invertis University',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (verificationStatus == 'verified') ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, color: Color(0xFF1DBF73), size: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      icon: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
          ),
          if (notifications > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  notifications > 9 ? '9+' : '$notifications',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SearchScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1DBF73).withValues(alpha: 0.12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF1DBF73).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1DBF73).withValues(alpha: 0.15),
                      const Color(0xFF1DBF73).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: Color(0xFF1DBF73), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search items...',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Books, Electronics, Sports gear & more',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '✨ New Feature',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Share & Earn Rewards!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Lend items to earn trust points and unlock exclusive badges',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Start Lending',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF6366F1),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // Top Row - Trust Score (full width for prominence)
          _buildPrimaryStatCard(
            'Trust Score',
            TrustScoreBadge(score: trustScore, showLabel: false, size: 20),
            Icons.shield_rounded,
            const Color(0xFF1DBF73),
            const Color(0xFF0F766E),
            'Build trust by lending & borrowing',
            () {},
          ),
          const SizedBox(height: 16),
          // Bottom Row - Coins & Impact
          Row(
            children: [
              Expanded(
                child: _buildSecondaryStatCard(
                  'Lend Coins',
                  CoinBalance(balance: coinBalance, showLabel: false, iconSize: 22),
                  Icons.monetization_on_rounded,
                  const Color(0xFFFFA726),
                  const Color(0xFFFF8F00),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSecondaryStatCard(
                  'Items Shared',
                  Text(
                    '${impactData?['items_shared'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                      letterSpacing: -1,
                    ),
                  ),
                  Icons.eco_rounded,
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImpactScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.4), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardWithWidget(String title, Widget valueWidget, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  valueWidget,
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.4), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryStatCard(String title, Widget valueWidget, IconData icon, Color primaryColor, Color secondaryColor, String subtitle, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                valueWidget,
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatCard(String title, Widget valueWidget, IconData icon, Color primaryColor, Color secondaryColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.15),
                        primaryColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: primaryColor, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            valueWidget,
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Lend Item',
                  Icons.add_box_rounded,
                  const Color(0xFF1DBF73),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Browse',
                  Icons.search_rounded,
                  const Color(0xFF6366F1),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Messages',
                  Icons.chat_rounded,
                  const Color(0xFFEC4899),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Groups',
                  Icons.groups_rounded,
                  const Color(0xFFF59E0B),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Browse Categories',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SearchScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Row(
                  children: const [
                    Text(
                      'See All',
                      style: TextStyle(
                        color: Color(0xFF1DBF73),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF1DBF73),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(initialQuery: category['query']),
                    ),
                  );
                },
                child: Container(
                  width: 85,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: (category['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: (category['color'] as Color).withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (category['color'] as Color).withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          category['icon'] as IconData,
                          color: category['color'] as Color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImpactSummary() {
    final moneySaved = impactData?['money_saved'] ?? 0;
    final itemsShared = impactData?['items_shared'] ?? 0;
    final co2Saved = impactData?['co2_saved'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ImpactScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your Positive Impact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildImpactItem('₹$moneySaved', 'Saved'),
                  _buildImpactDivider(),
                  _buildImpactItem('$itemsShared', 'Items Shared'),
                  _buildImpactDivider(),
                  _buildImpactItem('${co2Saved}kg', 'CO₂ Reduced'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpactItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildImpactDivider() {
    return Container(
      height: 35,
      width: 1,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildNewArrivals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.new_releases_rounded, color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'New Arrivals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if ((newArrivals?.length ?? 0) > 5)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SearchScreen()),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF1DBF73)),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: (newArrivals?.length ?? 0).clamp(0, 10),
            itemBuilder: (context, index) {
              final item = newArrivals![index];
              return _buildItemCard(item, isHorizontal: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Near You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if ((itemsNearYou?.length ?? 0) > 5)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SearchScreen()),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF1DBF73)),
                  ),
                ),
            ],
          ),
        ),
        if (itemsNearYou?.isEmpty ?? true)
          _buildEmptyNearby(MediaQuery.of(context).size.width)
        else
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, right: 4),
              physics: const BouncingScrollPhysics(),
              itemCount: (itemsNearYou?.length ?? 0).clamp(0, 10),
              itemBuilder: (context, index) {
                final item = itemsNearYou![index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildItemCard(item, isHorizontal: true, showDistance: true),
                );
              },
            ),
          ),
      ],
    );
  }

          Widget _buildEmptyNearby(double width) {
            return Center(
              child: Container(
                width: width > 340 ? width - 40 : width, // leave some margin
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        hasLocationPermission ? Icons.location_off_rounded : Icons.location_disabled_rounded,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasLocationPermission ? 'No items nearby' : 'Enable Location',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasLocationPermission
                          ? 'Be the first to share items in your area!'
                          : 'Allow location to discover items near you',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!hasLocationPermission) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Geolocator.openAppSettings();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('Open Settings'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

  Widget _buildItemCard(Map<String, dynamic> item, {bool isHorizontal = false, bool showDistance = false}) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: item),
            settings: RouteSettings(arguments: uid),
          ),
        );
        
        if (result == true && mounted) {
          setState(() {
            newArrivals?.removeWhere((i) => i['id'] == item['id']);
            itemsNearYou?.removeWhere((i) => i['id'] == item['id']);
          });
        }
      },
      child: Container(
        width: isHorizontal ? 200 : null,
        margin: EdgeInsets.only(right: isHorizontal ? 16 : 0, bottom: isHorizontal ? 0 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: (item['image'] != null && item['image'].toString().isNotEmpty)
                        ? Image.network(
                            item['image'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  // Availability Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (item['available'] ?? true) 
                            ? const Color(0xFF10B981) 
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (item['available'] ?? true) ? 'Available' : 'Unavailable',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Type Badge
                  if (item['type'] != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['type']?.toString().toUpperCase() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown Item',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                        ),
                        child: ClipOval(
                          child: _buildSmallAvatar(item['userAvatar'], item['owner'] ?? 'U'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item['owner'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item['ownerTrustScore'] != null)
                        TrustScoreBadge(
                          score: (item['ownerTrustScore'] ?? 50).toInt(), 
                          showLabel: false, 
                          size: 14
                        ),
                    ],
                  ),
                  if (showDistance && item['distance'] != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          item['distance'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(Icons.image_rounded, color: Colors.grey[400], size: 36),
      ),
    );
  }

  Widget _buildActiveGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_rounded, color: Color(0xFF6366F1), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Active Groups',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(color: Color(0xFF1DBF73)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 70,
          width: double.infinity,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: (activeGroups?.length ?? 0).clamp(0, 5),
            itemBuilder: (context, index) {
              final group = activeGroups![index];
              return _buildGroupChip(group);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupChip(Map<String, dynamic> group) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GroupsScreen()),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (group['name'] ?? 'G').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] ?? 'Group',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${group['members_count'] ?? 0} members',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }





  Widget _buildChatItem(Map<String, dynamic> chat, {bool isLast = false}) {
    final otherUserName = chat['other_user_name'] ?? chat['otherUserName'] ?? chat['name'] ?? 'User';
    final otherUserAvatar = chat['other_user_avatar'] ?? chat['otherUserAvatar'] ?? chat['avatar'];
    final lastMessage = chat['last_message'] ?? chat['lastMessage'] ?? '';
    final unreadCount = chat['unread_count'] ?? chat['unreadCount'] ?? 0;
    final lastMessageTime = chat['last_message_time'] ?? chat['lastMessageTime'];
    
    String timeAgo = '';
    if (lastMessageTime != null) {
      try {
        final DateTime msgTime = lastMessageTime is String 
            ? DateTime.parse(lastMessageTime) 
            : DateTime.fromMillisecondsSinceEpoch(lastMessageTime);
        final diff = DateTime.now().difference(msgTime);
        if (diff.inMinutes < 1) {
          timeAgo = 'now';
        } else if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h';
        } else if (diff.inDays < 7) {
          timeAgo = '${diff.inDays}d';
        } else {
          timeAgo = '${(diff.inDays / 7).floor()}w';
        }
      } catch (_) {
        // Date parsing failed - show empty time, not critical
      }
    }
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to messages screen which handles chat opening
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: isLast ? null : Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unreadCount > 0 
                          ? const Color(0xFFEC4899) 
                          : Colors.grey.withValues(alpha: 0.2),
                      width: unreadCount > 0 ? 2 : 1,
                    ),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1F5F9),
                    ),
                    child: ClipOval(
                      child: _buildSmallAvatar(otherUserAvatar, otherUserName),
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEC4899),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherUserName,
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: unreadCount > 0 
                                ? const Color(0xFFEC4899) 
                                : Colors.grey[500],
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage.isEmpty ? 'Start chatting...' : lastMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: unreadCount > 0 
                          ? const Color(0xFF475569) 
                          : Colors.grey[500],
                      fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChallenge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'List 1 item today and earn 50 bonus coins!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityFeed() {
    // Show loading state if activities are being loaded
    if (loadingActivities) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
            child: Row(
              children: [
                const Text(
                  'Campus Activity',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DBF73).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1DBF73),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Loading',
                        style: TextStyle(
                          color: Color(0xFF1DBF73),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DBF73)),
            ),
          ),
        ],
      );
    }

    // Show empty state if no activities
    if (campusActivities == null || campusActivities!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
            child: Row(
              children: [
                const Text(
                  'Campus Activity',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'No Activity',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 120,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    size: 32,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recent activity on campus',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
          child: Row(
            children: [
              const Text(
                'Campus Activity',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DBF73).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.trending_up_rounded, color: Color(0xFF1DBF73), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Color(0xFF1DBF73),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: campusActivities!.length,
            itemBuilder: (context, index) {
              final activity = campusActivities![index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1DBF73),
                      child: activity['user']['avatar'] != null 
                        ? Text(
                            activity['user']['avatar']!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          )
                        : Text(
                            (activity['user']['name'] as String?)?.isNotEmpty == true 
                              ? activity['user']['name'][0].toUpperCase()
                              : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                              children: [
                                TextSpan(
                                  text: activity['user']['name'] ?? 'Anonymous',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(text: ' ${_getActivityAction(activity['type'])} '),
                                TextSpan(
                                  text: activity['title'] ?? 'Activity',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1DBF73)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                ActivitiesService.formatTimestamp(activity['timestamp']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              if (activity['likes'] != null && activity['likes'] > 0) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.favorite_rounded,
                                  size: 12,
                                  color: Colors.red[400],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${activity['likes']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper method to get activity action text based on type
  String _getActivityAction(String? type) {
    switch (type) {
      case 'item_listed':
        return 'listed';
      case 'transaction_completed':
        return 'completed transaction for';
      case 'challenge_completed':
        return 'completed challenge';
      case 'group_joined':
        return 'joined group';
      case 'impact_shared':
        return 'shared impact about';
      case 'achievement_unlocked':
        return 'unlocked achievement';
      case 'milestone_reached':
        return 'reached milestone';
      case 'friend_added':
        return 'added friend';
      default:
        return 'had activity with';
    }
  }
}
