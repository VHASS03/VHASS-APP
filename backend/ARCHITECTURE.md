# VHASS Backend Architecture

## Overview

Complete TypeScript backend for Emergency & Safety Tracking Application with strict separation of concerns:
- **Backend decides** (escalation logic, state management)
- **Device executes** (calls, SMS via SIM)

## Tech Stack

- **Node.js + TypeScript**: Type-safe backend
- **Express.js**: REST API framework
- **MongoDB + Mongoose**: Persistent data storage
- **Redis**: In-memory state, OTP storage, caching
- **BullMQ**: Background job processing (escalation delays)
- **Socket.IO**: Real-time location streaming

## Architecture Principles

### 1. Backend Controls Logic, Device Executes Actions

```
Backend → Returns Instructions → Flutter App → Executes via SIM
```

**Example:**
```json
{
  "instructions": [
    {
      "action": "CALL",
      "phoneNumber": "9876543210",
      "contactName": "Mom",
      "priority": 1,
      "sosId": "sos_123"
    },
    {
      "action": "SEND_SMS",
      "phoneNumber": "9876543210",
      "message": "EMERGENCY: ...",
      "sosId": "sos_123"
    }
  ]
}
```

Flutter app receives instructions and executes them using device SIM.

### 2. State Management

- **Redis**: Active SOS state, OTP storage, location cache
- **MongoDB**: Historical data, user profiles, logs
- **BullMQ**: Delayed escalation jobs (survives restarts)

### 3. SOS Lifecycle

```
IDLE → TRIGGERED → CONTACTING → RESPONDER_ASSIGNED → ACTIVE → RESOLVED
```

States stored in:
- Redis (active SOS)
- MongoDB (history)

### 4. Device Binding

- JWT contains `deviceId`
- SOS cancellation ONLY from triggering device
- Device pairing tracked in MongoDB

## Module Structure

### Models (MongoDB)

1. **User**: Phone-based authentication, device references
2. **Device**: Device pairing, BLE/IoT support
3. **EmergencyContact**: Priority-based contacts (max 3)
4. **SOS**: Complete SOS lifecycle and history
5. **Log**: Append-only event logging

### Services

1. **sosService**: Core SOS logic, escalation management
2. **Redis Client**: OTP, state, location caching
3. **BullMQ Workers**: Background escalation processing

### Routes

1. **/api/auth**: OTP-based authentication
2. **/api/sos**: SOS trigger, status, location updates
3. **/api/contacts**: Emergency contact management
4. **/api/device**: Device pairing, validation

### Socket.IO

- **Authentication**: JWT-based
- **Rooms**: `sos:<SOS_ID>` for location streaming
- **Events**:
  - `location:update` (client → server)
  - `sos:status` (server → client)
  - `location:update` (server → room)

## Key Features

### 1. OTP Authentication

- OTP generated and stored in Redis (TTL: 10 minutes)
- Verified and consumed on login
- JWT issued with device binding

### 2. SOS Escalation

**Why BullMQ?**
- Jobs persist in Redis (survive restarts)
- Automatic retry on failure
- Delayed execution (escalation delays)
- Better than `setTimeout` for production

**Escalation Flow:**
1. Trigger SOS → Contact priority 1
2. Schedule escalation job (30s delay)
3. If no response → Escalate to priority 2
4. Repeat until all contacts exhausted
5. Escalate to emergency number (112)

### 3. Location Tracking

- Socket.IO room: `sos:<SOS_ID>`
- Updates every 5 seconds during active SOS
- Stored in MongoDB (history) and Redis (cache)
- Broadcast to room for monitoring

### 4. Device Pairing

- BLE/IoT device pairing API
- Device validation for triggers
- Backend validates, Flutter handles BLE

### 5. Logging

- Append-only logs in MongoDB
- Log types: AUTH, SOS_TRIGGER, CALL_ATTEMPT, etc.
- Metadata stored for analytics

## API Endpoints

### Authentication
- `POST /api/auth/send-otp` - Send OTP
- `POST /api/auth/verify-otp` - Verify OTP, login, device binding

### SOS
- `POST /api/sos/trigger` - Trigger SOS, get instructions
- `POST /api/sos/update-location` - Update location
- `POST /api/sos/report-call-result` - Report call/SMS result
- `POST /api/sos/end` - End SOS (resolve/cancel)
- `GET /api/sos/status/:sosId` - Get SOS status

### Contacts
- `GET /api/contacts` - List contacts
- `POST /api/contacts` - Add contact (max 3)
- `PUT /api/contacts/:id` - Update contact
- `DELETE /api/contacts/:id` - Delete contact

### Device
- `POST /api/device/pair` - Pair BLE/IoT device
- `POST /api/device/validate-trigger` - Validate device trigger
- `GET /api/device/list` - List paired devices

## Socket.IO Events

### Client → Server
- `location:update` - Send location update
- `sos:status:request` - Request SOS status

### Server → Client
- `sos:status` - SOS status update
- `location:update` - Location broadcast (to room)
- `error` - Error messages

## Security

1. **JWT Authentication**: All routes (except auth)
2. **Device Binding**: Token contains deviceId
3. **SOS Cancellation**: Only from triggering device
4. **Socket.IO Auth**: JWT verification on connection
5. **OTP Expiry**: 10 minutes TTL in Redis

## Reliability

1. **State Persistence**: Redis + MongoDB
2. **Job Persistence**: BullMQ in Redis
3. **Graceful Shutdown**: Clean disconnect handlers
4. **Error Handling**: Try-catch with logging
5. **Connection Recovery**: MongoDB/Redis reconnection logic

## Running the System

1. **Start MongoDB**: `mongod` or MongoDB Atlas
2. **Start Redis**: `redis-server`
3. **Start API Server**: `npm run dev`
4. **Start Escalation Worker**: `npm run worker` (separate process)

## Environment Variables

See `env.example` for required configuration:
- MongoDB URI
- Redis host/port
- JWT secret
- OTP expiry
- SOS escalation delay
- Emergency number

## Notes

- **No Third-Party APIs**: No Twilio, no Firebase Auth
- **SIM-Based**: All calls/SMS via device SIM
- **Backend Logic**: Escalation, state, decisions
- **Device Execution**: Calls, SMS, location updates
- **Production Ready**: Error handling, logging, persistence

