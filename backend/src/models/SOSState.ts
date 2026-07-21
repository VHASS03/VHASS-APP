import mongoose, { Document, Schema } from 'mongoose';

export interface ISOSState extends Document {
  sosId: string;
  userId: string;
  deviceId: string;
  status: string;
  currentContactIndex: number;
  startedAt: Date;
  userName: string;
  createdAt: Date;
  updatedAt: Date;
}

const SOSStateSchema = new Schema<ISOSState>(
  {
    sosId: {
      type: String,
      required: true,
      index: true,
      unique: true,
    },
    userId: {
      type: String,
      required: true,
      index: true,
    },
    deviceId: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      required: true,
      index: true,
    },
    currentContactIndex: {
      type: Number,
      required: true,
      default: 0,
    },
    startedAt: {
      type: Date,
      required: true,
    },
    userName: {
      type: String,
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

SOSStateSchema.index({ status: 1, startedAt: -1 });

export default mongoose.model<ISOSState>('SOSState', SOSStateSchema);

