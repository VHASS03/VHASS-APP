# Fixing Backend Issues

## Issue 1: Port 5000 Already in Use

Process ID 32624 is using port 5000. Let's kill it:

**Option 1: Kill the process**
```powershell
taskkill /PID 32624 /F
```

**Option 2: Change backend port**
Edit `.env` file and change:
```
PORT=5001
```

## Issue 2: Redis Not Running

Redis is required for:
- OTP storage
- SOS state management
- BullMQ queues

### Install Redis on Windows

**Option A: Use WSL (Windows Subsystem for Linux)**
1. Install WSL: `wsl --install`
2. Install Redis in WSL:
   ```bash
   wsl
   sudo apt-get update
   sudo apt-get install redis-server
   sudo service redis-server start
   ```
3. Update `.env`:
   ```
   REDIS_HOST=localhost
   REDIS_PORT=6379
   ```

**Option B: Use Redis Cloud (Free)**
1. Sign up: https://redis.com/try-free/
2. Create free database
3. Get connection details
4. Update `.env`:
   ```
   REDIS_HOST=your-redis-host
   REDIS_PORT=your-redis-port
   REDIS_PASSWORD=your-redis-password
   ```

**Option C: Use Docker (if installed)**
```powershell
docker run -d -p 6379:6379 redis:latest
```

**Option D: Download Windows Redis**
- Download: https://github.com/microsoftarchive/redis/releases
- Extract and run `redis-server.exe`

