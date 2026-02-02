// Load environment variables FIRST, before any other imports
import './config/env';

import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import { createServer } from 'http';
import database from './config/database';
import redisClient from './config/redis';
import { initializeSocket } from './socket/socketHandler';

// Import routes
import authRoutes from './routes/auth';
import sosRoutes from './routes/sos';
import contactsRoutes from './routes/contacts';
import deviceRoutes from './routes/device';
import voiceRoutes from './routes/voice';
import chatRoutes from './routes/chat';

const app: Express = express();
const httpServer = createServer(app);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'OK',
    message: 'VHASS Backend API is running',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/contacts', contactsRoutes);
app.use('/api/device', deviceRoutes);
app.use('/api/voice', voiceRoutes);
app.use('/api/chat', chatRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: any) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// Initialize Socket.IO
const io = initializeSocket(httpServer);
app.set('io', io);

// Start server
const PORT = process.env.PORT || 5000;

async function startServer() {
  try {
    // Connect to MongoDB (required - server won't start without it)
    await database.connect();

    // Connect to Redis (non-blocking - server will start even if Redis fails)
    // Redis connection errors are logged but won't prevent server startup
    try {
      redisClient.connect();
      console.log('✅ Redis connection initiated');
    } catch (redisError) {
      console.warn('⚠️  Redis connection failed, but server will continue');
      console.warn('   Some features requiring Redis may not work (OTP, caching, queues)');
    }

    // Start HTTP server
    httpServer.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📡 Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`🔌 Socket.IO initialized`);
      console.log(`\n⚠️  IMPORTANT: Start the escalation worker separately:`);
      console.log(`   npm run worker\n`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await database.disconnect();
  await redisClient.disconnect();
  httpServer.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await database.disconnect();
  await redisClient.disconnect();
  httpServer.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

startServer();

export { app, httpServer, io };

