import { Worker, Job } from 'bullmq';
import sosService from '../services/sosService';
import { redisConnection } from '../config/queues';
import EmergencyContact from '../models/EmergencyContact';

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

      console.log(`[Escalation Worker] Successfully escalated SOS ${sosId} to contact ${contactIndex + 1}`);
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

