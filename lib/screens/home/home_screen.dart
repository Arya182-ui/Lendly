import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'item_detail_screen.dart';
import 'search_screen.dart';
import 'add_item_screen.dart';
import '../../services/home_service.dart';
import '../../services/session_service.dart';
import '../../services/impact_service.dart';
import '../../services/enhanced_chat_service.dart';
import '../../config/api_config.dart';
import 'package:geolocator/geolocator.dart';
import '../notifications/notifications_screen.dart';
import '../groups/groups_screen.dart';
import '../impact/impact_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/messages_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

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
  double trustScore = 0;
  String verificationStatus = 'unknown';
  int wallet = 0;
  
  // Home Data
  List<dynamic>? newArrivals = [];
  List<dynamic>? itemsNearYou = [];
  List<dynamic>? activeGroups = [];
  List<dynamic>? recentChats = [];
  Map<String, dynamic>? impactData;
  
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

  Future<void> _initData() async {
    try {
      uid = await SessionService.getUserId();
      
      if (uid != null) {
        await Future.wait([
          _loadUserData(),
          _loadHomeData(),
          _loadImpactData(),
          _loadRecentChats(),
        ]);
        await _checkLocationPermission();
      }
      
      setState(() => isLoading = false);
      _fadeController.forward();
    } catch (e) {
      debugPrint('Error initializing home screen: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied && !_locationPermissionAsked) {
        _locationPermissionAsked = true;
        permission = await Geolocator.requestPermission();
      }
      
      hasLocationPermission = permission == LocationPermission.always || 
                             permission == LocationPermission.whileInUse;
      
      if (hasLocationPermission) {
        await _loadNearbyItems();
      }
    } catch (e) {
      debugPrint('Error checking location permission: $e');
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
        trustScore = (userData['trust_score'] ?? 4.5).toDouble();
        verificationStatus = userData['verification_status'] ?? 'pending';
        wallet = userData['wallet'] ?? 0;
        notifications = userData['notifications'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Set defaults on error
      setState(() {
        userName = 'Student';
        userCollege = 'Invertis University';
        trustScore = 4.5;
      });
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
      debugPrint('Error loading home data: $e');
    }
  }

  Future<void> _loadImpactData() async {
    try {
      final impactService = ImpactService(ApiConfig.baseUrl);
      final data = await impactService.getPersonalImpact(uid!);
      setState(() => impactData = data);
    } catch (e) {
      debugPrint('Error loading impact data: $e');
    }
  }

  Future<void> _loadRecentChats() async {
    try {
      final chatService = ChatService();
      final chats = await chatService.getChatList(uid!, limit: 5);
      setState(() => recentChats = chats);
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
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
      debugPrint('Error loading nearby items: $e');
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
    debugPrint('Invalid avatar path: $cleanPath');
    return null;
  }

  /// Build avatar widget (handles SVG, assets, and network images)
  Widget _buildAvatarWidget(String? avatarPath, String fallbackText) {
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
              // Animated logo placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DBF73), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DBF73).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/app-icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.handshake_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Lendly',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share. Save. Sustain.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: const Color(0xFF1DBF73),
                  strokeWidth: 3,
                  backgroundColor: Colors.grey[200],
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
              
              // Search Bar
              SliverToBoxAdapter(child: _buildSearchBar()),
              
              // Welcome/Promo Banner
              SliverToBoxAdapter(child: _buildPromoBanner()),
              
              // Quick Stats Cards
              SliverToBoxAdapter(child: _buildQuickStats()),
              
              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions()),
              
              // Categories
              SliverToBoxAdapter(child: _buildCategories()),
              
              // Impact Summary - Always show with defaults
              SliverToBoxAdapter(child: _buildImpactSummary()),
              
              // New Arrivals
              if (newArrivals?.isNotEmpty ?? false)
                SliverToBoxAdapter(child: _buildNewArrivals()),
              
              // Items Near You
              SliverToBoxAdapter(child: _buildNearbyItems()),
              
              // Recent Messages
              SliverToBoxAdapter(child: _buildRecentMessages()),
              
              // Active Groups
              if (activeGroups?.isNotEmpty ?? false)
                SliverToBoxAdapter(child: _buildActiveGroups()),
              
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
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1DBF73),
                const Color(0xFF0D9488),
                const Color(0xFF0D9488).withValues(alpha: 0.9),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // User Avatar
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ),
                        child: Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _buildAvatarWidget(userAvatar, userName ?? 'U'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              userName ?? 'Student',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Notification Bell
                      _buildNotificationBell(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // College Tag with better styling
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userCollege ?? 'Invertis University',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (verificationStatus == 'verified') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, color: Color(0xFF1DBF73), size: 14),
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
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
            if (notifications > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    notifications > 99 ? '99+' : '$notifications',
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
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SearchScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1DBF73).withValues(alpha: 0.08), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DBF73).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: Color(0xFF1DBF73), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search items...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Books, Electronics, Sports gear & more',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✨ New Feature',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Share & Earn Rewards!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lend items to earn trust points and unlock exclusive badges',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Start Lending →',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Trust Score',
              trustScore.toStringAsFixed(1),
              Icons.shield_rounded,
              const Color(0xFF1DBF73),
              () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Wallet',
              '₹$wallet',
              Icons.account_balance_wallet_rounded,
              const Color(0xFF6366F1),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Impact',
              '${impactData?['items_shared'] ?? 0}',
              Icons.eco_rounded,
              const Color(0xFF10B981),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImpactScreen()),
              ),
            ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.5), size: 14),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Browse Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
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
          height: 100,
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
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: (category['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
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
          _buildEmptyNearby()
        else
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: (itemsNearYou?.length ?? 0).clamp(0, 10),
              itemBuilder: (context, index) {
                final item = itemsNearYou![index];
                return _buildItemCard(item, isHorizontal: true, showDistance: true);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyNearby() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
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
                  backgroundColor: const Color(0xFF1DBF73),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        width: isHorizontal ? 170 : null,
        margin: EdgeInsets.only(right: isHorizontal ? 12 : 0, bottom: isHorizontal ? 0 : 12),
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
                  const SizedBox(width: 10),
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
          height: 90,
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

  Widget _buildRecentMessages() {
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
                      color: const Color(0xFFFCE7F3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFEC4899), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF1DBF73)),
                label: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF1DBF73), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (recentChats?.isEmpty ?? true)
          _buildEmptyMessages()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(
                  (recentChats?.length ?? 0).clamp(0, 3),
                  (index) => _buildChatItem(recentChats![index], isLast: index == (recentChats!.length.clamp(0, 3) - 1)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyMessages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFEC4899).withValues(alpha: 0.08),
                const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEC4899).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 28,
                  color: Color(0xFFEC4899),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start a Conversation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect with lenders & borrowers',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
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
      } catch (_) {}
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
}
