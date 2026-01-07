import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../widgets/app_layout.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';

// Use AppNotification from enhanced_notification_service.dart
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const NotificationTile({Key? key, required this.notification, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(notification.title),
      subtitle: Text(notification.message),
      trailing: notification.read ? null : Icon(Icons.circle, color: Colors.blue, size: 12),
      onTap: onTap,
    );
  }
}


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = await SessionService.getUid();
      if (uid != null) {
        context.read<NotificationService>().fetchNotifications(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      showBottomNav: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Consumer<NotificationService>(
              builder: (context, notificationService, child) {
                return notificationService.unreadCount > 0
                    ? TextButton(
                        onPressed: () async {
                          final uid = await SessionService.getUid();
                          if (uid != null) {
                            notificationService.markAllAsRead(uid);
                          }
                        },
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: Consumer<NotificationService>(
          builder: (context, notificationService, child) {
            if (notificationService.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (notificationService.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When you have updates, they\'ll appear here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                final uid = await SessionService.getUid();
                if (uid != null) {
                  await notificationService.fetchNotifications(uid);
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notificationService.notifications.length,
                itemBuilder: (context, index) {
                  final notification = notificationService.notifications[index];
                  return NotificationTile(
                    notification: notification,
                    onTap: () {
                      _handleNotificationTap(context, notification);
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // Handle navigation based on notification type and actionUrl
    if (notification.actionUrl != null) {
      // Navigate to specific screen based on actionUrl
      if (notification.actionUrl!.contains('/transactions/')) {
        Navigator.pushNamed(context, '/transactions');
      } else if (notification.actionUrl!.contains('/friends/')) {
        Navigator.pushNamed(context, '/friends');
      } else if (notification.actionUrl!.contains('/challenges/')) {
        Navigator.pushNamed(context, '/challenges');
      } else if (notification.actionUrl!.contains('/wallet/')) {
        Navigator.pushNamed(context, '/wallet');
      }
    } else {
      // Handle based on notification type
      switch (notification.type) {
        case 'friend_request':
        case 'friend_accepted':
          Navigator.pushNamed(context, '/friends');
          break;
        case 'challenge_completed':
          Navigator.pushNamed(context, '/challenges');
          break;
        case 'coins_earned':
        case 'welcome_bonus':
        case 'daily_streak':
          Navigator.pushNamed(context, '/wallet');
          break;
        default:
          // Stay on notifications screen
          break;
      }
    }
  }
}