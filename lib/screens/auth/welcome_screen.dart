import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              // App logo (bigger, lower)
              Image.asset('assets/images/logo.png', height: 110),
              const SizedBox(height: 36),
              // Illustration (bigger, lower)
              Image.asset(
                'assets/images/welcome_illustration.png',
                height: 320,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              // App name
              const Text(
                'Welcome to Lendly',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1DBF73),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Tagline
              const Text(
                'Students share books, laptops, bicycles, and more.',
                style: TextStyle(fontSize: 16, color: Color(0xFF1a237e)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              // Trust/Community indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFE8F9F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.groups_rounded, color: Color(0xFF1DBF73), size: 20),
                    SizedBox(width: 8),
                    Text('Friendly, sustainable, student-only', style: TextStyle(color: Color(0xFF1a237e))),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Get Started button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DBF73),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  child: const Text('Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
