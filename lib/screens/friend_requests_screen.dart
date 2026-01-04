import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

class FriendRequestsScreen extends StatefulWidget {
  final String? myUid;
  const FriendRequestsScreen({Key? key, this.myUid}) : super(key: key);

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  List<Map<String, dynamic>> friendRequests = [];
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
  }

  Future<void> _fetchFriendRequests() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final res = await http.get(Uri.parse('https://ary-lendly-production.up.railway.app/user/friends?uid=${widget.myUid}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          friendRequests = (data['friendRequests'] ?? []) is List ? List<Map<String, dynamic>>.from(data['friendRequests']) : [];
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

  Future<void> _handleFriendRequest(String? requestUid, bool accept) async {
    if (requestUid == null || widget.myUid == null) return;
    if (accept) {
      // Accept friend request
      try {
        await http.post(
          Uri.parse('https://ary-lendly-production.up.railway.app/user/accept-friend-request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fromUid': requestUid, 'toUid': widget.myUid}),
        );
        setState(() {
          friendRequests.removeWhere((r) => r['uid'] == requestUid);
        });
      } catch (e) {
        // Optionally show error
      }
    } else {
      // Reject friend request (delete request)
      try {
        await http.post(
          Uri.parse('https://ary-lendly-production.up.railway.app/user/reject-friend-request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fromUid': requestUid, 'toUid': widget.myUid}),
        );
        setState(() {
          friendRequests.removeWhere((r) => r['uid'] == requestUid);
        });
      } catch (e) {
        // Optionally show error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friend Requests')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (isError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friend Requests')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Failed to load friend requests', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchFriendRequests,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
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
      body: friendRequests.isEmpty
          ? const Center(child: Text('No friend requests.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: friendRequests.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final req = friendRequests[i];
                final avatar = req['avatar'] ?? '';
                Widget avatarWidget;
                if (avatar.endsWith('.svg')) {
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
                } else if (avatar.isNotEmpty) {
                  avatarWidget = CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: AssetImage(avatar),
                  );
                } else {
                  avatarWidget = CircleAvatar(
                    backgroundColor: Colors.green[700],
                    child: const Icon(Icons.person, color: Colors.white),
                  );
                }
                return ListTile(
                  leading: avatarWidget,
                  title: Text(req['name'] ?? 'Unknown'),
                  subtitle: Text(req['college'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        tooltip: 'Accept',
                        onPressed: () async {
                          await _handleFriendRequest(req['uid'], true);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        tooltip: 'Reject',
                        onPressed: () async {
                          await _handleFriendRequest(req['uid'], false);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
