import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

/// Service for continuous voice monitoring that listens for "help me out" phrase
/// and can trigger SOS automatically
class ContinuousVoiceService {
  static final ContinuousVoiceService _instance =
      ContinuousVoiceService._internal();
  factory ContinuousVoiceService() => _instance;
  ContinuousVoiceService._internal();

  stt.SpeechToText? _speechToText;
  bool _isListening = false;
  bool _isInitialized = false;

  // Callback when "help me out" is detected
  Function()? onTriggerDetected;

  // Trigger phrases to detect
  final List<String> _triggerPhrases = [
    'help me out',
    'help me',
    'emergency',
    'sos',
  ];

  /// Initialize the speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _speechToText = stt.SpeechToText();
      final available = await _speechToText!.initialize(
        onError: (error) {
          debugPrint('❌ Voice monitoring error: ${error.errorMsg}');
          // Automatically restart listening on error
          Future.delayed(const Duration(seconds: 2), () {
            if (_isListening) {
              _startListeningInternal();
            }
          });
        },
        onStatus: (status) {
          debugPrint('🎤 Voice status: $status');
          // Restart listening when it stops
          if (status == 'done' && _isListening) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isListening) {
                _startListeningInternal();
              }
            });
          }
        },
      );

      _isInitialized = available;
      debugPrint(
        _isInitialized
            ? '✅ Voice monitoring initialized'
            : '❌ Voice monitoring unavailable',
      );

      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Failed to initialize voice monitoring: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start continuous listening for trigger phrases
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) {
      debugPrint('⚠️ Already listening');
      return true;
    }

    _isListening = true;
    return await _startListeningInternal();
  }

  /// Internal method to start speech recognition
  Future<bool> _startListeningInternal() async {
    if (_speechToText == null || !_isInitialized) return false;

    try {
      await _speechToText!.listen(
        onResult: (result) {
          if (result.finalResult) {
            final text = result.recognizedWords.toLowerCase();
            debugPrint('🎤 Heard: "$text"');

            // Check for trigger phrases
            for (final phrase in _triggerPhrases) {
              if (text.contains(phrase)) {
                debugPrint('🚨 TRIGGER DETECTED: "$phrase" in "$text"');
                _handleTriggerDetected(phrase, text);
                break;
              }
            }
          }
        },
        listenFor: const Duration(
          seconds: 30,
        ), // Listen for 30 seconds at a time
        pauseFor: const Duration(
          seconds: 5,
        ), // Pause for 5 seconds between words
        partialResults: false, // Only process final results
        localeId: 'en_IN', // Indian English
        listenMode: stt.ListenMode.dictation, // Continuous dictation mode
      );

      debugPrint('🎤 Listening started...');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to start listening: $e');
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;

    if (_speechToText != null) {
      await _speechToText!.stop();
      debugPrint('🛑 Listening stopped');
    }
  }

  /// Handle when trigger phrase is detected
  void _handleTriggerDetected(String phrase, String fullText) {
    // Call the callback if set
    if (onTriggerDetected != null) {
      onTriggerDetected!();
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  Future<void> dispose() async {
    await stopListening();
    _speechToText = null;
    _isInitialized = false;
    onTriggerDetected = null;
  }
}
