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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1a237e)),
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
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: Column(
          children: [
            // Category chips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: categories.map((cat) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selectedCategory == cat,
                    onSelected: (_) => setState(() => selectedCategory = cat),
                    selectedColor: const Color(0xFF1DBF73),
                    backgroundColor: const Color(0xFFF5F5F5),
                    labelStyle: TextStyle(color: selectedCategory == cat ? Colors.white : const Color(0xFF1a237e)),
                  ),
                )).toList(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            notifications.isEmpty ? Icons.notifications_none : Icons.filter_alt_off,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            notifications.isEmpty
                                ? 'No notifications yet'
                                : 'No ${selectedCategory.toLowerCase()} notifications',
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notifications.isEmpty
                                ? 'When you have notifications, they\'ll appear here'
                                : 'Try selecting a different category',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final n = filtered[idx];
                        final isUnread = !(n['read'] ?? false);
                        final type = _getTypeFromNotification(n);
                        
                        return Card(
                          elevation: isUnread ? 2 : 0,
                          color: isUnread ? Colors.white : const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: isUnread ? const BorderSide(color: Color(0xFF1DBF73), width: 1.2) : BorderSide.none,
                          ),
                          child: ListTile(
                            onTap: isUnread ? () => _markAsRead(n['id']) : null,
                            leading: Icon(
                              type == 'request'
                                  ? Icons.shopping_bag
                                  : type == 'group'
                                      ? Icons.groups
                                      : type == 'system'
                                          ? Icons.settings
                                          : Icons.notifications,
                              color: type == 'system'
                                  ? Colors.amber[800]
                                  : type == 'group'
                                      ? Colors.purple
                                      : const Color(0xFF1a237e),
                              size: 32,
                            ),
                            title: Text(
                              n['title'] ?? 'Notification',
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                color: const Color(0xFF1a237e),
                              ),
                            ),
                            subtitle: Text(
                              n['message'] ?? 'No message',
                              style: TextStyle(
                                color: isUnread ? Colors.black : Colors.black54,
                              ),
                            ),
                            trailing: Text(
                              _formatTimestamp(n['createdAt']),
                              style: const TextStyle(fontSize: 12, color: Colors.black45),
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
}
