/**
 * Test Signup Endpoint
 * This script tests the signup API endpoint directly
 */

const http = require('http');

const testData = {
  name: 'Test User',
  phone: '1234567890',
  email: 'test@example.com',
  age: 25,
  occupation: 'Developer',
  emergencyContacts: []
};

const postData = JSON.stringify(testData);

const options = {
  hostname: 'localhost',
  port: 5000,
  path: '/api/auth/signup',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('🧪 Testing signup endpoint...');
console.log('📝 Request data:', testData);
console.log('');

const req = http.request(options, (res) => {
  let data = '';

  console.log(`📊 Status Code: ${res.statusCode}`);
  console.log(`📊 Headers:`, res.headers);
  console.log('');

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log('📥 Response:');
    try {
      const json = JSON.parse(data);
      console.log(JSON.stringify(json, null, 2));
      
      if (json.success) {
        console.log('\n✅ Signup successful!');
        console.log(`   User ID: ${json.userId}`);
        if (json.otp) {
          console.log(`   OTP: ${json.otp}`);
        }
      } else {
        console.log('\n❌ Signup failed!');
        console.log(`   Message: ${json.message}`);
        if (json.errors) {
          console.log(`   Errors:`, json.errors);
        }
        if (json.error) {
          console.log(`   Error: ${json.error}`);
        }
      }
    } catch (e) {
      console.log('Raw response:', data);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error.message);
  console.error('\n💡 Make sure the backend server is running on port 5000');
});

req.write(postData);
req.end();

