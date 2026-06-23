import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import sosService from '../services/sosService';
import { authenticate } from '../middleware/auth';
import SOS from '../models/SOS';

const router = Router();

/**
 * GET /track/:sosId
 * PUBLIC endpoint - serves a live tracking web page
 * Emergency contacts can view real-time location by clicking this link
 * NO AUTHENTICATION REQUIRED - anyone with the link can view
 */
router.get('/track/:sosId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { sosId } = req.params;
    
    // Get SOS data
    const sos = await SOS.findById(sosId).populate('userId', 'name');
    
    if (!sos) {
      res.status(404).send(generateErrorPage('SOS alert not found', 'This tracking link may have expired or is invalid.'));
      return;
    }
    
    // Get latest location
    const latestLocation = sos.locations && sos.locations.length > 0 
      ? sos.locations[sos.locations.length - 1] 
      : null;
    
    const userName = (sos.userId as any)?.name || 'User';
    const isActive = ['TRIGGERED', 'CONTACTING', 'RESPONDER_ASSIGNED', 'ACTIVE'].includes(sos.status);
    
    // Serve the live tracking HTML page
    res.setHeader('Content-Type', 'text/html');
    res.send(generateTrackingPage(
      sosId,
      userName,
      latestLocation,
      isActive,
      sos.startedAt
    ));
  } catch (error: any) {
    console.error('Track page error:', error);
    res.status(500).send(generateErrorPage('Error loading tracking page', 'Please try again later.'));
  }
});

/**
 * GET /track/:sosId/location
 * API endpoint to get latest location (called by tracking page via AJAX)
 */
router.get('/track/:sosId/location', async (req: Request, res: Response): Promise<void> => {
  try {
    const { sosId } = req.params;
    
    const sos = await SOS.findById(sosId).populate('userId', 'name');
    
    if (!sos) {
      res.status(404).json({ success: false, message: 'SOS not found' });
      return;
    }
    
    const latestLocation = sos.locations && sos.locations.length > 0 
      ? sos.locations[sos.locations.length - 1] 
      : null;
    
    const isActive = ['TRIGGERED', 'CONTACTING', 'RESPONDER_ASSIGNED', 'ACTIVE'].includes(sos.status);
    
    res.json({
      success: true,
      location: latestLocation,
      userName: (sos.userId as any)?.name || 'User',
      status: sos.status,
      isActive,
      locationCount: sos.locations?.length || 0,
      startedAt: sos.startedAt,
    });
  } catch (error: any) {
    console.error('Get location error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * Generate the live tracking HTML page
 */
function generateTrackingPage(
  sosId: string,
  userName: string,
  location: any,
  isActive: boolean,
  startedAt: Date
): string {
  const lat = location?.latitude || 0;
  const lng = location?.longitude || 0;
  const hasLocation = location !== null;
  const accuracy = location?.accuracy || 0;
  
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🚨 LIVE TRACKING - ${userName}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      min-height: 100vh;
      color: white;
    }
    .header {
      background: linear-gradient(90deg, #e74c3c, #c0392b);
      padding: 15px 20px;
      text-align: center;
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      z-index: 1000;
      box-shadow: 0 2px 10px rgba(231, 76, 60, 0.5);
    }
    .header h1 {
      font-size: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
    }
    .pulse {
      width: 12px;
      height: 12px;
      background: #fff;
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(1); opacity: 1; }
      50% { transform: scale(1.3); opacity: 0.7; }
      100% { transform: scale(1); opacity: 1; }
    }
    .status-badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: bold;
      margin-top: 8px;
    }
    .status-active { background: #27ae60; }
    .status-ended { background: #7f8c8d; }
    .map-container {
      position: fixed;
      top: 90px;
      left: 0;
      right: 0;
      bottom: 180px;
    }
    #map {
      width: 100%;
      height: 100%;
    }
    .info-panel {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      background: rgba(26, 26, 46, 0.95);
      padding: 15px 20px;
      border-top-left-radius: 20px;
      border-top-right-radius: 20px;
      backdrop-filter: blur(10px);
    }
    .info-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 12px;
      margin-bottom: 15px;
    }
    .info-item {
      background: rgba(255, 255, 255, 0.1);
      padding: 12px;
      border-radius: 10px;
    }
    .info-label {
      font-size: 11px;
      color: #bdc3c7;
      margin-bottom: 4px;
    }
    .info-value {
      font-size: 14px;
      font-weight: 600;
    }
    .btn-emergency {
      display: block;
      width: 100%;
      padding: 15px;
      background: linear-gradient(90deg, #e74c3c, #c0392b);
      color: white;
      border: none;
      border-radius: 10px;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      text-decoration: none;
      text-align: center;
    }
    .btn-emergency:active { transform: scale(0.98); }
    .last-update {
      text-align: center;
      font-size: 11px;
      color: #7f8c8d;
      margin-top: 10px;
    }
    .refresh-indicator {
      display: inline-block;
      margin-left: 8px;
      width: 8px;
      height: 8px;
      background: #27ae60;
      border-radius: 50%;
      animation: blink 2s infinite;
    }
    @keyframes blink {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.3; }
    }
    .no-location {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      color: #bdc3c7;
    }
    .no-location-icon { font-size: 48px; margin-bottom: 16px; }
  </style>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
  <div class="header">
    <h1>
      <span class="pulse"></span>
      🚨 EMERGENCY - ${userName}
    </h1>
    <div class="status-badge ${isActive ? 'status-active' : 'status-ended'}">
      ${isActive ? '🔴 LIVE TRACKING' : '⚪ ENDED'}
    </div>
  </div>
  
  <div class="map-container">
    <div id="map">
      ${!hasLocation ? `
        <div class="no-location">
          <div class="no-location-icon">📍</div>
          <div>Waiting for location...</div>
          <div style="font-size: 12px; margin-top: 8px;">Location will appear automatically</div>
        </div>
      ` : ''}
    </div>
  </div>
  
  <div class="info-panel">
    <div class="info-grid">
      <div class="info-item">
        <div class="info-label">📍 Latitude</div>
        <div class="info-value" id="lat">${hasLocation ? lat.toFixed(6) : 'Loading...'}</div>
      </div>
      <div class="info-item">
        <div class="info-label">📍 Longitude</div>
        <div class="info-value" id="lng">${hasLocation ? lng.toFixed(6) : 'Loading...'}</div>
      </div>
      <div class="info-item">
        <div class="info-label">📏 Accuracy</div>
        <div class="info-value" id="accuracy">${accuracy > 0 ? accuracy.toFixed(0) + 'm' : '--'}</div>
      </div>
      <div class="info-item">
        <div class="info-label">⏰ Started</div>
        <div class="info-value">${new Date(startedAt).toLocaleTimeString()}</div>
      </div>
    </div>
    
    <a href="tel:112" class="btn-emergency">
      📞 CALL EMERGENCY (112)
    </a>
    
    <div class="last-update">
      Last updated: <span id="lastUpdate">${new Date().toLocaleTimeString()}</span>
      <span class="refresh-indicator"></span>
      Auto-refreshing every 5 seconds
    </div>
  </div>
  
  <script>
    let map = null;
    let marker = null;
    let pathLine = null;
    let pathCoords = [];
    const sosId = '${sosId}';
    const hasInitialLocation = ${hasLocation};
    const initialLat = ${lat};
    const initialLng = ${lng};
    
    // Initialize map
    function initMap() {
      if (hasInitialLocation) {
        map = L.map('map').setView([initialLat, initialLng], 16);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '© OpenStreetMap'
        }).addTo(map);
        
        // Custom emergency marker
        const emergencyIcon = L.divIcon({
          html: '<div style="width: 24px; height: 24px; background: #e74c3c; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 10px rgba(0,0,0,0.3); animation: pulse 1.5s infinite;"></div>',
          className: '',
          iconSize: [24, 24],
          iconAnchor: [12, 12]
        });
        
        marker = L.marker([initialLat, initialLng], { icon: emergencyIcon }).addTo(map);
        marker.bindPopup('<b>${userName}</b><br>Emergency location').openPopup();
        
        pathCoords.push([initialLat, initialLng]);
        pathLine = L.polyline(pathCoords, { color: '#e74c3c', weight: 3 }).addTo(map);
      }
    }
    
    // Fetch latest location
    async function fetchLocation() {
      try {
        const response = await fetch('/api/sos/track/${sosId}/location');
        const data = await response.json();
        
        if (data.success && data.location) {
          const lat = data.location.latitude;
          const lng = data.location.longitude;
          const accuracy = data.location.accuracy || 0;
          
          // Update UI
          document.getElementById('lat').textContent = lat.toFixed(6);
          document.getElementById('lng').textContent = lng.toFixed(6);
          document.getElementById('accuracy').textContent = accuracy > 0 ? accuracy.toFixed(0) + 'm' : '--';
          document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
          
          // Update map
          if (!map && lat && lng) {
            document.getElementById('map').innerHTML = '';
            map = L.map('map').setView([lat, lng], 16);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
              attribution: '© OpenStreetMap'
            }).addTo(map);
            
            const emergencyIcon = L.divIcon({
              html: '<div style="width: 24px; height: 24px; background: #e74c3c; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 10px rgba(0,0,0,0.3);"></div>',
              className: '',
              iconSize: [24, 24],
              iconAnchor: [12, 12]
            });
            
            marker = L.marker([lat, lng], { icon: emergencyIcon }).addTo(map);
            pathLine = L.polyline([[lat, lng]], { color: '#e74c3c', weight: 3 }).addTo(map);
          } else if (map && marker) {
            marker.setLatLng([lat, lng]);
            map.panTo([lat, lng]);
            
            // Add to path
            pathCoords.push([lat, lng]);
            if (pathLine) {
              pathLine.setLatLngs(pathCoords);
            }
          }
          
          // Update status
          if (!data.isActive) {
            document.querySelector('.status-badge').textContent = '⚪ ENDED';
            document.querySelector('.status-badge').className = 'status-badge status-ended';
          }
        }
      } catch (error) {
        console.error('Error fetching location:', error);
      }
    }
    
    // Initialize
    initMap();
    
    // Auto-refresh every 5 seconds
    setInterval(fetchLocation, 5000);
  </script>
</body>
</html>`;
}

/**
 * Generate error page
 */
function generateErrorPage(title: string, message: string): string {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Error - VHASS</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      text-align: center;
      padding: 20px;
    }
    .error-container {
      background: rgba(255, 255, 255, 0.1);
      padding: 40px;
      border-radius: 20px;
      max-width: 400px;
    }
    .error-icon { font-size: 48px; margin-bottom: 20px; }
    h1 { font-size: 24px; margin-bottom: 10px; }
    p { color: #bdc3c7; }
  </style>
</head>
<body>
  <div class="error-container">
    <div class="error-icon">⚠️</div>
    <h1>${title}</h1>
    <p>${message}</p>
  </div>
</body>
</html>`;
}

/**
 * POST /api/sos/trigger
 * Trigger new SOS event
 * Returns instructions for device to execute (CALL/SMS)
 */
router.post(
  '/trigger',
  authenticate,
  [
    body('latitude').optional().isFloat().withMessage('Invalid latitude'),
    body('longitude').optional().isFloat().withMessage('Invalid longitude'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { latitude, longitude } = req.body;
      const { userId, deviceId } = req.user!;

      const result = await sosService.triggerSOS(
        userId,
        deviceId,
        latitude && longitude ? { latitude, longitude } : undefined
      );

      // Send alerts to emergency contacts asynchronously (don't wait for it)
      sosService.notifyEmergencyContacts(
        result.sosId,
        userId,
        result.userName,
        latitude,
        longitude
      ).catch((err) => console.error('Failed to notify contacts:', err));

      res.status(201).json({
        success: true,
        message: 'SOS triggered successfully',
        sosId: result.sosId,
        instructions: result.instructions, // Device executes these
      });
    } catch (error: any) {
      if (error.message === 'SOS already active') {
        // Refresh active SOS timestamps so dashboards show "recent" activity
        await sosService.touchActiveSOS(req.user!.userId);

        // Return existing SOS ID so client can use it
        const existingSOS = await sosService.getActiveSOS(req.user!.userId);
        res.status(409).json({ 
          success: false, 
          message: error.message,
          sosId: existingSOS?.sosId || null
        });
        return;
      }
      if (error.message === 'No emergency contacts configured') {
        res.status(400).json({ success: false, message: error.message });
        return;
      }
      console.error('Trigger SOS error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * POST /api/sos/update-location
 * Update SOS location (called periodically during active SOS)
 */
router.post(
  '/update-location',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('latitude').isFloat().withMessage('Invalid latitude'),
    body('longitude').isFloat().withMessage('Invalid longitude'),
    body('accuracy').optional().isFloat(),
    body('address').optional().isString(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, latitude, longitude, accuracy, address } = req.body;
      
      console.log(`[POST /update-location] Received update for SOS ${sosId}:`, { latitude, longitude, accuracy, address });

      await sosService.updateLocation(sosId, {
        latitude,
        longitude,
        accuracy,
        address,
      });

      res.json({
        success: true,
        message: 'Location updated',
      });
    } catch (error: any) {
      console.error('[POST /update-location] Error:', error.message, error.stack);
      res.status(500).json({ 
        success: false, 
        message: 'Server error',
        error: error.message 
      });
    }
  }
);

/**
 * POST /api/sos/report-call-result
 * Device reports result of CALL/SMS instruction
 */
router.post(
  '/report-call-result',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('contactId').notEmpty().withMessage('Contact ID is required'),
    body('instructionType').isIn(['CALL', 'SMS']).withMessage('Invalid instruction type'),
    body('success').isBoolean().withMessage('Success must be boolean'),
    body('responded').optional().isBoolean(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, contactId, instructionType, success, responded } = req.body;

      await sosService.reportCallResult(sosId, contactId, instructionType, success, responded || false);

      res.json({
        success: true,
        message: 'Call result recorded',
      });
    } catch (error: any) {
      console.error('Report call result error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * POST /api/sos/end
 * End SOS (resolve or cancel)
 * Cancellation ONLY allowed from same device
 */
router.post(
  '/end',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('reason').isIn(['RESOLVED', 'CANCELLED']).withMessage('Invalid reason'),
    body('latitude').optional().isFloat(),
    body('longitude').optional().isFloat(),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, reason, latitude, longitude } = req.body;
      const { deviceId } = req.user!;

      await sosService.endSOS(
        sosId,
        deviceId,
        reason,
        latitude && longitude ? { latitude, longitude } : undefined
      );

      res.json({
        success: true,
        message: `SOS ${reason.toLowerCase()} successfully`,
      });
    } catch (error: any) {
      if (error.message === 'SOS can only be cancelled from the triggering device') {
        res.status(403).json({ success: false, message: error.message });
        return;
      }
      if (error.message === 'SOS not found') {
        res.status(404).json({ success: false, message: error.message });
        return;
      }
      console.error('End SOS error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * GET /api/sos/status/:sosId
 * Get current SOS status
 */
router.get('/status/:sosId', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { sosId } = req.params;
    const status = await sosService.getSOSStatus(sosId);

    if (!status) {
      res.status(404).json({ success: false, message: 'SOS not found' });
      return;
    }

    res.json({
      success: true,
      status,
    });
  } catch (error: any) {
    console.error('Get SOS status error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/sos/deactivate-with-pin
 * Deactivate SOS by verifying user's PIN
 */
router.post(
  '/deactivate-with-pin',
  authenticate,
  [
    body('sosId').notEmpty().withMessage('SOS ID is required'),
    body('pin').notEmpty().withMessage('PIN is required'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { sosId, pin } = req.body;
      const { userId, deviceId } = req.user!;

      // Verify PIN and deactivate SOS
      const result = await sosService.deactivateWithPIN(sosId, userId, deviceId, pin);

      res.json({
        success: true,
        message: 'SOS deactivated successfully',
        sos: result,
      });
    } catch (error: any) {
      if (error.message === 'Invalid PIN') {
        res.status(401).json({ success: false, message: error.message });
        return;
      }
      if (error.message === 'SOS not found') {
        res.status(404).json({ success: false, message: error.message });
        return;
      }
      if (error.message === 'SOS already ended') {
        res.status(400).json({ success: false, message: error.message });
        return;
      }
      console.error('Deactivate with PIN error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * PUT /api/sos/set-pin
 * Set user's custom SOS deactivation PIN
 */
router.put(
  '/set-pin',
  authenticate,
  [
    body('pin').notEmpty().withMessage('PIN is required').isLength({ min: 4, max: 6 }).withMessage('PIN must be 4-6 digits'),
    body('pin').matches(/^\d+$/).withMessage('PIN must contain only digits'),
  ],
  async (req: Request, res: Response): Promise<void> => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        res.status(400).json({ success: false, errors: errors.array() });
        return;
      }

      const { pin } = req.body;
      const { userId } = req.user!;

      // Set custom PIN
      await sosService.setSosPin(userId, pin);

      res.json({
        success: true,
        message: 'SOS PIN updated successfully',
      });
    } catch (error: any) {
      console.error('Set SOS PIN error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

export default router;

