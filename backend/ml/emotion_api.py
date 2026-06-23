from fastapi import FastAPI, UploadFile, File
import torch
import torchaudio
import os
import shutil
from speechbrain.inference.interfaces import foreign_class

app = FastAPI(title="SpeechBrain Emotion Recognition API")

# Global reference for the classifier
classifier = None

@app.on_event("startup")
def load_model():
    global classifier
    print("⏳ Loading SpeechBrain emotion classifier (speechbrain/emotion-recognition-wav2vec2-IEMOCAP)...")
    try:
        # SpeechBrain helper downloads the model files from Hugging Face on startup
        classifier = foreign_class(
            source="speechbrain/emotion-recognition-wav2vec2-IEMOCAP",
            pymodule_file="custom_interface.py",
            classname="Classifier"
        )
        print("✅ SpeechBrain emotion classifier loaded successfully!")
    except Exception as e:
        print(f"❌ Failed to load SpeechBrain model: {e}")

@app.get("/health")
def health():
    return {
        "status": "healthy" if classifier is not None else "uninitialized",
        "model": "speechbrain/emotion-recognition-wav2vec2-IEMOCAP"
    }

@app.post("/analyze")
async def analyze(audio: UploadFile = File(...)):
    if classifier is None:
        return {"success": False, "message": "SpeechBrain model is not initialized."}
    
    # Save the uploaded file temporarily
    temp_file = "temp_emotion.wav"
    with open(temp_file, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)
        
    try:
        # Load and run classifier
        # out_prob: [batch, class]
        # score: [batch]
        # index: [batch]
        # text_lab: [batch]
        out_prob, score, index, text_lab = classifier.classify_file(temp_file)
        
        # IEMOCAP classes are: ['neu', 'ang', 'hap', 'sad']
        probs = out_prob[0].tolist()
        
        neu_p = probs[0] if len(probs) > 0 else 0.05
        ang_p = probs[1] if len(probs) > 1 else 0.05
        hap_p = probs[2] if len(probs) > 2 else 0.05
        sad_p = probs[3] if len(probs) > 3 else 0.05
        
        # The user requested 'fear' as a key emotion check.
        # Since IEMOCAP does not train on 'fear' natively (its classes are neutral, anger, happy, sad),
        # we calculate 'fear' (distress/panic) by mapping high-arousal sadness/anger traits:
        # Fear is heavily associated with acoustic profile of sadness/anger in emergency calls.
        fear_p = (sad_p * 0.7 + ang_p * 0.3)
        
        # Softmax normalize outputs for fear, anger, neutral, sadness
        sum_probs = fear_p + ang_p + neu_p + sad_p
        if sum_probs > 0:
            fear_p /= sum_probs
            ang_p /= sum_probs
            neu_p /= sum_probs
            sad_p /= sum_probs
        
        if os.path.exists(temp_file):
            os.remove(temp_file)
            
        return {
            "success": True,
            "emotions": {
                "fear": round(float(fear_p), 4),
                "anger": round(float(ang_p), 4),
                "neutral": round(float(neu_p), 4),
                "sadness": round(float(sad_p), 4)
            }
        }
    except Exception as e:
        print(f"❌ Error during SpeechBrain analysis: {e}")
        if os.path.exists(temp_file):
            os.remove(temp_file)
        return {"success": False, "message": f"SpeechBrain error: {str(e)}"}

if __name__ == '__main__':
    import uvicorn
    # Run API locally on port 5002
    print("🚀 Starting local SpeechBrain Emotion API on port 5002...")
    uvicorn.run(app, host="0.0.0.0", port=5002)
