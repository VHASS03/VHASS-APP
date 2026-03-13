import mongoose, { Document, Schema } from 'mongoose';
import { DeviceType } from '../types';

export interface IDevice extends Document {
  deviceId: string; // Unique device identifier (e.g., IMEI, MAC address)
  userId: mongoose.Types.ObjectId;
  deviceType: DeviceType;
  deviceName?: string;
  pairedAt: Date;
  lastSeenAt: Date;
  isActive: boolean;
  metadata?: {
    os?: string;
    model?: string;
    appVersion?: string;
  };
  createdAt: Date;
  updatedAt: Date;
}

const DeviceSchema = new Schema<IDevice>(
  {
    deviceId: {
      type: String,
      required: true,
      index: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    deviceType: {
      type: String,
      enum: Object.values(DeviceType),
      required: true,
    },
    deviceName: {
      type: String,
      trim: true,
    },
    pairedAt: {
      type: Date,
      default: Date.now,
    },
    lastSeenAt: {
      type: Date,
      default: Date.now,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    metadata: {
      os: String,
      model: String,
      appVersion: String,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for user-device queries
DeviceSchema.index({ userId: 1, isActive: 1 });
DeviceSchema.index({ deviceId: 1, userId: 1 }, { unique: true });

export default mongoose.model<IDevice>('Device', DeviceSchema);

