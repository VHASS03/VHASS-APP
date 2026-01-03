import 'package:flutter/material.dart';
import '../../core/colors.dart';
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

  final List<Map<String, TextEditingController>> _emergencyContacts = [
    {'name': TextEditingController(), 'phone': TextEditingController()}
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

  void _handleNextStep() {
    if (_formKey.currentState!.validate()) {
      // If valid, move to OTP step
      setState(() {
        _isOtpStep = true;
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
        title: Text(_isOtpStep ? "Verify Phone" : "Create Account", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
                _buildTextField(_nameController, "Full Name", Icons.person_outline, 
                  validator: (v) => v!.isEmpty ? 'Name is required' : null),
                const SizedBox(height: 16),
                _buildTextField(_phoneController, "Phone Number", Icons.phone_android_outlined, 
                  keyboard: TextInputType.phone, maxLength: 10, validator: _validatePhone),
                const SizedBox(height: 16),
                _buildTextField(_emailController, "Email Address", Icons.email_outlined, 
                  keyboard: TextInputType.emailAddress, validator: _validateEmail),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_ageController, "Age", Icons.calendar_today, 
                      keyboard: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(_occupationController, "Occupation", Icons.work_outline,
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ],
                ),

                const SizedBox(height: 32),
                _buildSectionHeader("EMERGENCY CONTACTS"),
                const SizedBox(height: 16),
                ..._emergencyContacts.asMap().entries.map((entry) => _buildContactCard(entry.key, theme, isDark)),
                
                if (_emergencyContacts.length < 3)
                  TextButton.icon(
                    onPressed: () => setState(() => _emergencyContacts.add({'name': TextEditingController(), 'phone': TextEditingController()})),
                    icon: const Icon(Icons.add),
                    label: const Text("Add another contact"),
                  ),

                const SizedBox(height: 32),
                _buildActionButton("Next", _handleNextStep, theme),
              ] else ...[
                // --- STEP 2: OTP ---
                const SizedBox(height: 40),
                Center(child: Icon(Icons.mark_email_read_outlined, size: 80, color: theme.colorScheme.primary)),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    "We've sent a 6-digit code to\n+91 ${_phoneController.text}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField(_otpController, "6-Digit OTP", Icons.lock_clock_outlined, 
                  keyboard: TextInputType.number, maxLength: 6, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                _buildActionButton("Verify & Register", () {
                  if (_otpController.text.length == 6) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (r) => false);
                  }
                }, theme),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isOtpStep = false),
                    child: const Text("Edit Phone Number"),
                  ),
                )
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, 
      {TextInputType keyboard = TextInputType.text, int? maxLength, String? Function(String?)? validator, TextAlign textAlign = TextAlign.start}) {
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildContactCard(int index, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Column(
        children: [
          _buildTextField(_emergencyContacts[index]['name']!, "Contact Name", Icons.person_pin, 
            validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 8),
          _buildTextField(_emergencyContacts[index]['phone']!, "Contact Phone", Icons.phone, 
            keyboard: TextInputType.phone, maxLength: 10, validator: _validatePhone),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2));
  }
}