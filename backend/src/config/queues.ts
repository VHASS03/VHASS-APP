// Load environment variables FIRST
import './env';

import { Queue, QueueOptions } from 'bullmq';
import sharedRedisClient from './redis-shared';

/**
 * BullMQ Queue Configuration
 * 
 * WHY BullMQ?
 * 1. Persistent job queues survive server restarts
 * 2. Built-in retry logic and failure handling
 * 3. Delayed job execution (for escalation delays)
 * 4. Job prioritization
 * 5. Redis-backed (fast and reliable)
 * 6. Better than setTimeout for production (survives crashes)
 * 
 * OPTIMIZATION:
 * - Uses shared Redis client with periodic PING to reduce connection overhead
 * - Single connection instance reused for all queue operations
 */

// Get the shared Redis connection
const redisConnection = sharedRedisClient.getClient();

// Log connection details (without password)
redisConnection.on('connect', () => {
  console.log(`✅ Redis connected to ${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || '6379'}`);
});

// Throttle error logging for queues Redis connection
let lastQueueErrorTime = 0;
let queueErrorCount = 0;
const QUEUE_ERROR_THROTTLE_MS = 5000;

redisConnection.on('error', (err: any) => {
  const now = Date.now();
  queueErrorCount++;
  
  // Throttle error logging to prevent spam
  if (now - lastQueueErrorTime > QUEUE_ERROR_THROTTLE_MS) {
    const errorCode = err.code || err.errno || 'UNKNOWN';
    console.error('❌ Redis connection error (Queues):', err.message || err);
    console.error(`   Attempting to connect to: ${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || '6379'}`);
    
    if (errorCode === 'EACCES' || err.errno === -4092) {
      console.error('   ⚠️  Access denied. Check Redis Cloud IP whitelist settings.');
    }
    
    if (queueErrorCount > 1) {
      console.error(`   (This error has occurred ${queueErrorCount} times)`);
    }
    
    lastQueueErrorTime = now;
  }
});

const queueOptions: QueueOptions = {
  connection: redisConnection as any,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
    removeOnComplete: {
      age: 3600, // Keep completed jobs for 1 hour
      count: 1000,
    },
    removeOnFail: {
      age: 86400, // Keep failed jobs for 24 hours
    },
  },
};

/**
 * Escalation Queue
 * Handles delayed escalation to next contact or emergency services
 */
export const escalationQueue = new Queue('escalation', queueOptions);

/**
 * Emergency Fallback Queue
 * Handles emergency number calling after all contacts fail
 */
export const emergencyQueue = new Queue('emergency', queueOptions);

/**
 * Location Update Queue
 * Processes location updates in batches
 */
export const locationQueue = new Queue('location', queueOptions);

export { redisConnection };

