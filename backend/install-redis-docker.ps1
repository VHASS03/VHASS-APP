# Install Redis using Docker
Write-Host "Starting Redis with Docker..." -ForegroundColor Green

docker run -d `
  --name vhass-redis `
  -p 6379:6379 `
  redis:latest

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Redis started successfully on port 6379" -ForegroundColor Green
    Write-Host "Redis is now running. You can start the backend with: npm run dev" -ForegroundColor Cyan
} else {
    Write-Host "❌ Docker is not installed or not running" -ForegroundColor Red
    Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
}

