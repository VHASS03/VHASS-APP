/**
 * Check Emergency Contacts in MongoDB Database
 * Usage: node check-contacts.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

async function checkContacts() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/vhass_db';
  
  try {
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB');
    
    const db = mongoose.connection.db;
    const contactsCollection = db.collection('emergencycontacts');
    
    const contacts = await contactsCollection.find({}).toArray();
    console.log(`\n📊 Found ${contacts.length} total contacts:`);
    
    contacts.forEach((c, index) => {
      console.log(`\nContact ${index + 1}:`);
      console.log(`  ID: ${c._id}`);
      console.log(`  User ID: ${c.userId}`);
      console.log(`  Name: ${c.name}`);
      console.log(`  Phone: ${c.phone}`);
      console.log(`  Priority: ${c.priority}`);
      console.log(`  Is Active: ${c.isActive}`);
      console.log(`  Country Code: ${c.countryCode || 'IN (not set - defaulted)'}`);
    });
    
    // Check indexes on emergencycontacts
    const indexes = await contactsCollection.indexes();
    console.log('\n🔍 Indexes on emergencycontacts collection:');
    console.log(JSON.stringify(indexes, null, 2));
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await mongoose.disconnect();
  }
}

checkContacts();
