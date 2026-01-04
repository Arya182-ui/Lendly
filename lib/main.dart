import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_notifier.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/add_item_screen.dart';
import 'screens/home/search_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/chat/messages_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'widgets/bottom_nav.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/impact/impact_screen.dart';
import 'screens/requests_screen.dart';
import 'services/session_service.dart';

import 'services/home_service.dart';



void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'lendly',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const SplashDecider(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/messages': (context) => MessagesScreen(),
        '/groups': (context) => GroupsScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/add-item': (context) => const AddItemScreen(),
        '/requests': (context) => const RequestsScreen(),
      },
    );
  }
}

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  bool? _firstLaunch;
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunchAndSession();
    _syncUserProviderUid();
  }

  Future<void> _syncUserProviderUid() async {
    // Load verification status from storage first
    await SessionService.loadVerificationStatus();
    
    final uid = await SessionService.getUid();
    if (uid != null && uid.isNotEmpty) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUid(uid);
      // Sync verification status from SessionService
      userProvider.setVerificationStatus(SessionService.verificationStatus);
    }
  }
  Future<void> _checkFirstLaunchAndSession() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
      );
      final seen = prefs.getBool('seen_welcome') ?? false;
      if (!seen) {
        await prefs.setBool('seen_welcome', true);
        setState(() { _firstLaunch = true; _loggedIn = false; });
        return;
      }
      // Check session using SessionService with timeout
      final isLoggedIn = await SessionService.isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      setState(() {
        _firstLaunch = false;
        _loggedIn = isLoggedIn;
      });
    } catch (e) {
      print('Session check error: $e');
      setState(() {
        _firstLaunch = false;
        _loggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLaunch == null || _loggedIn == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // If first launch, always show welcome
    if (_firstLaunch!) {
      return const WelcomeScreen();
    }
    // If not logged in, show welcome
    if (!_loggedIn!) {
      return const WelcomeScreen();
    }
    // If logged in, show dashboard
    return const AppRoot();
  }
}


class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const SizedBox.shrink(), // Placeholder for plus button
    NotificationsScreen(),
    ProfileScreen(),
    ImpactScreen(), // Only import from impact/impact_screen.dart
  ];


  void _onTabTapped(int index) async {
    if (index == 2) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.verificationStatus != 'verified') {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verification Required'),
            content: const Text('Please verify your student status before adding items.'),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  setState(() {
                    _selectedIndex = 4; // Go to Profile tab for verification
                  });
                },
                child: const Text('Verify Now'),
              ),
            ],
          ),
        );
        return;
      }
      final added = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddItemScreen()),
      );
      // Optionally refresh home screen if needed
      if (added == true && _selectedIndex == 0 && mounted) {
        setState(() {}); // Triggers rebuild, HomeScreen will reload if coded to do so
      }
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _CustomBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(
                icon: Icons.home,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavIcon(
                icon: Icons.search,
                label: 'Search',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              // Plus button (center, floating)
              GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DBF73),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DBF73).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
              _NavIcon(
                icon: Icons.person,
                label: 'Profile',
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
              _NavIcon(
                icon: Icons.eco,
                label: 'Impact',
                selected: currentIndex == 5,
                onTap: () => onTap(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1DBF73) : const Color(0xFF1a237e);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
