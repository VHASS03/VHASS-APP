import 'package:flutter/material.dart';
import '../../core/colors.dart';

class QrVerificationScreen extends StatefulWidget {
  const QrVerificationScreen({super.key});

  @override
  State<QrVerificationScreen> createState() => _QrVerificationScreenState();
}

class _QrVerificationScreenState extends State<QrVerificationScreen> {
  bool _showMyQr = true;
  String _scanResult = "";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("QR Verification System"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Select
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("My Campus QR Pass")),
                      selected: _showMyQr,
                      onSelected: (selected) {
                        setState(() => _showMyQr = true);
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Guard Code Scanner")),
                      selected: !_showMyQr,
                      onSelected: (selected) {
                        setState(() => _showMyQr = false);
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: _showMyQr ? _buildMyQrView() : _buildScannerView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyQrView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const Text(
                  "CAMPUS ID PASS",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Simulated QR code
                Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 20,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: 400,
                    itemBuilder: (context, index) {
                      // Generate pseudo-random QR pattern
                      final isActive = (index * 7 + 13) % 5 == 0 || (index * 3) % 4 == 0 || index < 40 || index > 360 || index % 20 < 3 || index % 20 > 17;
                      return Container(
                        color: isActive ? Colors.black : Colors.white,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Jane Doe",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Text(
                  "Student ID: 2026-CS-8921",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    const Text("ACTIVE PASS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Show this QR code at campus gates or security checkpoints for digital verification.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.camera_alt, color: Colors.white38, size: 48),
                // Scanner laser line simulator
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 200),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Positioned(
                      top: 20 + value,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          boxShadow: [
                            BoxShadow(color: Colors.redAccent, blurRadius: 4, spreadRadius: 1),
                          ],
                        ),
                      ),
                    );
                  },
                  onEnd: () {},
                ),
                Positioned(
                  bottom: 12,
                  child: Text(
                    "Aim camera at visitor/student pass QR code",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Trigger simulated scans
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _simulateScan("Student: Jane Doe\nID: 2026-CS-8921\nStatus: APPROVED ✅"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("Scan Student"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _simulateScan("Visitor: Bruce Wayne\nPurpose: Seminar Speaker\nStatus: REGISTERED ✅"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text("Scan Visitor"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_scanResult.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scan Results", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(_scanResult, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.4)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _simulateScan(String result) {
    setState(() {
      _scanResult = result;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("QR Code Scanned successfully"), backgroundColor: Colors.green),
    );
  }
}
