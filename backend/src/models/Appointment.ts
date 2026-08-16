import mongoose, { Document, Schema } from 'mongoose';

export interface IAppointment extends Document {
  studentId: mongoose.Types.ObjectId;
  counsellorId: mongoose.Types.ObjectId;
  studentName: string;
  studentPhone: string;
  concern: string;
  date: Date;
  timeSlot: String;
  status: string; // 'Pending', 'Approved', 'Rejected', 'Completed', 'Cancelled', 'Rescheduled'
  isHighPriority: boolean;
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

const AppointmentSchema = new Schema<IAppointment>(
  {
    studentId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    counsellorId: { type: Schema.Types.ObjectId, ref: 'Counsellor', required: true },
    studentName: { type: String, required: true },
    studentPhone: { type: String, required: true },
    concern: { type: String, required: true },
    date: { type: Date, required: true },
    timeSlot: { type: String, required: true },
    status: { type: String, default: 'Pending' },
    isHighPriority: { type: Boolean, default: false },
    notes: { type: String, default: '' },
  },
  { timestamps: true }
);

export default mongoose.model<IAppointment>('Appointment', AppointmentSchema);
