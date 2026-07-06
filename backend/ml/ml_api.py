#!/usr/bin/env python3
"""
Flask API for ML Voice Classifier
Provides a simple HTTP endpoint to use the trained ML model
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import sys
from pathlib import Path
import json

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from voice_classifier import voice_classifier

app = Flask(__name__)
CORS(app)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_trained': voice_classifier.is_trained,
        'model_info': voice_classifier.get_model_info()
    }), 200

@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict if text contains trigger phrase
    
    Request body:
    {
        "text": "help me out",
        "threshold": 0.5  (optional, default 0.5)
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'text' not in data:
            return jsonify({
                'success': False,
                'message': 'Missing required field: text'
            }), 400
        
        text = data['text']
        threshold = data.get('threshold', 0.5)
        
        # Make prediction
        result = voice_classifier.predict(text, threshold)
        
        return jsonify({
            'success': True,
            'data': result
        }), 200
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

@app.route('/train', methods=['POST'])
def train():
    """
    Train the model with custom data
    
    Request body:
    {
        "positive": ["help me out", "emergency"],
        "negative": ["hello", "goodbye"]
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'positive' not in data or 'negative' not in data:
            return jsonify({
                'success': False,
                'message': 'Missing required fields: positive, negative'
            }), 400
        
        training_data = {
            'positive': data['positive'],
            'negative': data['negative']
        }
        
        # Train model
        voice_classifier.train(training_data)
        
        return jsonify({
            'success': True,
            'message': 'Model trained successfully',
            'model_info': voice_classifier.get_model_info()
        }), 200
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

if __name__ == '__main__':
    print("🚀 Starting ML Voice Classifier API on port 5001...")
    print("   Health Check: http://localhost:5001/health")
    print("   Predict Endpoint: POST http://localhost:5001/predict")
    print("   Train Endpoint: POST http://localhost:5001/train")
    
    app.run(host='localhost', port=5001, debug=False)
