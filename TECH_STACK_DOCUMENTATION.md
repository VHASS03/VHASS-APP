# VHASS App - Complete Tech Stack Documentation

## 📱 Overview
VHASS (Voice-activated Health and Safety System) is a comprehensive emergency response and wellness tracking application built with Flutter and Node.js/TypeScript backend.

---

## 🎯 Tech Stack Summary

### **Frontend**
- Flutter 3.9.2+
- Dart SDK ^3.9.2

### **Backend**
- Node.js 18+
- TypeScript 5.3.3
- Express.js 4.18.2

### **Databases**
- MongoDB 8.0.3 (with Mongoose ODM)
- Redis 4.6.12 / IORedis 5.3.2

### **AI Services** (Chatbot Only)
- Google Gemini API (Generative AI)
- Groq SDK (Alternative AI provider)

### **Real-time Communication**
- Socket.IO 4.6.1 (WebSocket)

### **Job Queue**
- BullMQ 5.3.0 (Redis-based queue)

---

## 📦 Frontend - Flutter Application

### **Core Framework**
- **Flutter**: Cross-platform mobile development framework
- **Dart**: Programming language for Flutter
- **SDK Version**: ^3.9.2

### **State Management & Architecture**
- Service-oriented architecture with dedicated services for each feature
- Local storage for offline-first capabilities
- Real-time data synchronization

### **Key Flutter Packages**

#### **1. HTTP & Networking**
```yaml
http: ^1.1.0                    # REST API communication
socket_io_client: ^2.0.3+1      # Real-time bidirectional communication
```
**Usage:**
- HTTP for CRUD operations with backend API
- Socket.IO for real-time SOS status updates, location tracking, and chat

#### **2. Local Storage & Persistence**
```yaml
shared_preferences: ^2.2.2      # Key-value storage for tokens, settings
```
**Usage:**
- JWT token storage for authentication
- User preferences and settings
- Offline data caching

#### **3. Location Services**
```yaml
geolocator: ^11.0.0            # GPS location tracking
permission_handler: ^11.1.0     # Runtime permissions management
```
**Usage:**
- Real-time location tracking during SOS
- Location-based emergency alerts
- Distance calculations for emergency contacts
- Permission management (location, phone, notifications)

#### **4. Maps Integration**
```yaml
google_maps_flutter: ^2.8.0    # Google Maps SDK
```
**Usage:**
- Display user location on map
- Show emergency contact locations
- Real-time location updates visualization

#### **5. Voice & Speech**
```yaml
speech_to_text: ^7.3.0         # Voice recognition
```
**Usage:**
- Voice monitoring for trigger phrases
- Voice-activated SOS ("help me out")
- Voice commands for emergency activation
- Accessibility features

#### **6. Device Integration**
```yaml
url_launcher: ^6.2.2           # Launch phone calls, SMS, URLs
device_info_plus: ^9.1.1       # Device information
battery_plus: ^6.1.0           # Battery status monitoring
```
**Usage:**
- Direct phone calls to emergency contacts
- SMS sending for non-app users
- Device identification for pairing
- Battery level tracking during emergencies

#### **7. Notifications**
```yaml
flutter_local_notifications: ^17.2.3    # Local push notifications
android_alarm_manager_plus: ^4.0.0      # Background tasks
```
**Usage:**
- High-priority SOS alert notifications
- Silent mode bypass for emergencies
- Background task scheduling
- Custom notification sounds

#### **8. Security**
```yaml
local_auth: ^2.1.8             # Biometric authentication
```
**Usage:**
- Fingerprint/Face ID for emergency cancellation
- Secure app access
- Biometric verification for sensitive operations

#### **9. Utilities**
```yaml
intl: ^0.18.1                  # Internationalization
cupertino_icons: ^1.0.8        # iOS-style icons
```
**Usage:**
- Date/time formatting
- Number formatting for phone numbers
- Multi-language support preparation

---

## 🖥️ Backend - Node.js/TypeScript API

### **Core Technologies**

#### **1. Runtime & Language**
- **Node.js 18+**: JavaScript runtime
- **TypeScript 5.3.3**: Type-safe JavaScript
- **ts-node-dev**: Development server with hot reload

#### **2. Web Framework**
```json
"express": "^4.18.2"           # REST API framework
"cors": "^2.8.5"               # Cross-Origin Resource Sharing
"express-validator": "^7.0.1"  # Request validation
```
**Usage:**
- RESTful API endpoints
- Middleware for authentication, validation
- Request/response handling
- CORS configuration for Flutter app

#### **3. Database & ODM**

##### **MongoDB**
```json
"mongoose": "^8.0.3"           # MongoDB object modeling
```
**Usage:**
- User profiles and authentication data
- Emergency contacts storage
- SOS history and logs (append-only)
- Device pairing records
- Chat message history
- Wellness data persistence

**Collections:**
- `users`: User accounts, phone numbers, device IDs
- `contacts`: Emergency contacts with priority levels
- `sos`: SOS incident records and timelines
- `devices`: Paired BLE/IoT devices
- `chats`: Conversation history with AI chatbot
- `wellness`: Health tracking data

##### **Redis**
```json
"redis": "^4.6.12"             # Redis client
"ioredis": "^5.3.2"            # Alternative Redis client
```
**Usage:**
- OTP storage (10-minute TTL)
- Active SOS state caching
- Real-time location updates
- Session management
- Rate limiting
- BullMQ job queue backend

#### **4. Real-time Communication**
```json
"socket.io": "^4.6.1"          # WebSocket server
```
**Usage:**
- Real-time SOS status broadcasts
- Live location tracking
- Chat message streaming
- Multi-device synchronization

**Events:**
- `location:update` - GPS coordinates broadcast
- `sos:status` - Emergency status updates
- `chat:message` - Real-time chat messages

#### **5. Job Queue & Background Processing**
```json
"bullmq": "^5.3.0"             # Redis-based job queue
```
**Usage:**
- SOS escalation automation
- Priority-based contact calling sequence
- Retry logic for failed operations
- Background task scheduling
- Job persistence (survives restarts)

**Worker:** `escalationWorker.ts`
- Processes SOS escalation jobs
- Handles contact notification sequence
- Manages retry attempts
- Updates SOS status

#### **6. Authentication & Security**
```json
"jsonwebtoken": "^9.0.2"       # JWT token generation
"bcryptjs": "^2.4.3"           # Password hashing
```
**Usage:**
- Phone-based authentication (OTP)
- JWT token generation and validation
- Secure session management
- Password hashing (future feature)

#### **7. AI Integration (Chatbot Only)**

##### **Google Gemini**
```json
"@google/generative-ai": "^0.24.1"
```
**Usage:**
- Real-time chatbot conversations
- Context-aware health/wellness advice
- Safety tips and emergency guidance
- Conversation history management
- Streaming responses
- Content safety filtering

**Model:** `gemini-pro`
**Features:**
- Multi-turn conversations
- Fast response times
- Safety settings enabled
- System instructions for VHASS context

##### **Groq SDK**
```json
"groq-sdk": "^0.3.0"
```
**Usage:**
- Alternative AI provider option for chatbot
- Fast inference capabilities
- Backup for Gemini API

#### **8. HTTP Client**
```json
"axios": "^1.13.2"             # HTTP client
```
**Usage:**
- External API calls
- Third-party integrations

---

## 🗄️ Database Architecture

### **MongoDB Collections**

#### **users**
```javascript
{
  _id: ObjectId,
  phoneNumber: String (unique, indexed),
  name: String,
  deviceId: String,
  emergencyContacts: [ObjectId],  // References to contacts
  createdAt: Date,
  lastLogin: Date
}
```

#### **contacts**
```javascript
{
  _id: ObjectId,
  userId: ObjectId,  // Reference to user
  name: String,
  phoneNumber: String,
  priority: Number (1-3),  // 1 = highest
  relationship: String,
  hasApp: Boolean,
  createdAt: Date
}
```

#### **sos**
```javascript
{
  _id: ObjectId,
  userId: ObjectId,
  status: String,  // 'active', 'resolved', 'cancelled'
  location: {
    latitude: Number,
    longitude: Number,
    timestamp: Date
  },
  timeline: [{
    timestamp: Date,
    action: String,  // 'CALL', 'SMS', 'LOCATION_UPDATE'
    contactId: ObjectId,
    result: String,
    details: Object
  }],
  startTime: Date,
  endTime: Date,
  resolvedBy: String
}
```

### **Redis Key Patterns**

```
otp:{phoneNumber}              # OTP codes (TTL: 10 min)
sos:active:{userId}            # Active SOS state
location:{sosId}               # Real-time location cache
session:{token}                # JWT session data
rate:{phoneNumber}             # Rate limiting
```

---

## 🔄 Real-time Architecture

### **Socket.IO Implementation**

#### **Client → Server Events**
1. **Connection**
   ```javascript
   socket.emit('authenticate', { token: JWT_TOKEN });
   ```

2. **Location Updates**
   ```javascript
   socket.emit('location:update', {
     sosId: String,
     latitude: Number,
     longitude: Number,
     accuracy: Number
   });
   ```

3. **SOS Status Request**
   ```javascript
   socket.emit('sos:status:request', { sosId: String });
   ```

#### **Server → Client Events**
1. **SOS Status Broadcast**
   ```javascript
   socket.emit('sos:status', {
     sosId: String,
     status: String,
     currentContact: Object,
     timeline: Array
   });
   ```

2. **Location Broadcast**
   ```javascript
   socket.emit('location:update', {
     sosId: String,
     location: Object,
     timestamp: Date
   });
   ```

3. **Chat Messages**
   ```javascript
   socket.emit('chat:message', {
     message: String,
     sender: 'user' | 'bot',
     timestamp: Date
   });
   ```

---

## 🔐 Authentication Flow

### **Phone-based OTP Authentication**

1. **Request OTP**
   ```
   POST /api/auth/send-otp
   Body: { phoneNumber: "+919876543210" }
   ```
   - Generates 6-digit OTP
   - Stores in Redis with 10-minute TTL
   - Returns success (no SMS sent - manual entry)

2. **Verify OTP**
   ```
   POST /api/auth/verify-otp
   Body: { phoneNumber: "+919876543210", otp: "123456" }
   ```
   - Validates OTP from Redis
   - Creates/updates user in MongoDB
   - Generates JWT token
   - Returns token + user profile

3. **Authenticated Requests**
   ```
   Header: Authorization: Bearer <JWT_TOKEN>
   ```
   - JWT middleware validates token
   - Extracts userId from token payload
   - Attaches user to request object

---

## 📡 API Endpoints Overview

### **Authentication**
- `POST /api/auth/send-otp` - Generate OTP
- `POST /api/auth/verify-otp` - Validate OTP and login

### **SOS Management**
- `POST /api/sos/trigger` - Activate emergency
- `POST /api/sos/update-location` - Send GPS coordinates
- `POST /api/sos/report-call-result` - Report call/SMS status
- `POST /api/sos/end` - Deactivate emergency
- `GET /api/sos/status/:sosId` - Get current status

### **Emergency Contacts**
- `GET /api/contacts` - List all contacts
- `POST /api/contacts` - Add contact (max 3)
- `PUT /api/contacts/:id` - Update contact
- `DELETE /api/contacts/:id` - Remove contact

### **Device Management**
- `POST /api/device/pair` - Pair BLE/IoT device
- `POST /api/device/validate-trigger` - Validate trigger source
- `GET /api/device/list` - List paired devices

### **AI Chatbot**
- `POST /api/chat/message` - Send message, get AI response
- Uses Google Gemini API for context-aware replies

### **Voice Trigger**
- `POST /api/voice/trigger` - Detect "help me out" phrase
- Uses pattern matching (simple string contains check)

---

## 🎨 Key Features & Technologies Used

### **1. SOS Alert System**
**Technologies:**
- Flutter: UI, location services, phone/SMS integration
- Node.js: SOS lifecycle management, escalation logic
- BullMQ: Priority-based contact queue
- Socket.IO: Real-time status updates
- Redis: Active SOS state caching
- MongoDB: SOS history and logs

**Flow:**
1. User triggers SOS (button or voice)
2. Backend creates SOS record
3. Location captured via Geolocator
4. BullMQ queues contact notifications
5. Worker processes calls/SMS in priority order
6. Real-time updates via Socket.IO
7. Complete timeline logged to MongoDB

### **2. Voice-Activated Emergency**
**Technologies:**
- Flutter speech_to_text: Device speech recognition
- Node.js: Pattern matching for trigger detection

**Flow:**
1. User activates voice listening
2. Speech-to-text conversion on device
3. Text sent to backend for pattern matching
4. If "help me out" detected, auto-activate SOS
5. Emergency contacts notified

**Detection Method:**
```typescript
// Simple pattern matching - no ML
const triggered = ['help me out', 'help me'].some(
  phrase => text.toLowerCase().includes(phrase)
);
```

### **3. AI Health Chatbot**
**Technologies:**
- Google Gemini API: Generative AI
- Groq SDK: Alternative AI provider
- Socket.IO: Streaming responses
- MongoDB: Conversation history
- Flutter: Chat UI

**Features:**
- Context-aware conversations
- Health/wellness guidance
- Safety tips
- Emergency protocol advice
- Multi-turn dialogue support

### **4. Real-time Location Tracking**
**Technologies:**
- Flutter Geolocator: GPS coordinates
- Socket.IO: Live location streaming
- Redis: Location caching
- Google Maps: Visualization

**Usage:**
- Continuous tracking during SOS
- Shared with emergency contacts
- Historical location trail
- Accuracy reporting

### **5. Smart Contact Management**
**Technologies:**
- MongoDB: Contact storage
- Priority-based queuing
- App/non-app user detection
- Relationship tracking

**Logic:**
- Max 3 emergency contacts
- Priority 1-3 (1 = highest)
- Auto-escalation if no response
- Parallel SMS for non-app users

### **6. Notification System**
**Technologies:**
- flutter_local_notifications: Local notifications
- Android Alarm Manager: Background scheduling
- Custom notification channels
- Silent mode bypass

**Features:**
- High-priority alerts
- Custom sounds
- Full-screen intent for critical alerts
- Works in Do Not Disturb mode

### **7. Device Pairing (IoT Integration)**
**Technologies:**
- BLE (Bluetooth Low Energy) support
- Device validation API
- Unique device ID tracking
- MongoDB device registry

**Use Cases:**
- Wearable emergency buttons
- Smart home triggers
- IoT safety devices

### **8. Wellness Data Tracking**
**Technologies:**
- MongoDB: Data persistence
- Battery monitoring: battery_plus
- Device health tracking
- Historical data analysis

**Metrics:**
- Battery levels
- App usage patterns
- Emergency response times
- Location accuracy logs

---

## 🔧 Development Tools

### **Frontend**
- **Flutter DevTools**: Debugging, profiling
- **Dart Analyzer**: Code quality
- **Android Studio**: Android development
- **Xcode**: iOS development (macOS)

### **Backend**
- **TypeScript Compiler**: Type checking
- **ESLint**: Code linting
- **ts-node-dev**: Hot reload development
- **Postman**: API testing

### **Database**
- **MongoDB Compass**: Database GUI
- **Redis CLI**: Redis management
- **MongoDB Atlas**: Cloud hosting

### **Version Control**
- **Git**: Source control
- **GitHub**: Repository hosting

---

## 🚀 Deployment Architecture

### **Frontend - Flutter App**
- **Android**: APK/AAB via Google Play Store
- **iOS**: IPA via Apple App Store
- **Build System**: Flutter build tools

### **Backend - Node.js API**
**Recommended Platforms:**
- Render.com (Free tier available)
- Railway.app
- Fly.io
- Heroku
- DigitalOcean

**Requirements:**
- Node.js 18+
- MongoDB connection string
- Redis instance
- Environment variables

### **Database Hosting**
- **MongoDB**: MongoDB Atlas (free tier)
- **Redis**: Redis Cloud, Upstash, Railway

---

## 🌐 Environment Variables

### **Backend (.env)**
```bash
# Server
PORT=5000
NODE_ENV=development

# Database
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/vhass_db
REDIS_HOST=your-redis-host
REDIS_PORT=18109
REDIS_PASSWORD=your-redis-password

# Authentication
JWT_SECRET=your-secret-key-here

# AI Services (Chatbot)
GEMINI_API_KEY=your-gemini-api-key
GROQ_API_KEY=your-groq-api-key

# SOS Configuration
SOS_ESCALATION_DELAY_SECONDS=30
EMERGENCY_NUMBER=112
```

### **Flutter (api_config.dart)**
```dart
// Production
static const String baseUrl = 'https://your-app.onrender.com/api';
static const String socketUrl = 'https://your-app.onrender.com';

// Development
static const String baseUrl = 'http://10.1.179.191:5001/api';
static const String socketUrl = 'http://10.1.179.191:5001';
```

---

## 📊 Performance Optimizations

### **Frontend**
- Local storage for offline functionality
- Image caching
- Lazy loading of screens
- Efficient state management

### **Backend**
- Redis caching for hot data
- Database indexing on phoneNumber, userId
- Connection pooling for MongoDB
- Job queue for async operations
- TypeScript compilation for production

### **Real-time**
- Socket.IO rooms for targeted broadcasts
- Message throttling
- Heartbeat monitoring
- Automatic reconnection

---

## 🔒 Security Measures

1. **Authentication**
   - JWT tokens with expiry
   - Phone-based OTP verification
   - Token refresh mechanism

2. **API Security**
   - CORS configuration
   - Request validation (express-validator)
   - Rate limiting (Redis)
   - Input sanitization

3. **Data Protection**
   - Password hashing (bcrypt)
   - Encrypted storage for sensitive data
   - HTTPS for production
   - Secure WebSocket connections

4. **Biometric**
   - Fingerprint/Face ID for critical actions
   - Device-level security integration

---

## 📝 Summary

VHASS is a full-stack emergency response application built with:

**Frontend:** Flutter + Dart with 15+ specialized packages  
**Backend:** TypeScript + Express.js + Socket.IO  
**Databases:** MongoDB (persistence) + Redis (caching/queues)  
**AI:** Google Gemini + Groq (chatbot only)  
**Real-time:** Socket.IO WebSocket  
**Job Processing:** BullMQ with Redis  
**Authentication:** JWT + Phone-based OTP  
**Voice Detection:** Simple pattern matching  
**Deployment:** Mobile apps + Cloud API + Database hosting  

The stack is designed for:
- ✅ Real-time emergency response
- ✅ Offline-first capabilities
- ✅ AI-powered chatbot assistance
- ✅ Voice activation (pattern matching)
- ✅ Scalable architecture
- ✅ High availability
- ✅ Cross-platform support

---

**Tech Stack Version:** 2.0.0  
**Last Updated:** February 2026  
**Platform Support:** Android, iOS (via Flutter)
