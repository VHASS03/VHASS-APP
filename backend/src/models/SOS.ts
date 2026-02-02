import mongoose, { Document, Schema } from 'mongoose';
import { SOSStatus } from '../types';

export interface ISOS extends Document {
  userId: mongoose.Types.ObjectId;
  deviceId: string;  // Device ID string from app (not ObjectId)
  status: SOSStatus;
  currentContactIndex: number;
  startedAt: Date;
  resolvedAt?: Date;
  cancelledAt?: Date;
  cancellationDeviceId?: string;  // Device ID string
  cancellationReason?: string;
  locations: Array<{
    latitude: number;
    longitude: number;
    accuracy?: number;
    timestamp: Date;
    address?: string;
  }>;
  escalationHistory: Array<{
    contactId: mongoose.Types.ObjectId;
    attemptedAt: Date;
    responded: boolean;
    instructionType: 'CALL' | 'SMS';
  }>;
  finalLocation?: {
    latitude: number;
    longitude: number;
    timestamp: Date;
  };
  createdAt: Date;
  updatedAt: Date;
}

const SOSSchema = new Schema<ISOS>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    deviceId: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      enum: Object.values(SOSStatus),
      default: SOSStatus.IDLE,
      required: true,
      index: true,
    },
    currentContactIndex: {
      type: Number,
      default: 0,
      min: 0,
      max: 3,
    },
    startedAt: {
      type: Date,
      default: Date.now,
    },
    resolvedAt: {
      type: Date,
    },
    cancelledAt: {
      type: Date,
    },
    cancellationDeviceId: {
      type: String,
    },
    cancellationReason: {
      type: String,
    },
    locations: [
      {
        latitude: { type: Number, required: true },
        longitude: { type: Number, required: true },
        accuracy: { type: Number },
        timestamp: { type: Date, default: Date.now },
        address: { type: String },
      },
    ],
    escalationHistory: [
      {
        contactId: { type: Schema.Types.ObjectId, ref: 'EmergencyContact' },
        attemptedAt: { type: Date, default: Date.now },
        responded: { type: Boolean, default: false },
        instructionType: { type: String, enum: ['CALL', 'SMS'] },
      },
    ],
    finalLocation: {
      latitude: { type: Number },
      longitude: { type: Number },
      timestamp: { type: Date },
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for query performance
SOSSchema.index({ userId: 1, status: 1 });
SOSSchema.index({ status: 1, startedAt: -1 });
SOSSchema.index({ deviceId: 1 });

export default mongoose.model<ISOS>('SOS', SOSSchema);

