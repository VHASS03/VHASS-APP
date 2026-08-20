import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/services/auth_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/services/otp_service.dart';
import '../../core/config/api_config.dart';
import '../../core/colors.dart';
import '../home/home.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _otpController = TextEditingController();

  // Selections
  String _selectedCourse = 'B.Tech';
  String _selectedDepartment = 'cse';
  String _selectedYear = '1st Year';
  String _selectedGender = 'Female';
  String _residenceType = 'Hosteller'; // 'Hosteller' or 'Day Scholar'
  String _guardianRelationship = 'Parent';

  // Additional optional emergency contact (if user wants >1)
  final List<Map<String, TextEditingController>> _additionalContacts = [];

  // Options lists
  final List<String> _courseOptions = [
    'B.Tech',
    'M.Tech',
    'B.Sc',
    'M.Sc',
    'BCA',
    'MCA',
    'BBA',
    'MBA',
    'B.Com',
    'MBBS',
    'PhD',
    'Other',
  ];

  final List<String> _departmentOptions = [
    'cse',
    'ece',
    'eee',
    'mech',
    'civil',
    'bba',
  ];

  final List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Post Graduate',
  ];

  final List<String> _genderOptions = ['Female', 'Male', 'Other'];
  final List<String> _relationshipOptions = [
    'Parent',
    'Sibling',
    'Guardian',
    'Relative',
    'Friend',
    'Other',
  ];

  bool _isOtpStep = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isResending = false;

  // OTP Timer
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResendOTP = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneController.text = widget.initialPhone!;
    }
    _initializeOTPListener();
  }

  void _initializeOTPListener() async {
    try {
      await OTPService.initializeOTPConnection(ApiConfig.socketUrl);

      OTPService.onOTPReceived((otp, phone, expiresIn) {
        if (!mounted) return;

        if (_isOtpStep && _phoneController.text == phone) {
          setState(() {
            _otpController.text = otp;
          });

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
              duration: const Duration(seconds: 8),
            ),
          );

          if (!_isResending) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _otpController.text.length == 6) {
                _verifyOTP();
              }
            });
          } else {
            setState(() {
              _isResending = false;
            });
          }
        }
      });
    } catch (e) {
      print('❌ OTP listener error: $e');
    }
  }

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
      await OTPService.registerForOTP(_phoneController.text);

      // Build emergency contacts payload (Guardian is primary contact 1)
      final List<Map<String, String>> emergencyContacts = [
        {
          'name': _guardianNameController.text.trim(),
          'phone': _guardianPhoneController.text.trim(),
        },
      ];

      // Add secondary contacts if added by user
      for (final c in _additionalContacts) {
        final name = c['name']?.text.trim() ?? '';
        final phone = c['phone']?.text.trim() ?? '';
        if (name.isNotEmpty && phone.isNotEmpty) {
          emergencyContacts.add({'name': name, 'phone': phone});
        }
      }

      final response = await AuthService.signup(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        admissionNumber: _admissionNumberController.text.trim(),
        email: _emailController.text.trim(),
        course: _selectedCourse,
        department: _selectedDepartment,
        year: _selectedYear,
        age: _ageController.text.trim(),
        gender: _selectedGender,
        residenceType: _residenceType,
        roomNumber: _residenceType == 'Hosteller' ? _roomNumberController.text.trim() : null,
        guardianName: _guardianNameController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
        emergencyRelationship: _guardianRelationship,
        emergencyContacts: emergencyContacts,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        setState(() {
          _isOtpStep = true;
          _errorMessage = null;
        });

        String? otpForSMS;
        bool smsSentFromServer = false;

        if (response.data is Map) {
          smsSentFromServer = response.data!['smsSent'] == true;
          if (response.data!['otp'] != null) {
            otpForSMS = response.data!['otp'].toString();
          }
        }

        if (!smsSentFromServer && otpForSMS != null) {
          await SMSService.sendOTP(_phoneController.text, otpForSMS);
        }

        _startResendTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Verification code sent.'),
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
    _admissionNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _roomNumberController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _otpController.dispose();
    for (final c in _additionalContacts) {
      c['name']?.dispose();
      c['phone']?.dispose();
    }
    OTPService.disconnect();
    super.dispose();
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
    try {
      setState(() {
        _isResending = true;
        _otpController.clear();
      });

      await OTPService.registerForOTP(_phoneController.text);
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
          await SMSService.sendOTP(_phoneController.text, otpForSMS);
        }

        _startResendTimer();
      }
    } catch (e) {
      print('❌ Resend OTP error: $e');
    }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (_isOtpStep) {
              setState(() => _isOtpStep = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isOtpStep ? "Verify OTP" : "Student Sign Up",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isOtpStep) ...[
                  // Header subtitle
                  Text(
                    "Please enter your student and emergency contact details below.",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- SECTION 1: STUDENT INFORMATION ---
                  _buildCardSection(
                    title: "STUDENT INFORMATION",
                    icon: Icons.school,
                    isDark: isDark,
                    children: [
                      _buildTextField(
                        _nameController,
                        "Full Name",
                        Icons.person_outline,
                        validator: (v) => v!.trim().isEmpty ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _admissionNumberController,
                        "Admission / Roll Number",
                        Icons.badge_outlined,
                        validator: (v) => v!.trim().isEmpty ? 'Admission number is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _phoneController,
                        "Phone Number (10 digits)",
                        Icons.phone_android_outlined,
                        keyboard: TextInputType.phone,
                        maxLength: 10,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _emailController,
                        "Email Address",
                        Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _ageController,
                        "Age",
                        Icons.cake_outlined,
                        keyboard: TextInputType.number,
                        validator: (v) => v!.trim().isEmpty ? 'Age is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        value: _selectedCourse,
                        items: _courseOptions,
                        label: "Course / Degree",
                        icon: Icons.menu_book_outlined,
                        onChanged: (val) => setState(() => _selectedCourse = val!),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        value: _selectedDepartment,
                        items: _departmentOptions,
                        label: "Department",
                        icon: Icons.business_outlined,
                        onChanged: (val) => setState(() => _selectedDepartment = val!),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        value: _selectedYear,
                        items: _yearOptions,
                        label: "Year of Study",
                        icon: Icons.calendar_today_outlined,
                        onChanged: (val) => setState(() => _selectedYear = val!),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Gender",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildSegmentedChips(
                        options: _genderOptions,
                        selected: _selectedGender,
                        onSelected: (val) => setState(() => _selectedGender = val),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // --- SECTION 2: RESIDENCE DETAILS ---
                  _buildCardSection(
                    title: "RESIDENCE DETAILS",
                    icon: Icons.home_work_outlined,
                    isDark: isDark,
                    children: [
                      _buildSegmentedChips(
                        options: ['Hosteller', 'Day Scholar'],
                        selected: _residenceType,
                        onSelected: (val) => setState(() => _residenceType = val),
                        isDark: isDark,
                      ),
                      if (_residenceType == 'Hosteller') ...[
                        const SizedBox(height: 14),
                        _buildTextField(
                          _roomNumberController,
                          "Hostel Room Number / Block",
                          Icons.meeting_room_outlined,
                          validator: (v) => _residenceType == 'Hosteller' && (v == null || v.trim().isEmpty)
                              ? 'Room number is required for hostellers'
                              : null,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 18),

                  // --- SECTION 3: GUARDIAN & EMERGENCY CONTACT ---
                  _buildCardSection(
                    title: "GUARDIAN & EMERGENCY CONTACT",
                    icon: Icons.contact_phone_outlined,
                    isDark: isDark,
                    children: [
                      _buildTextField(
                        _guardianNameController,
                        "Parent / Guardian Full Name",
                        Icons.family_restroom_outlined,
                        validator: (v) => v!.trim().isEmpty ? 'Guardian name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _guardianPhoneController,
                        "Parent / Guardian Phone (10 digits)",
                        Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        maxLength: 10,
                        validator: (v) => v == null || v.trim().length != 10
                            ? 'Enter valid 10-digit guardian phone'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        value: _guardianRelationship,
                        items: _relationshipOptions,
                        label: "Relationship to Student",
                        icon: Icons.people_outline,
                        onChanged: (val) => setState(() => _guardianRelationship = val!),
                      ),
                    ],
                  ),

                  // Additional emergency contacts if needed
                  if (_additionalContacts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ..._additionalContacts.asMap().entries.map(
                          (entry) => _buildAdditionalContactCard(entry.key, isDark),
                        ),
                  ],

                  if (_additionalContacts.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _additionalContacts.add({
                            'name': TextEditingController(),
                            'phone': TextEditingController(),
                          }),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("Add Secondary Emergency Contact"),
                      ),
                    ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  _buildActionButton(
                    "Register & Get OTP",
                    _handleNextStep,
                    theme,
                    isLoading: _isLoading,
                  ),
                ] else ...[
                  // --- STEP 2: OTP VERIFICATION ---
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      "Enter 6-Digit Verification Code",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Code sent to +91 ${_phoneController.text}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    _otpController,
                    "6-Digit Code",
                    Icons.lock_clock_outlined,
                    keyboard: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _canResendOTP && !_isLoading ? _resendOTP : null,
                      child: Text(
                        _canResendOTP
                            ? "Didn't receive code? Resend OTP"
                            : "Resend code in ${_resendCountdown}s",
                        style: TextStyle(
                          color: _canResendOTP ? AppColors.primary : Colors.grey,
                          fontSize: 13,
                          fontWeight: _canResendOTP ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _buildActionButton(
                    "Verify OTP & Launch App",
                    _verifyOTP,
                    theme,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _isOtpStep = false),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("Edit Registration Details"),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card Section Container for clean visual grouping
  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  /// Standard input text field with icon & clean styling
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
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.8), size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }

  /// Dropdown field with full width & clean icon
  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      dropdownColor: isDark ? AppColors.card : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.8), size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Segmented choice chips (Gender & Residence)
  Widget _buildSegmentedChips({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.map((opt) {
          final isSel = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdditionalContactCard(int index, bool isDark) {
    final contact = _additionalContacts[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Secondary Contact #${index + 2}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                onPressed: () => setState(() {
                  _additionalContacts.removeAt(index);
                }),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            contact['name']!,
            "Contact Name",
            Icons.person_pin_outlined,
          ),
          const SizedBox(height: 8),
          _buildTextField(
            contact['phone']!,
            "Phone Number (10 digits)",
            Icons.phone_outlined,
            keyboard: TextInputType.phone,
            maxLength: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    VoidCallback onPressed,
    ThemeData theme, {
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
