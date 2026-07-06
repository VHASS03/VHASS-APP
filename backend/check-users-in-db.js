/**
 * Check Users in MongoDB Database
 * This script will list all users in the database
 */

require('dotenv').config();
const mongoose = require('mongoose');

async function checkUsers() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/vhass_db';
  
  console.log('🔍 Checking users in MongoDB...');
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
    
    // Define User schema (matching the TypeScript model)
    const UserSchema = new mongoose.Schema({
      phone: { type: String, required: true, unique: true },
      name: { type: String },
      email: { type: String },
      age: { type: Number },
      occupation: { type: String },
      isPhoneVerified: { type: Boolean, default: false },
      devices: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Device' }],
      emergencyContacts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'EmergencyContact' }],
    }, { timestamps: true });
    
    const User = mongoose.model('User', UserSchema);
    
    // Get all users
    const users = await User.find({}).lean();
    
    console.log(`\n📊 Found ${users.length} user(s) in database:\n`);
    
    if (users.length === 0) {
      console.log('❌ No users found in database!');
      console.log('\n💡 This means:');
      console.log('   - Either no signup requests have been made');
      console.log('   - Or the signup requests are failing silently');
      console.log('   - Or users are being saved to a different database/collection');
    } else {
      users.forEach((user, index) => {
        console.log(`User ${index + 1}:`);
        console.log(`  ID: ${user._id}`);
        console.log(`  Phone: ${user.phone}`);
        console.log(`  Name: ${user.name || '(not set)'}`);
        console.log(`  Email: ${user.email || '(not set)'}`);
        console.log(`  Age: ${user.age || '(not set)'}`);
        console.log(`  Occupation: ${user.occupation || '(not set)'}`);
        console.log(`  Verified: ${user.isPhoneVerified}`);
        console.log(`  Created: ${user.createdAt}`);
        console.log(`  Updated: ${user.updatedAt}`);
        console.log('');
      });
    }
    
    // Also check the raw collection
    const db = mongoose.connection.db;
    const collections = await db.listCollections().toArray();
    console.log(`\n📁 Collections in database: ${collections.map(c => c.name).join(', ')}`);
    
    // Check users collection directly
    const usersCollection = db.collection('users');
    const userCount = await usersCollection.countDocuments();
    console.log(`\n📊 Direct collection count: ${userCount} documents in 'users' collection`);
    
    if (userCount > 0) {
      const rawUsers = await usersCollection.find({}).limit(5).toArray();
      console.log('\n📄 Sample documents from users collection:');
      rawUsers.forEach((user, index) => {
        console.log(`\nDocument ${index + 1}:`);
        console.log(JSON.stringify(user, null, 2));
      });
    }
    
  } catch (error) {
    console.error('\n❌ Error checking users:');
    console.error('Error name:', error.name);
    console.error('Error message:', error.message);
    console.error('Error code:', error.code);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

checkUsers();

