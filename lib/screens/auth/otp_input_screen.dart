import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'set_new_password_screen.dart';
import '../../services/session_service.dart';



class OtpInputScreen extends StatefulWidget {
  final String email;
  final bool isLogin;
  final String? otpId;
  const OtpInputScreen({super.key, required this.email, this.isLogin = false, this.otpId});

  @override
  State<OtpInputScreen> createState() => _OtpInputScreenState();
}


class _OtpInputScreenState extends State<OtpInputScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  bool _expired = false;
  int _resendSeconds = 30;
  String? _otpId;
  int _attemptsLeft = 3;

  @override
  void initState() {
    super.initState();
    if (widget.isLogin && widget.otpId != null) {
      _otpId = widget.otpId;
    } else {
      _sendOtp();
    }
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _expired = false;
      _resendSeconds = 30;
    });
    Future.doWhile(() async {
      if (_resendSeconds == 0) {
        setState(() {
          _expired = true;
        });
        return false;
      }
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    final res = await AuthService.sendOtp(widget.email);
    setState(() { _loading = false; });
    if (res['success'] == true) {
      setState(() { _otpId = res['otpId']; _expired = false; _resendSeconds = 30; });
      _startResendTimer();
    } else {
      setState(() { _error = res['error'] ?? 'Failed to send OTP'; });
    }
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int idx, String value) {
    if (value.length == 1) {
      if (idx < 5) {
        _focusNodes[idx + 1].requestFocus();
      } else {
        _focusNodes[idx].unfocus();
      }
    } else if (value.isEmpty) {
      if (idx > 0) {
        _focusNodes[idx - 1].requestFocus();
        _controllers[idx - 1].selection = TextSelection.collapsed(offset: _controllers[idx - 1].text.length);
      }
    }
    setState(() {});
  }

  Future<void> _verifyOtp() async {
    if (_attemptsLeft == 0) return;
    setState(() { _loading = true; _error = null; });
    Map<String, dynamic> res;
    final otp = _otpValue;
    if (otp.length != 6) {
      setState(() { _loading = false; _error = 'Enter all 6 digits'; });
      return;
    }
    if (widget.isLogin) {
      res = await AuthService.loginWithOtp(widget.email, otp, _otpId ?? '');
    } else {
      res = await AuthService.verifyOtp(widget.email, otp, _otpId ?? '');
    }
    setState(() { _loading = false; });
    if (res['success'] == true) {
      if (widget.isLogin && res['uid'] != null) {
        // Save UID to session for login
        await SessionService.setUid(res['uid']);
        
        // Also update SharedPreferences directly as backup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', res['uid']);
        await prefs.setBool('is_logged_in', true);
        
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SetNewPasswordScreen(uid: res['uid']),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _attemptsLeft--;
        _error = (_attemptsLeft > 0)
            ? (res['error'] ?? 'Invalid OTP') + ' (${_attemptsLeft} attempts left)'
            : 'No attempts left. Please resend OTP.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Theme.of(context).primaryColor),
                const SizedBox(height: 16),
                Text('Enter the 6-digit OTP sent to', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
                const SizedBox(height: 4),
                Text(widget.email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (idx) => _buildOtpBox(idx)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 8),
                Text('Attempts left: $_attemptsLeft', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_expired && _resendSeconds > 0)
                      Text('Resend in $_resendSeconds seconds', style: const TextStyle(color: Colors.grey)),
                    if (_expired || _resendSeconds == 0)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _attemptsLeft = 3;
                            _error = null;
                          });
                          for (final c in _controllers) { c.clear(); }
                          _sendOtp();
                        },
                        child: const Text('Resend OTP'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_expired)
                  const Text('OTP expired. Please request a new one.', style: TextStyle(color: Colors.red)),
                if (_attemptsLeft == 0 && !_expired)
                  const Text('No attempts left. Please resend OTP.', style: TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_expired || _attemptsLeft == 0) ? null : _verifyOtp,
                          child: const Text('Verify OTP'),
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

  Widget _buildOtpBox(int idx) {
    return Container(
      width: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Focus(
        onKey: (node, event) {
          if (event.isKeyPressed(LogicalKeyboardKey.backspace) && _controllers[idx].text.isEmpty && idx > 0) {
            _focusNodes[idx - 1].requestFocus();
            _controllers[idx - 1].clear();
            setState(() {});
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controllers[idx],
          focusNode: _focusNodes[idx],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          obscureText: true,
          obscuringCharacter: '•',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _focusNodes[idx].hasFocus ? Theme.of(context).primaryColor : Colors.black,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _focusNodes[idx].hasFocus ? Colors.green[50] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _focusNodes[idx].hasFocus ? const Color(0xFF2ecc71) : Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2ecc71), width: 2),
            ),
          ),
          onChanged: (val) => _onOtpChanged(idx, val),
          onSubmitted: (val) {
            if (idx == 5 && _otpValue.length == 6) _verifyOtp();
          },
        ),
      ),
    );
  }
}

