import 'package:flutter/material.dart';

import '../../services/session_service.dart';
import '../../services/group_service.dart';
import '../../services/user_service.dart';
import '../profile/public_profile_screen.dart';


class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final IconData groupIcon;
  final String groupType;
  final List<String> members;
  final String description;
  final String? createdBy;

  const GroupDetailScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
    required this.groupType,
    required this.members,
    required this.description,
    this.createdBy,
  }) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String? _uid;
  bool _loading = false;
  List<String> _members = [];
  Map<String, String> _memberNames = {};
  bool _loadingNames = false;

  String? _groupName;
  String? _description;
  String? _groupType;
  @override
  void initState() {
    super.initState();
    // Load group and uid in parallel
    Future.wait([
      _fetchGroup(),
      _loadUid(),
    ]);
  }

  Future<void> _fetchGroup() async {
    try {
      final group = await GroupService.fetchGroupById(widget.groupId);
      if (mounted) {
        setState(() {
          _groupName = group['name'] ?? '';
          _description = group['description'] ?? '';
          _groupType = group['type'] ?? '';
          _members = List<String>.from(group['members'] ?? []);
        });
        await _fetchMemberNames();
      }
    } catch (e) {
      // fallback to widget values if fetch fails
      setState(() {
        _groupName = widget.groupName;
        _description = widget.description;
        _groupType = widget.groupType;
        _members = List<String>.from(widget.members);
      });
      await _fetchMemberNames();
    }
  }

  Future<void> _fetchMemberNames() async {
    setState(() => _loadingNames = true);
    final Map<String, String> names = {};
    // Fetch all member profiles in parallel
    final futures = _members.map((uid) async {
      final profile = await UserService.fetchPublicProfile(uid);
      return MapEntry(uid, profile);
    }).toList();
    final results = await Future.wait(futures);
    for (final entry in results) {
      final uid = entry.key;
      final profile = entry.value;
      if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
        names[uid] = profile['name'];
      } else {
        names[uid] = uid;
      }
    }
    if (mounted) {
      setState(() {
        _memberNames = names;
        _loadingNames = false;
      });
    }
  }

  Future<void> _loadUid() async {
    final uid = await SessionService.getUid();
    setState(() {
      _uid = uid;
    });
  }

  Future<void> _handleJoinLeave() async {
    if (_uid == null) return;
    setState(() => _loading = true);
    try {
      final isMember = _members.contains(_uid);
      if (isMember) {
        await GroupService.leaveGroup(groupId: widget.groupId, uid: _uid!);
        setState(() => _members.remove(_uid));
        await _fetchMemberNames();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left group')));
        }
      } else {
        await GroupService.joinGroup(groupId: widget.groupId, uid: _uid!);
        setState(() => _members.add(_uid!));
        await _fetchMemberNames();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined group')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMember = _uid != null && _members.contains(_uid);
    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName ?? ''),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1a237e),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFE8F9F1),
                child: Icon(widget.groupIcon, color: const Color(0xFF1DBF73), size: 36),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_groupName ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1a237e))),
                  const SizedBox(height: 4),
                  Text('${_members.length} members · ${_groupType ?? ''}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(_description ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87)),
          if (_uid == widget.createdBy) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1DBF73),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final result = await showDialog<Map<String, String>>(
                  context: context,
                  builder: (context) {
                    final nameController = TextEditingController(text: widget.groupName);
                    final descController = TextEditingController(text: widget.description);
                    return AlertDialog(
                      title: const Text('Edit Group'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Group Name'),
                          ),
                          TextField(
                            controller: descController,
                            decoration: const InputDecoration(labelText: 'Description'),
                            maxLines: 2,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context, {
                                'name': nameController.text.trim(),
                                'description': descController.text.trim(),
                            });
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
                if (result != null && result['name'] != null && result['description'] != null) {
                  try {
                    await GroupService.updateGroup(
                      groupId: widget.groupId,
                      name: result['name']!,
                      description: result['description']!,
                    );
                    await _fetchGroup();
                    if (mounted) Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated!')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update group: $e')));
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 32),
          const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1a237e))),
          const SizedBox(height: 10),
          if (_loadingNames)
            const Center(child: CircularProgressIndicator())
          else if (_members.isEmpty)
            Center(
              child: Text('No members yet.', style: TextStyle(fontSize: 15, color: Colors.black54)),
            )
          else
            ..._members.map((member) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F9F1),
                      child: Icon(Icons.person, color: const Color(0xFF1DBF73)),
                    ),
                    title: Text(_memberNames[member] ?? member, style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PublicProfileScreen(uid: member),
                        ),
                      );
                    },
                  ),
                )),
        ],
      ),
    );
  }
}
