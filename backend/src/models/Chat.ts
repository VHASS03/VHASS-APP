import mongoose, { Schema, Document } from 'mongoose';

interface IChatMessage {
  sender: 'user' | 'bot';
  text: string;
  timestamp: Date;
  metadata?: {
    intent?: string;
    confidence?: number;
  };
}

export interface IChat extends Document {
  userId: mongoose.Types.ObjectId;
  messages: IChatMessage[];
  startedAt: Date;
  updatedAt: Date;
  isActive: boolean;
  topic?: string; // Current conversation topic/intent
}

const chatMessageSchema = new Schema<IChatMessage>(
  {
    sender: {
      type: String,
      enum: ['user', 'bot'],
      required: true,
    },
    text: {
      type: String,
      required: true,
      maxlength: 1000,
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
    metadata: {
      intent: String,
      confidence: Number,
    },
  },
  { _id: false }
);

const chatSchema = new Schema<IChat>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    messages: {
      type: [chatMessageSchema],
      default: [],
    },
    startedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    topic: {
      type: String,
      default: 'general',
    },
  },
  {
    timestamps: true,
  }
);

// Index for efficient queries
chatSchema.index({ userId: 1, isActive: 1 });
chatSchema.index({ userId: 1, startedAt: -1 });

export default mongoose.model<IChat>('Chat', chatSchema);
