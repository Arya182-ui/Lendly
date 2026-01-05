import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/api_client.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = this.createTicker((elapsed) {
      // Add animation logic here if needed
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 0),
              // Back button
              if (Navigator.canPop(context))
                Padding(
                  padding: const EdgeInsets.only(left: 0, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1a237e)),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              // App logo
              Image.asset('assets/images/logo.png', height: 90),
              const SizedBox(height: 32),
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1DBF73),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Image.asset('assets/images/signup_illustration.png', height: 150),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Student Email or personal Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _error,
                ),
              ),
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
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DBF73),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(fontSize: 15)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Login',
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
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _loading = false; _error = 'Please enter a valid email'; });
      return;
    }
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
      final user = await firebaseAuth.signUp(email, password);
      
      if (user?.user != null) {
        final uid = user!.user!.uid;
        
        // Create basic user profile in backend
        try {
          await SimpleApiClient.post(
            '/auth/complete-onboarding',
            body: {
              'uid': uid,
              'displayName': email.split('@')[0], // Use email prefix as default name
              'email': email,
              'avatarChoice': 'default',
            },
            requiresAuth: false, // Newly signed up user may not have token yet
          );
        } catch (e) {
        }
        
        setState(() { _loading = false; });
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = 'Registration failed. Please try again.';
      
      // Handle Firebase Auth exceptions with user-friendly messages
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'An account already exists with this email address.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak. Please choose a stronger password.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.toString().contains('operation-not-allowed')) {
        errorMessage = 'Email/password accounts are not enabled.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many requests. Please try again later.';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      setState(() { 
        _loading = false; 
        _error = errorMessage; 
      });
    }
  }
}