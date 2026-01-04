import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? otpId;
  const OtpVerificationScreen({super.key, required this.email, this.otpId});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _expired = false;
  int _resendSeconds = 30;
  String? _otpId;

  @override
  void initState() {
    super.initState();
    _otpId = widget.otpId;
    _startResendTimer();
  }

  void _startResendTimer() {
    _expired = false;
    _resendSeconds = 30;
    Future.doWhile(() async {
      if (_resendSeconds == 0) {
        setState(() => _expired = true);
        return false;
      }
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; _error = null; });
    final res = await AuthService.verifyOtp(widget.email, _otpController.text.trim(), _otpId ?? '');
    setState(() { _loading = false; });
    if (res['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _error = res['error'] ?? 'Invalid OTP'; });
    }
  }

  Future<void> _resendOtp() async {
    setState(() { _loading = true; _error = null; });
    final res = await AuthService.resendOtp(widget.email);
    setState(() { _loading = false; });
    if (res['success'] == true) {
      setState(() { _otpId = res['otpId']; _expired = false; _resendSeconds = 30; });
      _startResendTimer();
    } else {
      setState(() { _error = res['error'] ?? 'Failed to resend OTP'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 60),
            const SizedBox(height: 24),
            Text('Enter the code sent to ${widget.email}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: 'OTP Code',
                errorText: _error,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _expired ? null : _verifyOtp,
                    child: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ecc71),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
            const SizedBox(height: 16),
            _expired
                ? TextButton(
                    onPressed: _resendOtp,
                    child: const Text('Resend Code'),
                  )
                : Text('Resend in $_resendSeconds seconds'),
            const SizedBox(height: 8),
            if (_expired)
              const Text('Didn\'t receive the code? Check spam or retry.', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
