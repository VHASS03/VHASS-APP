#!/usr/bin/env python3
"""
Train the voice trigger phrase ML model

Usage:
    python train_model.py

This script trains a neural network to classify whether text contains "help me out" trigger phrase.
"""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from voice_classifier import VoiceTriggerClassifier

def main():
    print("=" * 60)
    print("Voice Trigger Phrase Classifier - Training Script")
    print("=" * 60)
    
    # Create classifier instance
    classifier = VoiceTriggerClassifier()
    
    # Custom training data (you can expand this)
    training_data = {
        'positive': [
            # Direct trigger phrases
            'help me out',
            'help me out please',
            'help me out now',
            'help me out urgent',
            'help me out emergency',
            'help me out I am in danger',
            'help me out I need help',
            'help me out quickly',
            'please help me out',
            'someone help me out',
            'help me',
            'help',
            'i need help',
            'help needed',
            'help me now',
            'help urgent',
            # Emergency-related phrases
            'emergency',
            'emergency help',
            'emergency assistance',
            'distress',
            'in distress',
            'in danger',
            'emergency services',
            'call help',
            'need emergency',
            'urgent help',
            'sos',
            'mayday',
            'need assistance urgently',
            'assist me',
            'help me please',
            'i need assistance',
        ],
        'negative': [
            # Greetings
            'hello',
            'hi',
            'hi there',
            'good morning',
            'good afternoon',
            'good evening',
            'hey',
            # Questions
            'how are you',
            'what time is it',
            'what is the weather',
            'who are you',
            'where am i',
            # Commands (non-emergency)
            'play music',
            'stop music',
            'pause',
            'resume',
            'next',
            'previous',
            'cancel',
            'close',
            'open app',
            # Requests (non-emergency)
            'call my friend',
            'send message',
            'send email',
            'open maps',
            'set alarm',
            'set reminder',
            'tell me a joke',
            'what is the news',
            # Polite phrases
            'thank you',
            'thank you so much',
            'thanks',
            'please',
            'okay',
            'sure',
            'fine',
            # Casual conversation
            'goodbye',
            'see you',
            'see you later',
            'bye bye',
            'have a good day',
            'take care',
            # Activity-related
            'turn on light',
            'turn off light',
            'set temperature',
            'lock door',
            'unlock door',
        ]
    }
    
    print("\n📊 Training Data:")
    print(f"  Positive samples (trigger): {len(training_data['positive'])}")
    print(f"  Negative samples (non-trigger): {len(training_data['negative'])}")
    
    # Train the model
    print("\n🧠 Starting training...")
    history = classifier.train(training_data)
    
    # Print results
    print("\n" + "=" * 60)
    print("Training Complete!")
    print("=" * 60)
    
    # Test the model
    print("\n🧪 Testing model on sample phrases:")
    
    test_samples = [
        ('help me out', True),
        ('help me out please', True),
        ('i need help', True),
        ('emergency', True),
        ('hello', False),
        ('how are you', False),
        ('play music', False),
    ]
    
    correct = 0
    for text, expected in test_samples:
        result = classifier.predict(text)
        is_trigger = result['is_trigger']
        confidence = result['confidence']
        
        status = "✅" if is_trigger == expected else "❌"
        print(f"  {status} '{text}' → {is_trigger} (conf: {confidence:.2%})")
        
        if is_trigger == expected:
            correct += 1
    
    accuracy = correct / len(test_samples)
    print(f"\n📈 Test Accuracy: {accuracy:.2%} ({correct}/{len(test_samples)})")
    
    # Print model info
    info = classifier.get_model_info()
    print("\n📋 Model Information:")
    print(f"  Status: {info['status']}")
    print(f"  Model Path: {info['model_path']}")
    print(f"  Layers: {info['layers']}")
    print(f"  Parameters: {info['parameters']:,}")
    print(f"  Input Shape: {info['input_shape']}")
    
    print("\n✅ Model trained and saved successfully!")
    print(f"   Location: {classifier.model_path}")

if __name__ == '__main__':
    main()
