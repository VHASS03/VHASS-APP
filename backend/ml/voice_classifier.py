"""
Voice Trigger Phrase Classifier
Uses a neural network to detect "help me out" with high accuracy
Trained using TensorFlow/Keras
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
from sklearn.feature_extraction.text import TfidfVectorizer
import pickle
import json
from pathlib import Path

class VoiceTriggerClassifier:
    def __init__(self, model_path: str = './models/voice_classifier.h5', vectorizer_path: str = './models/vectorizer.pkl'):
        """
        Initialize the voice trigger classifier
        
        Args:
            model_path: Path to the trained Keras model
            vectorizer_path: Path to the fitted TfidfVectorizer
        """
        self.model_path = model_path
        self.vectorizer_path = vectorizer_path
        self.model = None
        self.vectorizer = None
        self.is_trained = False
        
        # Try to load existing model
        self.load_model()
    
    def load_model(self):
        """Load pre-trained model and vectorizer"""
        try:
            if Path(self.model_path).exists() and Path(self.vectorizer_path).exists():
                self.model = keras.models.load_model(self.model_path)
                with open(self.vectorizer_path, 'rb') as f:
                    self.vectorizer = pickle.load(f)
                self.is_trained = True
                print(f"✅ Loaded pre-trained model from {self.model_path}")
                return True
        except Exception as e:
            print(f"⚠️ Could not load model: {e}")
        
        return False
    
    def train(self, training_samples: dict = None):
        """
        Train the classifier with trigger phrases and negative examples
        
        Args:
            training_samples: Dict with 'positive' and 'negative' keys containing text samples
        """
        if training_samples is None:
            # Default training data
            training_samples = {
                'positive': [
                    'help me out',
                    'help me out please',
                    'help me out now',
                    'help me out I need help',
                    'help me out urgent',
                    'help me out emergency',
                    'please help me out',
                    'help me',
                    'help',
                    'i need help',
                    'emergency help',
                    'emergency',
                    'sos',
                    'distress',
                    'in danger',
                    'need assistance',
                ],
                'negative': [
                    'hello',
                    'hi there',
                    'good morning',
                    'how are you',
                    'what time is it',
                    'tell me a joke',
                    'play music',
                    'stop',
                    'cancel',
                    'thank you',
                    'goodbye',
                    'see you later',
                    'call my friend',
                    'send message',
                    'weather today',
                    'what is my balance',
                ]
            }
        
        # Prepare data
        texts = training_samples['positive'] + training_samples['negative']
        labels = [1] * len(training_samples['positive']) + [0] * len(training_samples['negative'])
        
        # Vectorize text using TF-IDF
        self.vectorizer = TfidfVectorizer(
            max_features=100,
            lowercase=True,
            stop_words='english',
            ngram_range=(1, 2),
            min_df=1
        )
        
        X = self.vectorizer.fit_transform(texts).toarray()
        y = np.array(labels)
        
        # Build neural network model
        self.model = keras.Sequential([
            keras.layers.Dense(64, activation='relu', input_shape=(X.shape[1],)),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(32, activation='relu'),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(16, activation='relu'),
            keras.layers.Dense(1, activation='sigmoid')
        ])
        
        # Compile model
        self.model.compile(
            optimizer='adam',
            loss='binary_crossentropy',
            metrics=['accuracy']
        )
        
        # Train model
        print("🧠 Training voice trigger classifier...")
        history = self.model.fit(
            X, y,
            epochs=50,
            batch_size=4,
            validation_split=0.2,
            verbose=0
        )
        
        # Save model
        Path(self.model_path).parent.mkdir(parents=True, exist_ok=True)
        self.model.save(self.model_path)
        
        with open(self.vectorizer_path, 'wb') as f:
            pickle.dump(self.vectorizer, f)
        
        self.is_trained = True
        
        print(f"✅ Model trained! Final accuracy: {history.history['accuracy'][-1]:.2%}")
        print(f"✅ Saved model to {self.model_path}")
        
        return history
    
    def predict(self, text: str, threshold: float = 0.5) -> dict:
        """
        Predict if text contains trigger phrase
        
        Args:
            text: Input text to classify
            threshold: Confidence threshold (0-1). Default 0.5
        
        Returns:
            {
                'is_trigger': bool,
                'confidence': float,
                'text': str,
                'threshold': float
            }
        """
        if not self.is_trained or self.model is None or self.vectorizer is None:
            return {
                'is_trigger': False,
                'confidence': 0.0,
                'text': text,
                'error': 'Model not trained'
            }
        
        try:
            # Vectorize input text
            X = self.vectorizer.transform([text.lower()]).toarray()
            
            # Get prediction
            confidence = float(self.model.predict(X, verbose=0)[0][0])
            is_trigger = confidence >= threshold
            
            return {
                'is_trigger': is_trigger,
                'confidence': round(confidence, 4),
                'text': text,
                'threshold': threshold
            }
        except Exception as e:
            return {
                'is_trigger': False,
                'confidence': 0.0,
                'text': text,
                'error': str(e)
            }
    
    def get_model_info(self) -> dict:
        """Get information about the trained model"""
        if not self.is_trained:
            return {'status': 'not_trained'}
        
        return {
            'status': 'trained',
            'model_path': self.model_path,
            'vectorizer_path': self.vectorizer_path,
            'input_shape': self.model.input_shape,
            'layers': len(self.model.layers),
            'parameters': self.model.count_params()
        }


# Initialize global classifier instance
voice_classifier = VoiceTriggerClassifier()

# Train if not already trained
if not voice_classifier.is_trained:
    print("🚀 First run: Training voice trigger classifier...")
    voice_classifier.train()
