#!/bin/bash

# RYO AWS ALB Multi-Port Production Deployment Script
# This script sets up Nginx configuration for AWS ALB with multiple target groups

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/path/to/ryo_app"  # Update this path
NGINX_CONF_SOURCE="./nginx-configs/aws-alb-multiport.conf"
NGINX_CONF_DEST="/etc/nginx/sites-available/ryo-alb-multiport"
ALB_DNS_NAME="your-alb-dns-name.us-east-1.elb.amazonaws.com"  # Update this

echo -e "${BLUE}🚀 RYO AWS ALB Multi-Port Deployment Script${NC}"
echo "============================================="

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root. This is not recommended for Docker operations."
fi

# Check prerequisites
echo -e "\n${BLUE}📋 Checking Prerequisites${NC}"

# Check if Docker is installed
if command -v docker >/dev/null 2>&1; then
    print_status "Docker is installed"
else
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if command -v docker-compose >/dev/null 2>&1; then
    print_status "Docker Compose is installed"
else
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if Nginx is installed
if command -v nginx >/dev/null 2>&1; then
    print_status "Nginx is installed"
else
    print_error "Nginx is not installed. Please install Nginx first."
    exit 1
fi

# Check if configuration file exists
if [[ -f "$NGINX_CONF_SOURCE" ]]; then
    print_status "Nginx configuration file found"
else
    print_error "Nginx configuration file not found at $NGINX_CONF_SOURCE"
    exit 1
fi

# Prompt for ALB configuration
echo -e "\n${BLUE}🌐 AWS ALB Configuration${NC}"
read -p "Enter your ALB DNS name (default: $ALB_DNS_NAME): " input_alb
ALB_DNS_NAME=${input_alb:-$ALB_DNS_NAME}

read -p "Enter your project directory (default: $PROJECT_DIR): " input_project
PROJECT_DIR=${input_project:-$PROJECT_DIR}

# Validate project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
    print_error "Project directory $PROJECT_DIR does not exist"
    exit 1
fi

if [[ ! -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    print_error "docker-compose.yml not found in $PROJECT_DIR"
    exit 1
fi

print_status "Using ALB DNS name: $ALB_DNS_NAME"
print_status "Using project directory: $PROJECT_DIR"

# Update environment variables
echo -e "\n${BLUE}📝 Updating Environment Variables${NC}"
if [[ -f "$PROJECT_DIR/.env" ]]; then
    # Update .env file with ALB DNS name
    sed -i.backup "s/your-alb-dns-name\.us-east-1\.elb\.amazonaws\.com/$ALB_DNS_NAME/g" "$PROJECT_DIR/.env"
    print_status "Updated backend .env file"
fi

# Update frontend API configuration
if [[ -f "$PROJECT_DIR/frontend/src/utils/API.tsx" ]]; then
    sed -i.backup "s/your-alb-dns-name\.us-east-1\.elb\.amazonaws\.com/$ALB_DNS_NAME/g" "$PROJECT_DIR/frontend/src/utils/API.tsx"
    print_status "Updated frontend API configuration"
fi

# Update admin dashboard API configuration
if [[ -f "../admin-dashboard/src/utils/API.tsx" ]]; then
    sed -i.backup "s/your-alb-dns-name\.us-east-1\.elb\.amazonaws\.com/$ALB_DNS_NAME/g" "../admin-dashboard/src/utils/API.tsx"
    print_status "Updated admin dashboard API configuration"
fi

# Backup existing Nginx configuration
echo -e "\n${BLUE}💾 Backing up existing configuration${NC}"
if [[ -f "$NGINX_CONF_DEST" ]]; then
    sudo cp "$NGINX_CONF_DEST" "$NGINX_CONF_DEST.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Existing Nginx configuration backed up"
fi

# Copy and configure Nginx
echo -e "\n${BLUE}📝 Installing Nginx configuration${NC}"
sudo cp "$NGINX_CONF_SOURCE" "$NGINX_CONF_DEST"
print_status "Nginx configuration installed"

# Enable site
echo -e "\n${BLUE}🔗 Enabling Nginx site${NC}"
sudo ln -sf "$NGINX_CONF_DEST" /etc/nginx/sites-enabled/ryo-alb-multiport

# Remove default site if exists
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    sudo rm /etc/nginx/sites-enabled/default
    print_status "Default Nginx site removed"
fi

# Remove other RYO configs that might conflict
if [[ -L /etc/nginx/sites-enabled/ryo-combined ]]; then
    sudo rm /etc/nginx/sites-enabled/ryo-combined
    print_status "Old RYO combined config removed"
fi

# Test Nginx configuration
echo -e "\n${BLUE}🧪 Testing Nginx configuration${NC}"
if sudo nginx -t; then
    print_status "Nginx configuration test passed"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# Reload Nginx
echo -e "\n${BLUE}🔄 Reloading Nginx${NC}"
if sudo systemctl reload nginx; then
    print_status "Nginx reloaded successfully"
else
    print_error "Failed to reload Nginx"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

# Check if services are already running
echo -e "\n${BLUE}🐳 Managing Docker services${NC}"
if docker-compose ps | grep -q "Up"; then
    print_warning "Some services are already running. Stopping first..."
    docker-compose down
fi

# Pull latest images
echo -e "\n${BLUE}📥 Pulling latest Docker images${NC}"
docker-compose pull

# Build services
echo -e "\n${BLUE}🏗️ Building Docker services${NC}"
docker-compose build

# Start services
echo -e "\n${BLUE}▶️ Starting Docker services${NC}"
docker-compose up -d

# Wait for services to start
echo -e "\n${BLUE}⏳ Waiting for services to start${NC}"
sleep 15

# Check service status
echo -e "\n${BLUE}📊 Checking service status${NC}"
if docker-compose ps | grep -q "Up"; then
    print_status "Docker services are running"
    docker-compose ps
else
    print_error "Some Docker services failed to start"
    docker-compose ps
    echo -e "\nService logs:"
    docker-compose logs --tail=20
    exit 1
fi

# Test connections
echo -e "\n${BLUE}🔍 Testing connections${NC}"

# Test backend direct
if curl -s -f http://localhost:8082/health/ >/dev/null; then
    print_status "Backend direct connection (8082): OK"
else
    print_warning "Backend direct connection (8082): Failed"
fi

# Test frontend direct
if curl -s -f http://localhost:8080/ >/dev/null; then
    print_status "Frontend direct connection (8080): OK"
else
    print_warning "Frontend direct connection (8080): Failed"
fi

# Test Nginx proxies
if curl -s -f http://localhost:8082/health-check >/dev/null; then
    print_status "Nginx backend proxy (8082): OK"
else
    print_warning "Nginx backend proxy (8082): Failed"
fi

if curl -s -f http://localhost:8080/health-check >/dev/null; then
    print_status "Nginx frontend proxy (8080): OK"
else
    print_warning "Nginx frontend proxy (8080): Failed"
fi

if curl -s -f http://localhost:5433/health-check >/dev/null; then
    print_status "Nginx database proxy (5433): OK"
else
    print_warning "Nginx database proxy (5433): Failed"
fi

# Show status
echo -e "\n${GREEN}🎉 AWS ALB Multi-Port Deployment Complete!${NC}"
echo "================================================="
echo -e "ALB DNS Name: ${BLUE}$ALB_DNS_NAME${NC}"
echo ""
echo -e "ALB Target Groups:"
echo -e "├── Backend:  ${BLUE}$ALB_DNS_NAME:8082${NC}"
echo -e "├── Frontend: ${BLUE}$ALB_DNS_NAME:8080${NC}"
echo -e "└── Database: ${BLUE}$ALB_DNS_NAME:5433${NC} (admin only)"
echo ""
echo -e "Local Nginx Ports:"
echo -e "├── Backend Proxy:  ${BLUE}localhost:8082${NC}"
echo -e "├── Frontend Proxy: ${BLUE}localhost:8080${NC}"
echo -e "└── Database Proxy: ${BLUE}localhost:5433${NC}"
echo ""
echo "Next steps:"
echo "1. Configure AWS ALB with target groups pointing to EC2:8082, EC2:8080, EC2:5433"
echo "2. Update security groups to allow ALB → EC2 on ports 8080, 8082, 5433"
echo "3. Configure ALB health checks to /health-check endpoints"
echo "4. Test through ALB URLs"
echo ""
echo "AWS ALB Target Group Configuration:"
echo "- Backend TG: Port 8082, Health Check: /health-check"
echo "- Frontend TG: Port 8080, Health Check: /health-check"  
echo "- Database TG: Port 5433, Health Check: /health-check"
echo ""
echo "Useful commands:"
echo "- View service status: docker-compose ps"
echo "- View logs: docker-compose logs -f"
echo "- Restart services: docker-compose restart"
echo "- Stop services: docker-compose down"

# Show port usage
echo -e "\n${BLUE}📡 Port Usage${NC}"
echo "- Backend (Nginx → Docker): 8082 → 127.0.0.1:8082"
echo "- Frontend (Nginx → Docker): 8080 → 127.0.0.1:8080"
echo "- Database (Nginx → Docker): 5433 → 127.0.0.1:5433"
echo ""
echo "Check with: sudo netstat -tlnp | grep -E ':(8080|8082|5433)'"
