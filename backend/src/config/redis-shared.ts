// Load environment variables FIRST
import './env';

import Redis from 'ioredis';
import { RedisOptions } from 'ioredis';

/**
 * Shared Redis Client Module
 * 
 * Consolidates main Redis and BullMQ queue connections into a single client
 * to reduce connection overhead and ECONNRESET frequency.
 * 
 * Features:
 * - Single connection instance shared by main client and queues
 * - Periodic PING (every 15 seconds) to prevent idle timeouts
 * - Automatic reconnect on network errors
 * - TCP keepalive to maintain connection health
 */

class SharedRedisClient {
  private static instance: SharedRedisClient;
  private client: Redis | null = null;
  private pingInterval: NodeJS.Timeout | null = null;
  private lastErrorTime: number = 0;
  private errorCount: number = 0;
  private readonly ERROR_THROTTLE_MS = 5000;
  private readonly PING_INTERVAL_MS = 5000; // PING every 5 seconds to prevent idle timeout (Redis Cloud timeout ~5min)

  private constructor() {}

  static getInstance(): SharedRedisClient {
    if (!SharedRedisClient.instance) {
      SharedRedisClient.instance = new SharedRedisClient();
    }
    return SharedRedisClient.instance;
  }

  connect(): Redis {
    if (this.client && this.client.status === 'ready') {
      return this.client;
    }

    const host = process.env.REDIS_HOST || 'localhost';
    const port = parseInt(process.env.REDIS_PORT || '6379');
    const hasPassword = !!process.env.REDIS_PASSWORD;
    const connectTimeout = parseInt(process.env.REDIS_CONNECT_TIMEOUT_MS || '20000');
    const commandTimeout = parseInt(process.env.REDIS_COMMAND_TIMEOUT_MS || '60000');

    console.log(`🔌 Connecting to Redis: ${host}:${port} (password: ${hasPassword ? 'set' : 'not set'})`);

    const options: RedisOptions = {
      host,
      port,
      password: process.env.REDIS_PASSWORD || undefined,
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
      maxRetriesPerRequest: null, // Allow infinite retries for queue operations
      connectTimeout,
      commandTimeout,
      enableReadyCheck: true,
      enableOfflineQueue: true,
      // Keep TCP connections alive to reduce NAT timeouts
      keepAlive: 30000,
      // Socket configuration to prevent idle timeout
      socket: {
        keepAlive: true,
        keepAliveInitialDelay: 30000,
        noDelay: true, // TCP_NODELAY - send data immediately
      },
      // Reconnect automatically on network errors
      reconnectOnError: (err: any) => {
        const msg = err && (err.message || err.code || err.errno);
        if (!msg) return false;
        if (/ECONNRESET|EPIPE|READONLY|ETIMEDOUT|ECONNREFUSED|EHOSTUNREACH/i.test(String(msg))) {
          return true;
        }
        return false;
      },
    };

    this.client = new Redis(options);

    this.client.on('connect', () => {
      console.log('✅ Redis connected');
      // Start periodic PING after successful connection
      this.startPingInterval();
    });

    this.client.on('error', (err: any) => {
      const now = Date.now();
      this.errorCount++;

      if (now - this.lastErrorTime > this.ERROR_THROTTLE_MS) {
        const errorCode = err.code || err.errno || 'UNKNOWN';
        const errorMessage = err.message || 'Unknown error';

        console.error('❌ Redis connection error:', errorMessage);
        console.error(`   Attempting to connect to: ${host}:${port}`);

        if (errorCode === 'ECONNRESET') {
          console.error('   ⚠️  Connection reset by peer. Likely idle timeout or network issue.');
          console.error('   💡 Ensure Redis Cloud allows persistent connections, or increase idle timeout.');
        } else if (errorCode === 'EACCES' || err.errno === -4092) {
          console.error('   ⚠️  Access denied. Check Redis Cloud IP whitelist settings.');
        } else if (errorCode === 'ETIMEDOUT') {
          console.error('   ⚠️  Connection timeout. Check network connectivity.');
        }

        if (this.errorCount > 1) {
          console.error(`   (This error has occurred ${this.errorCount} times)`);
        }

        this.lastErrorTime = now;
      }
    });

    this.client.on('close', () => {
      console.warn('⚠️ Redis connection closed');
      this.stopPingInterval();
    });

    this.client.on('reconnecting', () => {
      if (this.errorCount % 10 === 0) {
        console.log(`🔄 Redis reconnecting... (attempt ${this.errorCount})`);
      }
    });

    return this.client;
  }

  /**
   * Start periodic PING to keep connection alive and prevent idle timeouts.
   * Redis Cloud may disconnect idle connections after 5-10 minutes.
   */
  private startPingInterval(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
    }

    this.pingInterval = setInterval(async () => {
      if (this.client && this.client.status === 'ready') {
        try {
          await this.client.ping();
          // console.log('🔔 PING');
        } catch (err: any) {
          const errorMsg = err.message || 'Unknown error';
          console.error('❌ PING failed:', errorMsg);
        }
      }
    }, this.PING_INTERVAL_MS);
  }

  /**
   * Stop periodic PING interval.
   */
  private stopPingInterval(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
  }

  getClient(): Redis {
    if (!this.client) {
      return this.connect();
    }
    return this.client;
  }

  async disconnect(): Promise<void> {
    this.stopPingInterval();
    if (this.client) {
      await this.client.quit();
      this.client = null;
      console.log('Redis disconnected');
    }
  }

  // ===== OTP Storage Methods =====
  async storeOTP(phone: string, otp: string, expirySeconds: number = 600): Promise<void> {
    const key = `otp:${phone}`;
    await this.getClient().setex(key, expirySeconds, otp);
  }

  async verifyOTP(phone: string, otp: string): Promise<boolean> {
    const key = `otp:${phone}`;
    const storedOTP = await this.getClient().get(key);

    if (storedOTP === otp) {
      await this.getClient().del(key);
      return true;
    }
    return false;
  }

  // ===== SOS State Methods =====
  async setSOSState(sosId: string, state: string, ttl: number = 3600): Promise<void> {
    const key = `sos:${sosId}`;
    await this.getClient().setex(key, ttl, state);
  }

  async getSOSState(sosId: string): Promise<string | null> {
    const key = `sos:${sosId}`;
    return await this.getClient().get(key);
  }

  async deleteSOSState(sosId: string): Promise<void> {
    const key = `sos:${sosId}`;
    await this.getClient().del(key);
  }

  // ===== Location Methods =====
  async setLocation(userId: string, location: string, ttl: number = 300): Promise<void> {
    const key = `location:${userId}`;
    await this.getClient().setex(key, ttl, location);
  }

  async getLocation(userId: string): Promise<string | null> {
    const key = `location:${userId}`;
    return await this.getClient().get(key);
  }

  // ===== Device Session Methods =====
  async setDeviceSession(userId: string, deviceId: string, token: string, ttl: number = 2592000): Promise<void> {
    const key = `session:${userId}:${deviceId}`;
    await this.getClient().setex(key, ttl, token);
  }

  async verifyDeviceSession(userId: string, deviceId: string, token: string): Promise<boolean> {
    const key = `session:${userId}:${deviceId}`;
    const storedToken = await this.getClient().get(key);
    return storedToken === token;
  }
}

export default SharedRedisClient.getInstance();
