import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/services/wake_word_service.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/config/api_config.dart';
import '../home/home.dart';
import 'signup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isResending = false; // Track if we're resending to skip auto-verify

  // Resend OTP timer
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResendOTP = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to rebuild the UI as the user types
    _phoneController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));

    // Initialize OTP real-time listener
    _initializeOTPListener();
  }

  void _initializeOTPListener() async {
    try {
      // Initialize OTP Socket in background (fallback for auto-fill). Don't block login.
      OTPService.initializeOTPConnection(ApiConfig.socketUrl)
          .then((_) {
            print('✅ OTP Socket init finished (SMS remains primary delivery)');
          })
          .catchError((e) {
            print('ℹ️ OTP Socket optional path unavailable — SMS will be used: $e');
          });

      // Set callback for when OTP is received (e.g. when socket works)
      OTPService.onOTPReceived((otp, phone, expiresIn) {
        if (!mounted) return;

        // If user has already sent OTP for this phone, auto-fill it
        if (_isOtpSent && _phoneController.text == phone) {
          setState(() {
            _otpController.text = _digitsOnly(otp);
          });

          // Show notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'OTP received: $otp (expires in ${expiresIn ~/ 60} min)',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 10),
            ),
          );

          // Auto-verify ONLY on first OTP send, NOT on resend
          // This gives user control when resending
          if (!_isResending) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _otpController.text.length == 6) {
                _verifyOTP();
              }
            });
          } else {
            // Reset resending flag after OTP arrives
            setState(() {
              _isResending = false;
            });
          }
        }
      });

      print('✅ OTP listener set (socket connects in background)');
    } catch (e) {
      print('❌ Failed to set OTP listener: $e');
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    OTPService.disconnect(); // Disconnect OTP Socket when leaving screen
    super.dispose();
  }

  // Logic to check if the button should be enabled
  bool _isButtonEnabled() {
    if (!_isOtpSent) {
      // Check if phone number is exactly 10 digits
      return _digitsOnly(_phoneController.text).length == 10;
    } else {
      // Check if OTP is exactly 6 digits
      return _digitsOnly(_otpController.text).length == 6;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Back arrow when on OTP step - go back to phone entry (sign-in form)
                  if (_isOtpSent)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _isOtpSent = false;
                            _errorMessage = null;
                            _otpController.clear();
                            _resendTimer?.cancel();
                            _canResendOTP = false;
                            _resendCountdown = 0;
                          });
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 0),
                  if (_isOtpSent)
                    const SizedBox(height: 8)
                  else
                    const SizedBox(height: 0),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isOtpSent ? 'Verify OTP' : 'Welcome to Syava AI',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtpSent
                        ? 'Enter the 6-digit code sent to your phone'
                        : 'Your safety companion',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (!_isOtpSent) ...[
                    _buildInputLabel('Phone Number'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _phoneController,
                      'Enter 10-digit number',
                      Icons.phone_outlined,
                      maxLength: 10,
                    ),
                  ] else ...[
                    _buildInputLabel('One-Time Password'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _otpController,
                      'Enter 6-digit OTP',
                      Icons.lock_outline,
                      maxLength: 6,
                    ),
                  ],

                  const SizedBox(height: 12),
                  if (_isOtpSent)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _canResendOTP && !_isLoading
                            ? _resendOTP
                            : null,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _canResendOTP
                              ? "Didn't receive code? Resend"
                              : "Resend OTP in ${_resendCountdown}s",
                          style: TextStyle(
                            color: _canResendOTP ? Colors.blue : Colors.grey,
                            fontSize: 13,
                            fontWeight: _canResendOTP
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "We'll send you a one-time password",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // MAIN ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      // BUTTON LOGIC: If conditions aren't met, onPressed is null (disabled)
                      onPressed: (_isButtonEnabled() && !_isLoading)
                          ? () async {
                              if (!_isOtpSent) {
                                await _sendOTP();
                              } else {
                                await _verifyOTP();
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isOtpSent ? 'Verify & Login' : 'Send OTP',
                              style: TextStyle(
                                fontSize: 18,
                                color: _isButtonEnabled()
                                    ? Colors.white
                                    : Colors.white38,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  if (!_isOtpSent) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      // Inside LoginScreen.dart
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },

                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: "Sign Up",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startResendTimer() {
    if (!mounted) return;

    setState(() {
      _resendCountdown = 30;
      _canResendOTP = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _canResendOTP = true;
          _resendTimer?.cancel();
        }
      });
    });
  }

  Future<void> _resendOTP() async {
    if (!_canResendOTP) return;
    await _resendOTPSilent();
  }

  /// Resend OTP silently without showing messages
  /// Only shows error if something goes wrong. SMS first, socket as fallback.
  Future<void> _resendOTPSilent() async {
    try {
      print('🔄 Silently resending OTP to ${_phoneController.text}...');

      // Set resending flag - this disables auto-verify so user can see the OTP
      setState(() {
        _isResending = true;
        _otpController.clear(); // Clear old OTP so user can see new one arrive
      });

      // Send OTP request to backend first (SMS path)
      final response = await AuthService.sendOTP(_phoneController.text);

      if (response.success) {
        String? otpForSMS;
        bool smsSentFromServer = false;

        if (response.data is Map) {
          smsSentFromServer = response.data!['smsSent'] == true;
          if (response.data!['otp'] != null) {
            otpForSMS = response.data!['otp'].toString();
          }
        }

        if (!smsSentFromServer && otpForSMS != null) {
          print('📱 Sending OTP via device SMS...');
          await SMSService.sendOTP(_phoneController.text, otpForSMS);
        }

        // Register socket in background for auto-fill if it connects
        OTPService.registerForOTP(_phoneController.text).catchError((_) {});

        print('✅ OTP resent successfully (silent mode)');
        _startResendTimer();
      } else {
        // Only show error if something fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resend OTP: ${response.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Resend OTP error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error resending OTP'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Send OTP request to backend first (SMS path – fast, no socket dependency)
      print('📱 Step 1: Sending OTP request to backend (SMS first)...');
      final response = await AuthService.sendOTP(_phoneController.text);

      if (response.success) {
        // Extract OTP from response for SMS delivery
        String? otpForSMS;
        bool smsSentFromServer = false;

        if (response.data is Map) {
          smsSentFromServer = response.data!['smsSent'] == true;
          if (response.data!['otp'] != null) {
            otpForSMS = response.data!['otp'].toString();
          }
        }

        // Step 2: Ensure user gets OTP via SMS (backend sent it, or we send from device)
        if (!smsSentFromServer && otpForSMS != null) {
          print('📱 Sending OTP via device SMS...');
          final smsSent = await SMSService.sendOTP(
            _phoneController.text,
            otpForSMS,
          );
          if (smsSent) {
            print('✅ SMS sent successfully');
          } else {
            print(
              '⚠️  Device SMS failed – user can still enter OTP if backend sent it',
            );
          }
        } else if (smsSentFromServer) {
          print('✅ Backend already sent SMS');
        }

        setState(() {
          _isLoading = false;
          _isOtpSent = true;
          _errorMessage = null;
        });

        // Start resend timer
        _startResendTimer();

        // Step 3: Register for socket in background (fallback for auto-fill when socket works)
        OTPService.registerForOTP(_phoneController.text)
            .then((_) {
              print('✅ Socket registered for auto-fill (if connected)');
            })
            .catchError((e) {
              print('⚠️  Socket registration skipped: $e');
            });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.sms, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'OTP sent! Check your SMS or wait for it to auto-fill...',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Error: ${e.toString()}\n\nMake sure backend is running at ${ApiConfig.socketUrl}';
      });
      print('❌ _sendOTP error: $e');
    }
  }

  Future<void> _verifyOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await AuthService.verifyOTP(
      phone: _phoneController.text,
      otp: _otpController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (response.success) {
      // Start background wake word monitoring service
      print('🎤 Starting background wake word monitoring service...');
      await WakeWordService.startService();

      // Initialize notification service for SOS alerts
      print('🔔 Initializing notification service...');
      await NotificationService.initialize();

      // Preload emergency contacts for instant SOS access
      print('📥 Preloading emergency contacts...');
      ContactsService.preloadContacts(); // Fire and forget, don't wait

      // Navigate to home screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      final msg = response.message ?? 'Invalid OTP. Please try again.';
      final isUserNotFound =
          msg.toLowerCase().contains('user not found') ||
          msg.toLowerCase().contains('sign up first');
      if (isUserNotFound && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SignUpScreen(initialPhone: _phoneController.text),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found. Please sign up to continue.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        setState(() {
          _errorMessage = msg;
        });
      }
    }
  }

  Widget _buildInputLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }
}

/*Sign-up 
1. googlesignup
2. emegencycontact atleast 1
3. name 
4. phonenumber
5. emailid
6. occupation
7. age


*/
