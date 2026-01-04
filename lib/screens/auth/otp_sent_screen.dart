import 'package:flutter/material.dart';
import 'otp_input_screen.dart';

class OtpSentScreen extends StatelessWidget {
  final String email;
  const OtpSentScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Sent')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email, size: 60, color: Color(0xFF2ecc71)),
            const SizedBox(height: 24),
            Text('An OTP has been sent to $email', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtpInputScreen(email: email),
                  ),
                );
              },
              child: const Text('Enter OTP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ecc71),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

