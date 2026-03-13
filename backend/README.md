# VHASS Backend API (TypeScript)

Complete backend architecture for Emergency & Safety Tracking Application.

## Quick Start

### Prerequisites

- Node.js 18+
- MongoDB (local or Atlas)
- Redis (local or cloud)

### Installation

```bash
cd backend
npm install
```

### Configuration

1. Copy `env.example` to `.env`
2. Configure MongoDB, Redis, and JWT secret

### Start Services

**Terminal 1: API Server**
```bash
npm run dev
```

**Terminal 2: Escalation Worker** (Required for SOS escalation)
```bash
npm run worker
```

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture documentation.

## Key Features

- ✅ TypeScript for type safety
- ✅ Phone-based OTP authentication (Redis)
- ✅ SOS lifecycle management
- ✅ Priority-based escalation (BullMQ)
- ✅ Real-time location tracking (Socket.IO)
- ✅ Device binding and pairing
- ✅ Append-only logging
- ✅ No third-party APIs (SIM-based calls/SMS)

## API Documentation

### Authentication
- `POST /api/auth/send-otp` - Send OTP to phone
- `POST /api/auth/verify-otp` - Verify OTP and login

### SOS Management
- `POST /api/sos/trigger` - Trigger SOS, get instructions
- `POST /api/sos/update-location` - Update location
- `POST /api/sos/report-call-result` - Report call/SMS result
- `POST /api/sos/end` - End SOS
- `GET /api/sos/status/:sosId` - Get SOS status

### Emergency Contacts
- `GET /api/contacts` - List contacts
- `POST /api/contacts` - Add contact (max 3)
- `PUT /api/contacts/:id` - Update contact
- `DELETE /api/contacts/:id` - Delete contact

### Device Management
- `POST /api/device/pair` - Pair BLE/IoT device
- `POST /api/device/validate-trigger` - Validate device trigger
- `GET /api/device/list` - List paired devices

## Socket.IO Events

### Client → Server
- `location:update` - Send location update
- `sos:status:request` - Request SOS status

### Server → Client
- `sos:status` - SOS status update
- `location:update` - Location broadcast

## Development

```bash
# Build TypeScript
npm run build

# Run in development (with auto-reload)
npm run dev

# Run escalation worker
npm run worker

# Lint code
npm run lint
```

## Production

```bash
# Build
npm run build

# Start API server
npm start

# Start worker (separate process)
node dist/workers/escalationWorker.js
```

## Important Notes

1. **Escalation Worker**: Must run separately for SOS escalation to work
2. **Redis Required**: For OTP, state, and BullMQ queues
3. **Device Binding**: SOS cancellation only from triggering device
4. **No Third-Party APIs**: All calls/SMS via device SIM
5. **Backend Provides Instructions**: Device executes actions

## License

ISC
