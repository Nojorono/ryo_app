#!/bin/bash

# Nginx Configuration Deployment Script for Ubuntu Server
# This script deploys both frontend and backend Nginx configurations

set -e

echo "🚀 RYO Nginx Configuration Deployment Script"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root"
    SUDO=""
else
    print_status "Running with sudo privileges"
    SUDO="sudo"
fi

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    print_error "Nginx is not installed. Please install Nginx first:"
    echo "sudo apt update && sudo apt install nginx -y"
    exit 1
fi

print_status "Nginx is installed ✓"

# Create sites-available directory if it doesn't exist
$SUDO mkdir -p /etc/nginx/sites-available
$SUDO mkdir -p /etc/nginx/sites-enabled

# Backup existing configurations if they exist
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -f "/etc/nginx/sites-available/frontend.conf" ]; then
    print_warning "Backing up existing ryo-frontend configuration"
    $SUDO cp /etc/nginx/sites-available/frontend.conf /etc/nginx/sites-available/frontend.conf.backup.$TIMESTAMP
fi

if [ -f "/etc/nginx/sites-available/backend.conf" ]; then
    print_warning "Backing up existing ryo-backend configuration"
    $SUDO cp /etc/nginx/sites-available/backend.conf /etc/nginx/sites-available/backend.conf.backup.$TIMESTAMP
fi

# Copy configuration files
print_status "Deploying frontend configuration..."
$SUDO cp ./nginx/ryo-frontend.conf /etc/nginx/sites-available/frontend.conf

print_status "Deploying backend configuration..."
$SUDO cp ./nginx/ryo-backend-wsl.conf /etc/nginx/sites-available/backend.conf

# Set proper permissions
$SUDO chmod 644 /etc/nginx/sites-available/frontend.conf
$SUDO chmod 644 /etc/nginx/sites-available/backend.conf

print_success "Configuration files deployed successfully"

# Enable sites by creating symlinks
print_status "Enabling frontend site..."
$SUDO ln -sf /etc/nginx/sites-available/frontend.conf /etc/nginx/sites-enabled/

print_status "Enabling backend site..."
$SUDO ln -sf /etc/nginx/sites-available/backend.conf /etc/nginx/sites-enabled/

# Disable default Nginx site if it exists
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    print_warning "Disabling default Nginx site"
    $SUDO rm -f /etc/nginx/sites-enabled/default
fi

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if $SUDO nginx -t; then
    print_success "Nginx configuration test passed ✓"
else
    print_error "Nginx configuration test failed ✗"
    print_error "Please check the configuration files for syntax errors"
    exit 1
fi

# Reload Nginx
print_status "Reloading Nginx..."
if $SUDO systemctl reload nginx; then
    print_success "Nginx reloaded successfully ✓"
else
    print_error "Failed to reload Nginx ✗"
    print_status "Trying to restart Nginx..."
    if $SUDO systemctl restart nginx; then
        print_success "Nginx restarted successfully ✓"
    else
        print_error "Failed to restart Nginx ✗"
        exit 1
    fi
fi

# Check Nginx status
print_status "Checking Nginx status..."
if $SUDO systemctl is-active --quiet nginx; then
    print_success "Nginx is running ✓"
else
    print_error "Nginx is not running ✗"
    print_status "Starting Nginx..."
    $SUDO systemctl start nginx
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Update domain names in the configuration files:"
echo "   - Edit /etc/nginx/sites-available/frontend.conf"
echo "   - Edit /etc/nginx/sites-available/backend.conf"
echo "   - Replace 'yourdomain.com' and 'api.yourdomain.com' with your actual domains"
echo ""
echo "2. Start your Docker containers:"
echo "   docker-compose up -d"
echo ""
echo "3. Test the deployment:"
echo "   - Frontend: http://localhost or http://yourdomain.com"
echo "   - Backend API: http://localhost:8080 or http://api.yourdomain.com"
echo "   - Backend Admin: http://localhost/admin or http://yourdomain.com/admin"
echo ""
echo "4. Configure SSL certificates (optional but recommended):"
echo "   - Install certbot: sudo apt install certbot python3-certbot-nginx"
echo "   - Get certificates: sudo certbot --nginx -d yourdomain.com -d api.yourdomain.com"
echo ""
echo "📁 Configuration files location:"
echo "   - Frontend: /etc/nginx/sites-available/frontend.conf"
echo "   - Backend: /etc/nginx/sites-available/backend.conf"
echo ""
echo "📊 Log files location:"
echo "   - Frontend access: /var/log/nginx/ryo-frontend-access.log"
echo "   - Frontend error: /var/log/nginx/ryo-frontend-error.log"
echo "   - Backend access: /var/log/nginx/ryo-backend-access.log"
echo "   - Backend error: /var/log/nginx/ryo-backend-error.log"
echo ""
print_success "RYO deployment is ready! 🚀"
