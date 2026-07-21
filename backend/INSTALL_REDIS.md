# Installing Redis on Windows

## Quick Options

### Option 1: Redis Cloud (Easiest - No Installation) ⭐ RECOMMENDED

1. **Sign up for free account:**
   - Go to: https://redis.com/try-free/
   - Sign up with email

2. **Create free database:**
   - Click "Create database"
   - Choose "Free" tier
   - Select region closest to you
   - Click "Create"

3. **Get connection details:**
   - Copy the connection details shown
   - You'll get:
     - Host: `redis-xxxxx.redis.cloud`
     - Port: `12345`
     - Password: `your-password`

4. **Update `.env` file:**
   ```env
   REDIS_HOST=redis-xxxxx.redis.cloud
   REDIS_PORT=12345
   REDIS_PASSWORD=your-password
   ```

5. **Done!** No installation needed.

---

### Option 2: Docker (If you have Docker Desktop)

1. **Check if Docker is installed:**
   ```powershell
   docker --version
   ```

2. **If Docker is installed, run:**
   ```powershell
   docker run -d --name vhass-redis -p 6379:6379 redis:latest
   ```

3. **Verify it's running:**
   ```powershell
   docker ps
   ```

4. **Your `.env` stays as:**
   ```env
   REDIS_HOST=localhost
   REDIS_PORT=6379
   REDIS_PASSWORD=
   ```

---

### Option 3: WSL (Windows Subsystem for Linux)

1. **Install WSL (if not installed):**
   ```powershell
   wsl --install
   ```
   - Restart computer after installation

2. **Install Redis in WSL:**
   ```powershell
   wsl
   sudo apt-get update
   sudo apt-get install redis-server
   sudo service redis-server start
   ```

3. **Test Redis:**
   ```powershell
   wsl redis-cli ping
   ```
   Should return: `PONG`

4. **Your `.env` stays as:**
   ```env
   REDIS_HOST=localhost
   REDIS_PORT=6379
   REDIS_PASSWORD=
   ```

5. **To start Redis later:**
   ```powershell
   wsl sudo service redis-server start
   ```

---

### Option 4: Download Windows Redis Build

1. **Download Redis for Windows:**
   - Go to: https://github.com/microsoftarchive/redis/releases
   - Download latest `Redis-x64-*.zip`

2. **Extract and run:**
   - Extract ZIP file
   - Run `redis-server.exe`
   - Keep window open (Redis runs in foreground)

3. **Your `.env` stays as:**
   ```env
   REDIS_HOST=localhost
   REDIS_PORT=6379
   REDIS_PASSWORD=
   ```

---

## Which Option Should You Choose?

- **Redis Cloud**: Best for beginners, no installation, works immediately
- **Docker**: Good if you already have Docker Desktop
- **WSL**: Good if you want local Redis and have WSL
- **Windows Build**: Good if you want simple local Redis

---

## After Installing Redis

1. **Update `.env`** (if using Redis Cloud)
2. **Start backend:**
   ```powershell
   npm run dev
   ```
3. **Start worker (in another terminal):**
   ```powershell
   npm run worker
   ```

---

## Verify Redis is Working

Test Redis connection:
```powershell
# If using local Redis
wsl redis-cli ping

# Or if using Docker
docker exec vhass-redis redis-cli ping

# Should return: PONG
```

