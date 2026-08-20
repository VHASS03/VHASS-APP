import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth';
import Wellness from '../models/Wellness';
import Counsellor from '../models/Counsellor';
import Appointment from '../models/Appointment';
import WellnessEvent from '../models/WellnessEvent';

const router = Router();

// Apply authentication to all wellness endpoints
router.use(authenticate);

/**
 * GET /api/wellness
 * Fetch wellness profile and all logs for logged-in user
 */
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    let wellness = await Wellness.findOne({ userId });
    if (!wellness) {
      wellness = await Wellness.create({
        userId,
        cycleLength: 28,
        periodLength: 5,
        healthCondition: 'None',
        setupDone: false,
        periodLogs: [],
        dailyLogs: [],
        cycleHistory: [],
      });
    }

    res.json({
      success: true,
      data: wellness,
    });
  } catch (error) {
    console.error('Error fetching wellness profile:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * PUT /api/wellness/settings
 * Update wellness settings / onboarding setup
 */
router.put('/settings', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { cycleLength, periodLength, lastPeriodDate, healthCondition, setupDone } = req.body;

    const updateData: Record<string, any> = {};
    if (cycleLength !== undefined) updateData.cycleLength = cycleLength;
    if (periodLength !== undefined) updateData.periodLength = periodLength;
    if (lastPeriodDate !== undefined) updateData.lastPeriodDate = lastPeriodDate ? new Date(lastPeriodDate) : undefined;
    if (healthCondition !== undefined) updateData.healthCondition = healthCondition;
    if (setupDone !== undefined) updateData.setupDone = setupDone;

    const wellness = await Wellness.findOneAndUpdate(
      { userId },
      { $set: updateData },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      data: wellness,
      message: 'Wellness settings updated successfully',
    });
  } catch (error) {
    console.error('Error updating wellness settings:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/wellness/period-log
 * Add or update a period log
 */
router.post('/period-log', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { date, endDate, flow, symptoms, notes } = req.body;
    if (!date) {
      res.status(400).json({ success: false, message: 'Date is required' });
      return;
    }

    let wellness = await Wellness.findOne({ userId });
    if (!wellness) {
      wellness = new Wellness({ userId });
    }

    const logDate = new Date(date);
    const dateStr = logDate.toISOString().split('T')[0];

    // Remove any existing log for the same date string
    wellness.periodLogs = wellness.periodLogs.filter(
      (log) => new Date(log.date).toISOString().split('T')[0] !== dateStr
    );

    wellness.periodLogs.push({
      date: logDate,
      endDate: endDate ? new Date(endDate) : undefined,
      flow: flow || 'medium',
      symptoms: Array.isArray(symptoms) ? symptoms : [],
      notes: notes || '',
    });

    await wellness.save();

    res.json({
      success: true,
      data: wellness,
      message: 'Period log saved successfully',
    });
  } catch (error) {
    console.error('Error saving period log:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * DELETE /api/wellness/period-log/:date
 * Delete a period log for a given date
 */
router.delete('/period-log/:date', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { date } = req.params;
    const targetDateStr = new Date(date).toISOString().split('T')[0];

    const wellness = await Wellness.findOne({ userId });
    if (wellness) {
      wellness.periodLogs = wellness.periodLogs.filter(
        (log) => new Date(log.date).toISOString().split('T')[0] !== targetDateStr
      );
      await wellness.save();
    }

    res.json({
      success: true,
      message: 'Period log deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting period log:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * DELETE /api/wellness/daily-log/:date
 * Delete a daily log for a given date
 */
router.delete('/daily-log/:date', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { date } = req.params;
    const targetDateStr = new Date(date).toISOString().split('T')[0];

    const wellness = await Wellness.findOne({ userId });
    if (wellness) {
      wellness.dailyLogs = wellness.dailyLogs.filter(
        (log) => new Date(log.date).toISOString().split('T')[0] !== targetDateStr
      );
      await wellness.save();
    }

    res.json({
      success: true,
      message: 'Daily log deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting daily log:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/wellness/daily-log
 * Add or update a daily log
 */
router.post('/daily-log', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { date, mood, energyLevel, symptoms, notes, waterIntake } = req.body;
    if (!date) {
      res.status(400).json({ success: false, message: 'Date is required' });
      return;
    }

    let wellness = await Wellness.findOne({ userId });
    if (!wellness) {
      wellness = new Wellness({ userId });
    }

    const logDate = new Date(date);
    const dateStr = logDate.toISOString().split('T')[0];

    wellness.dailyLogs = wellness.dailyLogs.filter(
      (log) => new Date(log.date).toISOString().split('T')[0] !== dateStr
    );

    wellness.dailyLogs.push({
      date: logDate,
      mood,
      energyLevel: energyLevel ? Number(energyLevel) : undefined,
      symptoms: Array.isArray(symptoms) ? symptoms : [],
      notes: notes || '',
      waterIntake: waterIntake ? Number(waterIntake) : 0,
    });

    await wellness.save();

    res.json({
      success: true,
      data: wellness,
      message: 'Daily log saved successfully',
    });
  } catch (error) {
    console.error('Error saving daily log:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/wellness/sync
 * Bulk sync local offline data with backend database
 */
router.post('/sync', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { settings, periodLogs, dailyLogs, cycleHistory } = req.body;

    let wellness = await Wellness.findOne({ userId });
    if (!wellness) {
      wellness = new Wellness({ userId });
    }

    if (settings) {
      if (settings.cycleLength) wellness.cycleLength = settings.cycleLength;
      if (settings.periodLength) wellness.periodLength = settings.periodLength;
      if (settings.lastPeriodDate) wellness.lastPeriodDate = new Date(settings.lastPeriodDate);
      if (settings.healthCondition) wellness.healthCondition = settings.healthCondition;
      if (settings.setupDone !== undefined) wellness.setupDone = settings.setupDone;
    }

    if (Array.isArray(periodLogs) && periodLogs.length > 0) {
      const existingDates = new Set(
        wellness.periodLogs.map((l) => new Date(l.date).toISOString().split('T')[0])
      );
      for (const item of periodLogs) {
        const itemDateStr = new Date(item.date).toISOString().split('T')[0];
        if (!existingDates.has(itemDateStr)) {
          wellness.periodLogs.push({
            date: new Date(item.date),
            endDate: item.endDate ? new Date(item.endDate) : undefined,
            flow: item.flow || 'medium',
            symptoms: Array.isArray(item.symptoms) ? item.symptoms : [],
            notes: item.notes || '',
          });
        }
      }
    }

    if (Array.isArray(dailyLogs) && dailyLogs.length > 0) {
      const existingDailyDates = new Set(
        wellness.dailyLogs.map((l) => new Date(l.date).toISOString().split('T')[0])
      );
      for (const item of dailyLogs) {
        const itemDateStr = new Date(item.date).toISOString().split('T')[0];
        if (!existingDailyDates.has(itemDateStr)) {
          wellness.dailyLogs.push({
            date: new Date(item.date),
            mood: item.mood,
            energyLevel: item.energyLevel,
            symptoms: Array.isArray(item.symptoms) ? item.symptoms : [],
            notes: item.notes || '',
            waterIntake: item.waterIntake || 0,
          });
        }
      }
    }

    if (Array.isArray(cycleHistory) && cycleHistory.length > 0) {
      wellness.cycleHistory = cycleHistory.map((c: any) => ({
        startDate: new Date(c.startDate),
        endDate: c.endDate ? new Date(c.endDate) : undefined,
        cycleLength: c.cycleLength || 28,
        periodLength: c.periodLength || 5,
      }));
    }

    await wellness.save();

    res.json({
      success: true,
      data: wellness,
      message: 'Data synced successfully',
    });
  } catch (error) {
    console.error('Error syncing wellness data:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * GET /api/wellness/counsellors
 * Fetch list of counsellors from database
 */
router.get('/counsellors', async (req: Request, res: Response): Promise<void> => {
  try {
    let list = await Counsellor.find().lean();
    if (list.length === 0) {
      // Seed default counsellors if database has none
      list = await Counsellor.insertMany([
        {
          name: 'Dr. Elena Gilbert',
          specialization: 'Anxiety & Depression Specialist',
          imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=150',
          rating: 4.9,
          availability: ['09:00 AM', '10:00 AM', '11:30 AM', '02:00 PM', '04:00 PM'],
          email: 'elena.g@university.edu',
        },
        {
          name: 'Dr. Alaric Saltzman',
          specialization: 'Stress Management & Academics Specialist',
          imageUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=150',
          rating: 4.8,
          availability: ['10:30 AM', '11:00 AM', '01:00 PM', '03:00 PM', '05:00 PM'],
          email: 'alaric.s@university.edu',
        },
        {
          name: 'Dr. Stefan Salvatore',
          specialization: 'Crisis Intervention & Relationships Counsel',
          imageUrl: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=150',
          rating: 4.7,
          availability: ['09:30 AM', '12:00 PM', '02:30 PM', '03:30 PM', '04:30 PM'],
          email: 'stefan.s@university.edu',
        },
      ]) as any;
    }

    res.json({
      success: true,
      data: list,
    });
  } catch (error) {
    console.error('Error fetching counsellors:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * GET /api/wellness/appointments
 * Fetch logged in user's appointments
 */
router.get('/appointments', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const appointments = await Appointment.find({ studentId: userId })
      .populate('counsellorId')
      .sort({ date: -1 })
      .lean();

    res.json({
      success: true,
      data: appointments,
    });
  } catch (error) {
    console.error('Error fetching appointments:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/wellness/appointments
 * Book a new counselling appointment
 */
router.post('/appointments', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { counsellorId, studentName, studentPhone, concern, date, timeSlot, isHighPriority } = req.body;

    if (!counsellorId || !studentName || !studentPhone || !concern || !date || !timeSlot) {
      res.status(400).json({ success: false, message: 'Missing required appointment details' });
      return;
    }

    const newAppointment = await Appointment.create({
      studentId: userId,
      counsellorId,
      studentName,
      studentPhone,
      concern,
      date: new Date(date),
      timeSlot,
      isHighPriority: !!isHighPriority,
      status: 'Pending',
    });

    const populated = await Appointment.findById(newAppointment._id).populate('counsellorId').lean();

    res.json({
      success: true,
      data: populated,
      message: 'Appointment booked successfully',
    });
  } catch (error) {
    console.error('Error booking appointment:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * PUT /api/wellness/appointments/:id
 * Reschedule or update appointment status
 */
router.put('/appointments/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const { status, date, timeSlot } = req.body;

    const update: Record<string, any> = {};
    if (status !== undefined) update.status = status;
    if (date !== undefined) update.date = new Date(date);
    if (timeSlot !== undefined) update.timeSlot = timeSlot;

    const updated = await Appointment.findOneAndUpdate(
      { _id: id, studentId: userId },
      { $set: update },
      { new: true }
    ).populate('counsellorId').lean();

    if (!updated) {
      res.status(404).json({ success: false, message: 'Appointment not found' });
      return;
    }

    res.json({
      success: true,
      data: updated,
      message: 'Appointment updated successfully',
    });
  } catch (error) {
    console.error('Error updating appointment:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * GET /api/wellness/events
 * Fetch wellness events from database (returns [] if none in DB)
 */
router.get('/events', async (req: Request, res: Response): Promise<void> => {
  try {
    const events = await WellnessEvent.find().sort({ date: 1 }).lean();
    res.json({
      success: true,
      data: events,
    });
  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/wellness/events/:id/register
 * Register logged in user for an event
 */
router.post('/events/:id/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const event = await WellnessEvent.findById(id);
    if (!event) {
      res.status(404).json({ success: false, message: 'Event not found' });
      return;
    }

    if (!event.registeredUsers.includes(userId as any)) {
      event.registeredUsers.push(userId as any);
      await event.save();
    }

    res.json({
      success: true,
      message: 'Successfully registered for event',
      data: event,
    });
  } catch (error) {
    console.error('Error registering for event:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

export default router;
