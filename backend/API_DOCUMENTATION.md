# VHASS Backend API Documentation

## Base URL
```
Development: http://localhost:5000/api
Production: https://your-domain.com/api
```

## Authentication

All endpoints (except `/api/auth/*`) require JWT token in header:
```
Authorization: Bearer <token>
```

---

## Authentication Endpoints

### Send OTP
**POST** `/api/auth/send-otp`

Send OTP to phone number. OTP stored in Redis with 10-minute expiry.

**Request Body:**
```json
{
  "phone": "1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "otp": "123456"  // Only in development mode
}
```

---

### Verify OTP & Login
**POST** `/api/auth/verify-otp`

Verify OTP and create/login user. Device binding required.

**Request Body:**
```json
{
  "phone": "1234567890",
  "otp": "123456",
  "deviceId": "device_unique_id",
  "deviceType": "SMARTPHONE",
  "deviceName": "My Phone",
  "metadata": {
    "os": "Android",
    "model": "Samsung Galaxy",
    "appVersion": "1.0.0"
  }
}
```

**Device Types:** `SMARTPHONE`, `WEARABLE`, `IOT_BUTTON`, `BLE_DEVICE`

**Response:**
```json
{
  "success": true,
  "message": "OTP verified successfully",
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "phone": "1234567890",
    "name": "John Doe",
    "email": "john@example.com"
  },
  "device": {
    "id": "device_id",
    "deviceId": "device_unique_id",
    "deviceType": "SMARTPHONE"
  }
}
```

---

## SOS Endpoints

### Trigger SOS
**POST** `/api/sos/trigger`

Trigger new SOS event. Returns instructions for device to execute.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "latitude": 28.6139,
  "longitude": 77.2090
}
```

**Response:**
```json
{
  "success": true,
  "message": "SOS triggered successfully",
  "sosId": "sos_id_here",
  "instructions": [
    {
      "action": "CALL",
      "phoneNumber": "9876543210",
      "contactName": "Mom",
      "priority": 1,
      "sosId": "sos_id_here"
    },
    {
      "action": "SEND_SMS",
      "phoneNumber": "9876543210",
      "message": "EMERGENCY: Mom, I need immediate help...",
      "contactName": "Mom",
      "sosId": "sos_id_here"
    }
  ]
}
```

**Device executes these instructions using SIM.**

---

### Update Location
**POST** `/api/sos/update-location`

Update SOS location (called periodically during active SOS).

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "sosId": "sos_id_here",
  "latitude": 28.6139,
  "longitude": 77.2090,
  "accuracy": 10.5,
  "address": "123 Main St"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Location updated"
}
```

---

### Report Call Result
**POST** `/api/sos/report-call-result`

Device reports result of CALL/SMS instruction execution.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "sosId": "sos_id_here",
  "contactId": "contact_id",
  "instructionType": "CALL",
  "success": true,
  "responded": true
}
```

**Instruction Types:** `CALL`, `SMS`

**Response:**
```json
{
  "success": true,
  "message": "Call result recorded"
}
```

---

### End SOS
**POST** `/api/sos/end`

End SOS (resolve or cancel). Cancellation ONLY from triggering device.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "sosId": "sos_id_here",
  "reason": "RESOLVED",
  "latitude": 28.6139,
  "longitude": 77.2090
}
```

**Reasons:** `RESOLVED`, `CANCELLED`

**Response:**
```json
{
  "success": true,
  "message": "SOS resolved successfully"
}
```

**Error (if cancelled from different device):**
```json
{
  "success": false,
  "message": "SOS can only be cancelled from the triggering device"
}
```

---

### Get SOS Status
**GET** `/api/sos/status/:sosId`

Get current SOS status.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "status": {
    "sosId": "sos_id",
    "userId": "user_id",
    "status": "CONTACTING",
    "currentContactIndex": 0,
    "startedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

**SOS Statuses:** `IDLE`, `TRIGGERED`, `CONTACTING`, `RESPONDER_ASSIGNED`, `ACTIVE`, `RESOLVED`

---

## Emergency Contacts Endpoints

### List Contacts
**GET** `/api/contacts`

Get all emergency contacts for authenticated user.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "contacts": [
    {
      "_id": "contact_id",
      "name": "Mom",
      "phone": "9876543210",
      "priority": 1,
      "isActive": true
    }
  ]
}
```

---

### Add Contact
**POST** `/api/contacts`

Add emergency contact (max 3 per user).

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "name": "Mom",
  "phone": "9876543210",
  "priority": 1
}
```

**Priority:** 1, 2, or 3

**Response:**
```json
{
  "success": true,
  "message": "Emergency contact added",
  "contact": {
    "_id": "contact_id",
    "name": "Mom",
    "phone": "9876543210",
    "priority": 1
  }
}
```

**Error (if max contacts reached):**
```json
{
  "success": false,
  "message": "Maximum 3 emergency contacts allowed"
}
```

---

### Update Contact
**PUT** `/api/contacts/:id`

Update emergency contact.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "name": "Updated Name",
  "phone": "9876543211",
  "priority": 2
}
```

**Response:**
```json
{
  "success": true,
  "message": "Contact updated",
  "contact": { ... }
}
```

---

### Delete Contact
**DELETE** `/api/contacts/:id`

Delete emergency contact (soft delete).

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "message": "Contact deleted"
}
```

---

## Device Endpoints

### Pair Device
**POST** `/api/device/pair`

Pair BLE/IoT device. Backend validates, Flutter handles BLE.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "deviceId": "ble_device_id",
  "deviceType": "BLE_DEVICE",
  "deviceName": "Safety Button",
  "metadata": {
    "firmwareVersion": "1.0"
  }
}
```

**Device Types:** `BLE_DEVICE`, `IOT_BUTTON`, `WEARABLE`

**Response:**
```json
{
  "success": true,
  "message": "Device paired successfully",
  "device": {
    "id": "device_id",
    "deviceId": "ble_device_id",
    "deviceType": "BLE_DEVICE"
  }
}
```

---

### Validate Device Trigger
**POST** `/api/device/validate-trigger`

Validate device trigger (e.g., IoT button press).

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "deviceId": "device_id"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Device trigger validated",
  "device": {
    "id": "device_id",
    "deviceId": "device_unique_id",
    "deviceType": "IOT_BUTTON"
  }
}
```

---

### List Devices
**GET** `/api/device/list`

Get all paired devices for user.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "devices": [
    {
      "_id": "device_id",
      "deviceId": "device_unique_id",
      "deviceType": "SMARTPHONE",
      "deviceName": "My Phone",
      "pairedAt": "2024-01-01T00:00:00.000Z",
      "lastSeenAt": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

---

## Socket.IO Events

### Connection

Connect with JWT token:
```javascript
const socket = io('http://localhost:5000', {
  auth: {
    token: 'jwt_token_here'
  }
});
```

### Client → Server Events

#### `location:update`
Send location update during active SOS.

```javascript
socket.emit('location:update', {
  sosId: 'sos_id',
  latitude: 28.6139,
  longitude: 77.2090,
  accuracy: 10.5,
  address: '123 Main St'
});
```

#### `sos:status:request`
Request SOS status.

```javascript
socket.emit('sos:status:request', {
  sosId: 'sos_id'
});
```

### Server → Client Events

#### `sos:status`
SOS status update.

```javascript
socket.on('sos:status', (data) => {
  console.log(data);
  // {
  //   sosId: 'sos_id',
  //   status: 'CONTACTING',
  //   startedAt: '2024-01-01T00:00:00.000Z'
  // }
});
```

#### `location:update`
Location broadcast (to SOS room).

```javascript
socket.on('location:update', (data) => {
  console.log(data);
  // {
  //   sosId: 'sos_id',
  //   latitude: 28.6139,
  //   longitude: 77.2090,
  //   timestamp: '2024-01-01T00:00:00.000Z'
  // }
});
```

#### `error`
Error messages.

```javascript
socket.on('error', (error) => {
  console.error(error.message);
});
```

---

## Error Responses

All errors follow this format:

```json
{
  "success": false,
  "message": "Error message here",
  "errors": []  // Validation errors (if any)
}
```

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (device binding violation)
- `404` - Not Found
- `409` - Conflict (e.g., SOS already active)
- `500` - Internal Server Error

---

## Notes

1. **Device Instructions**: Backend returns instructions, device executes via SIM
2. **Device Binding**: SOS cancellation only from triggering device
3. **Socket.IO Rooms**: `sos:<SOS_ID>` for location streaming
4. **OTP Storage**: Redis (10-minute TTL)
5. **SOS State**: Redis (active) + MongoDB (history)
6. **Escalation**: BullMQ handles delayed escalation jobs

