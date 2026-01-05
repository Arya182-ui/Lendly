import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';

class SetNewPasswordScreen extends StatefulWidget {
  final String uid;
  const SetNewPasswordScreen({super.key, required this.uid});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _setPassword() async {
    setState(() { _loading = true; _error = null; });
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    if (password.isEmpty || password.length < 6) {
      setState(() { _loading = false; _error = 'Password must be at least 6 characters'; });
      return;
    }
    if (password != confirm) {
      setState(() { _loading = false; _error = 'Passwords do not match'; });
      return;
    }
    try {
      final firebaseAuth = FirebaseAuthService();
      final currentUser = firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.updatePassword(password);
        setState(() { _loading = false; });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successful! Please login.')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() { _loading = false; _error = 'User not authenticated'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.lock_reset, size: 64, color: Theme.of(context).primaryColor),
                const SizedBox(height: 16),
                const Text('Set a new password for your account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Choose a strong password you haven\'t used before.',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 32),
                _loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _setPassword,
                          child: const Text('Set Password'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ecc71),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
