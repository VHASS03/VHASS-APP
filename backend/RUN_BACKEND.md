# How to Run Backend

## Important Note
**The backend is a Node.js/TypeScript server that runs SEPARATELY from Android Studio.**
- Android Studio is for Flutter app development
- Backend runs as a standalone server
- Flutter app connects to backend via HTTP/Socket.IO

---

## Method 1: Using Android Studio Terminal

1. **Open Terminal in Android Studio:**
   - Click `View` → `Tool Windows` → `Terminal`
   - Or press `Alt + F12` (Windows/Linux) or `Option + F12` (Mac)

2. **Navigate to backend folder:**
   ```bash
   cd backend
   ```

3. **Install dependencies (first time only):**
   ```bash
   npm install
   ```

4. **Set up environment:**
   ```bash
   # Copy env.example to .env
   copy env.example .env    # Windows
   # OR
   cp env.example .env      # Mac/Linux
   ```
   
   Edit `.env` file with your configuration:
   ```env
   MONGODB_URI=mongodb://localhost:27017/vhass_db
   REDIS_HOST=localhost
   REDIS_PORT=6379
   JWT_SECRET=your_secret_key_here_min_32_chars
   ```

5. **Start MongoDB and Redis:**
   - **MongoDB**: Make sure MongoDB is running
   - **Redis**: Start Redis server
     ```bash
     # Windows (if installed)
     redis-server
     
     # Mac (if installed via Homebrew)
     brew services start redis
     
     # Linux
     sudo systemctl start redis
     ```

6. **Run the backend:**
   
   **Terminal 1 - API Server:**
   ```bash
   npm run dev
   ```
   
   **Terminal 2 - Escalation Worker (REQUIRED):**
   ```bash
   npm run worker
   ```

7. **Verify it's running:**
   - Open browser: `http://localhost:5000/api/health`
   - Should see: `{"status":"OK","message":"VHASS Backend API is running"}`

---

## Method 2: Using External Terminal/Command Prompt

1. **Open PowerShell (Windows) or Terminal (Mac/Linux)**

2. **Navigate to project:**
   ```bash
   cd "C:\Users\pramo\OneDrive\Documents\vhass app\VHASS-APP\backend"
   ```

3. **Follow steps 3-7 from Method 1**

---

## Method 3: Using VS Code (Recommended for Backend)

1. **Open VS Code**
2. **Open folder:** `VHASS-APP/backend`
3. **Open integrated terminal:** `Ctrl + ~` (Windows) or `Cmd + ~` (Mac)
4. **Run commands from Method 1**

---

## Running Both Backend and Flutter App

### Setup:

1. **Backend** (Terminal/Command Prompt):
   ```bash
   cd VHASS-APP/backend
   npm run dev          # Terminal 1
   npm run worker       # Terminal 2
   ```

2. **Flutter App** (Android Studio):
   - Open `VHASS-APP` folder in Android Studio
   - Run Flutter app on emulator/device
   - App connects to `http://localhost:5000/api` (or your backend URL)

---

## Connecting Flutter App to Backend

### Update Flutter App Base URL:

Create a config file in Flutter app:

```dart
// lib/config/api_config.dart
class ApiConfig {
  // For Android Emulator connecting to localhost
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  
  // For iOS Simulator
  // static const String baseUrl = 'http://localhost:5000/api';
  
  // For Physical Device (use your computer's IP)
  // static const String baseUrl = 'http://192.168.1.100:5000/api';
  
  // Socket.IO URL
  static const String socketUrl = 'http://10.0.2.2:5000';
}
```

### Find Your Computer's IP (for Physical Device):

**Windows:**
```bash
ipconfig
# Look for IPv4 Address (e.g., 192.168.1.100)
```

**Mac/Linux:**
```bash
ifconfig
# Look for inet address
```

---

## Troubleshooting

### Backend won't start:
- ✅ Check MongoDB is running: `mongod` or MongoDB service
- ✅ Check Redis is running: `redis-cli ping` (should return PONG)
- ✅ Check port 5000 is not in use
- ✅ Check `.env` file exists and has correct values

### Flutter can't connect to backend:
- ✅ Backend is running on port 5000
- ✅ Use `10.0.2.2` for Android emulator (not `localhost`)
- ✅ Use your computer's IP for physical device
- ✅ Check firewall allows port 5000
- ✅ Verify backend health: `http://localhost:5000/api/health`

### MongoDB connection error:
- ✅ MongoDB is running
- ✅ Connection string in `.env` is correct
- ✅ For MongoDB Atlas, whitelist your IP

### Redis connection error:
- ✅ Redis is running
- ✅ Check `REDIS_HOST` and `REDIS_PORT` in `.env`
- ✅ Test: `redis-cli ping`

---

## Quick Start Checklist

- [ ] Node.js installed (`node --version`)
- [ ] MongoDB installed and running
- [ ] Redis installed and running
- [ ] Backend dependencies installed (`npm install`)
- [ ] `.env` file created and configured
- [ ] API server running (`npm run dev`)
- [ ] Escalation worker running (`npm run worker`)
- [ ] Backend health check passes (`/api/health`)
- [ ] Flutter app configured with correct base URL

---

## Development Workflow

1. **Start Backend** (Terminal):
   ```bash
   npm run dev          # Auto-reloads on changes
   npm run worker       # Processes escalation jobs
   ```

2. **Start Flutter App** (Android Studio):
   - Click Run button or `Shift + F10`
   - App connects to backend automatically

3. **Test Connection:**
   - Flutter app calls `/api/auth/send-otp`
   - Backend logs appear in terminal
   - Check Android Studio Logcat for app logs

---

## Notes

- Backend runs on **port 5000** by default
- Flutter app runs on **emulator/device**
- They communicate via HTTP REST API and Socket.IO
- Backend must be running before Flutter app can connect
- Use `npm run dev` for development (auto-reload)
- Use `npm start` for production (after `npm run build`)

