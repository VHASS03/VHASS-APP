import mongoose, { Document, Schema } from 'mongoose';
import { LogType } from '../types';

export interface ILog extends Document {
  userId?: mongoose.Types.ObjectId;
  deviceId?: string;  // Device ID string from app
  sosId?: mongoose.Types.ObjectId;
  logType: LogType;
  message: string;
  metadata?: Record<string, any>;
  timestamp: Date;
  createdAt: Date;
}

const LogSchema = new Schema<ILog>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    deviceId: {
      type: String,
      index: true,
    },
    sosId: {
      type: Schema.Types.ObjectId,
      ref: 'SOS',
      index: true,
    },
    logType: {
      type: String,
      enum: Object.values(LogType),
      required: true,
      index: true,
    },
    message: {
      type: String,
      required: true,
    },
    metadata: {
      type: Schema.Types.Mixed,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for common queries
LogSchema.index({ userId: 1, logType: 1, timestamp: -1 });
LogSchema.index({ sosId: 1, timestamp: -1 });
LogSchema.index({ timestamp: -1 }); // For time-based queries

export default mongoose.model<ILog>('Log', LogSchema);

