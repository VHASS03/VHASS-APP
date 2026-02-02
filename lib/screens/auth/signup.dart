import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/services/auth_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/utils/phone_formatter.dart';
import '../home/home.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _occupationController = TextEditingController();
  final _ageController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpStep = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Resend OTP timer
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResendOTP = false;

  final List<Map<String, dynamic>> _emergencyContacts = [
    {
      'name': TextEditingController(),
      'phone': TextEditingController(),
      'countryCode': 'IN',
    },
  ];

  // Validation Logic
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (value.length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  Future<void> _handleNextStep() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Prepare emergency contacts
      final emergencyContacts = _emergencyContacts
          .where(
            (contact) =>
                contact['name']?.text.isNotEmpty == true &&
                contact['phone']?.text.isNotEmpty == true,
          )
          .map(
            (contact) => {
              'name': contact['name']!.text,
              'phone': contact['phone']!.text,
              'countryCode': contact['countryCode'] ?? 'IN',
            },
          )
          .toList();

      // Call signup API
      final response = await AuthService.signup(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        age: _ageController.text.isNotEmpty ? _ageController.text : null,
        occupation: _occupationController.text.isNotEmpty
            ? _occupationController.text
            : null,
        emergencyContacts: emergencyContacts.isNotEmpty
            ? emergencyContacts
                  .map(
                    (e) => {
                      'name': e['name'] as String,
                      'phone': e['phone'] as String,
                    },
                  )
                  .toList()
            : null,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        setState(() {
          _isOtpStep = true;
          _errorMessage = null;
        });

        // Extract OTP from response and send SMS
        String? otpForSMS;
        if (response.data is Map && response.data!['otp'] != null) {
          otpForSMS = response.data!['otp'].toString();
          print('📱 OTP received in response: $otpForSMS');
        }

        if (otpForSMS != null) {
          print('📱 Sending SMS via Android native SMS...');
          final smsSent = await SMSService.sendOTP(
            _phoneController.text,
            otpForSMS,
          );

          if (smsSent) {
            print('✅ SMS sent successfully');
          } else {
            print('⚠️  SMS sending failed - OTP will arrive via Socket.IO');
          }
        }

        // Start resend timer after OTP is sent
        _startResendTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! OTP sent to your phone.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to create account';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _occupationController.dispose();
    _ageController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 30;
      _canResendOTP = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
  /// Only shows error if something goes wrong
  Future<void> _resendOTPSilent() async {
    try {
      print('🔄 Silently resending OTP to ${_phoneController.text}...');

      // Send OTP request to backend
      final response = await AuthService.sendOTP(_phoneController.text);

      if (response.success) {
        print('✅ OTP resent successfully (silent mode)');
        // Start resend timer for next resend
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isOtpStep ? "Verify Phone" : "Create Account",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isOtpStep) ...[
                // --- STEP 1: DETAILS ---
                _buildSectionHeader("PERSONAL DETAILS"),
                const SizedBox(height: 16),
                _buildTextField(
                  _nameController,
                  "Full Name",
                  Icons.person_outline,
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _phoneController,
                  "Phone Number",
                  Icons.phone_android_outlined,
                  keyboard: TextInputType.phone,
                  maxLength: 10,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _emailController,
                  "Email Address",
                  Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _ageController,
                        "Age",
                        Icons.calendar_today,
                        keyboard: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        _occupationController,
                        "Occupation",
                        Icons.work_outline,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                _buildSectionHeader("EMERGENCY CONTACTS"),
                const SizedBox(height: 16),
                ..._emergencyContacts.asMap().entries.map(
                  (entry) => _buildContactCard(entry.key, theme, isDark),
                ),

                if (_emergencyContacts.length < 3)
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _emergencyContacts.add({
                        'name': TextEditingController(),
                        'phone': TextEditingController(),
                        'countryCode': 'IN',
                      }),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text("Add another contact"),
                  ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Resend OTP button
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _canResendOTP && !_isLoading ? _resendOTP : null,
                    child: Text(
                      _canResendOTP
                          ? 'Resend OTP'
                          : 'Resend OTP in ${_resendCountdown}s',
                      style: TextStyle(
                        color: _canResendOTP ? Colors.blue : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                _buildActionButton(
                  "Next",
                  _handleNextStep,
                  theme,
                  isLoading: _isLoading,
                ),
              ] else ...[
                // --- STEP 2: OTP ---
                const SizedBox(height: 40),
                Center(
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    "We've sent a 6-digit code to\n+91 ${_phoneController.text}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField(
                  _otpController,
                  "6-Digit OTP",
                  Icons.lock_clock_outlined,
                  keyboard: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _buildActionButton(
                  "Verify & Register",
                  _verifyOTP,
                  theme,
                  isLoading: _isLoading,
                ),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isOtpStep = false),
                    child: const Text("Edit Phone Number"),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
    TextAlign textAlign = TextAlign.start,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLength: maxLength,
      validator: validator,
      textAlign: textAlign,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF9146FF), size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF16161E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.verifyOTP(
        phone: _phoneController.text,
        otp: _otpController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (r) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Invalid OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  Widget _buildActionButton(
    String label,
    VoidCallback onPressed,
    ThemeData theme, {
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildContactCard(int index, ThemeData theme, bool isDark) {
    final contact = _emergencyContacts[index];
    final countries = PhoneFormatter.getAvailableCountries();
    final maxPhoneLength =
        PhoneFormatter
            .supportedCountries[contact['countryCode']]
            ?.numberLength ??
        10;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTextField(
            contact['name']!,
            "Contact Name",
            Icons.person_pin,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),

          // Country Selection
          DropdownButtonFormField<String>(
            initialValue: contact['countryCode'] ?? 'IN',
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.public),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: countries.map((country) {
              return DropdownMenuItem(
                value: country.countryCode,
                child: Text('${country.name} (${country.dialCode})'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  contact['countryCode'] = value;
                  contact['phone']?.clear();
                });
              }
            },
          ),
          const SizedBox(height: 8),

          _buildTextField(
            contact['phone']!,
            "Contact Phone",
            Icons.phone,
            keyboard: TextInputType.phone,
            maxLength: maxPhoneLength,
            validator: (v) => PhoneFormatter.validatePhoneNumber(
              v ?? '',
              contact['countryCode'] ?? 'IN',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
