import mongoose, { Document, Schema } from 'mongoose';

export interface IEmergencyContact extends Document {
  userId: mongoose.Types.ObjectId;
  name: string;
  phone: string;
  countryCode: string;  // e.g., 'IN', 'US', 'UK'
  priority: number; // 1, 2, or 3
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const EmergencyContactSchema = new Schema<IEmergencyContact>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    countryCode: {
      type: String,
      required: true,
      default: 'IN',
      enum: ['IN', 'US', 'UK', 'CA', 'AU', 'SG', 'PK', 'BD'],
    },
    priority: {
      type: Number,
      required: true,
      min: 1,
      max: 3,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// Ensure one priority per user
EmergencyContactSchema.index({ userId: 1, priority: 1 }, { unique: true });
EmergencyContactSchema.index({ userId: 1, isActive: 1 });

export default mongoose.model<IEmergencyContact>('EmergencyContact', EmergencyContactSchema);

