#!/bin/bash

# RYO App AWS Deployment Script
# Script untuk deploy aplikasi RYO di AWS EC2 dengan ALB

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== RYO App AWS Deployment ===${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on AWS EC2
print_status "Checking AWS EC2 environment..."
if ! curl -s http://169.254.169.254/latest/meta-data/instance-id > /dev/null; then
    print_warning "Not running on AWS EC2, continuing anyway..."
fi

# Create directories
print_status "Creating necessary directories..."
sudo mkdir -p /var/www/ryo-app/staticfiles
sudo mkdir -p /var/log/nginx
sudo chown -R $USER:$USER /var/www/ryo-app

# Set environment variables for AWS
print_status "Setting up environment for AWS..."
export AWS_EC2_IP="10.0.3.222"
export FRONTEND_PORT="8080"
export BACKEND_PORT="8082"

# Stop existing containers
print_status "Stopping existing containers..."
docker-compose -f docker-compose-aws.yml down --remove-orphans || true

# Clean up old images
print_status "Cleaning up old Docker images..."
docker system prune -f --volumes

# Build and start containers
print_status "Building and starting containers..."
docker-compose -f docker-compose-aws.yml up --build -d

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Check container status
print_status "Checking container status..."
docker-compose -f docker-compose-aws.yml ps

# Check if services are responding
print_status "Checking service health..."

# Check backend health
if curl -f http://localhost:8082/health > /dev/null 2>&1; then
    print_status "✅ Backend is healthy on port 8082"
else
    print_error "❌ Backend health check failed"
fi

# Check frontend health  
if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    print_status "✅ Frontend is healthy on port 8080"
else
    print_warning "⚠️  Frontend health check failed (might be normal if no /health endpoint)"
fi

# Show logs for debugging
print_status "Recent container logs:"
echo -e "${YELLOW}=== Backend Logs ===${NC}"
docker-compose -f docker-compose-aws.yml logs --tail=10 backend

echo -e "${YELLOW}=== Frontend Logs ===${NC}"
docker-compose -f docker-compose-aws.yml logs --tail=10 frontend

echo -e "${YELLOW}=== Nginx Logs ===${NC}"
docker-compose -f docker-compose-aws.yml logs --tail=10 nginx

# Show access URLs
print_status "Deployment completed!"
echo -e "${GREEN}Access URLs:${NC}"
echo -e "  Frontend: http://${AWS_EC2_IP}:${FRONTEND_PORT}"
echo -e "  Backend API: http://${AWS_EC2_IP}:${BACKEND_PORT}/api"
echo -e "  Django Admin: http://${AWS_EC2_IP}:${BACKEND_PORT}/admin"
echo ""
echo -e "${YELLOW}ALB Target Group Configuration:${NC}"
echo -e "  Frontend Target: ${AWS_EC2_IP}:${FRONTEND_PORT}"
echo -e "  Backend Target: ${AWS_EC2_IP}:${BACKEND_PORT}"
echo -e "  Health Check Path: /health"
echo ""
echo -e "${BLUE}To monitor logs: ${NC}docker-compose -f docker-compose-aws.yml logs -f"
echo -e "${BLUE}To restart: ${NC}docker-compose -f docker-compose-aws.yml restart"
echo -e "${BLUE}To stop: ${NC}docker-compose -f docker-compose-aws.yml down"
