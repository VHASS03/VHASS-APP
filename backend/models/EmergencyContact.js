const mongoose = require('mongoose');

const emergencyContactSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  phone: {
    type: String,
    required: true,
    trim: true,
    match: [/^[0-9]{10}$/, 'Please enter a valid 10-digit phone number']
  },
  priority: {
    type: Number,
    default: 1,
    min: 1,
    max: 3
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Ensure user can't have more than 3 emergency contacts
emergencyContactSchema.index({ userId: 1, priority: 1 });

module.exports = mongoose.model('EmergencyContact', emergencyContactSchema);


