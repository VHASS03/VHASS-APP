import { Server as SocketIOServer } from 'socket.io';
import { Server as HTTPServer } from 'http';
import { verifyToken } from '../utils/jwt';
import SOS from '../models/SOS';
import { SOSStatus } from '../types';
import sosService from '../services/sosService';
import redisClient from '../config/redis';
import { setupChatHandlers } from './chatHandler';

/**
 * Socket.IO Handler
 * Handles real-time location updates during active SOS
 * 
 * Key Features:
 * - JWT authentication for socket connections
 * - Room-based communication (sos:<SOS_ID>)
 * - Location streaming during active SOS only
 * - Automatic cleanup on disconnect
 */

export const initializeSocket = (httpServer: HTTPServer): SocketIOServer => {
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
    pingTimeout: parseInt(process.env.SOCKET_PING_TIMEOUT || '60000'),
    pingInterval: parseInt(process.env.SOCKET_PING_INTERVAL || '25000'),
    serveClient: false,
    allowUpgrades: true,
  });

  // Authentication middleware
  // If token is missing, mark the socket as public (allowed only for OTP room registration)
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;

      if (!token) {
        // Public socket (unauthenticated). Only OTP events will be available.
        socket.data.isPublic = true;
        console.log(`[Socket] Public socket created (no token): ${socket.id}`);
        return next();
      }

      const decoded = verifyToken(token);

      if (!decoded) {
        console.error(`[Socket] Token verification failed for socket: ${socket.id}`);
        return next(new Error('Invalid or expired token'));
      }

      // Attach user info to socket
      socket.data.userId = decoded.userId;
      socket.data.deviceId = decoded.deviceId;
      socket.data.phone = decoded.phone;
      socket.data.isPublic = false;

      console.log(`[Socket] Authenticated socket: ${socket.id} (User: ${decoded.userId})`);
      next();
    } catch (error: any) {
      console.error(`[Socket] Authentication middleware error: ${error.message}`);
      next(new Error(`Authentication failed: ${error.message}`));
    }
  });

  io.on('connection', async (socket) => {
    const { userId, deviceId, isPublic } = socket.data;

    console.log(`[Socket] Client connected: ${socket.id} (User: ${userId || 'public'}, Device: ${deviceId || 'n/a'})`);

    // Handle connection errors
    socket.on('connect_error', (error: any) => {
      console.error(`[Socket] Connection error for ${socket.id}: ${error.message || error}`);
    });

    socket.on('error', (error: any) => {
      console.error(`[Socket] Socket error for ${socket.id}: ${error.message || error}`);
    });

    // Join OTP room (to receive OTP broadcasts) — allowed for public sockets too
    // IMPORTANT: Supports both device-specific and phone-specific rooms to prevent multi-device OTP sends
    socket.on('auth:register-for-otp', (data: { phone: string; deviceId?: string }) => {
      const { phone, deviceId: requestDeviceId } = data;
      
      if (requestDeviceId) {
        // Device-specific room: OTP goes to THIS device only
        const deviceRoom = `device:${requestDeviceId}`;
        socket.join(deviceRoom);
        console.log(`[Socket] ${socket.id} registered for OTP on device: ${requestDeviceId}`);
        socket.emit('auth:otp-room-joined', { 
          phone, 
          deviceId: requestDeviceId,
          message: 'Ready to receive OTP on this device' 
        });
      } else {
        // Fallback to phone room if no device ID provided
        const otpRoom = `otp:${phone}`;
        socket.join(otpRoom);
        console.log(`[Socket] ${socket.id} registered for OTP on phone: ${phone}`);
        socket.emit('auth:otp-room-joined', { 
          phone, 
          message: 'Ready to receive OTP' 
        });
      }
    });

    // If socket is public (no JWT), stop here. They can only receive OTP.
    if (isPublic) {
      return;
    }

    // Setup chat handlers (requires authenticated user)
    setupChatHandlers(socket);

    // Create a user-specific room for SOS alerts
    // Contacts will join this room to receive alerts
    const userAlertRoom = `user-alerts:${userId}`;
    socket.join(userAlertRoom);
    console.log(`[Socket] ${socket.id} joined alert room: ${userAlertRoom}`);

    // Handle when contact explicitly joins to listen for a specific user's SOS alerts
    socket.on('sos:listen-for-contact-alerts', (data: { contactUserId: string }) => {
      const { contactUserId } = data;
      const contactAlertRoom = `user-alerts:${contactUserId}`;
      socket.join(contactAlertRoom);
      console.log(`[Socket] ${socket.id} joined contact alert room: ${contactAlertRoom}`);
      socket.emit('sos:alert-listener-ready', { contactUserId });
    });

    // Check for active SOS
    const activeSOS = await SOS.findOne({
      userId,
      status: { $in: [SOSStatus.TRIGGERED, SOSStatus.CONTACTING, SOSStatus.RESPONDER_ASSIGNED, SOSStatus.ACTIVE] },
    });

    if (activeSOS) {
      const roomName = `sos:${activeSOS._id}`;
      socket.join(roomName);
      console.log(`[Socket] ${socket.id} joined room: ${roomName}`);

      // Notify client of active SOS
      socket.emit('sos:status', {
        sosId: activeSOS._id.toString(),
        status: activeSOS.status,
        startedAt: activeSOS.startedAt,
      });
    }

    // Handle location updates
    socket.on('location:update', async (data: { sosId: string; latitude: number; longitude: number; accuracy?: number; address?: string }) => {
      try {
        const { sosId, latitude, longitude, accuracy, address } = data;

        // Verify SOS belongs to user and is active
        const sos = await SOS.findOne({
          _id: sosId,
          userId,
          status: { $in: [SOSStatus.TRIGGERED, SOSStatus.CONTACTING, SOSStatus.RESPONDER_ASSIGNED, SOSStatus.ACTIVE] },
        });

        if (!sos) {
          socket.emit('error', { message: 'SOS not found or not active' });
          return;
        }

        // Update location in database
        await sosService.updateLocation(sosId, {
          latitude,
          longitude,
          accuracy,
          address,
        });

        // Broadcast to SOS room (for emergency contacts monitoring)
        const roomName = `sos:${sosId}`;
        io.to(roomName).emit('location:update', {
          sosId,
          latitude,
          longitude,
          accuracy,
          timestamp: new Date(),
        });

        // Store in Redis cache
        await redisClient.setLocation(
          userId,
          JSON.stringify({ latitude, longitude, timestamp: new Date() }),
          300
        );
      } catch (error) {
        console.error('[Socket] Location update error:', error);
        socket.emit('error', { message: 'Failed to update location' });
      }
    });

    // Handle SOS status requests
    socket.on('sos:status:request', async (data: { sosId: string }) => {
      try {
        const { sosId } = data;
        const status = await sosService.getSOSStatus(sosId);

        if (status) {
          socket.emit('sos:status', status);
        } else {
          socket.emit('error', { message: 'SOS not found' });
        }
      } catch (error) {
        console.error('[Socket] SOS status request error:', error);
        socket.emit('error', { message: 'Failed to get SOS status' });
      }
    });

    // Handle disconnect
    socket.on('disconnect', (reason) => {
      console.log(`[Socket] Client disconnected: ${socket.id} (Reason: ${reason})`);
    });

    // Handle errors
    socket.on('error', (error) => {
      console.error(`[Socket] Error from ${socket.id}:`, error);
    });
  });

  return io;
};

