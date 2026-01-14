import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'theme_notifier.dart';
import 'theme/app_theme.dart';
import 'services/session_service.dart';
import 'services/app_initializer.dart';
import 'services/firebase_auth_service.dart';
import 'services/api_client.dart';
import 'services/app_logger.dart';
import 'services/connectivity_service.dart';
import 'config/env_config.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen_optimized.dart';
import 'screens/search/search_screen.dart';
import 'screens/home/add_item_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/impact/impact_screen.dart';
import 'screens/chat/messages_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'widgets/lendly_navigation.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment configuration
    await EnvConfig.load();
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize core services
    await Future.wait([
      FirebaseAuthService().initialize(),
      ApiClient().initialize(),
      AppInitializer.initialize(),
    ]);
    
    logger.info('App initialization completed successfully', tag: 'Main');
  } catch (e) {
    logger.error('App initialization failed', tag: 'Main', data: {'error': e.toString()});
    // Continue anyway, the app can work with some services failing
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: const LendlyApp(),
    ),
  );
}

class LendlyApp extends StatelessWidget {
  const LendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    
    return MaterialApp(
      title: 'Lendly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const AppInitializer(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const MainNavigationScreen(),
      },
    );
  }
}

/// App initialization and route management
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final userId = await SessionService.getUserId();
      setState(() {
        _isLoggedIn = userId != null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to check authentication status';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _checkAuthStatus();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return _isLoggedIn ? const MainNavigationScreen() : const LoginScreen();
  }
}

/// Main navigation screen with bottom navigation
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const HomeScreenOptimized(),
    const SearchScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Handle add item action
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddItemScreen()),
      );
      return;
    }
    
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: LendlyNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
