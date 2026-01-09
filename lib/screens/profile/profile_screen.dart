import 'package:lendly/screens/profile/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/env_config.dart';
import '../impact/impact_screen.dart';
import '../friends_screen.dart';
import '../auth/id_upload_screen.dart';
import '../settings/settings_screen.dart';
import '../home/edit_item_screen.dart';
import '../../services/verification_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../providers/user_provider.dart';
import 'package:lendly/widgets/avatar_options.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/api_client.dart';
import '../../services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/item_service.dart';
import 'user_ratings_screen.dart';
import '../wallet/wallet_screen.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/trust_score_widgets.dart';
import '../../services/trust_score_service.dart';
import '../../services/coins_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Widget _buildMyItemsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Item',
              onPressed: () {
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IdUploadScreen(uid: uid ?? ''),
                              ),
                            );
                          },
                          child: const Text('Verify Now'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.pushNamed(context, '/add-item');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        myItems.isEmpty
            ? Text('No items added yet.', style: theme.textTheme.bodyMedium)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myItems.length,
                itemBuilder: (context, index) {
                  final item = myItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(item['title'] ?? item['name'] ?? ''),
                      subtitle: Text(item['description'] ?? item['category'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editItem(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteItem(item),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
  List<dynamic> myItems = [];
  final ItemService _itemService = ItemService(EnvConfig.apiBaseUrl);
  int friendsCount = 0;

  /// Navigate to edit item screen
  void _editItem(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemScreen(item: item),
      ),
    );
    if (result == true) {
      _fetchProfile(); // Refresh items after edit
    }
  }

  /// Delete item with confirmation dialog
  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item['name'] ?? item['title'] ?? 'this item'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _itemService.deleteItem(
          id: item['id'] ?? '',
          ownerId: uid ?? '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchProfile(); // Refresh items after delete
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  late TabController _tabController;
  bool isBioExpanded = false;
  bool isLoading = false;
  bool isError = false;
  bool notLoggedIn = false;
  String? uid;
  String name = '';
  String college = '';
  String avatar = '';
  List interests = [];
  String? socialProfile;
  String bio = '';
  int trustScore = 0;
  int borrowed = 0;
  int lent = 0;
  double rating = 0;
  String verificationStatus = 'unknown';
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> borrows = [];
  List<Map<String, dynamic>> lends = [];
  List<Map<String, dynamic>> reviews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkSessionAndLoad();
  }

  Future<void> _checkSessionAndLoad() async {
    final sessionUid = await SessionService.getUid();
    if (sessionUid == null || sessionUid.isEmpty) {
      setState(() {
        notLoggedIn = true;
        isLoading = false;
      });
    } else {
      setState(() { uid = sessionUid; });
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    setState(() { isLoading = true; });
    try {
      final data = await SimpleApiClient.get(
        '/user/profile',
        queryParams: {'uid': uid ?? ''},
        requiresAuth: true,
      );
      setState(() {
        name = data['name'] ?? '';
        college = data['college'] ?? '';
        avatar = data['avatar'] ?? '';
        interests = data['interests'] ?? [];
        bio = data['bio'] ?? '';
        trustScore = data['trustScore'] ?? 0;
        borrowed = data['borrowed'] ?? 0;
        lent = data['lent'] ?? 0;
        rating = (data['rating'] ?? 0).toDouble();
        verificationStatus = data['verificationStatus'] ?? 'unknown';
        friendsCount = data['friendsCount'] ?? 0;
        isLoading = false;
      });
      
      // Update UserProvider and SessionService with latest verification status
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setVerificationStatus(verificationStatus);
        SessionService.verificationStatus = verificationStatus;
      }
      // Fetch user's items
      final allItems = await _itemService.getItems();
      setState(() {
        myItems = allItems.where((item) => item['ownerId'] == uid).toList();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  void _retry() {
    setState(() {
      isError = false;
      isLoading = true;
    });
    // Simulate loading
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
        isError = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _buildSkeletonLoader(),
      );
    }
    if (notLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.public),
                          label: const Text('Check your public profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            foregroundColor: Colors.blue[900],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () {
                            if (uid != null && uid!.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(uid: uid!),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('You must be logged in to view your profile.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }
    if (isError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          automaticallyImplyLeading: false,
        ),
        body: _buildErrorState(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Sign out from Firebase
              final firebaseAuth = FirebaseAuthService();
              await firebaseAuth.signOut();
              
              // Clear old session data
              await SessionService.clearSession();
              
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.verified_user, semanticLabel: 'Verification Status'),
            onPressed: () => _showVerificationStatus(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.people),
                  label: Text('Friends ($friendsCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('My Wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WalletScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text('My Reviews'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[50],
                    foregroundColor: Colors.amber[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    if (uid != null && uid!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserRatingsScreen(
                            uid: uid!,
                            userName: name,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.public),
                  label: const Text('Public Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    if (uid != null && uid!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(uid: uid!),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildVerificationStatusCard(context),
          const SizedBox(height: 16),
          // Impact entry from profile
          ListTile(
            leading: Icon(Icons.eco, color: Colors.green[700]),
            title: Text('Your Impact', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green[700]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ImpactScreen()),
              );
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 16),
          _buildTrustSummaryCard(theme),
          const SizedBox(height: 16),
          // ...existing code...
          _buildMyItemsSection(theme),
          const SizedBox(height: 16),
          _buildAboutSection(theme),
          const SizedBox(height: 16),
          _buildTabSection(theme),

// ...existing code...
// ...existing code...
// ...existing code...
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard(BuildContext context) {
    String status = verificationStatus;
    IconData icon;
    Color color;
    String text;
    String desc;
    switch (status) {
      case 'verified':
        icon = Icons.verified;
        color = Colors.green;
        text = 'Verified';
        desc = 'Your student status is verified.';
        break;
      case 'pending':
        icon = Icons.hourglass_top;
        color = Colors.orange;
        text = 'Pending Verification';
        desc = 'Your verification is under review.';
        break;
      case 'failed':
        icon = Icons.error;
        color = Colors.red;
        text = 'Verification Failed';
        desc = 'We could not verify your status.';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        text = 'Not Verified';
        desc = 'Please verify your student status.';
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            if (status != 'verified')
              ElevatedButton(
                onPressed: () async {
                  // Navigate to ID upload screen
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IdUploadScreen(uid: uid ?? ''),
                    ),
                  );
                  // Refresh status after upload
                  _fetchProfile();
                },
                child: const Text('Verify'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final currentAvatar = userProvider.avatar ?? avatar;
            return Container(
              key: ValueKey('profile_avatar_${currentAvatar}_${DateTime.now().millisecondsSinceEpoch}'),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: (currentAvatar != null && currentAvatar is String && currentAvatar.isNotEmpty && AvatarOptions.avatarOptions.contains(currentAvatar))
                    ? SvgPicture.asset(
                        currentAvatar, 
                        key: ValueKey('${currentAvatar}_${DateTime.now().millisecondsSinceEpoch}'), 
                        fit: BoxFit.contain
                      )
                    : SvgPicture.asset(
                        AvatarOptions.avatarOptions[0], 
                        key: ValueKey('default_avatar_${DateTime.now().millisecondsSinceEpoch}'), 
                        fit: BoxFit.contain
                      ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name.isNotEmpty ? name : 'Student',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  if (verificationStatus == 'verified')
                    Tooltip(
                      message: 'Verified Student',
                      child: Icon(Icons.verified, color: Colors.blue[700], size: 20),
                    ),
                ],
              ),
              Text(college.isNotEmpty ? college : 'Your College', style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () async {
            final result = await showDialog<Map<String, String>>(
              context: context,
              builder: (context) {
                final nameController = TextEditingController(text: name);
                final collegeController = TextEditingController(text: college);
                String tempAvatar = avatar.isNotEmpty && AvatarOptions.avatarOptions.contains(avatar)
                    ? avatar
                    : AvatarOptions.avatarOptions[0];
                String? nameError;
                String? collegeError;
                return StatefulBuilder(
                  builder: (context, setStateDialog) => Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.edit, color: Colors.green, size: 28),
                                SizedBox(width: 10),
                                Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: SvgPicture.asset(
                                    (tempAvatar != null && tempAvatar is String && tempAvatar.isNotEmpty && AvatarOptions.avatarOptions.contains(tempAvatar))
                                      ? tempAvatar
                                      : AvatarOptions.avatarOptions[0],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Wrap(
                                spacing: 8,
                                children: AvatarOptions.avatarOptions.map((url) => GestureDetector(
                                  onTap: () {
                                    setStateDialog(() {
                                      tempAvatar = url;
                                    });
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tempAvatar == url ? Colors.green[100] : Colors.grey[200],
                                      border: tempAvatar == url
                                          ? Border.all(color: Colors.green, width: 2)
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            (url != null && url is String && url.isNotEmpty && AvatarOptions.avatarOptions.contains(url))
                                              ? url
                                              : AvatarOptions.avatarOptions[0],
                                            fit: BoxFit.contain,
                                          ),
                                          if (tempAvatar == url)
                                            const Align(
                                              alignment: Alignment.bottomRight,
                                              child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: nameController,
                              maxLength: 30,
                              decoration: InputDecoration(
                                labelText: 'Name',
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                errorText: nameError,
                              ),
                              onChanged: (_) => setStateDialog(() { nameError = null; }),
                            ),
                            const SizedBox(height: 4),
                            Text('Only letters, spaces, and . allowed. Max 30 chars.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(height: 12),
                            TextField(
                              controller: collegeController,
                              maxLength: 40,
                              decoration: InputDecoration(
                                labelText: 'College',
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                errorText: collegeError,
                              ),
                              onChanged: (_) => setStateDialog(() { collegeError = null; }),
                            ),
                            const SizedBox(height: 4),
                            Text('Only letters, numbers, spaces, . and - allowed. Max 40 chars.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(onPressed: () {
                                  if (Navigator.canPop(context)) Navigator.pop(context);
                                }, child: const Text('Cancel')),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final nameText = nameController.text.trim();
                                    final collegeText = collegeController.text.trim();
                                    final nameValid = RegExp(r'^[a-zA-Z.\s]+$').hasMatch(nameText);
                                    final collegeValid = RegExp(r'^[a-zA-Z0-9.\-\s]+$').hasMatch(collegeText);
                                    bool hasError = false;
                                    if (nameText.isEmpty) {
                                      setStateDialog(() { nameError = 'Name required'; });
                                      hasError = true;
                                    } else if (!nameValid) {
                                      setStateDialog(() { nameError = 'Invalid characters in name'; });
                                      hasError = true;
                                    } else if (nameText.length > 30) {
                                      setStateDialog(() { nameError = 'Max 30 characters'; });
                                      hasError = true;
                                    }
                                    if (collegeText.isEmpty) {
                                      setStateDialog(() { collegeError = 'College required'; });
                                      hasError = true;
                                    } else if (!collegeValid) {
                                      setStateDialog(() { collegeError = 'Invalid characters in college'; });
                                      hasError = true;
                                    } else if (collegeText.length > 40) {
                                      setStateDialog(() { collegeError = 'Max 40 characters'; });
                                      hasError = true;
                                    }
                                    if (!hasError) {
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context, {
                                          'name': nameText,
                                          'college': collegeText,
                                          'avatar': tempAvatar,
                                        });
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: Colors.green[700],
                                  ),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
            if (result != null) {
              final newName = result['name'] ?? name;
              final newCollege = result['college'] ?? college;
              final newAvatar = result['avatar'] ?? avatar;
              
              // Persist to backend first
              try {
                await SimpleApiClient.put(
                  '/user/profile',
                  body: {
                    'uid': uid,
                    'name': newName,
                    'college': newCollege,
                    'avatar': newAvatar,
                  },
                  requiresAuth: true,
                );
                
                // Update UserProvider first
                if (mounted) {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  userProvider.setProfile(
                    newName: newName,
                    newCollege: newCollege,
                    newAvatar: newAvatar,
                  );
                  // Force user provider to refresh
                  userProvider.notifyListeners();
                }
                
                // Update UI immediately after successful API call
                setState(() {
                  name = newName;
                  college = newCollege;
                  avatar = newAvatar;
                });
                
                // Force rebuild by calling setState again to ensure avatar widget updates
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    setState(() {});
                    // Also trigger global rebuild for all Consumer widgets
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    userProvider.notifyListeners();
                  }
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update profile: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildTrustSummaryCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TrustScoreBadge(score: trustScore, showLabel: true, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TrustStat(label: 'Borrowed', value: borrowed.toString()),
                  _TrustStat(label: 'Lent', value: lent.toString()),
                  _TrustStat(label: 'Rating', value: rating.toStringAsFixed(1), icon: Icons.star, iconColor: Colors.amber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit Bio',
                  onPressed: () async {
                    final bioController = TextEditingController(text: bio);
                    int wordCount = bio.trim().isEmpty ? 0 : bio.trim().split(RegExp(r'\s+')).length;
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setStateDialog) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.edit_note, color: Colors.green, size: 28),
                                    SizedBox(width: 10),
                                    Text('Edit Bio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: bioController,
                                  maxLines: 4,
                                  onChanged: (val) {
                                    setStateDialog(() {});
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Bio',
                                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                    helperText: '${bioController.text.trim().isEmpty ? 0 : bioController.text.trim().split(RegExp(r'\\s+')).length}/500 words',
                                    helperStyle: TextStyle(
                                      color: (bioController.text.trim().isEmpty ? 0 : bioController.text.trim().split(RegExp(r'\\s+')).length) > 500 ? Colors.red : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(onPressed: () {
                                      if (Navigator.canPop(context)) Navigator.pop(context);
                                    }, child: const Text('Cancel')),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: (bioController.text.trim().isEmpty ? 0 : bioController.text.trim().split(RegExp(r'\\s+')).length) > 500
                                          ? null
                                          : () {
                                              if (Navigator.canPop(context)) {
                                                Navigator.pop(context, bioController.text.trim());
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        backgroundColor: Colors.green[700],
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        bio = result;
                      });
                      // Update bio in backend
                      try {
                        await SimpleApiClient.put(
                          '/user/profile',
                          body: {
                            'uid': uid,
                            'bio': result,
                          },
                          requiresAuth: true,
                        );
                      } catch (e) {
                        // Optionally show error
                      }
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 28),
            GestureDetector(
              onTap: () => setState(() => isBioExpanded = !isBioExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bio.isNotEmpty ? bio : 'No bio added yet.',
                    maxLines: isBioExpanded ? null : 2,
                    overflow: isBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      Text(isBioExpanded ? 'Show less' : 'Read more',
                          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w500)),
                      Icon(isBioExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: theme.primaryColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Social Profile', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                socialProfile == null
                    ? TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
                        onPressed: () async {
                          final controller = TextEditingController();
                          String? errorText;
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setStateDialog) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.link, color: Colors.green, size: 24),
                                          SizedBox(width: 10),
                                          Text('Add Social Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      TextField(
                                        controller: controller,
                                        decoration: InputDecoration(
                                          labelText: 'Profile Link (e.g. LinkedIn, Instagram)',
                                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                          errorText: errorText,
                                        ),
                                        onChanged: (val) {
                                          setStateDialog(() {
                                            errorText = null;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(onPressed: () {
                                            if (Navigator.canPop(context)) Navigator.pop(context);
                                          }, child: const Text('Cancel')),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              final text = controller.text.trim();
                                              if (text.isEmpty || (!text.startsWith('http://') && !text.startsWith('https://'))) {
                                                setStateDialog(() {
                                                  errorText = 'Link must start with http:// or https://';
                                                });
                                              } else {
                                                Navigator.pop(context, text);
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              backgroundColor: Colors.green[700],
                                            ),
                                            child: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (result != null && result.isNotEmpty) {
                            setState(() {
                              socialProfile = result;
                            });
                            // Update socialProfile in backend
                            try {
                              await SimpleApiClient.put(
                                '/user/profile',
                                body: {
                                  'uid': uid,
                                  'socialProfile': result,
                                },
                                requiresAuth: true,
                              );
                            } catch (e) {
                              // Optionally show error
                            }
                          }
                        },
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
                        onPressed: () async {
                          final controller = TextEditingController(text: socialProfile);
                          String? errorText;
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setStateDialog) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.link, color: Colors.green, size: 24),
                                          SizedBox(width: 10),
                                          Text('Edit Social Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      TextField(
                                        controller: controller,
                                        decoration: InputDecoration(
                                          labelText: 'Profile Link (e.g. LinkedIn, Instagram)',
                                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                          errorText: errorText,
                                        ),
                                        onChanged: (val) {
                                          setStateDialog(() {
                                            errorText = null;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(onPressed: () {
                                            if (Navigator.canPop(context)) Navigator.pop(context);
                                          }, child: const Text('Cancel')),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: controller.text.trim().isEmpty || controller.text.trim() == socialProfile
                                                ? null
                                                : () {
                                                    final text = controller.text.trim();
                                                    if (!text.startsWith('http://') && !text.startsWith('https://')) {
                                                      setStateDialog(() {
                                                        errorText = 'Link must start with http:// or https://';
                                                      });
                                                    } else {
                                                      Navigator.pop(context, text);
                                                    }
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              backgroundColor: Colors.green[700],
                                            ),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (result != null && result.isNotEmpty && result != socialProfile) {
                            setState(() {
                              socialProfile = result;
                            });
                            // Update socialProfile in backend
                            try {
                              await SimpleApiClient.put(
                                '/user/profile',
                                body: {
                                  'uid': uid,
                                  'socialProfile': result,
                                },
                                requiresAuth: true,
                              );
                            } catch (e) {
                              // Optionally show error
                            }
                          }
                        },
                      ),
              ],
            ),
            if (socialProfile != null && socialProfile!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: GestureDetector(
                        onTap: () async {
                          final url = Uri.parse(socialProfile!);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          socialProfile!,
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Interests', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
                  onPressed: interests.length >= 10
                      ? null
                      : () async {
                          final interestController = TextEditingController();
                          String? errorText;
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setStateDialog) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.interests, color: Colors.green, size: 24),
                                          SizedBox(width: 10),
                                          Text('Add Interest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      TextField(
                                        controller: interestController,
                                        maxLength: 30,
                                        decoration: InputDecoration(
                                          labelText: 'Interest',
                                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                          errorText: errorText,
                                        ),
                                        onChanged: (val) {
                                          setStateDialog(() {
                                            errorText = null;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      Text('No special characters, max 30 chars.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(onPressed: () {
                                            if (Navigator.canPop(context)) Navigator.pop(context);
                                          }, child: const Text('Cancel')),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              final text = interestController.text.trim();
                                              final valid = RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(text);
                                              if (text.isEmpty) {
                                                setStateDialog(() { errorText = 'Interest cannot be empty'; });
                                              } else if (!valid) {
                                                setStateDialog(() { errorText = 'Only letters, numbers, spaces allowed'; });
                                              } else if (text.length > 30) {
                                                setStateDialog(() { errorText = 'Max 30 characters'; });
                                              } else if (interests.map((e) => e.toString().toLowerCase()).contains(text.toLowerCase())) {
                                                setStateDialog(() { errorText = 'Already added'; });
                                              } else {
                                                Navigator.pop(context, text);
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              backgroundColor: Colors.green[700],
                                            ),
                                            child: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (result != null && result.isNotEmpty) {
                            setState(() {
                              interests = [...interests, result];
                            });
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: interests.isNotEmpty
                  ? interests
                      .asMap()
                      .entries
                      .map<Widget>((entry) => _InterestChip(
                            label: entry.value.toString(),
                            onDeleted: () {
                              setState(() {
                                interests.removeAt(entry.key);
                              });
                            },
                          ))
                      .toList()
                  : [const Text('No interests added yet.', style: TextStyle(color: Colors.grey))],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSection(ThemeData theme) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: theme.primaryColor, width: 2),
          ),
          tabs: const [
            Tab(text: 'Items'),
            Tab(text: 'History'),
            Tab(text: 'Reviews'),
          ],
        ),
        SizedBox(
          height: 340,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserItems(),
              _buildHistory(),
              _buildReviews(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserItems() {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No items found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        return ListTile(
          leading: Icon(Icons.inventory_2, color: Colors.blue[700]),
          title: Text(item['name'] ?? ''),
          subtitle: Text(item['status'] ?? '', style: TextStyle(
            color: item['status'] == 'Available' ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          )),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'view', child: Text('View')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistory() {
    if (borrows.isEmpty && lends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No history found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        if (borrows.isNotEmpty) ...[
          Text('Borrowed', style: TextStyle(fontWeight: FontWeight.bold)),
          ...borrows.map((b) => ListTile(
                leading: Icon(Icons.arrow_downward, color: Colors.orange[700]),
                title: Text(b['item'] ?? ''),
                trailing: _StatusChip(status: b['status'] ?? ''),
              )),
          const SizedBox(height: 12),
        ],
        if (lends.isNotEmpty) ...[
          Text('Lent', style: TextStyle(fontWeight: FontWeight.bold)),
          ...lends.map((l) => ListTile(
                leading: Icon(Icons.arrow_upward, color: Colors.green[700]),
                title: Text(l['item'] ?? ''),
                trailing: _StatusChip(status: l['status'] ?? ''),
              )),
        ],
      ],
    );
  }

  Widget _buildReviews() {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No reviews yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, i) {
        final r = reviews[i];
        final avatar = r['avatar']?.toString() ?? '';
        Widget avatarWidget;
        if (avatar.isNotEmpty && AvatarOptions.avatarOptions.contains(avatar)) {
          avatarWidget = Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: SvgPicture.asset(avatar, fit: BoxFit.contain),
            ),
          );
        } else if (avatar.startsWith('http')) {
          avatarWidget = AvatarUtils.buildCircleAvatar(
            avatarPath: avatar,
            fallbackText: r['name']?.toString() ?? 'U',
            backgroundColor: Colors.green[700],
          );
        } else {
          avatarWidget = CircleAvatar(
            backgroundColor: Colors.green[700],
            child: const Icon(Icons.person, color: Colors.white),
          );
        }
        return ListTile(
          leading: avatarWidget,
          title: Row(
            children: [
              Text(r['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              _buildStars((r['rating'] ?? 0) is int ? r['rating'] : int.tryParse(r['rating']?.toString() ?? '0') ?? 0),
            ],
          ),
          subtitle: Text(r['text']?.toString() ?? ''),
          trailing: Text(r['date']?.toString() ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        );
      },
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar skeleton
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          // Name skeleton
          Container(
            width: 200,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          // College skeleton
          Container(
            width: 250,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),
          // Stats cards skeleton
          Row(
            children: List.generate(3, (i) => 
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Bio section skeleton
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Additional sections skeleton
          ...List.generate(
            3,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 48),
          const SizedBox(height: 8),
          const Text('Failed to load profile.'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: _retry,
          ),
        ],
      ),
    );
  }

  void _showVerificationStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _VerificationStatusSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  void _showSafetyControls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SafetyControlsSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }
}

// --- UI Components ---

class _TrustStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  const _TrustStat({required this.label, required this.value, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon != null
            ? Icon(icon, color: iconColor ?? Colors.blue, size: 18)
            : Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (icon == null)
          const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;
  const _InterestChip({required this.label, this.onDeleted});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue[50],
      labelStyle: const TextStyle(color: Colors.blue),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      deleteIcon: onDeleted != null ? const Icon(Icons.close, size: 16) : null,
      onDeleted: onDeleted,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Returned':
        color = Colors.green;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Lent Out':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

class _VerificationStatusSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Mock: verified
    final status = 'verified'; // 'pending', 'failed'
    String title, desc;
    IconData icon;
    Color color;
    switch (status) {
      case 'verified':
        title = 'Verified';
        desc = 'Your student status is verified. Enjoy full access and trust benefits!';
        icon = Icons.verified;
        color = Colors.green;
        break;
      case 'pending':
        title = 'Pending Verification';
        desc = 'Your verification is under review. You will be notified soon.';
        icon = Icons.hourglass_top;
        color = Colors.orange;
        break;
      default:
        title = 'Verification Failed';
        desc = 'We could not verify your status. Please try again or contact support.';
        icon = Icons.error;
        color = Colors.red;
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (status == 'failed')
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Re-verify'),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}

class _SafetyControlsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('Block User'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.orange),
            title: const Text('Report User'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.visibility, color: Colors.blue),
            title: const Text('Profile Visibility'),
            subtitle: const Text('Control who can see your profile'),
            trailing: Switch(value: true, onChanged: (v) {}),
          ),
        ],
      ),
    );
  }
}

