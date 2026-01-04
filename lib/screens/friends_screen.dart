import 'package:flutter/material.dart';
import 'package:lendly/services/session_service.dart';
import 'package:lendly/services/auth_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'friend_requests_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/avatar_options.dart';
import 'profile/public_profile_screen.dart';

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
      final res = await http.get(Uri.parse('https://ary-lendly-production.up.railway.app/user/friends?uid=$myUid'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() {
          isError = true;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: const Center(child: CircularProgressIndicator()),
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
        color: Colors.grey[100],
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
                      padding: const EdgeInsets.all(16),
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final f = friends[i];
                        final avatar = f['avatar'] ?? '';
                        final name = f['name'] ?? '';
                        final college = f['college'] ?? '';
                        final uid = f['uid'] ?? '';
                        Widget avatarWidget;
                        if (avatar.endsWith('.svg')) {
                          avatarWidget = Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: SvgPicture.asset(avatar, fit: BoxFit.contain),
                            ),
                          );
                        } else if (avatar.isNotEmpty) {
                          avatarWidget = CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: AssetImage(avatar),
                          );
                        } else {
                          avatarWidget = CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.green[700],
                            child: const Icon(Icons.person, color: Colors.white, size: 28),
                          );
                        }
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: ListTile(
                            leading: avatarWidget,
                            title: Text(name.isNotEmpty ? name : 'No name', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(college.isNotEmpty ? college : 'No college info'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(uid: uid),
                                ),
                              );
                            },
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
}
