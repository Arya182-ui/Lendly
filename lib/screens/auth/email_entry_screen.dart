import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';

class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _loading = false; _error = 'Email required'; });
      return;
    }
    try {
      final firebaseAuth = FirebaseAuthService();
      await firebaseAuth.sendPasswordResetEmail(email);
      setState(() { _loading = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter College Email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'College Email',
                errorText: _error,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ecc71),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    child: const Text('Send OTP'),
                  ),
          ],
        ),
      ),
    );
  }
}

