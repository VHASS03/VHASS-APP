import mongoose, { Document, Schema } from 'mongoose';

export interface IUser extends Document {
  phone: string;
  name?: string;
  email?: string;
  age?: number;
  occupation?: string;
  isPhoneVerified: boolean;
  devices: mongoose.Types.ObjectId[];
  emergencyContacts: mongoose.Types.ObjectId[];
    sosPIN?: string;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    phone: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      match: [/^[0-9]{10}$/, 'Phone must be exactly 10 digits'],
      // Note: unique: true already creates an index, so we don't need index: true here
    },
    name: {
      type: String,
      trim: true,
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please enter a valid email'],
    },
    age: {
      type: Number,
      min: [13, 'Age must be at least 13'],
    },
    occupation: {
      type: String,
      trim: true,
    },
    isPhoneVerified: {
      type: Boolean,
      default: false,
        sosPIN: {
          type: String,
          default: null,
        },
    },
    devices: [
      {
        type: Schema.Types.ObjectId,
        ref: 'Device',
      },
    ],
    emergencyContacts: [
      {
        type: Schema.Types.ObjectId,
        ref: 'EmergencyContact',
      },
    ],
  },
  {
    timestamps: true,
  }
);

// Indexes for performance
// Note: phone index is already created by unique: true, so we only add isPhoneVerified index
UserSchema.index({ isPhoneVerified: 1 });

export default mongoose.model<IUser>('User', UserSchema);

