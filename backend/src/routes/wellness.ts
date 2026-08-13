import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth';
import Wellness from '../models/Wellness';

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

export default router;
