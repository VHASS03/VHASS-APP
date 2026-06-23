/**
 * Redis Connection Test Script (Verbose)
 * Run this to verify Redis connectivity, credentials, and performance
 * Usage: node test-redis-connection.js
 */

require('dotenv').config();
const Redis = require('ioredis');

async function testConnection() {
  const host = process.env.REDIS_HOST || 'localhost';
  const port = parseInt(process.env.REDIS_PORT || '6379');
  const password = process.env.REDIS_PASSWORD;
  
  console.log('🔍 Testing Redis Connection...');
  console.log(`📝 Host: ${host}:${port}`);
  console.log(`📝 Password: ${password ? '*** (Provided)' : 'None'}`);

  const client = new Redis({
    host,
    port,
    password: password || undefined,
    connectTimeout: 10000,
    maxRetriesPerRequest: 3, // Fail fast for testing
  });

  client.on('connect', () => {
    console.log('📡 Event: connect (socket connection established)');
  });

  client.on('ready', () => {
    console.log('✅ Event: ready (authenticated and ready for commands)');
  });

  client.on('error', (err) => {
    console.error('❌ Event: error:', err.message || err);
  });

  client.on('close', () => {
    console.log('🔌 Event: close (connection closed)');
  });

  client.on('reconnecting', (delay) => {
    console.log(`🔄 Event: reconnecting (next attempt in ${delay}ms)`);
  });

  try {
    console.log('⏳ Waiting for "ready" event...');
    await new Promise((resolve, reject) => {
      const onReady = () => {
        client.off('error', onError);
        resolve();
      };
      const onError = (err) => {
        client.off('ready', onReady);
        reject(err);
      };
      client.once('ready', onReady);
      client.once('error', onError);
    });

    console.log('🚀 Sending PING...');
    const pingResponse = await client.ping();
    console.log(`✅ Ping response: "${pingResponse}"`);

    // Test Set/Get
    const testKey = `test_key:${Date.now()}`;
    const testVal = 'VHASS Redis Connection Test OK';
    
    await client.set(testKey, testVal, 'EX', 60);
    console.log(`✅ Set key: "${testKey}"`);

    const readVal = await client.get(testKey);
    console.log(`✅ Read key: "${readVal}"`);

    if (readVal === testVal) {
      console.log('🎉 Value matches successfully! Redis is fully working.');
    } else {
      console.error('❌ Value mismatch!');
    }

    await client.del(testKey);
  } catch (error) {
    console.error('\n❌ Redis Connection Test Failed during operation:');
    console.error(error.stack || error);
  } finally {
    try {
      await client.quit();
    } catch (e) {}
    console.log('🏁 Script finished.');
  }
}

testConnection();
