import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geolocator/geolocator.dart';
import '../../core/colors.dart';
import '../../core/services/voice_service.dart';

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _recognizedText = '';
  String _statusMessage = '';
  bool _isProcessing = false;

  // Example trigger phrases
  final List<String> _triggerPhrases = ['help me out', 'help me'];

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          setState(() {
            _statusMessage = 'Error: ${error.errorMsg}';
            _isListening = false;
          });
        },
        onStatus: (status) {
          print('Speech status: $status');
        },
      );

      if (available) {
        setState(() {
          _statusMessage = 'Ready to listen. Say "help me out" to trigger SOS';
        });
      } else {
        setState(() {
          _statusMessage = 'Speech recognition not available';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize speech: $e';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_speechToText.isAvailable) {
      setState(() {
        _statusMessage = 'Speech recognition not available';
      });
      return;
    }

    if (_speechToText.isListening) {
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusMessage = 'Listening... Say "help me out"';
    });

    try {
      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
              _statusMessage = 'Processing...';
              _processVoiceInput(_recognizedText);
            }
          });
        },
        localeId: 'en_IN', // Indian English
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting listening: $e';
        _isListening = false;
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_speechToText.isListening) {
      return;
    }

    await _speechToText.stop();

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _processVoiceInput(String text) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Checking for trigger phrase...';
    });

    try {
      // Check if any trigger phrase is detected
      final isTrigger = _triggerPhrases.any(
        (phrase) => text.toLowerCase().contains(phrase),
      );

      if (!isTrigger) {
        setState(() {
          _statusMessage =
              'Trigger phrase not detected. You said: "$text". Please say "help me out"';
          _isProcessing = false;
        });
        return;
      }

      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
      } catch (e) {
        print('Location error: $e');
      }

      setState(() {
        _statusMessage = 'Sending voice trigger to backend...';
      });

      // Send to backend
      final response = await VoiceService.triggerVoice(
        text: text,
        latitude: position?.latitude,
        longitude: position?.longitude,
        confidence: 0.95,
      );

      setState(() {
        if (response.success) {
          _statusMessage =
              '✅ SOS Activated! Emergency contacts are being notified.';
          _showSosConfirmation(response.data?['sosId'] ?? 'Unknown');
        } else {
          _statusMessage = '❌ ${response.message}';
        }
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error processing voice input: $e';
        _isProcessing = false;
      });
    }
  }

  void _showSosConfirmation(String sosId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 SOS Activated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your SOS has been triggered!'),
            const SizedBox(height: 12),
            Text('SOS ID: $sosId'),
            const SizedBox(height: 12),
            const Text(
              'Emergency contacts are being notified with your location.',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionally show more details or allow cancellation
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice Commands'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Microphone icon and status
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.1),
                    border: Border.all(
                      color: _isListening ? Colors.red : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 60,
                    color: _isListening ? Colors.red : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 30),

                // Status message
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Recognized text
                if (_recognizedText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You said:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recognizedText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),

                // Trigger phrases info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Trigger Phrases:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._triggerPhrases.map(
                        (phrase) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text('"$phrase"'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Main button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : (_isListening ? _stopListening : _startListening),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening
                          ? Colors.red
                          : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isListening
                          ? 'Stop Listening'
                          : _isProcessing
                          ? 'Processing...'
                          : 'Start Listening',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }
}
