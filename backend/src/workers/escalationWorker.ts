// Load environment variables FIRST (the worker runs as its own process, not via server.ts)
import '../config/env';

import { Worker, Job } from 'bullmq';
import database from '../config/database';
import sosService from '../services/sosService';
import { redisConnection } from '../config/queues';
import EmergencyContact from '../models/EmergencyContact';

// The worker queries MongoDB, so it needs its own connection. Without it every
// job fails with "buffering timed out". Mongoose buffers queries until connected.
database.connect().catch((error) => {
  console.error('❌ Escalation Worker could not connect to MongoDB:', error);
  process.exit(1);
});

/**
 * Escalation Worker
 * Processes delayed escalation jobs from BullMQ
 * 
 * WHY BullMQ Workers?
 * - Survives server restarts (jobs persist in Redis)
 * - Automatic retry on failure
 * - Job prioritization
 * - Better than setTimeout for production reliability
 */

interface EscalationJobData {
  sosId: string;
  userId: string;
  contactIndex: number;
}

const escalationWorker = new Worker<EscalationJobData>(
  'escalation',
  async (job: Job<EscalationJobData>) => {
    const { sosId, userId, contactIndex } = job.data;

    console.log(`[Escalation Worker] Processing escalation for SOS ${sosId}, contact index ${contactIndex}`);

    try {
      // Get contacts
      const contacts = await EmergencyContact.find({
        userId,
        isActive: true,
      }).sort({ priority: 1 });

      // Check if contact index is valid
      if (contactIndex >= contacts.length) {
        // All contacts exhausted, escalate to emergency
        await sosService.escalate(sosId, contactIndex);
        return;
      }

      // Check if SOS is still active
      const sosStatus = await sosService.getSOSStatus(sosId);
      if (!sosStatus || sosStatus.status === 'RESOLVED') {
        console.log(`[Escalation Worker] SOS ${sosId} already resolved, skipping escalation`);
        return;
      }

      // Escalate to next contact
      await sosService.escalate(sosId, contactIndex);

      // escalate() moves to the next contact, or to emergency services after the last one
      console.log(`[Escalation Worker] Escalation step done for SOS ${sosId} (from contact index ${contactIndex})`);
    } catch (error) {
      console.error(`[Escalation Worker] Error processing escalation for SOS ${sosId}:`, error);
      throw error; // BullMQ will retry
    }
  },
  {
    connection: redisConnection as any,
    concurrency: 5, // Process 5 jobs concurrently
    limiter: {
      max: 10,
      duration: 1000, // Max 10 jobs per second
    },
  }
);

escalationWorker.on('completed', (job) => {
  console.log(`[Escalation Worker] Job ${job.id} completed`);
});

escalationWorker.on('failed', (job, err) => {
  console.error(`[Escalation Worker] Job ${job?.id} failed:`, err);
});

escalationWorker.on('error', (err) => {
  console.error('[Escalation Worker] Worker error:', err);
});

console.log('✅ Escalation Worker started');

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down Escalation Worker...');
  await escalationWorker.close();
  process.exit(0);
});

export default escalationWorker;

