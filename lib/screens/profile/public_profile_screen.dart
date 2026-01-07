import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../services/friendship_service.dart';
import '../../config/env_config.dart';
import 'package:lendly/widgets/avatar_options.dart';
import 'package:lendly/services/session_service.dart';
import '../chat/chat_screen.dart';
import '../../widgets/enhanced_ui_components.dart';
import '../../widgets/app_image.dart';
import '../../widgets/trust_score_widgets.dart';
import '../../providers/user_provider.dart';

class PublicProfileScreen extends StatefulWidget {
  final String uid;
  const PublicProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> with TickerProviderStateMixin {
    String? myUid;
    FriendshipStatus? friendshipStatus;
    bool isFriendshipLoading = true;
    late AnimationController _animationController;
    late Animation<double> _fadeAnimation;
    List<Map<String, dynamic>> userItems = [];
    List<Map<String, dynamic>> userBadges = [];
    bool isItemsLoading = false;
    int totalBorrows = 0;
    int totalLends = 0;
    String joinedDate = '';
    double profileCompleteness = 0.0;
    Map<String, dynamic>? profile;
    final FriendshipService _friendshipService = FriendshipService();


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  Future<void> _initProfile() async {
    myUid = await SessionService.getUid();
    await _fetchPublicProfile();
    await _fetchUserItems();
    await _fetchUserStats();
    if (myUid != null && myUid != widget.uid) {
      await _fetchFriendshipStatus();
    }
    _animationController.forward();
  }

  Future<void> _fetchUserItems() async {
    setState(() { isItemsLoading = true; });
    try {
      final data = await SimpleApiClient.get(
        '/user/items',
        queryParams: {'uid': widget.uid, 'limit': '6'},
        requiresAuth: true,
      );
      setState(() {
        userItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
      });
    } catch (e) {
      // Handle error silently
    }
    setState(() { isItemsLoading = false; });
  }

  Future<void> _fetchUserStats() async {
    try {
      final stats = await SimpleApiClient.get(
        '/user/stats',
        queryParams: {'uid': widget.uid},
        requiresAuth: true,
      );
      setState(() {
        totalBorrows = stats['totalBorrows'] ?? 0;
        totalLends = stats['totalLends'] ?? 0;
        joinedDate = stats['joinedDate'] ?? '';
        userBadges = List<Map<String, dynamic>>.from(stats['badges'] ?? []);
        profileCompleteness = stats['profileCompleteness'] ?? 0.0;
      });
    } catch (e) {
      // Handle error silently
    }
  }

    Future<void> _fetchFriendshipStatus() async {
      if (myUid == null) return;
      
      setState(() { isFriendshipLoading = true; });
      try {
        final statusData = await _friendshipService.getFriendshipStatus(myUid!, widget.uid);
        setState(() {
          friendshipStatus = FriendshipStatus.fromMap(statusData);
          isFriendshipLoading = false;
        });
      } catch (e) {
        setState(() { 
          friendshipStatus = null;
          isFriendshipLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load friendship status: ${e.toString()}')),
          );
        }
      }
    }

    Future<void> _handleAddFriend() async {
      if (myUid == null) return;
      
      setState(() { isFriendshipLoading = true; });
      
      try {
        await _friendshipService.sendFriendRequest(myUid!, widget.uid);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        await _fetchFriendshipStatus();
      } catch (e) {
        setState(() { isFriendshipLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send friend request: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> _handleAcceptRequest() async {
      if (myUid == null) return;
      
      setState(() { isFriendshipLoading = true; });
      
      try {
        await _friendshipService.acceptFriendRequest(widget.uid, myUid!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request accepted!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        await _fetchFriendshipStatus();
      } catch (e) {
        setState(() { isFriendshipLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to accept request: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> _handleRejectRequest() async {
      if (myUid == null) return;
      
      setState(() { isFriendshipLoading = true; });
      
      try {
        await _friendshipService.rejectFriendRequest(widget.uid, myUid!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        await _fetchFriendshipStatus();
      } catch (e) {
        setState(() { isFriendshipLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject request: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> _handleRemoveFriend() async {
      if (myUid == null) return;
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Friend'),
          content: Text('Are you sure you want to remove ${profile?['name'] ?? 'this user'} from your friends?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      
      if (result != true) return;
      
      setState(() { isFriendshipLoading = true; });
      
      try {
        await _friendshipService.removeFriend(myUid!, widget.uid);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend removed successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        await _fetchFriendshipStatus();
      } catch (e) {
        setState(() { isFriendshipLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove friend: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> _handleChat() async {
      if (profile == null) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedChatScreen(
            chatId: widget.uid, // Use the profile UID as chat ID
            peerUid: widget.uid,
            peerName: profile?['first_name'] ?? 'User',
            peerAvatar: profile?['avatar_url'] ?? '',
            isGroup: false,
          ),
        ),
      );
    }

  bool isLoading = true;
  bool isError = false;
  Future<void> _fetchPublicProfile() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final data = await SimpleApiClient.get(
        '/user/public-profile',
        queryParams: {'uid': widget.uid},
        requiresAuth: true,
      );
      setState(() {
        profile = data;
      });
      // Add delay to ensure UI renders properly before hiding loading
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  Widget _buildPublicProfileSkeleton() {
    return Container(
      color: Colors.white,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildShimmerCircle(120),
                    const SizedBox(height: 16),
                    _buildShimmerBox(150, 24),
                    const SizedBox(height: 8),
                    _buildShimmerBox(200, 16),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildShimmerBox(double.infinity, 60),
                  const SizedBox(height: 24),
                  _buildShimmerBox(double.infinity, 150),
                  const SizedBox(height: 24),
                  _buildShimmerBox(double.infinity, 100),
                  const SizedBox(height: 24),
                  _buildShimmerBox(double.infinity, 150),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildShimmerCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading profile...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (isError || profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Public Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey[50] ?? Colors.white, Colors.red[50] ?? Colors.red],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                const SizedBox(height: 24),
                Text('Failed to load profile', 
                     style: TextStyle(fontSize: 18, color: Colors.red[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchPublicProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    final avatar = profile!["avatar"] ?? "";
    final name = profile!["name"] ?? "";
    final college = profile!["college"] ?? "";
    final bio = profile!["bio"] ?? "";
    final rating = profile!["rating"] ?? 0;
    final trustScore = profile!["trustScore"] ?? 0;
    final verificationStatus = profile!["verificationStatus"] ?? "unknown";
    
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.white,
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Profile Avatar with Animation
                            Consumer<UserProvider>(
                              builder: (context, userProvider, child) {
                                // Use fresh avatar from provider if viewing own profile
                                final displayAvatar = (widget.uid == myUid && userProvider.avatar != null)
                                  ? userProvider.avatar!
                                  : avatar;
                                final timestamp = DateTime.now().millisecondsSinceEpoch;
                                
                                return Hero(
                                  tag: 'avatar_${widget.uid}',
                                  child: Container(
                                    key: ValueKey('public_avatar_${displayAvatar}_$timestamp'),
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      border: Border.all(color: Colors.white, width: 4),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: (displayAvatar.isNotEmpty && AvatarOptions.avatarOptions.contains(displayAvatar))
                                        ? SvgPicture.asset(
                                            displayAvatar,
                                            key: ValueKey('svg_${displayAvatar}_$timestamp'),
                                            fit: BoxFit.contain,
                                          )
                                        : SvgPicture.asset(
                                            AvatarOptions.avatarOptions[0],
                                            key: ValueKey('default_public_avatar_$timestamp'),
                                            fit: BoxFit.contain,
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          // Name with verification badge
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                                if (verificationStatus == 'verified') ...[
                                  const SizedBox(width: 8),
                                  const Tooltip(
                                    message: 'Verified Student',
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (college.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                college,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Action Buttons
                      if (myUid != null && myUid != widget.uid)
                        _buildActionButtons(),
                      
                      const SizedBox(height: 24),
                      
                      // Enhanced Stats Cards
                      _buildStatsSection(rating, trustScore, verificationStatus),
                      
                      const SizedBox(height: 24),
                      
                      // Badges Section
                      if (userBadges.isNotEmpty)
                        _buildBadgesSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Bio Section with better design
                      _buildBioSection(bio, theme),
                      
                      const SizedBox(height: 24),
                      
                      // Activity Overview
                      _buildActivitySection(),
                      
                      const SizedBox(height: 24),
                      
                      // User Items Preview
                      _buildUserItemsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Additional Info
                      _buildAdditionalInfo(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (myUid == widget.uid) {
      // Don't show action buttons for own profile
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: isFriendshipLoading
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _buildPrimaryActionButton(),
          ),
          const SizedBox(width: 12),
          _buildSecondaryActionButton(),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton() {
    if (friendshipStatus == null) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.person_add),
        label: const Text('Add Friend'),
        onPressed: _handleAddFriend,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    switch (friendshipStatus!.status) {
      case FriendshipService.STATUS_FRIENDS:
        return ElevatedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Chat'),
          onPressed: _handleChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      
      case FriendshipService.STATUS_PENDING_SENT:
        return ElevatedButton.icon(
          icon: const Icon(Icons.hourglass_empty),
          label: const Text('Request Sent'),
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      
      case FriendshipService.STATUS_PENDING_RECEIVED:
        return ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Accept Request'),
          onPressed: _handleAcceptRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      
      case FriendshipService.STATUS_BLOCKED:
        return ElevatedButton.icon(
          icon: const Icon(Icons.block),
          label: const Text('Blocked'),
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[300],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      
      default:
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Add Friend'),
          onPressed: _handleAddFriend,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
    }
  }

  Widget _buildSecondaryActionButton() {
    if (friendshipStatus?.status == FriendshipService.STATUS_FRIENDS) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'rate':
              _showRatingDialog();
              break;
            case 'remove':
              _handleRemoveFriend();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'rate',
            child: Row(
              children: [
                Icon(Icons.star, size: 18),
                SizedBox(width: 8),
                Text('Rate User'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Remove Friend', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.more_vert, color: Colors.grey),
        ),
      );
    } else if (friendshipStatus?.status == FriendshipService.STATUS_PENDING_RECEIVED) {
      return ElevatedButton(
        onPressed: _handleRejectRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Icon(Icons.close),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildStatsSection(int rating, int trustScore, String verificationStatus) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  icon: Icons.star,
                  value: rating.toStringAsFixed(1),
                  label: 'Rating',
                  color: Colors.grey[700] ?? Colors.grey,
                  gradient: [
                    Colors.grey[100] ?? Colors.grey,
                    Colors.grey[200] ?? Colors.grey,
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  child: TrustScoreBadge(score: trustScore, showLabel: true, size: 20),
                ),
                _buildStatCard(
                  icon: Icons.swap_horiz,
                  value: '${totalBorrows + totalLends}',
                  label: 'Transactions',
                  color: Colors.grey[700] ?? Colors.grey,
                  gradient: [
                    Colors.grey[100] ?? Colors.grey,
                    Colors.grey[200] ?? Colors.grey,
                  ],
                ),
              ],
            ),
          ),
          if (profileCompleteness > 0) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Completeness',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: profileCompleteness / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      profileCompleteness > 80 ? (Colors.green[600] ?? Colors.green) : (Colors.blue[600] ?? Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profileCompleteness.toInt()}% complete',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.military_tech, color: Colors.purple[600]),
                const SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: userBadges.length,
              itemBuilder: (context, index) {
                final badge = userBadges[index];
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple[400] ?? Colors.purple,
                              Colors.pink[400] ?? Colors.pink,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getBadgeIcon(badge['type']),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getBadgeIcon(String? type) {
    switch (type) {
      case 'trusted_lender':
        return Icons.handshake;
      case 'frequent_borrower':
        return Icons.repeat;
      case 'verified_student':
        return Icons.school;
      case 'top_rated':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  Widget _buildBioSection(String bio, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            bio.isNotEmpty
                ? Text(
                    bio,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: Colors.grey[700],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        Text(
                          'No bio provided yet.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.indigo[600]),
                const SizedBox(width: 8),
                Text(
                  'Activity Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildActivityCard(
                    icon: Icons.call_made,
                    title: 'Items Lent',
                    value: '$totalLends',
                    color: Colors.green[600]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActivityCard(
                    icon: Icons.call_received,
                    title: 'Items Borrowed',
                    value: '$totalBorrows',
                    color: Colors.blue[600]!,
                  ),
                ),
              ],
            ),
            if (joinedDate.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Member since $joinedDate',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserItemsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.teal[600]),
                const SizedBox(width: 8),
                Text(
                  'Recent Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (userItems.isNotEmpty)
                  TextButton(
                    onPressed: () => _showAllItems(),
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),
          if (isItemsLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (userItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                    Text(
                      'No items shared yet.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: userItems.length > 6 ? 6 : userItems.length,
                itemBuilder: (context, index) {
                  final item = userItems[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            item['title'] ?? 'Item',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.cyan[600]),
                const SizedBox(width: 8),
                Text(
                  'Additional Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.security, 'Trust & Safety', 'Verified user with secure transactions'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.support, 'Customer Support', '24/7 support available for all transactions'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.policy, 'Community Guidelines', 'Follows all community rules and guidelines'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAllItems() {
    // TODO: Navigate to user's items screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('View all items feature coming soon!')),
    );
  }

  void _showRatingDialog() {
    int selectedRating = 0;
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text('Rate ${profile!['name'] ?? 'User'}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your experience with this user?'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            selectedRating = index + 1;
                          });
                        },
                        child: Icon(
                          Icons.star,
                          color: selectedRating > index ? Colors.amber[600] : Colors.grey[300],
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  if (selectedRating > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Rating: $selectedRating/5 stars',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: feedbackController,
                      decoration: InputDecoration(
                        labelText: 'Add a comment (optional)',
                        hintText: 'Share your experience...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                      maxLength: 250,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              if (selectedRating > 0)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _rateUser(selectedRating);
                    feedbackController.dispose();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Rating'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _rateUser(int rating) async {
    if (myUid == null) return;
    
    try {
      await SimpleApiClient.post(
        '/user/rate',
        body: {
          'raterUid': myUid,
          'ratedUid': widget.uid,
          'rating': rating,
        },
        requiresAuth: true,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rated $rating stars! Thank you for your feedback.'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchPublicProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
