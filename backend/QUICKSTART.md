# Quick Start Guide

## Prerequisites

1. **Node.js** (v14 or higher)
2. **MongoDB** (local installation or MongoDB Atlas account)
3. **npm** or **yarn**

## Setup Steps

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Environment

Create a `.env` file in the `backend` folder:

```env
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/vhass_db
JWT_SECRET=your_super_secret_jwt_key_here
```

**Optional (for production):**
- Add Twilio credentials for SMS OTP
- Add OpenAI API key for AI chat

### 3. Start MongoDB

**Option A: Local MongoDB**
```bash
# Windows
net start MongoDB

# Mac/Linux
mongod
```

**Option B: MongoDB Atlas (Cloud)**
- Create free account at https://www.mongodb.com/cloud/atlas
- Create cluster and get connection string
- Update `MONGODB_URI` in `.env`

### 4. Run the Server

```bash
# Development mode (auto-reload)
npm run dev

# Production mode
npm start
```

You should see:
```
✅ Connected to MongoDB
🚀 Server running on port 5000
```

### 5. Test the API

Open your browser or use Postman:
```
http://localhost:5000/api/health
```

You should get:
```json
{
  "status": "OK",
  "message": "VHASS Backend API is running"
}
```

## Testing Authentication

### Send OTP
```bash
POST http://localhost:5000/api/auth/send-otp
Content-Type: application/json

{
  "phone": "1234567890"
}
```

**In development mode**, check the console for the OTP code.

### Verify OTP
```bash
POST http://localhost:5000/api/auth/verify-otp
Content-Type: application/json

{
  "phone": "1234567890",
  "otp": "123456"
}
```

You'll receive a JWT token for authenticated requests.

## Next Steps

1. **Connect Flutter App**: Update your Flutter app to use `http://localhost:5000/api` as the base URL
2. **Add HTTP Package**: Use `http` or `dio` package in Flutter for API calls
3. **Store JWT Token**: Save the token securely (use `shared_preferences` or `flutter_secure_storage`)
4. **Add Authorization Header**: Include `Authorization: Bearer <token>` in API requests

## Common Issues

**MongoDB Connection Error**
- Make sure MongoDB is running
- Check `MONGODB_URI` in `.env`
- For Atlas, whitelist your IP address

**Port Already in Use**
- Change `PORT` in `.env`
- Or stop the process using port 5000

**Module Not Found**
- Run `npm install` again
- Delete `node_modules` and reinstall

## API Base URL

- **Development**: `http://localhost:5000/api`
- **Production**: Update with your server URL

## Support

Check `README.md` for detailed API documentation.


