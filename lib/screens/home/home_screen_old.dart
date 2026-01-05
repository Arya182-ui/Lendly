import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'item_detail_screen.dart';
import 'search_screen.dart';
import 'add_item_screen.dart';
import '../../services/home_service.dart';
import '../../services/session_service.dart';
import '../../config/api_config.dart';
import '../../providers/user_provider.dart';
import 'package:lendly/widgets/avatar_options.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Helper for icon string
  IconData _iconFromString(String? icon) {
    switch (icon) {
      case 'home':
        return Icons.home;
      case 'memory':
        return Icons.memory;
      case 'sports_soccer':
        return Icons.sports_soccer;
      default:
        return Icons.group;
    }
  }

  String? userName;
  String? userCollege;
  String? userAvatar;
  String? uid;
  int notifications = 0;
  double trustScore = 0;
  String verificationStatus = 'unknown';
  int wallet = 0;
  List<dynamic>? newArrivals = [];
  List<dynamic>? itemsNearYou = [];
  List<dynamic>? publicGroups = [];
  bool isLoading = true;
  bool hasLocationPermission = false;
  String searchQuery = '';
  bool _locationPermissionAsked = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      uid = await SessionService.getUserId();
      
      if (uid != null) {
        await _loadUserData();
        await _loadHomeData();
        await _checkLocationPermission();
      }
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error initializing home screen: \$e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied && !_locationPermissionAsked) {
        _locationPermissionAsked = true;
        permission = await Geolocator.requestPermission();
      }
      
      setState(() {
        hasLocationPermission = permission == LocationPermission.always || 
                               permission == LocationPermission.whileInUse;
      });
      
      if (hasLocationPermission) {
        await _loadNearbyItems();
      }
    } catch (e) {
      print('Error checking location permission: \$e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      final userData = await homeService.getUserData(uid!);
      
      setState(() {
        userName = userData['name'];
        userCollege = userData['college'];
        userAvatar = userData['avatar'];
        trustScore = (userData['trust_score'] ?? 0).toDouble();
        verificationStatus = userData['verification_status'] ?? 'unknown';
        wallet = userData['wallet'] ?? 0;
        notifications = userData['notifications'] ?? 0;
      });
    } catch (e) {
      print('Error loading user data: \$e');
    }
  }

  Future<void> _loadHomeData() async {
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      
      // Load new arrivals
      final newArrivalsData = await homeService.getNewArrivals(uid!);
      setState(() {
        newArrivals = newArrivalsData;
      });
      
      // Load public groups
      final groupsData = await homeService.getPublicGroups(uid!);
      setState(() {
        publicGroups = groupsData;
      });
      
    } catch (e) {
      print('Error loading home data: \$e');
    }
  }

  Future<void> _loadNearbyItems() async {
    try {
      final homeService = HomeService(ApiConfig.baseUrl);
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      final nearbyData = await homeService.getItemsNearLocation(
        uid!,
        position.latitude,
        position.longitude,
      );
      
      setState(() {
        itemsNearYou = nearbyData;
      });
    } catch (e) {
      print('Error loading nearby items: \$e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    await _initData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: userAvatar != null && userAvatar!.isNotEmpty
                ? NetworkImage(userAvatar!)
                : null,
            child: userAvatar == null || userAvatar!.isEmpty
                ? Text(
                    userName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, \${userName ?? "User"}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1a237e),
              ),
            ),
            Text(
              userCollege ?? 'Your College',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
            icon: const Icon(Icons.search, color: Color(0xFF1a237e)),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  // Navigate to notifications
                },
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1a237e)),
              ),
              if (notifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      notifications > 99 ? '99+' : notifications.toString(),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Trust Score',
                      trustScore.toStringAsFixed(1),
                      Icons.verified_user,
                      const Color(0xFF1DBF73),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Wallet',
                      '₹\$wallet',
                      Icons.account_balance_wallet,
                      const Color(0xFF1a237e),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Add Item Button
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddItemScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add New Item', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DBF73),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  );
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text('Find Items', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a237e),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // New Arrivals Section
              if ((newArrivals?.isNotEmpty ?? false)) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Arrivals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a237e),
                      ),
                    ),
                    if ((newArrivals?.length ?? 0) > 5)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SearchScreen()),
                          );
                        },
                        child: const Text('See All'),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                ...((newArrivals ?? []).take(5).map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ItemCard(
                    item: item,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemDetailScreen(item: item),
                          settings: RouteSettings(arguments: uid),
                        ),
                      );
                      
                      if (result == true && mounted) {
                        setState(() {
                          newArrivals?.removeWhere((i) => i['id'] == item['id']);
                          itemsNearYou?.removeWhere((i) => i['id'] == item['id']);
                        });
                      } else if (result is Map<String, dynamic> && result['id'] == item['id'] && mounted) {
                        setState(() {
                          final idx = newArrivals?.indexWhere((i) => i['id'] == item['id']) ?? -1;
                          if (idx != -1) newArrivals![idx] = result;
                          final idx2 = itemsNearYou?.indexWhere((i) => i['id'] == item['id']) ?? -1;
                          if (idx2 != -1) itemsNearYou![idx2] = result;
                        });
                      }
                    },
                  ),
                ))),
                
                const SizedBox(height: 24),
              ],
              
              // Items Near You Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Items Near You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a237e),
                    ),
                  ),
                  if ((itemsNearYou?.length ?? 0) > 10)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SearchScreen()),
                        );
                      },
                      child: const Text('See All'),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              if ((itemsNearYou?.isEmpty ?? true)) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.location_off, size: 36, color: Colors.grey[400]),
                      const SizedBox(height: 6),
                      Text(
                        'No items nearby',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              ] else ...[
                ...(itemsNearYou ?? []).take(10).map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ItemCard(
                    item: item,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemDetailScreen(item: item),
                          settings: RouteSettings(arguments: uid),
                        ),
                      );
                      
                      if (result == true && mounted) {
                        setState(() {
                          newArrivals?.removeWhere((i) => i['id'] == item['id']);
                          itemsNearYou?.removeWhere((i) => i['id'] == item['id']);
                        });
                      } else if (result is Map<String, dynamic> && result['id'] == item['id'] && mounted) {
                        setState(() {
                          final idx = newArrivals?.indexWhere((i) => i['id'] == item['id']) ?? -1;
                          if (idx != -1) newArrivals![idx] = result;
                          final idx2 = itemsNearYou?.indexWhere((i) => i['id'] == item['id']) ?? -1;
                          if (idx2 != -1) itemsNearYou![idx2] = result;
                        });
                      }
                    },
                  ),
                ))
              ],
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Item Card Widget
class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const _ItemCard({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (item['image'] != null && item['image'].toString().isNotEmpty)
                ? Image.network(
                    item['image'],
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[300],
                    child: Icon(Icons.image, color: Colors.grey[600]),
                  ),
          ),
          title: Text(
            item['name'] ?? 'Unknown Item',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1a237e),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['owner'] ?? 'Unknown Owner',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: (item['available'] ?? false) ? const Color(0xFF1DBF73) : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (item['available'] ?? false) ? 'Available' : 'Unavailable',
                    style: TextStyle(
                      fontSize: 12,
                      color: (item['available'] ?? false) ? const Color(0xFF1DBF73) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF1DBF73)),
                  Text(
                    item['distance'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1a237e)),
                  ),
                ],
              ),
            ],
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        ),
      ),
    );
  }
}
