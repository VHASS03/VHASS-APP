@echo off
echo ========================================
echo   VHASS Backend Startup Script
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

echo [1/4] Checking Node.js...
node --version
echo.

echo [2/4] Checking if dependencies are installed...
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo Dependencies already installed.
)
echo.

echo [3/4] Checking .env file...
if not exist ".env" (
    echo WARNING: .env file not found!
    echo Copying env.example to .env...
    copy env.example .env
    echo.
    echo IMPORTANT: Please edit .env file with your configuration:
    echo   - MONGODB_URI
    echo   - REDIS_HOST and REDIS_PORT
    echo   - JWT_SECRET
    echo.
    pause
)
echo.

echo [4/4] Starting backend server...
echo.
echo ========================================
echo   Backend will start on http://localhost:5000
echo   Press Ctrl+C to stop
echo ========================================
echo.

REM Start the dev server
call npm run dev

pause

