const mongoose = require('mongoose');

const emergencyAlertSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  location: {
    latitude: {
      type: Number,
      required: true
    },
    longitude: {
      type: Number,
      required: true
    },
    address: String
  },
  batteryLevel: {
    type: Number,
    min: 0,
    max: 100
  },
  status: {
    type: String,
    enum: ['active', 'resolved', 'cancelled'],
    default: 'active'
  },
  contactsNotified: [{
    contactId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'EmergencyContact'
    },
    notifiedAt: Date,
    responded: {
      type: Boolean,
      default: false
    }
  }],
  startedAt: {
    type: Date,
    default: Date.now
  },
  resolvedAt: Date,
  cancelledAt: Date
}, {
  timestamps: true
});

module.exports = mongoose.model('EmergencyAlert', emergencyAlertSchema);


