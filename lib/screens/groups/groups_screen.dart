import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';
import '../../services/group_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
      String? _currentUid;
    List<Map<String, dynamic>> remoteSearchResults = [];
    bool _remoteSearchLoading = false;
    String? _remoteSearchError;
    Future<void>? _debounceFuture;
  List<Map<String, dynamic>> myGroups = [];
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> discoverGroups = [];
  bool _discoverLoading = true;
  String? _discoverError;
  String searchQuery = '';
  void _onSearchChanged(String val) async {
    setState(() {
      searchQuery = val;
      _remoteSearchError = null;
    });
    // Debounce: wait 500ms after user stops typing
    _debounceFuture?.ignore();
    if (val.trim().isEmpty) {
      setState(() {
        remoteSearchResults = [];
        _remoteSearchLoading = false;
      });
      return;
    }
    _remoteSearchLoading = true;
    Future.delayed(const Duration(milliseconds: 500)).then((_) async {
      // If searchQuery changed during debounce, skip
      if (val != searchQuery) return;
      try {
        final uid = await SessionService.getUid();
        if (uid == null) throw Exception('User not logged in');
        final groupService = GroupService();
        final results = await groupService.fetchDiscoverGroups(uid: uid, query: val);
        setState(() {
          remoteSearchResults = results;
          _remoteSearchLoading = false;
        });
      } catch (e) {
        setState(() {
          _remoteSearchError = e.toString();
          _remoteSearchLoading = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    SessionService.getUid().then((uid) {
      setState(() {
        _currentUid = uid;
      });
      // Load both groups in parallel
      _fetchAllGroups();
    });
  }

  Future<void> _fetchAllGroups() async {
    // Run both fetches in parallel
    await Future.wait([
      _fetchMyGroups(),
      _fetchDiscoverGroups(),
    ]);
  }

  Future<void> _fetchDiscoverGroups() async {
    setState(() {
      _discoverLoading = true;
      _discoverError = null;
    });
    try {
      final uid = await SessionService.getUid();
      if (uid == null) throw Exception('User not logged in');
      final groupService = GroupService();
      final groups = await groupService.fetchDiscoverGroups(uid: uid);
      setState(() {
        discoverGroups = groups;
        _discoverLoading = false;
      });
    } catch (e) {
      setState(() {
        _discoverError = e.toString();
        _discoverLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchMyGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await SessionService.getUid();
      if (uid == null) throw Exception('User not logged in');
      final groups = await GroupService.fetchMyGroupsStatic(uid);
      setState(() {
        myGroups = groups;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1DBF73),
            surfaceTintColor: const Color(0xFF1DBF73),
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: innerBoxIsScrolled ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: innerBoxIsScrolled
                ? const Text(
                    'Communities',
                    style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1DBF73), Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Communities',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect with your campus groups',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
          // Search bar
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1DBF73).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search groups...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DBF73).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.search, color: Color(0xFF1DBF73), size: 20),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),

          // Create Group Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateGroupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create a New Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DBF73),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // My Groups Section
          const Text('My Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1a237e))),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null || (!_loading && myGroups.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups, size: 60, color: Color(0xFF1DBF73)),
                    SizedBox(height: 16),
                    Text(
                      'You are not a member of any group',
                      style: TextStyle(fontSize: 18, color: Color(0xFF1a237e), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please join or create a group to get started.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (!_loading && _error == null && myGroups.isNotEmpty) ...[
            ...myGroups.map((group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailScreen(
                        groupId: group['id'] ?? '',
                        groupName: group['name'] ?? '',
                        groupIcon: Icons.groups, // TODO: Use real icon if available
                        groupType: group['type'] ?? '',
                        members: List<String>.from(group['members'] ?? []),
                        description: group['description'] ?? '',
                        createdBy: group['createdBy'],
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _fetchMyGroups();
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F9F1),
                      child: Icon(Icons.groups, color: const Color(0xFF1DBF73)),
                    ),
                    title: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                    subtitle: Text('${((group['members']?.cast<dynamic>() ?? []).length)} members', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    trailing: (_currentUid != null && group['createdBy'] == _currentUid)
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Group',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Group'),
                                  content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  final groupService = GroupService();
                                  await groupService.deleteGroup(group['id'], _currentUid!);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Group deleted'), backgroundColor: Colors.red),
                                    );
                                    _fetchMyGroups();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete group: ${e.toString()}'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            },
                          )
                        : null,
                  ),
                ),
              ),
            )),
          ] ,
          const SizedBox(height: 28),
          // Discover Groups Section
          const Text('Discover Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1a237e))),
          const SizedBox(height: 10),
          if (_discoverLoading)
            const Center(child: CircularProgressIndicator()),
          if (!_discoverLoading && _discoverError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  'Failed to load discover groups',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
            ),
          if (!_discoverLoading && _discoverError == null) ...[
            Builder(
              builder: (context) {
                final localFiltered = discoverGroups
                    .where((g) => searchQuery.isEmpty || (g['name']?.toLowerCase() ?? '').contains(searchQuery.toLowerCase()))
                    .toList();
                if (searchQuery.isEmpty) {
                  if (discoverGroups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Color(0xFF1DBF73)),
                            SizedBox(height: 18),
                            Text(
                              'No groups to discover right now',
                              style: TextStyle(fontSize: 18, color: Color(0xFF1a237e), fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'You have joined all available groups or none exist yet.',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Column(
                      children: localFiltered
                          .map((group) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GroupDetailScreen(
                                          groupId: group['id'] ?? '',
                                          groupName: group['name'] ?? '',
                                          groupIcon: Icons.groups,
                                          groupType: group['type'] ?? '',
                                          members: List<String>.from(group['members'] ?? []),
                                          description: group['description'] ?? '',
                                          createdBy: group['createdBy'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFE8F9F1),
                                        child: Icon(Icons.groups, color: const Color(0xFF1DBF73)),
                                      ),
                                      title: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                                      subtitle: Text('${((group['members'] as List?) ?? []).length} members · ${group['type'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.black54)),

                                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF1a237e)),
                                      isThreeLine: false,
                                      dense: false,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  }
                } else {
                  // If search is active
                  if (localFiltered.isNotEmpty) {
                    return Column(
                      children: localFiltered
                          .map((group) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GroupDetailScreen(
                                          groupId: group['id'] ?? '',
                                          groupName: group['name'] ?? '',
                                          groupIcon: Icons.groups,
                                          groupType: group['type'] ?? '',
                                          members: List<String>.from(group['members'] ?? []),
                                          description: group['description'] ?? '',
                                          createdBy: group['createdBy'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFE8F9F1),
                                        child: Icon(Icons.groups, color: const Color(0xFF1DBF73)),
                                      ),
                                      title: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                                      subtitle: Text('${_getMemberCount(group)} members · ${group['type'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                      trailing: _buildTrailingWidget(group),
                                      isThreeLine: false,
                                      dense: false,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  } else if (_remoteSearchLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (_remoteSearchError != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(
                        child: Text(
                          'Failed to search groups',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      ),
                    );
                  } else if (remoteSearchResults.isNotEmpty) {
                    return Column(
                      children: remoteSearchResults
                          .map((group) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GroupDetailScreen(
                                          groupId: group['id'] ?? '',
                                          groupName: group['name'] ?? '',
                                          groupIcon: Icons.groups,
                                          groupType: group['type'] ?? '',
                                          members: List<String>.from(group['members'] ?? []),
                                          description: group['description'] ?? '',
                                          createdBy: group['createdBy'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFE8F9F1),
                                        child: Icon(Icons.groups, color: const Color(0xFF1DBF73)),
                                      ),
                                      title: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                                      subtitle: Text('${(group['members']?.cast<dynamic>() ?? []).length} members · ${group['type'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                      trailing: _buildTrailingWidget(group),
                                      isThreeLine: false,
                                      dense: false,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Color(0xFF1DBF73)),
                            SizedBox(height: 18),
                            Text(
                              'No groups found for your search',
                              style: TextStyle(fontSize: 18, color: Color(0xFF1a237e), fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try a different name or spelling.',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(Map<String, dynamic> group) {
    // Check if current user is already a member
    final members = group['members']?.cast<String>() ?? <String>[];
    final isAlreadyMember = _currentUid != null && members.contains(_currentUid);
    final isCreator = _currentUid != null && group['createdBy'] == _currentUid;

    if (isAlreadyMember || isCreator) {
      return const Icon(Icons.chevron_right, color: Color(0xFF1a237e));
    } else {
      return ElevatedButton(
        onPressed: () async {
          try {
            // Join group API call
            final groupService = GroupService();
            await groupService.joinGroup(group['id'], _currentUid!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully joined group!'), backgroundColor: Colors.green),
              );
              _fetchDiscoverGroups(); // Refresh the list
              _fetchMyGroups(); // Refresh my groups
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to join group: ${e.toString()}'), backgroundColor: Colors.red),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DBF73),
          foregroundColor: Colors.white,
          minimumSize: const Size(60, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: const Text('Join', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
  }

  int _getMemberCount(Map<String, dynamic> group) {
    final members = group['members'];
    if (members == null) return 0;
    if (members is List) return members.length;
    return 0;
  }
}
