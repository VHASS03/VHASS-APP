# Environment Setup Guide

## Quick Setup

### Option 1: Interactive Setup (Recommended)

Run the setup script:
```bash
node setup-env.js
```

It will ask you for:
- MongoDB connection (local or Atlas)
- Redis configuration
- JWT secret
- Emergency number

### Option 2: Manual Setup

Copy `env.example` to `.env`:
```bash
copy env.example .env    # Windows
# OR
cp env.example .env       # Mac/Linux
```

Then edit `.env` file with your values.

---

## Required Information

Please provide the following:

### 1. MongoDB Connection

**Option A: Local MongoDB**
- If you have MongoDB installed locally, use:
  ```
  MONGODB_URI=mongodb://localhost:27017/vhass_db
  ```

**Option B: MongoDB Atlas (Cloud - Free)**
- Sign up at: https://www.mongodb.com/cloud/atlas
- Create a free cluster
- Get connection string (looks like):
  ```
  MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/vhass_db
  ```

**Which do you want to use?** (Local MongoDB or MongoDB Atlas)

---

### 2. Redis Configuration

**Option A: Local Redis**
- If you have Redis installed locally:
  ```
  REDIS_HOST=localhost
  REDIS_PORT=6379
  REDIS_PASSWORD=
  ```

**Option B: Redis Cloud (Free)**
- Sign up at: https://redis.com/try-free/
- Get connection details

**Do you have Redis installed locally, or do you need help setting it up?**

---

### 3. JWT Secret

This is a secret key for encrypting authentication tokens. 

**I can generate one for you, or you can provide your own (must be at least 32 characters).**

---

### 4. Emergency Number

Default is `112` (international emergency number).

**What emergency number should be used?** (e.g., 112, 911, etc.)

---

## Questions for You:

1. **MongoDB**: Do you have MongoDB installed locally, or do you want to use MongoDB Atlas (cloud)?
2. **Redis**: Do you have Redis installed locally, or do you need help setting it up?
3. **JWT Secret**: Should I generate a random secret key for you?
4. **Emergency Number**: What emergency number? (default: 112)

---

## Default Values (You can use these)

If you want to use defaults, I can create `.env` with:
- MongoDB: `mongodb://localhost:27017/vhass_db` (local)
- Redis: `localhost:6379` (local)
- JWT Secret: Auto-generated
- Emergency Number: `112`

**Just let me know and I'll create the .env file for you!**

