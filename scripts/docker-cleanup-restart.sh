#!/bin/bash

# Docker Cleanup and Restart Script for RYO
echo "🧹 RYO Docker Cleanup & Restart"
echo "==============================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Stop and remove only frontend and backend containers
print_status "Stopping frontend and backend containers..."
docker-compose stop frontend backend || true
docker-compose rm -f frontend backend || true

# Remove frontend and backend images
docker rmi -f $(docker images -q ryo_app_frontend) 2>/dev/null || true
docker rmi -f $(docker images -q ryo_app_backend) 2>/dev/null || true

# Build and start only frontend and backend
print_status "Building and starting frontend and backend containers..."
docker-compose build --no-cache frontend backend && docker-compose up -d frontend backend

# Build and start fresh
# print_status "Building and starting containers..."
# docker-compose build --no-cache
# docker-compose up -d

# Wait a moment
sleep 5

# Check status
print_status "Checking container status..."
docker-compose ps

print_success "Cleanup and restart completed!"
echo ""
echo "📋 Next steps:"
echo "1. Check logs: docker-compose logs -f"
echo "2. Test frontend: http://localhost:3000"
echo "3. Test backend: http://localhost:8081/health/"
