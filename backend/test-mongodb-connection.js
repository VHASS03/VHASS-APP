/**
 * MongoDB Connection Test Script
 * Run this to verify MongoDB connection and test user creation
 * Usage: node test-mongodb-connection.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

async function testConnection() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/vhass_db';
  
  console.log('🔍 Testing MongoDB Connection...');
  console.log(`📝 Connection URI: ${mongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')}`);
  
  try {
    // Connect to MongoDB
    await mongoose.connect(mongoUri, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
    });
    
    console.log('✅ Connected to MongoDB');
    console.log(`📊 Database: ${mongoose.connection.name}`);
    console.log(`📊 Host: ${mongoose.connection.host}:${mongoose.connection.port}`);
    
    // Test ping
    await mongoose.connection.db.admin().ping();
    console.log('✅ Ping successful');
    
    // Test creating a user
    const UserSchema = new mongoose.Schema({
      phone: { type: String, required: true, unique: true },
      name: { type: String },
      isPhoneVerified: { type: Boolean, default: false },
    }, { timestamps: true });
    
    const TestUser = mongoose.model('TestUser', UserSchema);
    
    // Try to create a test user
    const testPhone = `test_${Date.now()}`;
    const testUser = await TestUser.create({
      phone: testPhone,
      name: 'Test User',
      isPhoneVerified: false,
    });
    
    console.log(`✅ Test user created: ${testUser._id}`);
    
    // Verify it was saved
    const foundUser = await TestUser.findById(testUser._id);
    if (foundUser) {
      console.log(`✅ Test user verified in database: ${foundUser.phone}`);
    } else {
      console.error('❌ Test user not found in database!');
    }
    
    // Clean up test user
    await TestUser.deleteOne({ _id: testUser._id });
    console.log('✅ Test user cleaned up');
    
    console.log('\n✅ All tests passed! MongoDB connection is working correctly.');
    
  } catch (error) {
    console.error('\n❌ MongoDB connection test failed:');
    console.error('Error name:', error.name);
    console.error('Error message:', error.message);
    console.error('Error code:', error.code);
    
    if (error.name === 'MongoServerSelectionError') {
      console.error('\n💡 Possible issues:');
      console.error('   - MongoDB is not running');
      console.error('   - MongoDB connection string is incorrect');
      console.error('   - Network connectivity issues');
      console.error('\n💡 Solutions:');
      console.error('   1. Make sure MongoDB is running: mongod (or net start MongoDB on Windows)');
      console.error('   2. Check your MONGODB_URI in .env file');
      console.error('   3. Verify MongoDB is accessible at the specified host/port');
    }
    
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

testConnection();

