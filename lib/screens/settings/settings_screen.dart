import 'contact_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lendly/widgets/avatar_options.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme_notifier.dart';
import '../../services/session_service.dart';
import '../admin/admin_panel_screen.dart';
import '../info/terms_screen.dart';
import '../info/privacy_policy_screen.dart';
import '../info/about_app_screen.dart';
import 'report_issue_screen.dart';
import 'safety_tips_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool appNotifications = true;
  bool emailUpdates = false;
  bool showProfilePublic = true;
  bool allowMessages = true;
  bool isLoading = false;
  bool isError = false;

  // Simulated user data (replace with real user model/provider in production)
  String? userName;
  String? userUid;
  String? userAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() { isLoading = true; });
    final session = await SharedPreferences.getInstance();
    final uid = session.getString('uid');
    if (uid == null || uid.isEmpty) {
      setState(() {
        userUid = '';
        isLoading = false;
      });
      return;
    }
    userUid = uid;
    try {
      final res = await http.get(Uri.parse('https://ary-lendly-production.up.railway.app/user/profile?uid=$uid'));
      final data = jsonDecode(res.body);
      setState(() {
        userName = data['name'] ?? '';
        userAvatarUrl = data['avatar'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  Future<void> _performLogout() async {
    try {
      // Clear session data
      await SessionService.clearSession();
      
      // Clear additional SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('uid');
      
      // Navigate to login and remove all previous routes
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error during logout. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green[700],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      const Text('Could not load settings.'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => setState(() => isError = false),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Account Section
                    _sectionHeader('Account Settings'),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: (userAvatarUrl != null && userAvatarUrl!.isNotEmpty && AvatarOptions.avatarOptions.contains(userAvatarUrl))
                                ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[200],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: SvgPicture.asset(
                                        (userAvatarUrl != null && userAvatarUrl is String && userAvatarUrl?.isNotEmpty == true && AvatarOptions.avatarOptions.contains(userAvatarUrl))
                                            ? userAvatarUrl!
                                            : AvatarOptions.avatarOptions[0],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: Colors.green[700],
                                    child: const Icon(Icons.person, color: Colors.white),
                                  ),
                            title: Text(
                              (userName != null && userName!.isNotEmpty)
                                  ? userName!
                                  : 'Name not set',
                              style: TextStyle(
                                color: (userName != null && userName!.isNotEmpty)
                                    ? null
                                    : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              (userUid != null && userUid!.isNotEmpty)
                                  ? userUid!
                                  : 'UID not set',
                              style: TextStyle(
                                color: (userUid != null && userUid!.isNotEmpty)
                                    ? null
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.verified_user, color: Colors.green),
                            title: const Text('Verification'),
                            subtitle: const Text('Verified'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('You are verified!'),
                                  content: const Text('Your student status is verified.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        if (Navigator.canPop(context)) Navigator.pop(context);
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                            title: const Text('Admin Panel'),
                            subtitle: const Text('Manage verifications and users'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminPanelScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.logout, color: Colors.red),
                            title: const Text('Logout', style: TextStyle(color: Colors.red)),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Logout'),
                                  content: const Text('Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(onPressed: () {
                                      if (Navigator.canPop(context)) Navigator.pop(context);
                                    }, child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (Navigator.canPop(context)) Navigator.pop(context);
                                        // Proper logout implementation
                                        await _performLogout();
                                      },
                                      child: const Text('Logout'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Privacy & Safety Section
                    _sectionHeader('Privacy & Safety'),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.block, color: Colors.orange),
                            title: const Text('Blocked Users'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
                              );
                            },
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.visibility),
                            title: const Text('Show profile publicly'),
                            value: showProfilePublic,
                            onChanged: (v) => setState(() => showProfilePublic = v),
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.message),
                            title: const Text('Allow messages from anyone'),
                            value: allowMessages,
                            onChanged: (v) => setState(() => allowMessages = v),
                          ),
                          ListTile(
                            leading: const Icon(Icons.shield, color: Colors.blue),
                            title: const Text('Safety Tips'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SafetyTipsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Notifications Section
                    _sectionHeader('Notifications'),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.notifications),
                            title: const Text('App notifications'),
                            value: appNotifications,
                            onChanged: (v) => setState(() => appNotifications = v),
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.email),
                            title: const Text('Email updates'),
                            value: emailUpdates,
                            onChanged: (v) => setState(() => emailUpdates = v),
                          ),
                        ],
                      ),
                    ),
                    // App Preferences Section
                    _sectionHeader('App Preferences'),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.language),
                            title: const Text('Language'),
                            subtitle: const Text('English'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {},
                          ),
                          Consumer<ThemeNotifier>(
                            builder: (context, themeNotifier, _) {
                              final isDark = themeNotifier.themeMode == ThemeMode.dark;
                              return ListTile(
                                leading: const Icon(Icons.brightness_6),
                                title: const Text('Theme'),
                                subtitle: Text(isDark ? 'Dark' : 'Light'),
                                trailing: Switch(
                                  value: isDark,
                                  onChanged: (val) {
                                    themeNotifier.toggleTheme();
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Support & Legal Section
                    _sectionHeader('Support & Legal'),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ExpansionTile(
                            leading: const Icon(Icons.question_answer),
                            title: const Text('FAQs'),
                            children: [
                              ListTile(
                                title: const Text('How does borrowing work?'),
                                subtitle: const Text('You can request items from others and return them after use.'),
                              ),
                              ListTile(
                                title: const Text('How do I report an issue?'),
                                subtitle: const Text('Go to Report Issue and fill out the form.'),
                              ),
                            ],
                          ),
                          ListTile(
                            leading: const Icon(Icons.contact_support),
                            title: const Text('Contact Support'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.report_problem, color: Colors.red),
                            title: const Text('Report an Issue', style: TextStyle(color: Colors.red)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ReportIssueScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Legal & Info Section
                    _sectionHeader('Legal & Info'),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.description),
                            title: const Text('Terms & Conditions'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TermsScreen()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.privacy_tip),
                            title: const Text('Privacy Policy'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('About App'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AboutAppScreen()),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text('App version 1.0.0', style: theme.textTheme.bodySmall),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4, top: 16),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
      ),
    );
  }
}

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock: empty blocked list
    final blockedUsers = <Map<String, String>>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Colors.green[700],
      ),
      body: blockedUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: Colors.grey[400], size: 64),
                  const SizedBox(height: 12),
                  const Text('No blocked users yet.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: blockedUsers.length,
              itemBuilder: (context, i) {
                final user = blockedUsers[i];
                final avatar = user['avatar'];
                Widget avatarWidget;
                if (avatar != null && AvatarOptions.avatarOptions.contains(avatar)) {
                  avatarWidget = Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: SvgPicture.asset(
                        (avatar != null && avatar is String && avatar.isNotEmpty && AvatarOptions.avatarOptions.contains(avatar))
                            ? avatar
                            : AvatarOptions.avatarOptions[0],
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                } else {
                  avatarWidget = CircleAvatar(
                    backgroundColor: Colors.green[700],
                    child: const Icon(Icons.person, color: Colors.white),
                  );
                }
                return ListTile(
                  leading: avatarWidget,
                  title: Text(user['name']!),
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Unblock'),
                  ),
                );
              },
            ),
    );
  }
}
