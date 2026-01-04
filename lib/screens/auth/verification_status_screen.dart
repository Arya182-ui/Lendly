import 'package:flutter/material.dart';

class VerificationStatusScreen extends StatelessWidget {
  final String status; // 'pending', 'verified', 'failed'
  const VerificationStatusScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    Color color;
    if (status == 'pending') {
      message = 'We’re verifying your details…';
      icon = Icons.hourglass_top;
      color = Colors.orange;
    } else if (status == 'verified') {
      message = 'You’re verified! Start borrowing/lending.';
      icon = Icons.verified;
      color = const Color(0xFF2ecc71);
    } else {
      message = 'Couldn’t verify. Try again or contact support.';
      icon = Icons.error;
      color = Colors.red;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Status')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 24),
            Text(message, style: TextStyle(fontSize: 18, color: color)),
            if (status == 'failed') ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Contact Support'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
