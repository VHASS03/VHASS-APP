import mongoose, { Document, Schema } from 'mongoose';

export interface IPeriodLog {
  date: Date;
  endDate?: Date;
  flow?: string;
  symptoms?: string[];
  notes?: string;
}

export interface IDailyLog {
  date: Date;
  mood?: string;
  energyLevel?: number;
  symptoms?: string[];
  notes?: string;
  waterIntake?: number;
}

export interface ICycleData {
  startDate: Date;
  endDate?: Date;
  cycleLength: number;
  periodLength: number;
}

export interface IWellness extends Document {
  userId: mongoose.Types.ObjectId;
  cycleLength: number;
  periodLength: number;
  lastPeriodDate?: Date;
  healthCondition: string;
  setupDone: boolean;
  periodLogs: IPeriodLog[];
  dailyLogs: IDailyLog[];
  cycleHistory: ICycleData[];
  createdAt: Date;
  updatedAt: Date;
}

const PeriodLogSchema = new Schema<IPeriodLog>({
  date: { type: Date, required: true },
  endDate: { type: Date },
  flow: { type: String, default: 'medium' },
  symptoms: [{ type: String }],
  notes: { type: String, default: '' },
});

const DailyLogSchema = new Schema<IDailyLog>({
  date: { type: Date, required: true },
  mood: { type: String },
  energyLevel: { type: Number, min: 1, max: 5 },
  symptoms: [{ type: String }],
  notes: { type: String, default: '' },
  waterIntake: { type: Number, default: 0 },
});

const CycleDataSchema = new Schema<ICycleData>({
  startDate: { type: Date, required: true },
  endDate: { type: Date },
  cycleLength: { type: Number, required: true, default: 28 },
  periodLength: { type: Number, required: true, default: 5 },
});

const WellnessSchema = new Schema<IWellness>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    cycleLength: { type: Number, default: 28 },
    periodLength: { type: Number, default: 5 },
    lastPeriodDate: { type: Date },
    healthCondition: { type: String, default: 'None' },
    setupDone: { type: Boolean, default: false },
    periodLogs: [PeriodLogSchema],
    dailyLogs: [DailyLogSchema],
    cycleHistory: [CycleDataSchema],
  },
  { timestamps: true }
);

export default mongoose.model<IWellness>('Wellness', WellnessSchema);
