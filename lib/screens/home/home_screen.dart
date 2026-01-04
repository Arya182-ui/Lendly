import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'item_detail_screen.dart';
import 'search_screen.dart';
import 'add_item_screen.dart';
import '../../services/home_service.dart';
import '../../services/session_service.dart';
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
  List<dynamic> newArrivals = [];
  List<dynamic> itemsNearYou = [];
  List<dynamic> publicGroups = [];
  final List<String> categories = ['Books', 'Tech', 'Sports', 'Tools'];
  String selectedCategory = 'Books';
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMsg;
  final HomeService _service = HomeService('https://ary-lendly-production.up.railway.app');


  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadAll();
  }

  Future<void> _requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final sessionUid = await SessionService.getUid();
      if (sessionUid == null || sessionUid.isEmpty) {
        setState(() {
          isLoading = false;
          errorMsg = 'User not logged in.';
        });
        return;
      }
      uid = sessionUid;

      // Start location and API fetches in parallel
      Future<Position?> locationFuture = (() async {
        try {
          final locPerm = await Geolocator.checkPermission();
          if (locPerm == LocationPermission.denied) {
            await Geolocator.requestPermission();
          }
          // Add timeout to prevent hanging
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Location timeout', const Duration(seconds: 10)),
          );
        } catch (e) {
          print('Location error: $e');
          return null;
        }
      })();

      Future<Map<String, dynamic>> summaryFuture = _service.getSummary(uid!).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Summary API timeout', const Duration(seconds: 15)),
      );
      Future<List<dynamic>> arrivalsFuture = _service.getNewArrivals().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Arrivals API timeout', const Duration(seconds: 15)),
      );
      Future<List<dynamic>> groupsFuture = _service.getGroups().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Groups API timeout', const Duration(seconds: 15)),
      );

      // Wait for summary, arrivals, groups in parallel with overall timeout
      final results = await Future.wait([
        summaryFuture,
        arrivalsFuture,
        groupsFuture,
        locationFuture,
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Overall loading timeout', const Duration(seconds: 20)),
      );

      final summary = results[0] as Map<String, dynamic>;
      final arrivals = results[1] as List<dynamic>;
      final groups = results[2] as List<dynamic>;
      final pos = results[3] as Position?;

      setState(() {
        userName = summary['name'] ?? '';
        userCollege = summary['college'] ?? '';
        userAvatar = summary['avatar'] ?? '';
        notifications = summary['notifications'] ?? 0;
        trustScore = (summary['trustScore'] ?? 0).toDouble();
        wallet = summary['wallet'] ?? 0;
        newArrivals = arrivals;
        publicGroups = groups;
        verificationStatus = summary['verificationStatus'] ?? 'unknown';
        SessionService.verificationStatus = verificationStatus;
      });

      // Update UserProvider with summary data
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updateFromSummary(summary);
      }

      // Fetch items near you only if location is available
      if (pos != null) {
        try {
          final near = await _service.getItemsNearYou(uid: uid!, latitude: pos.latitude, longitude: pos.longitude);
          setState(() {
            itemsNearYou = near;
          });
        } catch (e) {
          setState(() {
            errorMsg = 'Could not load nearby items.';
          });
        }
      } else {
        setState(() {
          errorMsg = 'Location unavailable. Enable location to see items near you.';
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMsg != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMsg!.contains('TimeoutException')
                              ? 'Connection timed out. Please check your internet and try again.'
                              : errorMsg!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DBF73),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMsg = null;
                            });
                            _loadAll();
                          },
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      children: [
              // User Greeting - more prominent
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    (userAvatar != null && userAvatar!.isNotEmpty && AvatarOptions.avatarOptions.contains(userAvatar))
                        ? Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: userAvatar!.endsWith('.svg')
                                  ? SvgPicture.asset(userAvatar!, fit: BoxFit.contain)
                                  : Image(image: AssetImage(userAvatar!), fit: BoxFit.contain),
                            ),
                          )
                        : CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFE8F9F1),
                            child: Icon(Icons.person, size: 32, color: Color(0xFF1DBF73)),
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName != null && userName!.isNotEmpty ? 'Hi, $userName! 👋' : 'Hi!',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1a237e)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userCollege != null && userCollege!.isNotEmpty ? userCollege! : '',
                            style: const TextStyle(fontSize: 15, color: Color(0xFF1DBF73), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.message_outlined, color: Color(0xFF1a237e)),
                      onPressed: () {
                        Navigator.pushNamed(context, '/messages');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Color(0xFF1a237e)),
                      onPressed: () {
                        Navigator.pushNamed(context, '/notifications');
                      },
                    ),
                  ],
                ),
              ), 

              // Search bar
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF1a237e), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'What do you need today?',
                          style: TextStyle(fontSize: 15, color: Color(0xFF7B7B7B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter chips (horizontal scroll)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = categories[idx];
                    final selected = cat == selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => selectedCategory = cat);
                      },
                      selectedColor: const Color(0xFF1DBF73),
                      backgroundColor: const Color(0xFFF5F5F5),
                      labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF1a237e)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Always show only the Explore Community button (no group list)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F9F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.groups, color: const Color(0xFF1DBF73), size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Find your community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1a237e))),
                          SizedBox(height: 2),
                          Text('Join or create a group to share and borrow safely.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/groups');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DBF73),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Explore'),
                    ),
                  ],
                ),
              ),


              // Lend an Item button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (verificationStatus != 'verified') {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Verification Required'),
                          content: const Text('Please verify your student status before adding items.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                if (Navigator.canPop(context)) Navigator.pop(context);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                if (Navigator.canPop(context)) Navigator.pop(context);
                                Navigator.pushNamed(context, '/profile');
                              },
                              child: const Text('Verify Now'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddItemScreen()),
                      );
                      if (result != null && result is Map<String, dynamic>) {
                        setState(() {
                          newArrivals = [result, ...newArrivals];
                        });
                        _loadAll();
                      } else if (result == true) {
                        _loadAll();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DBF73),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('+  Lend an Item'),
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 16),

              const SizedBox(height: 18),
              // New Arrivals (horizontal scroll)
              const Text('New Arrivals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1a237e))),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: newArrivals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 36, color: Colors.grey[400]),
                            const SizedBox(height: 6),
                            Text(
                              'No items this time',
                              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: newArrivals.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, idx) {
                          final item = newArrivals[idx];
                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ItemDetailScreen(item: item),
                                  settings: RouteSettings(arguments: uid),
                                ),
                              );
                              // If item was deleted, remove from list
                              if (result == true && mounted) {
                                setState(() {
                                  newArrivals.removeWhere((i) => i['id'] == item['id']);
                                  itemsNearYou.removeWhere((i) => i['id'] == item['id']);
                                });
                              } else if (result is Map<String, dynamic> && result['id'] == item['id'] && mounted) {
                                setState(() {
                                  // Update the item in both lists
                                  final idx = newArrivals.indexWhere((i) => i['id'] == item['id']);
                                  if (idx != -1) newArrivals[idx] = result;
                                  final idx2 = itemsNearYou.indexWhere((i) => i['id'] == item['id']);
                                  if (idx2 != -1) itemsNearYou[idx2] = result;
                                });
                              }
                            },
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: (item['image'] != null && item['image'].toString().isNotEmpty)
                                      ? Image.network(
                                          item['image'],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.image, color: Colors.grey[600]),
                                        ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: (item['userAvatar'] != null && item['userAvatar'].toString().isNotEmpty)
                                      ? (item['userAvatar'].toString().endsWith('.svg')
                                          ? CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.transparent,
                                              child: SvgPicture.asset(item['userAvatar'], width: 20, height: 20),
                                            )
                                          : item['userAvatar'].toString().startsWith('http')
                                              ? CircleAvatar(
                                                  radius: 12,
                                                  backgroundImage: NetworkImage(item['userAvatar']),
                                                )
                                              : CircleAvatar(
                                                  radius: 12,
                                                  backgroundImage: AssetImage(item['userAvatar']),
                                                ))
                                      : CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.grey[300],
                                          child: Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),
              // Items Near You (Top 10 + See All)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Items Near You', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1a237e))),
                  if (itemsNearYou.length > 10)
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
              const SizedBox(height: 10),
              if (itemsNearYou.isEmpty) ...[
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
              ] else ...itemsNearYou.take(10).map<Widget>((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
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
                        newArrivals.removeWhere((i) => i['id'] == item['id']);
                        itemsNearYou.removeWhere((i) => i['id'] == item['id']);
                      });
                    } else if (result is Map<String, dynamic> && result['id'] == item['id'] && mounted) {
                      setState(() {
                        final idx = newArrivals.indexWhere((i) => i['id'] == item['id']);
                        if (idx != -1) newArrivals[idx] = result;
                        final idx2 = itemsNearYou.indexWhere((i) => i['id'] == item['id']);
                        if (idx2 != -1) itemsNearYou[idx2] = result;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
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
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['owner'], style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 10, color: item['available'] ? Color(0xFF1DBF73) : Colors.grey),
                              const SizedBox(width: 4),
                              Text(item['available'] ? 'Available' : 'Unavailable', style: TextStyle(fontSize: 12, color: item['available'] ? Color(0xFF1DBF73) : Colors.grey)),
                              const SizedBox(width: 10),
                              Icon(Icons.location_on, size: 14, color: Color(0xFF1DBF73)),
                              Text(item['distance'], style: const TextStyle(fontSize: 12, color: Color(0xFF1a237e))),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      // No FAB, sticky bottom nav will be handled in main.dart
    );
  }
}

// Item Card Widget
class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  child: (item['image'] != null && item['image'].toString().isNotEmpty)
                      ? Image.network(
                          item['image'],
                          width: 100,
                          height: 90,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 100,
                          height: 90,
                          color: Colors.grey[300],
                          child: Icon(Icons.image, color: Colors.grey[600]),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1a237e))),
                            const SizedBox(width: 6),
                            if (item['verified'])
                              Tooltip(
                                message: 'Verified Student',
                                child: Icon(Icons.verified, color: Color(0xFF1DBF73), size: 18),
                              ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFE8F9F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(item['group'], style: const TextStyle(fontSize: 11, color: Color(0xFF1DBF73))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Text('${item['trust']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            const SizedBox(width: 10),
                            Icon(Icons.location_on, color: Color(0xFF1DBF73), size: 16),
                            Text(item['distance'], style: const TextStyle(fontSize: 13, color: Color(0xFF1a237e))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item['available'] ? const Color(0xFF1DBF73) : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(item['available'] ? 'Available' : 'Unavailable', style: TextStyle(fontSize: 12, color: item['available'] ? const Color(0xFF1DBF73) : Colors.grey)),
                            const Spacer(),
                            if ((item['type'] == 'sell' || item['type'] == 'rent') && item['price'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1DBF73),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['price'] == 0 ? 'Free' : '₹${item['price']}${item['type'] == 'rent' ? "/day" : ""}',
                                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (item['type'] != null && item['type'].toString().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFE8F9F1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(item['type'], style: const TextStyle(fontSize: 11, color: Color(0xFF1DBF73))),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: item['available'] ? () {} : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1a237e),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              child: Text(item['available'] ? 'Request' : 'View'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Skeleton Loader for Feed
class _FeedSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (idx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      )),
    );
  }
}

// Empty State Widget
class _EmptyFeed extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyFeed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.sentiment_dissatisfied, color: Colors.grey[400], size: 60),
          const SizedBox(height: 16),
          const Text('No items nearby', style: TextStyle(fontSize: 18, color: Color(0xFF1a237e), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Try adjusting your filters or refresh.', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DBF73),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
