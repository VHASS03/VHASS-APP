@echo off
echo ========================================
echo   VHASS Escalation Worker
echo ========================================
echo.
echo Starting BullMQ escalation worker...
echo This processes delayed SOS escalation jobs
echo.
echo Press Ctrl+C to stop
echo.

call npm run worker

pause

