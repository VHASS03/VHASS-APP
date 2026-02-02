import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import EmergencyContact from '../models/EmergencyContact';
import { authenticate } from '../middleware/auth';

const router = Router();

/**
 * GET /api/contacts
 * Get all emergency contacts for authenticated user
 */
router.get('/', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.user!;

    const contacts = await EmergencyContact.find({
      userId,
      isActive: true,
    }).sort({ priority: 1 });

    res.json({
      success: true,
      contacts,
    });
  } catch (error: any) {
    console.error('Get contacts error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/contacts
 * Add emergency contact (max 3)
 */
router.post(
  '/',
  authenticate,
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('phone').isLength({ min: 10, max: 10 }).withMessage('Phone must be 10 digits'),
    body('priority').isInt({ min: 1, max: 3 }).withMessage('Priority must be 1-3'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { userId } = req.user!;
      const { name, phone, priority } = req.body;

      // Check max contacts
      const contactCount = await EmergencyContact.countDocuments({
        userId,
        isActive: true,
      });

      if (contactCount >= 3) {
        res.status(400).json({
          success: false,
          message: 'Maximum 3 emergency contacts allowed',
        });
        return;
      }

      // Check if priority already exists
      const existingPriority = await EmergencyContact.findOne({
        userId,
        priority,
        isActive: true,
      });

      if (existingPriority) {
        res.status(400).json({
          success: false,
          message: `Priority ${priority} already assigned`,
        });
        return;
      }

      const contact = await EmergencyContact.create({
        userId,
        name,
        phone,
        priority,
      });

      res.status(201).json({
        success: true,
        message: 'Emergency contact added',
        contact,
      });
    } catch (error: any) {
      console.error('Add contact error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * PUT /api/contacts/:id
 * Update emergency contact
 */
router.put(
  '/:id',
  authenticate,
  [
    body('name').optional().notEmpty(),
    body('phone').optional().isLength({ min: 10, max: 10 }),
    body('priority').optional().isInt({ min: 1, max: 3 }),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { userId } = req.user!;
      const { id } = req.params;
      const updates = req.body;

      const contact = await EmergencyContact.findOne({
        _id: id,
        userId,
        isActive: true,
      });

      if (!contact) {
        res.status(404).json({ success: false, message: 'Contact not found' });
        return;
      }

      Object.assign(contact, updates);
      await contact.save();

      res.json({
        success: true,
        message: 'Contact updated',
        contact,
      });
    } catch (error: any) {
      console.error('Update contact error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * DELETE /api/contacts/:id
 * Delete emergency contact
 */
router.delete('/:id', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.user!;
    const { id } = req.params;

    const contact = await EmergencyContact.findOne({
      _id: id,
      userId,
    });

    if (!contact) {
      res.status(404).json({ success: false, message: 'Contact not found' });
      return;
    }

    contact.isActive = false;
    await contact.save();

    res.json({
      success: true,
      message: 'Contact deleted',
    });
  } catch (error: any) {
    console.error('Delete contact error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

export default router;

