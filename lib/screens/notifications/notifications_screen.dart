import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/enhanced_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Requests', 'Groups', 'System'];
  List<Map<String, dynamic>> notifications = [];
  bool _loading = true;
  String? _error;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      _currentUid = await SessionService.getUid();
      if (_currentUid == null) {
        setState(() {
          _error = 'Please log in to view notifications';
          _loading = false;
        });
        return;
      }
      
      final enhancedService = EnhancedNotificationService();
      final fetchedNotifications = await enhancedService.fetchNotifications(_currentUid!);
      setState(() {
        notifications = fetchedNotifications;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_currentUid == null) return;
    
    try {
      final enhancedService = EnhancedNotificationService();
      await enhancedService.markAsRead(_currentUid!, notificationId);
      // Update local state
      setState(() {
        final index = notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          notifications[index]['read'] = true;
        }
      });
    } catch (e) {
      // Show error silently, don't break UX
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUid == null) return;
    
    try {
      final enhancedService = EnhancedNotificationService();
      await enhancedService.markAllAsRead(_currentUid!);
      setState(() {
        for (var notification in notifications) {
          notification['read'] = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_currentUid == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final enhancedService = EnhancedNotificationService();
        await enhancedService.clearAllNotifications(_currentUid!);
        setState(() => notifications.clear());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  String _getTypeFromNotification(Map<String, dynamic> notification) {
    final type = notification['type']?.toString().toLowerCase() ?? '';
    switch (type) {
      case 'transaction_request':
      case 'transaction_approved':
      case 'transaction_rejected':
        return 'request';
      case 'group_joined':
      case 'group_announcement':
        return 'group';
      case 'verification_approved':
      case 'verification_rejected':
      case 'system_update':
        return 'system';
      default:
        return 'request';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return timestamp.toString();
      }
      
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      
      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1a237e)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Notifications', style: TextStyle(color: Color(0xFF1a237e), fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1a237e)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Notifications', style: TextStyle(color: Color(0xFF1a237e), fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNotifications,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = selectedCategory == 'All'
        ? notifications
        : notifications.where((n) {
            final type = _getTypeFromNotification(n);
            return type.toLowerCase().contains(selectedCategory.toLowerCase()) ||
                   selectedCategory.toLowerCase() == type.toLowerCase();
          }).toList();
          
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: innerBoxIsScrolled ? const Color(0xFF1E293B) : const Color(0xFF1DBF73),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: innerBoxIsScrolled
                ? const Text(
                    'Notifications',
                    style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                  )
                : null,
            actions: [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: innerBoxIsScrolled ? const Color(0xFF1E293B) : const Color(0xFF1DBF73),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'mark_all_read':
                      _markAllAsRead();
                      break;
                    case 'clear_all':
                      _clearAllNotifications();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('Clear all', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DBF73).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.notifications_rounded,
                                color: Color(0xFF1DBF73),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  '${notifications.where((n) => !(n['read'] ?? false)).length} unread',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _loadNotifications,
          color: const Color(0xFF1DBF73),
          child: Column(
            children: [
              // Category chips - Enhanced
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: categories.map((cat) {
                    final isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF1DBF73), Color(0xFF10B981)],
                                  )
                                : null,
                            color: isSelected ? null : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1DBF73).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                notifications.isEmpty ? Icons.notifications_off_outlined : Icons.filter_alt_off_rounded,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              notifications.isEmpty
                                  ? 'No notifications yet'
                                  : 'No ${selectedCategory.toLowerCase()} notifications',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notifications.isEmpty
                                  ? 'When you have notifications, they\'ll appear here'
                                  : 'Try selecting a different category',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final n = filtered[idx];
                          final isUnread = !(n['read'] ?? false);
                          final type = _getTypeFromNotification(n);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isUnread ? Colors.white : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: isUnread
                                  ? Border.all(
                                      color: const Color(0xFF1DBF73).withOpacity(0.3),
                                      width: 1.5,
                                    )
                                  : null,
                              boxShadow: isUnread
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1DBF73).withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: isUnread ? () => _markAsRead(n['id']) : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: type == 'system'
                                              ? Colors.amber.withOpacity(0.1)
                                              : type == 'group'
                                                  ? Colors.purple.withOpacity(0.1)
                                                  : const Color(0xFF1DBF73).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          type == 'request'
                                              ? Icons.shopping_bag_rounded
                                              : type == 'group'
                                                  ? Icons.groups_rounded
                                                  : type == 'system'
                                                      ? Icons.settings_rounded
                                                      : Icons.notifications_rounded,
                                          color: type == 'system'
                                              ? Colors.amber[800]
                                              : type == 'group'
                                                  ? Colors.purple
                                                  : const Color(0xFF1DBF73),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    n['title'] ?? 'Notification',
                                                    style: TextStyle(
                                                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                                      fontSize: 15,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                                if (isUnread)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF1DBF73),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n['message'] ?? 'No message',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isUnread ? const Color(0xFF475569) : Colors.grey[500],
                                                height: 1.3,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatTimestamp(n['createdAt']),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[400],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
