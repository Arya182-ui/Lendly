import 'package:flutter/material.dart';
import 'package:lendly/services/session_service.dart';
import 'package:lendly/services/api_client.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'friend_requests_screen.dart';
import '../widgets/avatar_options.dart';
import 'profile/public_profile_screen.dart';

import '../config/env_config.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> friends = [];
  bool isLoading = true;
  bool isError = false;
  String? myUid;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    myUid = await SessionService.getUid();
    if (myUid == null) {
      setState(() {
        isError = true;
        isLoading = false;
      });
      return;
    }
    try {
      final data = await SimpleApiClient.get(
        '/user/friends',
        queryParams: {'uid': myUid!},
        requiresAuth: true,
      );
      setState(() {
        friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1a237e),
          elevation: 0.5,
        ),
        body: _buildFriendsSkeletonLoader(),
      );
    }
    if (isError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Failed to load friends', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchFriends,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1a237e),
        elevation: 0.5,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
      ),
      body: Container(
        width: double.infinity,
        color: Colors.grey[50],
        child: Column(
          children: [
            if (myUid != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('View Friend Requests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendRequestsScreen(myUid: myUid),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: friends.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No friends yet.', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final f = friends[i];
                        final avatar = f['avatar'] ?? '';
                        final name = f['name'] ?? '';
                        final college = f['college'] ?? '';
                        final uid = f['uid'] ?? '';
                        Widget avatarWidget;
                        if (avatar.endsWith('.svg') && avatar.isNotEmpty) {
                          avatarWidget = Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SvgPicture.asset(avatar, fit: BoxFit.contain),
                            ),
                          );
                        } else if (avatar.isNotEmpty) {
                          avatarWidget = CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: AssetImage(avatar),
                          );
                        } else {
                          avatarWidget = CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF1DBF73),
                            child: const Icon(Icons.person, color: Colors.white, size: 32),
                          );
                        }
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Colors.grey[50]!],
                              ),
                            ),
                            child: ListTile(
                              leading: avatarWidget,
                              title: Text(
                                name.isNotEmpty ? name : 'User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Text(
                                college.isNotEmpty ? college : 'No college info',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PublicProfileScreen(uid: uid),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsSkeletonLoader() {
    return Container(
      width: double.infinity,
      color: Colors.grey[50],
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar skeleton
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text skeleton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 200,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arrow skeleton
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
