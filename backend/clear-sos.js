/**
 * Quick cleanup script to clear old SOS records
 * Run: node clear-sos.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/vhass_db';

async function clearOldSOS() {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(mongoUri);
    console.log('✅ Connected');

    // Define SOS schema inline
    const sosSchema = new mongoose.Schema({}, { collection: 'sos' });
    const SOS = mongoose.model('SOS', sosSchema);

    // Find all active SOS
    const activeSOS = await SOS.find({
      status: { $in: ['TRIGGERED', 'CONTACTING', 'RESPONDER_ASSIGNED', 'ACTIVE'] },
    });

    console.log(`\n📋 Found ${activeSOS.length} active SOS records:`);
    activeSOS.forEach((sos) => {
      console.log(`   - ID: ${sos._id}, Status: ${sos.status}, User: ${sos.userId}`);
    });

    if (activeSOS.length === 0) {
      console.log('\n✅ No active SOS to clear');
      await mongoose.disconnect();
      return;
    }

    // Clear them
    const result = await SOS.deleteMany({
      status: { $in: ['TRIGGERED', 'CONTACTING', 'RESPONDER_ASSIGNED', 'ACTIVE'] },
    });

    console.log(`\n🗑️  Deleted ${result.deletedCount} active SOS records`);
    console.log('✅ Cleanup complete!');

    await mongoose.disconnect();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

clearOldSOS();
