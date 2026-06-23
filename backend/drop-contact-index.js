/**
 * Drop Emergency Contact Index in MongoDB
 * Usage: node drop-contact-index.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

async function dropIndex() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/vhass_db';
  
  try {
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB');
    
    const db = mongoose.connection.db;
    const contactsCollection = db.collection('emergencycontacts');
    
    console.log('🔍 Checking indexes...');
    const indexes = await contactsCollection.indexes();
    const indexExists = indexes.some(idx => idx.name === 'userId_1_priority_1');
    
    if (indexExists) {
      console.log('🗑️ Dropping old index userId_1_priority_1...');
      await contactsCollection.dropIndex('userId_1_priority_1');
      console.log('✅ Index dropped successfully!');
    } else {
      console.log('ℹ️ Index userId_1_priority_1 not found. Nothing to drop.');
    }
    
    console.log('\n🔍 Current indexes:');
    const currentIndexes = await contactsCollection.indexes();
    console.log(JSON.stringify(currentIndexes, null, 2));
    
  } catch (error) {
    console.error('❌ Error dropping index:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB');
  }
}

dropIndex();
