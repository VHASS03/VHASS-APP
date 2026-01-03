import 'package:flutter/material.dart';
// Import your auth screen once you've created the file
import 'auth/login_screen.dart'; 

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(), // Pushes content to the middle
              
              // Logo and Branding
              const Icon(Icons.shield, size: 80, color: Color(0xFF6A1B9A)),
              const SizedBox(height: 24),
              const Text(
                'VHASS',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Instant help. Even when you can’t speak.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              
              const Spacer(), // Pushes button to the bottom

              // Get Started Button
              SizedBox(
                width: double.infinity, // Full width button
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Login Screen
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (context) => const LoginScreen()),
                     );
                    print("Navigate to Login");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}