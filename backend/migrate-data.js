/**
 * Database Migration Script
 * Copies all collections and data from MongoDB Atlas to AWS DocumentDB.
 * Usage: node migrate-data.js
 */

const { MongoClient } = require('mongodb');

// Source MongoDB Atlas URI
const SOURCE_URI = 'mongodb+srv://vhass0310:Uday_123@cluster0.zndptf0.mongodb.net/vhass_db?retryWrites=true&w=majority';

// Target AWS DocumentDB URI
const TARGET_URI = 'mongodb://documentdb:%3C4%28idpSi%21M1pHY9AiLyC%21xfG%2966g@vhass-documentdb.c5gaissa82qn.ap-south-2.docdb.amazonaws.com:27017/vhass-documentdb?tls=true&tlsAllowInvalidCertificates=true&retryWrites=false&authMechanism=SCRAM-SHA-1';

async function migrate() {
  console.log('🏁 Starting Database Migration...');
  console.log('📡 Source: MongoDB Atlas (vhass_db)');
  console.log('📡 Target: AWS DocumentDB (vhass-documentdb)\n');

  let sourceClient, targetClient;

  try {
    // Connect to source database
    console.log('🔌 Connecting to Source Database (Atlas)...');
    sourceClient = new MongoClient(SOURCE_URI);
    await sourceClient.connect();
    const sourceDb = sourceClient.db('vhass_db');
    console.log('✅ Connected to Source Database');

    // Connect to target database
    console.log('🔌 Connecting to Target Database (DocumentDB)...');
    targetClient = new MongoClient(TARGET_URI);
    await targetClient.connect();
    const targetDb = targetClient.db('vhass-documentdb');
    console.log('✅ Connected to Target Database\n');

    // Get list of collections from source
    const collections = await sourceDb.listCollections().toArray();
    console.log(`📋 Found ${collections.length} collections in source database.`);

    for (const colInfo of collections) {
      const colName = colInfo.name;
      
      // Skip system collections if any
      if (colName.startsWith('system.')) {
        console.log(`⏭️ Skipping system collection: ${colName}`);
        continue;
      }

      console.log(`\n📦 Processing collection: "${colName}"...`);
      const sourceCol = sourceDb.collection(colName);
      const targetCol = targetDb.collection(colName);

      // Fetch all documents from source
      const documents = await sourceCol.find({}).toArray();
      console.log(`   Fetched ${documents.length} documents from source.`);

      if (documents.length === 0) {
        console.log('   Empty collection, skipping migration.');
        continue;
      }

      // Optional: Clean up target collection first if you want a clean copy
      console.log(`   Cleaning up existing target collection "${colName}"...`);
      await targetCol.deleteMany({});

      // Insert documents into target in batches (to handle large datasets)
      const batchSize = 500;
      for (let i = 0; i < documents.length; i += batchSize) {
        const batch = documents.slice(i, i + batchSize);
        await targetCol.insertMany(batch);
        console.log(`   Migrated documents ${i + 1} to ${Math.min(i + batchSize, documents.length)}`);
      }
      
      console.log(`✅ Collection "${colName}" migrated successfully!`);
    }

    console.log('\n🎉 Database Migration completed successfully!');

  } catch (error) {
    console.error('\n❌ Migration failed with error:');
    console.error(error);
  } finally {
    if (sourceClient) {
      await sourceClient.close();
      console.log('\n🔌 Closed connection to Source Database');
    }
    if (targetClient) {
      await targetClient.close();
      console.log('🔌 Closed connection to Target Database');
    }
  }
}

migrate();
