import mongoose, { Document, Schema } from 'mongoose';

export interface ICounsellor extends Document {
  name: string;
  specialization: string;
  imageUrl: string;
  rating: number;
  availability: string[];
  email: string;
}

const CounsellorSchema = new Schema<ICounsellor>(
  {
    name: { type: String, required: true },
    specialization: { type: String, required: true },
    imageUrl: { type: String, required: true },
    rating: { type: Number, default: 4.8 },
    availability: [{ type: String }],
    email: { type: String, required: true },
  },
  { timestamps: true }
);

export default mongoose.model<ICounsellor>('Counsellor', CounsellorSchema);
