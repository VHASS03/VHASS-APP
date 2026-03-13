import SOS from '../models/SOS';
import SOSState from '../models/SOSState';
import EmergencyContact from '../models/EmergencyContact';
import User from '../models/User';
import { SOSStatus, DeviceInstruction } from '../types';
import redisClient from '../config/redis';
import { escalationQueue } from '../config/queues';
import Log, { ILog } from '../models/Log';
import { LogType } from '../types';

// Extend global type for app reference
declare global {
  var app: any;
}

/**
 * SOS Service
 * Manages SOS lifecycle and escalation logic
 */
class SOSService {
  /**
   * "Re-trigger" an already active SOS:
   * - refresh startedAt so dashboards show a recent timestamp
   * - refresh Redis + SOSState mirror
   * This does NOT notify contacts again.
   */
  async touchActiveSOS(userId: string): Promise<{ sosId: string } | null> {
    const activeSOS = await SOS.findOne({
      userId,
      status: {
        $in: [
          SOSStatus.TRIGGERED,
          SOSStatus.CONTACTING,
          SOSStatus.RESPONDER_ASSIGNED,
          SOSStatus.ACTIVE,
        ],
      },
    }).populate('userId', 'name');

    if (!activeSOS) return null;

    // Refresh startedAt to "now" for UI recency
    activeSOS.startedAt = new Date();
    await activeSOS.save();

    const userName = (activeSOS.userId as any)?.name || 'User';
    const state = {
      sosId: activeSOS._id.toString(),
      userId: activeSOS.userId.toString(),
      deviceId: activeSOS.deviceId,
      status: activeSOS.status,
      currentContactIndex: activeSOS.currentContactIndex,
      startedAt: activeSOS.startedAt.toISOString(),
      userName,
    };

    await redisClient.setSOSState(
      activeSOS._id.toString(),
      JSON.stringify(state),
      parseInt(process.env.SOS_MAX_DURATION_SECONDS || '3600')
    );

    await SOSState.findOneAndUpdate(
      { sosId: activeSOS._id.toString() },
      {
        sosId: activeSOS._id.toString(),
        userId: activeSOS.userId.toString(),
        deviceId: activeSOS.deviceId,
        status: activeSOS.status,
        currentContactIndex: activeSOS.currentContactIndex,
        startedAt: activeSOS.startedAt,
        userName,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    return { sosId: activeSOS._id.toString() };
  }

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

    const ttl = parseInt(process.env.SOS_MAX_DURATION_SECONDS || '3600');

    await redisClient.setSOSState(sos._id.toString(), JSON.stringify(sosState), ttl);

    await SOSState.findOneAndUpdate(
      { sosId: sos._id.toString() },
      {
        sosId: sos._id.toString(),
        userId,
        deviceId,
        status: SOSStatus.TRIGGERED,
        currentContactIndex: 0,
        startedAt: sos.startedAt,
        userName,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
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

    // Generate instructions for ALL contacts simultaneously (conference-style)
    // Instead of calling one-by-one, we contact everyone at once
    const allInstructions: DeviceInstruction[] = [];
    contacts.forEach((contact, index) => {
      const contactInstructions = this.generateContactInstructions(
        sos._id.toString(), 
        contact, 
        index, 
        userName
      );
      allInstructions.push(...contactInstructions);
    });

    console.log(`🚨 CONFERENCE MODE: Generated instructions for ALL ${contacts.length} contacts`);

    // No escalation queue needed - all contacts are called simultaneously
    // The escalation is now handled by the app calling everyone at once

    // Update status to CONTACTING
    sos.status = SOSStatus.CONTACTING;
    await sos.save();

    return {
      sosId: sos._id.toString(),
      userName,
      instructions: allInstructions,
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
    }).populate('userId', 'name');

    if (!activeSOS) {
      return null;
    }

    // Ensure SOSState mirror exists/updated even for previously created SOS
    const userName = (activeSOS.userId as any)?.name || 'User';
    await SOSState.findOneAndUpdate(
      { sosId: activeSOS._id.toString() },
      {
        sosId: activeSOS._id.toString(),
        userId: activeSOS.userId.toString(),
        deviceId: activeSOS.deviceId,
        status: activeSOS.status,
        currentContactIndex: activeSOS.currentContactIndex,
        startedAt: activeSOS.startedAt,
        userName,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

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

      await SOSState.findOneAndUpdate(
        { sosId },
        {
          sosId,
          userId: sos.userId.toString(),
          deviceId: sos.deviceId,
          status: SOSStatus.CONTACTING,
          currentContactIndex: nextContactIndex,
          startedAt: sos.startedAt,
          userName: (sos as any).userId?.name || 'User',
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
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
   * NOW AUTOMATICALLY SENDS MAP LINK TO ALL CONTACTS!
   */
  async updateLocation(
    sosId: string,
    location: { latitude: number; longitude: number; accuracy?: number; address?: string }
  ): Promise<void> {
    try {
      const sos = await SOS.findById(sosId).populate('userId');

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
      }
      
      // AUTOMATICALLY send location update to ALL contacts as map link!
      // This ensures contacts always get the latest location without needing to view map
      const user = await User.findById(sos.userId);
      const userName = user?.name || 'User';
      
      await this.sendLocationUpdateToContacts(
        sosId,
        sos.userId.toString(),
        userName,
        location.latitude,
        location.longitude
      );
      
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
   * 
   * FEATURES:
   * - Sends Google Maps link automatically (not just coordinates)
   * - Triggers ALARM notification (loud even on silent)
   * - Sends location as clickable link in SMS
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

      // Generate Google Maps link (clickable!)
      const mapsLink = latitude && longitude 
        ? `https://maps.google.com/?q=${latitude},${longitude}`
        : null;

      const alertPayload = {
        sosId,
        userId,
        userName,
        latitude: latitude || null,
        longitude: longitude || null,
        mapsLink,  // Include clickable map link!
        timestamp: new Date().toISOString(),
        message: `🚨 ${userName} has triggered an emergency alert!`,
        isAlarm: true,  // Flag to trigger LOUD alarm on client
        priority: 'critical',
      };

      // SMS message with CLICKABLE MAP LINK
      const smsMessage = `🚨🚨 EMERGENCY ALERT 🚨🚨\n\n` +
        `${userName} needs IMMEDIATE help!\n\n` +
        `📍 LOCATION:\n${mapsLink || 'Location being determined...'}\n\n` +
        `⚠️ Call them NOW or go to their location!\n` +
        `If no response, call 112 immediately.`;

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
            
            // Send ALARM alert (will trigger loud notification on app)
            io.to(contactUserAlertRoom).emit('sos:alert-received', alertPayload);
            
            // Also send as separate alarm event for priority handling
            io.to(contactUserAlertRoom).emit('sos:alarm', {
              ...alertPayload,
              alarmType: 'EMERGENCY_SOS',
              soundEnabled: true,
              vibrationEnabled: true,
              overrideSilentMode: true,  // Play even on silent!
            });

            console.log(`[SOS] 🚨 ALARM alert sent to contact ${contact.name}`);
          }

          // Send SMS to contact with MAP LINK (regardless of whether they're registered or not)
          // This is critical for non-registered emergency contacts
          await this.sendSMSAlert(contact.phone, smsMessage, contact.name);
          
          console.log(`[SOS] 📱 SMS with map link sent to ${contact.name}`);
        } catch (error) {
          console.error(`[SOS] Failed to notify contact ${contact.name}:`, error);
        }
      }

      // Log notification
      await this.logEvent({
        userId,
        sosId,
        logType: LogType.SOS_TRIGGER,
        message: `Alerts sent to ${contacts.length} emergency contacts with map link`,
        metadata: { contactCount: contacts.length, mapsLink },
      });
      
      console.log(`[SOS] ✅ All contacts notified with map: ${mapsLink}`);
    } catch (error) {
      console.error('[SOS] Error notifying emergency contacts:', error);
      // Don't throw - this is non-critical
    }
  }
  
  /**
   * Send location update to all contacts (called periodically during active SOS)
   * Automatically sends map link as a message
   */
  async sendLocationUpdateToContacts(
    sosId: string,
    userId: string,
    userName: string,
    latitude: number,
    longitude: number
  ): Promise<void> {
    try {
      const contacts = await EmergencyContact.find({ userId, isActive: true });
      const app = global.app as any;
      const io = app?.get?.('io');
      
      const mapsLink = `https://maps.google.com/?q=${latitude},${longitude}`;
      
      const locationUpdate = {
        sosId,
        userId,
        userName,
        latitude,
        longitude,
        mapsLink,
        timestamp: new Date().toISOString(),
        type: 'location_update',
      };
      
      for (const contact of contacts) {
        const contactUser = await User.findOne({ 
          phone: contact.phone.replace(/\D/g, '').slice(-10)
        });
        
        if (contactUser && io) {
          const contactUserAlertRoom = `user-alerts:${contactUser._id.toString()}`;
          io.to(contactUserAlertRoom).emit('sos:location-update', locationUpdate);
        }
      }
      
      console.log(`[SOS] 📍 Location update sent: ${mapsLink}`);
    } catch (error) {
      console.error('[SOS] Error sending location update:', error);
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

