FROM python:3.10-slim

# Install system dependencies for audio reading (libsndfile1, ffmpeg)
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

EXPOSE 5002

# Start uvicorn server
CMD ["python", "emotion_api.py"]
