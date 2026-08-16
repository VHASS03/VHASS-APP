import mongoose, { Document, Schema } from 'mongoose';

export interface IWellnessEvent extends Document {
  title: string;
  description: string;
  date: Date;
  time: string;
  location: string;
  speaker: string;
  imageUrl: string;
  registeredUsers: mongoose.Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
}

const WellnessEventSchema = new Schema<IWellnessEvent>(
  {
    title: { type: String, required: true },
    description: { type: String, required: true },
    date: { type: Date, required: true },
    time: { type: String, required: true },
    location: { type: String, required: true },
    speaker: { type: String, required: true },
    imageUrl: { type: String, required: true },
    registeredUsers: [{ type: Schema.Types.ObjectId, ref: 'User' }],
  },
  { timestamps: true }
);

export default mongoose.model<IWellnessEvent>('WellnessEvent', WellnessEventSchema);
