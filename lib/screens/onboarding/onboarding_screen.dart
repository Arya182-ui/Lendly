import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.school, size: 80, color: Color(0xFF2ecc71)),
            SizedBox(height: 24),
            Text('Welcome to lendly', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Why buy, when you can borrow?', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
