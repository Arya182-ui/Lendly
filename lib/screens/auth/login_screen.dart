
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';
import '../../services/auth_service.dart';
import 'otp_input_screen.dart';
import '../../main.dart';
import '../../services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _loginWithPassword = true;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), // Reduced vertical padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80), // Even more top space for extra breathing room
              // App logo (match signup)
              Image.asset('assets/images/logo.png', height: 80), // Slightly smaller logo
              const SizedBox(height: 16), // Less space below logo
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1DBF73),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Image.asset('assets/images/login_illustration.png', height: 120), // Smaller illustration
              const SizedBox(height: 18), // Less space below illustration
              // Toggle for login method
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Password'),
                    selected: _loginWithPassword,
                    onSelected: (v) => setState(() => _loginWithPassword = true),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('OTP'),
                    selected: !_loginWithPassword,
                    onSelected: (v) => setState(() => _loginWithPassword = false),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _error,
                ),
              ),
              if (_loginWithPassword) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _onForgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _loginWithPassword ? _loginWithPasswordMethod : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DBF73),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 3,
                        ),
                        child: Text(
                          _loginWithPassword ? 'Login' : 'Login with OTP',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(fontSize: 15)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Color(0xFF1a237e),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _loading = false; _error = 'Email required'; });
      return;
    }
    final res = await AuthService.sendOtp(email);
    setState(() { _loading = false; });
    if (res['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpInputScreen(email: email, isLogin: true, otpId: res['otpId']),
        ),
      );
    } else {
      setState(() { _error = res['error'] ?? 'Failed to send OTP'; });
    }
  }

  Future<void> _loginWithPasswordMethod() async {
    setState(() { _loading = true; _error = null; });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() { _loading = false; _error = 'Email and password required'; });
      return;
    }
    final res = await AuthService.loginWithPassword(email, password);
    setState(() { _loading = false; });
    if (res['success'] == true) {
      // Save session, navigate to AppRoot (main layout with bottom nav)
      if (res['uid'] != null) {
        await SessionService.setUid(res['uid']);
        
        // Also update SharedPreferences directly as backup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', res['uid']);
        await prefs.setBool('is_logged_in', true);
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AppRoot()),
        (route) => false,
      );
    } else {
      setState(() { _error = res['error'] ?? 'Login failed'; });
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _error = 'Enter your email to reset password'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final res = await AuthService.sendOtp(email);
    setState(() { _loading = false; });
    if (res['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpInputScreen(email: email, isLogin: true, otpId: res['otpId']),
        ),
      );
    } else {
      setState(() { _error = res['error'] ?? 'Failed to send OTP'; });
    }
  }
}
