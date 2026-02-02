import SOS from '../models/SOS';
import EmergencyContact from '../models/EmergencyContact';
import User from '../models/User';
import { SOSStatus, DeviceInstruction } from '../types';
import redisClient from '../config/redis';
import { escalationQueue } from '../config/queues';
import Log, { ILog } from '../models/Log';
import { LogType } from '../types';

/**
 * SOS Service
 * Manages SOS lifecycle and escalation logic
 */
class SOSService {
  /**
   * Trigger new SOS event
   * Only ONE active SOS per user allowed
   */
  async triggerSOS(
    userId: string,
    deviceId: string,
    initialLocation?: { latitude: number; longitude: number }
  ): Promise<{ sosId: string; userName: string; instructions: DeviceInstruction[] }> {
    // Check for existing active SOS
    const existingSOS = await SOS.findOne({
      userId,
      status: { $in: [SOSStatus.TRIGGERED, SOSStatus.CONTACTING, SOSStatus.RESPONDER_ASSIGNED, SOSStatus.ACTIVE] },
    });

    if (existingSOS) {
      throw new Error('SOS already active');
    }

    // Get user name for notification
    const user = await User.findById(userId);
    const userName = user?.name || 'User';

    // Get emergency contacts
    const contacts = await EmergencyContact.find({
      userId,
      isActive: true,
    }).sort({ priority: 1 });

    if (contacts.length === 0) {
      throw new Error('No emergency contacts configured');
    }

    // Create SOS record
    const sos = new SOS({
      userId,
      deviceId,
      status: SOSStatus.TRIGGERED,
      currentContactIndex: 0,
      locations: initialLocation
        ? [
            {
              latitude: initialLocation.latitude,
              longitude: initialLocation.longitude,
              timestamp: new Date(),
            },
          ]
        : [],
    });

    await sos.save();

    // Store SOS state in Redis for fast access
    const sosState = {
      sosId: sos._id.toString(),
      userId,
      deviceId,
      status: SOSStatus.TRIGGERED,
      currentContactIndex: 0,
      startedAt: sos.startedAt.toISOString(),
      userName,
    };

    await redisClient.setSOSState(
      sos._id.toString(),
      JSON.stringify(sosState),
      parseInt(process.env.SOS_MAX_DURATION_SECONDS || '3600')
    );

    // Log SOS trigger
    await this.logEvent({
      userId,
      deviceId,
      sosId: sos._id,
      logType: LogType.SOS_TRIGGER,
      message: 'SOS triggered',
      metadata: { location: initialLocation },
    });

    // Generate initial instructions (contact first priority)
    const instructions = this.generateContactInstructions(sos._id.toString(), contacts[0], 0, userName);

    // Schedule escalation job (BullMQ)
    const escalationDelay = parseInt(process.env.SOS_ESCALATION_DELAY_SECONDS || '30') * 1000;
    await escalationQueue.add(
      `escalate-${sos._id}`,
      {
        sosId: sos._id.toString(),
        userId,
        contactIndex: 0,
      },
      {
        delay: escalationDelay,
        jobId: `escalate-${sos._id}-0`,
      }
    );

    // Update status to CONTACTING
    sos.status = SOSStatus.CONTACTING;
    await sos.save();

    return {
      sosId: sos._id.toString(),
      userName,
      instructions,
    };
  }

  /**
   * Generate device instructions for contacting emergency contact
   */
  private generateContactInstructions(
    sosId: string,
    contact: any,
    priority: number,
    userName: string = 'User'
  ): DeviceInstruction[] {
    const instructions: DeviceInstruction[] = [];

    // Get country code from contact or default to 'IN' (India)
    const countryCode = contact.countryCode || 'IN';

    // Primary instruction: CALL
    instructions.push({
      action: 'CALL',
      phoneNumber: contact.phone,
      contactName: contact.name,
      priority,
      sosId,
      countryCode,
    });

    // Secondary instruction: SEND SMS (parallel)
    instructions.push({
      action: 'SEND_SMS',
      phoneNumber: contact.phone,
      message: `🚨 EMERGENCY ALERT! 🚨\n${userName} is in an EMERGENCY situation! Please respond immediately and call them back. Their location is being shared.`,
      contactName: contact.name,
      sosId,
      countryCode,
    });

    return instructions;
  }

  /**
   * Get active SOS for a user (if any)
   */
  async getActiveSOS(userId: string): Promise<{ sosId: string } | null> {
    const activeSOS = await SOS.findOne({
      userId,
      status: { $in: [SOSStatus.TRIGGERED, SOSStatus.CONTACTING, SOSStatus.RESPONDER_ASSIGNED, SOSStatus.ACTIVE] },
    });

    if (!activeSOS) {
      return null;
    }

    return { sosId: activeSOS._id.toString() };
  }

  /**
   * Handle escalation to next contact or emergency services
   */
  async escalate(sosId: string, currentContactIndex: number): Promise<void> {
    const sos = await SOS.findById(sosId).populate('userId');

    if (!sos || sos.status === SOSStatus.RESOLVED) {
      return; // SOS already resolved
    }

    const contacts = await EmergencyContact.find({
      userId: sos.userId,
      isActive: true,
    }).sort({ priority: 1 });

    // Check if we've exhausted all contacts
    if (currentContactIndex >= contacts.length - 1) {
      // Escalate to emergency number
      await this.escalateToEmergency(sosId);
      return;
    }

    // Move to next contact
    const nextContactIndex = currentContactIndex + 1;
    sos.currentContactIndex = nextContactIndex;
    sos.status = SOSStatus.CONTACTING;
    await sos.save();

    // Update Redis state
    const sosState = await redisClient.getSOSState(sosId);
    if (sosState) {
      const state = JSON.parse(sosState);
      state.currentContactIndex = nextContactIndex;
      state.status = SOSStatus.CONTACTING;
      await redisClient.setSOSState(sosId, JSON.stringify(state));
    }

    // Log escalation
    await this.logEvent({
      userId: sos.userId.toString(),
      sosId: sos._id,
      logType: LogType.ESCALATION,
      message: `Escalated to contact ${nextContactIndex + 1}`,
      metadata: { contactIndex: nextContactIndex },
    });

    // Schedule next escalation
    const escalationDelay = parseInt(process.env.SOS_ESCALATION_DELAY_SECONDS || '30') * 1000;
    await escalationQueue.add(
      `escalate-${sosId}`,
      {
        sosId,
        userId: sos.userId.toString(),
        contactIndex: nextContactIndex,
      },
      {
        delay: escalationDelay,
        jobId: `escalate-${sosId}-${nextContactIndex}`,
      }
    );
  }

  /**
   * Escalate to emergency services (112 or country-specific)
   */
  private async escalateToEmergency(sosId: string): Promise<void> {
    const sos = await SOS.findById(sosId);

    if (!sos) return;

    sos.status = SOSStatus.ACTIVE;
    await sos.save();

    // Log emergency escalation
    await this.logEvent({
      userId: sos.userId.toString(),
      sosId: sos._id,
      logType: LogType.ESCALATION,
      message: 'Escalated to emergency services',
      metadata: { emergencyNumber: process.env.EMERGENCY_NUMBER || '112' },
    });

    // Add emergency number call instruction to queue
    // This will be picked up by worker and sent to device
  }

  /**
   * Report call/SMS attempt result from device
   */
  async reportCallResult(
    sosId: string,
    contactId: string,
    instructionType: 'CALL' | 'SMS',
    success: boolean,
    responded: boolean = false
  ): Promise<void> {
    const sos = await SOS.findById(sosId);

    if (!sos) return;

    // Update escalation history
    sos.escalationHistory.push({
      contactId: contactId as any,
      attemptedAt: new Date(),
      responded,
      instructionType,
    });

    await sos.save();

    // Log attempt
    await this.logEvent({
      userId: sos.userId.toString(),
      sosId: sos._id,
      logType: instructionType === 'CALL' ? LogType.CALL_ATTEMPT : LogType.SMS_ATTEMPT,
      message: `${instructionType} attempt ${success ? 'succeeded' : 'failed'}`,
      metadata: { contactId, responded },
    });

    // If contact responded, mark as responder assigned
    if (responded && sos.status === SOSStatus.CONTACTING) {
      sos.status = SOSStatus.RESPONDER_ASSIGNED;
      await sos.save();

      // Cancel pending escalation jobs for this contact
      const jobs = await escalationQueue.getJobs(['delayed', 'waiting']);
      for (const job of jobs) {
        if (job.data.sosId === sosId && job.data.contactIndex === sos.currentContactIndex) {
          await job.remove();
        }
      }
    }
  }

  /**
   * End SOS (resolve or cancel)
   */
  async endSOS(
    sosId: string,
    deviceId: string,
    reason: 'RESOLVED' | 'CANCELLED',
    finalLocation?: { latitude: number; longitude: number }
  ): Promise<void> {
    const sos = await SOS.findById(sosId);

    if (!sos) {
      throw new Error('SOS not found');
    }

    // Verify cancellation from same device
    if (reason === 'CANCELLED') {
      const sosDevice = await SOS.findById(sosId).populate('deviceId');
      if (sos.deviceId.toString() !== deviceId) {
        throw new Error('SOS can only be cancelled from the triggering device');
      }
    }

    sos.status = SOSStatus.RESOLVED;
    sos.resolvedAt = new Date();

    if (reason === 'CANCELLED') {
      sos.cancelledAt = new Date();
      sos.cancellationDeviceId = deviceId as any;
    }

    if (finalLocation) {
      sos.finalLocation = {
        latitude: finalLocation.latitude,
        longitude: finalLocation.longitude,
        timestamp: new Date(),
      };
    }

    await sos.save();

    // Remove from Redis
    await redisClient.deleteSOSState(sosId);

    // Cancel all pending escalation jobs
    const jobs = await escalationQueue.getJobs(['delayed', 'waiting', 'active']);
    for (const job of jobs) {
      if (job.data.sosId === sosId) {
        await job.remove();
      }
    }

    // Log end event
    await this.logEvent({
      userId: sos.userId.toString(),
      deviceId,
      sosId: sos._id,
      logType: LogType.SOS_END,
      message: `SOS ended: ${reason}`,
      metadata: { reason, finalLocation },
    });
  }

  /**
   * Update SOS location
   */
  async updateLocation(
    sosId: string,
    location: { latitude: number; longitude: number; accuracy?: number; address?: string }
  ): Promise<void> {
    try {
      const sos = await SOS.findById(sosId);

      if (!sos) {
        console.error(`[updateLocation] SOS not found: ${sosId}`);
        throw new Error(`SOS record not found: ${sosId}`);
      }

      console.log(`[updateLocation] Updating SOS ${sosId} with location:`, location);

      // Ensure locations array exists
      if (!sos.locations) {
        sos.locations = [];
      }

      sos.locations.push({
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        timestamp: new Date(),
        address: location.address,
      });

      const saved = await sos.save();
      console.log(`[updateLocation] SOS saved successfully, total locations: ${saved.locations.length}`);

      // Update Redis cache
      try {
        await redisClient.setLocation(
          sos.userId.toString(),
          JSON.stringify(location),
          300
        );
      } catch (redisError) {
        console.error('[updateLocation] Redis cache error:', redisError);
        // Don't fail the entire operation if Redis fails
      }
    } catch (error) {
      console.error('[updateLocation] Error:', error);
      throw error;
    }
  }

  /**
   * Get current SOS status
   */
  async getSOSStatus(sosId: string): Promise<any> {
    // Try Redis first
    const cachedState = await redisClient.getSOSState(sosId);
    if (cachedState) {
      return JSON.parse(cachedState);
    }

    // Fallback to MongoDB
    const sos = await SOS.findById(sosId);
    if (!sos) return null;

    return {
      sosId: sos._id.toString(),
      userId: sos.userId.toString(),
      status: sos.status,
      currentContactIndex: sos.currentContactIndex,
      startedAt: sos.startedAt,
    };
  }

  /**
   * Log event helper
   */
  private async logEvent(logData: Partial<ILog>): Promise<void> {
    try {
      const log = new Log({
        ...logData,
        timestamp: new Date(),
      });
      await log.save();
    } catch (error) {
      console.error('Logging error:', error);
      // Don't throw - logging failures shouldn't break the app
    }
  }

  /**
   * Deactivate SOS using PIN verification
   */
  async deactivateWithPIN(sosId: string, userId: string, deviceId: string, pin: string): Promise<any> {
    // Get User model
    const User = require('../models/User').default;
    
    // Find SOS
    const sos = await SOS.findById(sosId);
    if (!sos) {
      throw new Error('SOS not found');
    }

    // Verify it's the same device that triggered SOS
    if (sos.deviceId !== deviceId) {
      throw new Error('SOS can only be deactivated from the triggering device');
    }

    // Check if SOS is already ended
    if (![SOSStatus.TRIGGERED, SOSStatus.CONTACTING, SOSStatus.RESPONDER_ASSIGNED, SOSStatus.ACTIVE].includes(sos.status)) {
      throw new Error('SOS already ended');
    }

    // Get user
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Verify PIN (custom if set, else device PIN - last 4 digits of phone)
    let validPin = false;
    
    if (user.sosPIN) {
      // Custom PIN is set
      validPin = pin === user.sosPIN;
    } else {
      // Use device PIN (last 4 digits of phone)
      const lastFourDigits = user.phoneNumber.slice(-4);
      validPin = pin === lastFourDigits;
    }

    if (!validPin) {
      throw new Error('Invalid PIN');
    }

    // Deactivate SOS
    sos.status = SOSStatus.CANCELLED;
    sos.cancelledAt = new Date();
    sos.cancellationDeviceId = deviceId;
    sos.cancellationReason = 'PIN_DEACTIVATION';
    await sos.save();

    // Remove from Redis
    await redisClient.deleteSOSState(sosId);

    // Log deactivation
    await this.logEvent({
      userId,
      deviceId,
      sosId: sos._id,
      logType: LogType.SOS_DEACTIVATION,
      message: 'SOS deactivated with PIN',
      metadata: { method: 'PIN' },
    });

    return {
      sosId: sos._id.toString(),
      status: sos.status,
      cancelledAt: sos.cancelledAt,
    };
  }

  /**
   * Set user's custom SOS deactivation PIN
   */
  async setSosPin(userId: string, pin: string): Promise<void> {
    const User = require('../models/User').default;

    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    user.sosPIN = pin;
    await user.save();

    // Log PIN change
    await this.logEvent({
      userId,
      logType: LogType.PIN_UPDATE,
      message: 'SOS PIN updated',
    });
  }

  /**
   * Send SOS alert notifications to emergency contacts via Socket.IO and SMS
   * This notifies contacts about the emergency in real-time
   */
  async notifyEmergencyContacts(
    sosId: string,
    userId: string,
    userName: string,
    latitude?: number,
    longitude?: number
  ): Promise<void> {
    try {
      // Get emergency contacts
      const contacts = await EmergencyContact.find({
        userId,
        isActive: true,
      });

      if (contacts.length === 0) {
        console.log('[SOS] No emergency contacts to notify');
        return;
      }

      // Get the io instance from global scope (set in server.ts)
      const app = global.app as any;
      const io = app?.get?.('io');

      const alertPayload = {
        sosId,
        userId,
        userName,
        latitude: latitude || null,
        longitude: longitude || null,
        timestamp: new Date().toISOString(),
        message: `🚨 ${userName} has triggered an emergency alert!`,
      };

      const smsMessage = `🚨 EMERGENCY: ${userName} needs help NOW!\n` +
        `Location: ${latitude && longitude ? `${latitude.toFixed(4)}, ${longitude.toFixed(4)}` : 'Locating...'}\n` +
        `Please respond immediately or call 112`;

      // Send alert to each contact via their user ID rooms
      for (const contact of contacts) {
        try {
          // Find if this contact phone number matches any registered user
          const contactUser = await User.findOne({ 
            phone: contact.phone.replace(/\D/g, '').slice(-10) // Extract last 10 digits
          });

          if (contactUser && io) {
            // Broadcast to contact's user alert room (covers all their devices)
            const contactUserAlertRoom = `user-alerts:${contactUser._id.toString()}`;
            io.to(contactUserAlertRoom).emit('sos:alert-received', alertPayload);

            console.log(`[SOS] Socket alert sent to contact ${contact.name}`);
          }

          // Send SMS to contact (regardless of whether they're registered or not)
          // This is critical for non-registered emergency contacts
          await this.sendSMSAlert(contact.phone, smsMessage, contact.name);
        } catch (error) {
          console.error(`[SOS] Failed to notify contact ${contact.name}:`, error);
        }
      }

      // Log notification
      await this.logEvent({
        userId,
        sosId: new (require('mongoose').Types.ObjectId)(sosId),
        logType: LogType.SOS_TRIGGER,
        message: `Alerts sent to ${contacts.length} emergency contacts`,
        metadata: { contactCount: contacts.length },
      });
    } catch (error) {
      console.error('[SOS] Error notifying emergency contacts:', error);
      // Don't throw - this is non-critical
    }
  }

  /**
   * Send SMS alert to emergency contact
   * Uses Twilio or backend SMS service
   */
  private async sendSMSAlert(phoneNumber: string, message: string, contactName: string): Promise<void> {
    try {
      const formattedPhone = this.formatPhoneNumber(phoneNumber);

      // If using Twilio integration
      const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
      const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
      const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

      if (twilioAccountSid && twilioAuthToken && twilioPhoneNumber) {
        // Use Twilio to send SMS
        const twilio = require('twilio');
        const client = twilio(twilioAccountSid, twilioAuthToken);

        await client.messages.create({
          body: message,
          from: twilioPhoneNumber,
          to: formattedPhone,
        });

        console.log(`[SOS] SMS sent via Twilio to ${contactName} (${formattedPhone})`);
      } else {
        console.log(`[SOS] Twilio not configured - SMS would be sent to ${contactName} (${formattedPhone})`);
        // Log for manual follow-up or use alternative SMS service
      }
    } catch (error) {
      console.error(`[SOS] Failed to send SMS to ${phoneNumber}:`, error);
      // Don't throw - SMS failure shouldn't break alert system
    }
  }

  /**
   * Format phone number to international format
   */
  private formatPhoneNumber(phone: string): string {
    // Remove all non-digits
    const digits = phone.replace(/\D/g, '');

    // If already 12 digits (with +1 country code), return as is
    if (digits.length === 12 && digits.startsWith('1')) {
      return `+${digits}`;
    }

    // If 10 digits (US format), add country code
    if (digits.length === 10) {
      return `+91${digits}`; // Default to India
    }

    // If last 10 digits, add India country code
    if (digits.length > 10) {
      const lastTen = digits.slice(-10);
      return `+91${lastTen}`;
    }

    // Fallback
    return `+${digits}`;
  }
}

export default new SOSService();

