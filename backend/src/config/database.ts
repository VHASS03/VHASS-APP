import mongoose from 'mongoose';

/**
 * MongoDB Connection Manager
 * Handles connection lifecycle and error recovery
 */
class Database {
  private static instance: Database;
  private isConnected = false;

  private constructor() {}

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  async connect(): Promise<void> {
    if (this.isConnected) {
      console.log('✅ MongoDB already connected');
      return;
    }

    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/vhass_db';

    try {
      console.log(`🔌 Attempting to connect to MongoDB: ${mongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')}`);
      
      await mongoose.connect(mongoUri, {
        maxPoolSize: 10,
        serverSelectionTimeoutMS: 10000, // Increased timeout
        socketTimeoutMS: 45000,
      });

      // Verify connection is actually working by running a ping
      await mongoose.connection.db.admin().ping();
      
      this.isConnected = true;
      console.log('✅ MongoDB connected successfully');
      console.log(`📊 Database: ${mongoose.connection.name}`);
      console.log(`📊 Host: ${mongoose.connection.host}:${mongoose.connection.port}`);

      // Handle connection events
      mongoose.connection.on('error', (err) => {
        console.error('❌ MongoDB connection error:', err);
        this.isConnected = false;
      });

      mongoose.connection.on('disconnected', () => {
        console.warn('⚠️ MongoDB disconnected');
        this.isConnected = false;
      });

      mongoose.connection.on('reconnected', () => {
        console.log('✅ MongoDB reconnected');
        this.isConnected = true;
      });

    } catch (error: any) {
      console.error('❌ MongoDB connection failed:', error);
      console.error('❌ Error details:', {
        name: error.name,
        message: error.message,
        code: error.code,
      });
      
      // Provide helpful error messages for common issues
      if (error.name === 'MongooseServerSelectionError' || error.message?.includes('whitelist')) {
        console.error('\n💡 MongoDB Atlas IP Whitelist Issue Detected:');
        console.error('   Your IP address is not whitelisted in MongoDB Atlas.');
        console.error('   To fix this:');
        console.error('   1. Go to: https://cloud.mongodb.com/');
        console.error('   2. Navigate to: Network Access → IP Access List');
        console.error('   3. Click "Add IP Address"');
        console.error('   4. Add your current IP or use "0.0.0.0/0" (less secure, for development only)');
        console.error('   5. Wait 1-2 minutes for changes to propagate');
        console.error('   6. Restart your server\n');
      }
      
      this.isConnected = false;
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (!this.isConnected) return;

    await mongoose.disconnect();
    this.isConnected = false;
    console.log('MongoDB disconnected');
  }

  getConnectionStatus(): boolean {
    return this.isConnected;
  }
}

export default Database.getInstance();

