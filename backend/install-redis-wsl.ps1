# Install Redis using WSL (Windows Subsystem for Linux)
Write-Host "Installing Redis via WSL..." -ForegroundColor Green

# Check if WSL is installed
wsl --status
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL is not installed. Installing WSL..." -ForegroundColor Yellow
    wsl --install
    Write-Host "Please restart your computer after WSL installation, then run this script again." -ForegroundColor Yellow
    exit
}

Write-Host "Installing Redis in WSL..." -ForegroundColor Cyan
wsl bash -c "sudo apt-get update && sudo apt-get install -y redis-server"

Write-Host "Starting Redis service in WSL..." -ForegroundColor Cyan
wsl bash -c "sudo service redis-server start"

Write-Host "✅ Redis should now be running. Testing connection..." -ForegroundColor Green
wsl redis-cli ping

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Redis is working!" -ForegroundColor Green
    Write-Host "To start Redis in the future, run: wsl sudo service redis-server start" -ForegroundColor Cyan
} else {
    Write-Host "❌ Redis installation failed. Please try manual installation." -ForegroundColor Red
}

