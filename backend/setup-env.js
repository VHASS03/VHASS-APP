const fs = require('fs');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

async function setupEnv() {
  console.log('========================================');
  console.log('  VHASS Backend Environment Setup');
  console.log('========================================\n');

  // MongoDB Configuration
  console.log('📦 MONGODB CONFIGURATION');
  console.log('1. Local MongoDB (mongodb://localhost:27017/vhass_db)');
  console.log('2. MongoDB Atlas (cloud)');
  const mongoChoice = await question('Choose option (1 or 2): ');
  
  let mongoUri;
  if (mongoChoice === '2') {
    mongoUri = await question('Enter MongoDB Atlas connection string: ');
  } else {
    mongoUri = 'mongodb://localhost:27017/vhass_db';
  }

  // Redis Configuration
  console.log('\n🔴 REDIS CONFIGURATION');
  const redisHost = await question('Redis host (default: localhost): ') || 'localhost';
  const redisPort = await question('Redis port (default: 6379): ') || '6379';
  const redisPassword = await question('Redis password (optional, press Enter to skip): ') || '';

  // JWT Secret
  console.log('\n🔐 JWT SECRET');
  console.log('This should be a random secret key (at least 32 characters)');
  const jwtSecret = await question('Enter JWT secret (or press Enter for default): ') || 
    'vhass_super_secret_jwt_key_change_this_in_production_' + Date.now();

  // Emergency Number
  console.log('\n🆘 EMERGENCY NUMBER');
  const emergencyNumber = await question('Emergency number (default: 112): ') || '112';

  // Create .env content
  const envContent = `# Server Configuration
PORT=5000
NODE_ENV=development

# MongoDB Connection
MONGODB_URI=${mongoUri}

# Redis Configuration
REDIS_HOST=${redisHost}
REDIS_PORT=${redisPort}
REDIS_PASSWORD=${redisPassword}

# JWT Secret
JWT_SECRET=${jwtSecret}

# OTP Configuration
OTP_EXPIRY_SECONDS=600
OTP_LENGTH=6

# SOS Configuration
SOS_ESCALATION_DELAY_SECONDS=30
SOS_MAX_DURATION_SECONDS=3600
EMERGENCY_NUMBER=${emergencyNumber}

# Socket.IO Configuration
SOCKET_PING_TIMEOUT=60000
SOCKET_PING_INTERVAL=25000
`;

  // Write .env file
  fs.writeFileSync('.env', envContent);
  console.log('\n✅ .env file created successfully!');
  console.log('\n📝 Next steps:');
  console.log('1. Make sure MongoDB is running');
  console.log('2. Make sure Redis is running');
  console.log('3. Run: npm run dev');
  console.log('4. Run worker in another terminal: npm run worker');
  
  rl.close();
}

setupEnv().catch(console.error);

