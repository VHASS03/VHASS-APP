const mongoose = require('mongoose');
require('dotenv').config();

async function fixDeviceIndex() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    const db = mongoose.connection.db;
    const collection = db.collection('devices');

    // List current indexes
    const indexes = await collection.listIndexes().toArray();
    console.log('📋 Current indexes:');
    indexes.forEach((idx, i) => {
      console.log(`  ${i}. ${JSON.stringify(idx.key)} ${idx.unique ? '[UNIQUE]' : ''}`);
    });

    // Drop both indexes
    try {
      await collection.dropIndex('deviceId_1');
      console.log('✅ Dropped deviceId_1 index');
    } catch (error) {
      if (error.code !== 27) throw error;
      console.log('ℹ️  Index deviceId_1 does not exist');
    }

    try {
      await collection.dropIndex('deviceId_1_userId_1');
      console.log('✅ Dropped deviceId_1_userId_1 index');
    } catch (error) {
      if (error.code !== 27) throw error;
      console.log('ℹ️  Index deviceId_1_userId_1 does not exist');
    }

    // Create new compound unique index
    await collection.createIndex({ deviceId: 1, userId: 1 }, { unique: true });
    console.log('✅ Created compound unique index on (deviceId, userId)');

    // List updated indexes
    const updatedIndexes = await collection.listIndexes().toArray();
    console.log('\n📋 Updated indexes:');
    updatedIndexes.forEach((idx, i) => {
      console.log(`  ${i}. ${JSON.stringify(idx.key)} ${idx.unique ? '[UNIQUE]' : ''}`);
    });

    console.log('\n✅ Device index fixed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

fixDeviceIndex();
