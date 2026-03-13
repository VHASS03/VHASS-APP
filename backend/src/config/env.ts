/**
 * Environment Configuration Loader
 * This file MUST be imported first to ensure dotenv loads before any other modules
 */
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Verify critical environment variables are loaded
if (!process.env.REDIS_HOST) {
  console.warn('⚠️ REDIS_HOST not set in .env, using default: localhost');
}

if (!process.env.MONGODB_URI) {
  console.warn('⚠️ MONGODB_URI not set in .env');
}

if (!process.env.JWT_SECRET) {
  console.warn('⚠️ JWT_SECRET not set in .env');
}

export {};

