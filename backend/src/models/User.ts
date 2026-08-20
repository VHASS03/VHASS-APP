import mongoose, { Document, Schema } from 'mongoose';

export interface IUser extends Document {
  phone: string;
  name?: string;
  admissionNumber?: string;
  email?: string;
  course?: string;
  department?: string;
  year?: string;
  age?: number;
  gender?: string;
  residenceType?: string;
  roomNumber?: string;
  guardianName?: string;
  guardianPhone?: string;
  emergencyRelationship?: string;
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
    },
    name: {
      type: String,
      trim: true,
    },
    admissionNumber: {
      type: String,
      trim: true,
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please enter a valid email'],
    },
    course: {
      type: String,
      trim: true,
    },
    department: {
      type: String,
      enum: ['cse', 'ece', 'eee', 'mech', 'civil', 'bba'],
      trim: true,
    },
    year: {
      type: String,
      trim: true,
    },
    age: {
      type: Number,
      min: [13, 'Age must be at least 13'],
    },
    gender: {
      type: String,
      trim: true,
    },
    residenceType: {
      type: String,
      enum: ['Hosteller', 'Day Scholar'],
      default: 'Day Scholar',
    },
    roomNumber: {
      type: String,
      trim: true,
    },
    guardianName: {
      type: String,
      trim: true,
    },
    guardianPhone: {
      type: String,
      trim: true,
    },
    emergencyRelationship: {
      type: String,
      trim: true,
    },
    occupation: {
      type: String,
      trim: true,
    },
    isPhoneVerified: {
      type: Boolean,
      default: false,
    },
    sosPIN: {
      type: String,
      default: null,
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

UserSchema.index({ isPhoneVerified: 1 });

export default mongoose.model<IUser>('User', UserSchema);


