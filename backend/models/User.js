const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  phone: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    match: [/^[0-9]{10}$/, 'Please enter a valid 10-digit phone number']
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    match: [/^\S+@\S+\.\S+$/, 'Please enter a valid email']
  },
  age: {
    type: Number,
    required: true,
    min: [13, 'Age must be at least 13']
  },
  occupation: {
    type: String,
    required: true,
    trim: true
  },
  isPhoneVerified: {
    type: Boolean,
    default: false
  },
  otp: {
    code: String,
    expiresAt: Date
  },
  emergencyContacts: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'EmergencyContact'
  }],
  location: {
    latitude: Number,
    longitude: Number,
    lastUpdated: Date
  },
  isEmergencyActive: {
    type: Boolean,
    default: false
  },
  emergencyPin: {
    type: String,
    select: false
  }
}, {
  timestamps: true
});

// Hash emergency PIN before saving
userSchema.pre('save', async function(next) {
  if (this.isModified('emergencyPin') && this.emergencyPin) {
    this.emergencyPin = await bcrypt.hash(this.emergencyPin, 10);
  }
  next();
});

// Method to verify emergency PIN
userSchema.methods.verifyEmergencyPin = async function(pin) {
  if (!this.emergencyPin) return false;
  return await bcrypt.compare(pin, this.emergencyPin);
};

module.exports = mongoose.model('User', userSchema);


