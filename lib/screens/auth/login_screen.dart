import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../home/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isOtpSent = false;

  // Logic to check if the button should be enabled
  bool _isButtonEnabled() {
    if (!_isOtpSent) {
      // Check if phone number is exactly 10 digits
      return _phoneController.text.length == 10;
    } else {
      // Check if OTP is exactly 6 digits
      return _otpController.text.length == 6;
    }
  }

  @override
  void initState() {
    super.initState();
    // Add listeners to rebuild the UI as the user types
    _phoneController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
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
              height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isOtpSent ? 'Verify OTP' : 'Welcome to VHASS',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtpSent ? 'Enter the 6-digit code sent to your phone' : 'Your safety companion',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 48),

                  if (!_isOtpSent) ...[
                    _buildInputLabel('Phone Number'),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneController, 'Enter 10-digit number', Icons.phone_outlined, maxLength: 10),
                  ] else ...[
                    _buildInputLabel('One-Time Password'),
                    const SizedBox(height: 12),
                    _buildTextField(_otpController, 'Enter 6-digit OTP', Icons.lock_outline, maxLength: 6),
                  ],

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isOtpSent ? "Didn't receive code? Resend" : "We'll send you a one-time password",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // MAIN ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      // BUTTON LOGIC: If conditions aren't met, onPressed is null (disabled)
                      onPressed: _isButtonEnabled() 
                        ? () {
                            if (!_isOtpSent) {
                              setState(() => _isOtpSent = true);
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                              );
                            }
                          }
                        : null, 
                      style: ElevatedButton.styleFrom(
                        // Use a lighter color when disabled for better UX
                        backgroundColor: const Color(0xFF3B125C),
                        disabledBackgroundColor: const Color(0xFF3B125C).withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _isOtpSent ? 'Verify & Login' : 'Send OTP',
                        style: TextStyle(
                          fontSize: 18, 
                          color: _isButtonEnabled() ? Colors.white : Colors.white38, 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ),

                  if (!_isOtpSent) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () { /* Navigate to Sign Up */ },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: "Sign Up",
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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

  Widget _buildInputLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int? maxLength}) {
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
        fillColor: const Color(0xFF1A1A22),
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