#!/bin/bash

# RYO Pre-deployment Verification Script
# This script checks all configurations before production deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/path/to/ryo_app"  # Update this path

echo -e "${BLUE}✅ RYO Pre-deployment Verification${NC}"
echo "====================================="

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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Track verification status
verification_errors=0
verification_warnings=0

# Function to add error
add_error() {
    ((verification_errors++))
    print_error "$1"
}

# Function to add warning
add_warning() {
    ((verification_warnings++))
    print_warning "$1"
}

# Get project directory
read -p "Enter your project directory (default: $PROJECT_DIR): " input_project
PROJECT_DIR=${input_project:-$PROJECT_DIR}

if [[ ! -d "$PROJECT_DIR" ]]; then
    add_error "Project directory $PROJECT_DIR does not exist"
    exit 1
fi

print_info "Using project directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

# Check 1: Environment files
echo -e "\n${BLUE}📄 Environment Files${NC}"

if [[ -f ".env" ]]; then
    print_status ".env file exists"
    
    # Check important environment variables
    source .env 2>/dev/null || true
    
    if [[ -n "$API_BASE_URL" ]]; then
        print_status "API_BASE_URL is set: $API_BASE_URL"
    else
        add_warning "API_BASE_URL not set in .env"
    fi
    
    if [[ -n "$FRONTEND_URL" ]]; then
        print_status "FRONTEND_URL is set: $FRONTEND_URL"
    else
        add_warning "FRONTEND_URL not set in .env"
    fi
    
    if [[ -n "$PSQL_NAME" && -n "$PSQL_USER" && -n "$PSQL_PASSWORD" ]]; then
        print_status "Database credentials are configured"
    else
        add_warning "Database credentials incomplete in .env"
    fi
    
else
    add_error ".env file not found"
fi

# Check frontend .env
if [[ -f "frontend/.env" ]]; then
    print_status "Frontend .env file exists"
    
    # Check VITE_API_BASE_URL
    if grep -q "VITE_API_BASE_URL" frontend/.env; then
        local api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d= -f2)
        print_status "Frontend API URL configured: $api_url"
    else
        add_warning "VITE_API_BASE_URL not found in frontend/.env"
    fi
else
    add_warning "Frontend .env file not found"
fi

# Check 2: Docker files
echo -e "\n${BLUE}🐳 Docker Configuration${NC}"

if [[ -f "docker-compose.yml" ]]; then
    print_status "docker-compose.yml exists"
    
    # Check if ports are correctly configured
    if grep -q "127.0.0.1:8081:8080" docker-compose.yml; then
        print_status "Backend port mapping correct (127.0.0.1:8081:8080)"
    else
        add_error "Backend port mapping incorrect in docker-compose.yml"
    fi
    
    if grep -q "127.0.0.1:3001:80" docker-compose.yml; then
        print_status "Frontend port mapping correct (127.0.0.1:3001:80)"
    else
        add_error "Frontend port mapping incorrect in docker-compose.yml"
    fi
    
    # Check if nginx service is commented out
    if grep -q "nginx:" docker-compose.yml && ! grep -q "#.*nginx:" docker-compose.yml; then
        add_warning "Nginx service should be commented out for host-based deployment"
    else
        print_status "Nginx service correctly disabled"
    fi
    
else
    add_error "docker-compose.yml not found"
fi

# Check Dockerfiles
if [[ -f "backend/Dockerfile" ]]; then
    print_status "Backend Dockerfile exists"
else
    add_error "Backend Dockerfile not found"
fi

if [[ -f "frontend/Dockerfile" ]]; then
    print_status "Frontend Dockerfile exists"
else
    add_error "Frontend Dockerfile not found"
fi

# Check 3: Nginx configuration
echo -e "\n${BLUE}🌐 Nginx Configuration${NC}"

if [[ -f "../nginx-configs/production-ryo-combined.conf" ]]; then
    print_status "Production Nginx configuration exists"
    
    # Check if domains are updated
    if grep -q "yourdomain.com" ../nginx-configs/production-ryo-combined.conf; then
        add_warning "Domain placeholders (yourdomain.com) still present in Nginx config"
    else
        print_status "Domain placeholders updated in Nginx config"
    fi
    
    # Check upstream configuration
    if grep -q "127.0.0.1:8081" ../nginx-configs/production-ryo-combined.conf; then
        print_status "Backend upstream correctly configured"
    else
        add_error "Backend upstream not correctly configured"
    fi
    
    if grep -q "127.0.0.1:3001" ../nginx-configs/production-ryo-combined.conf; then
        print_status "Frontend upstream correctly configured"
    else
        add_error "Frontend upstream not correctly configured"
    fi
    
else
    add_error "Production Nginx configuration not found"
fi

# Check 4: Django settings
echo -e "\n${BLUE}⚙️ Django Settings${NC}"

if [[ -f "backend/core/settings.py" ]]; then
    print_status "Django settings file exists"
    
    # Check ALLOWED_HOSTS
    if grep -q "ALLOWED_HOSTS" backend/core/settings.py; then
        print_status "ALLOWED_HOSTS configured"
    else
        add_warning "ALLOWED_HOSTS not found in Django settings"
    fi
    
    # Check CORS settings
    if grep -q "CORS_ALLOWED_ORIGINS" backend/core/settings.py; then
        print_status "CORS settings configured"
    else
        add_warning "CORS settings not found in Django settings"
    fi
    
    # Check database configuration
    if grep -q "DATABASES" backend/core/settings.py; then
        print_status "Database configuration found"
    else
        add_error "Database configuration not found"
    fi
    
else
    add_error "Django settings file not found"
fi

# Check 5: Frontend build configuration
echo -e "\n${BLUE}⚛️ Frontend Configuration${NC}"

if [[ -f "frontend/vite.config.js" ]]; then
    print_status "Vite configuration exists"
    
    # Check if proxy is configured correctly
    if grep -q "proxy" frontend/vite.config.js; then
        print_status "Vite proxy configuration found"
    else
        add_warning "Vite proxy configuration not found"
    fi
else
    add_error "Vite configuration file not found"
fi

if [[ -f "frontend/package.json" ]]; then
    print_status "Frontend package.json exists"
else
    add_error "Frontend package.json not found"
fi

# Check 6: System prerequisites
echo -e "\n${BLUE}🖥️ System Prerequisites${NC}"

# Check Docker
if command -v docker >/dev/null 2>&1; then
    print_status "Docker is installed"
    
    # Check Docker daemon
    if docker info >/dev/null 2>&1; then
        print_status "Docker daemon is running"
    else
        add_error "Docker daemon is not running"
    fi
else
    add_error "Docker is not installed"
fi

# Check Docker Compose
if command -v docker-compose >/dev/null 2>&1; then
    print_status "Docker Compose is installed"
else
    add_error "Docker Compose is not installed"
fi

# Check Nginx
if command -v nginx >/dev/null 2>&1; then
    print_status "Nginx is installed"
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        print_status "Nginx is running"
    else
        add_warning "Nginx is not running"
    fi
else
    add_error "Nginx is not installed"
fi

# Check 7: Port availability
echo -e "\n${BLUE}🔌 Port Availability${NC}"

check_port() {
    local port=$1
    local service=$2
    
    if ss -tlnp | grep -q ":$port "; then
        local process=$(ss -tlnp | grep ":$port " | awk '{print $6}' | cut -d',' -f2 | cut -d'"' -f2)
        add_warning "Port $port is already in use by $process (needed for $service)"
        return 1
    else
        print_status "Port $port is available for $service"
        return 0
    fi
}

check_port 80 "Nginx HTTP"
check_port 8081 "Backend (Docker)"
check_port 3001 "Frontend (Docker)"
check_port 5433 "PostgreSQL (Docker)"

# Check 8: File permissions
echo -e "\n${BLUE}📁 File Permissions${NC}"

# Check if user can write to required directories
if [[ -w "." ]]; then
    print_status "Project directory is writable"
else
    add_error "Project directory is not writable"
fi

if [[ -w "backend/media" ]] || [[ ! -d "backend/media" ]]; then
    print_status "Media directory permissions OK"
else
    add_error "Media directory is not writable"
fi

# Check 9: Git status
echo -e "\n${BLUE}📝 Git Status${NC}"

if [[ -d ".git" ]]; then
    print_status "Git repository detected"
    
    # Check for uncommitted changes
    if git diff --quiet && git diff --staged --quiet; then
        print_status "No uncommitted changes"
    else
        add_warning "Uncommitted changes detected"
        print_info "Consider committing changes before deployment"
    fi
    
    # Show current branch
    local branch=$(git branch --show-current)
    print_info "Current branch: $branch"
else
    add_warning "Not a Git repository"
fi

# Summary
echo -e "\n${BLUE}📊 Verification Summary${NC}"
echo "========================"

if [[ $verification_errors -eq 0 ]] && [[ $verification_warnings -eq 0 ]]; then
    print_status "All checks passed! Ready for deployment! 🎉"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./scripts/deploy-production.sh"
    echo "2. After deployment, run: ./scripts/monitor-production.sh health"
    echo "3. For SSL setup: ./scripts/setup-ssl.sh"
    exit 0
elif [[ $verification_errors -eq 0 ]]; then
    echo -e "${YELLOW}⚠ $verification_warnings warning(s) found${NC}"
    echo "You can proceed with deployment, but consider addressing the warnings."
    echo ""
    read -p "Continue with deployment? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Proceeding with deployment..."
        exit 0
    else
        echo "Deployment cancelled. Please address the warnings."
        exit 1
    fi
else
    echo -e "${RED}✗ $verification_errors error(s) and $verification_warnings warning(s) found${NC}"
    echo "Please fix the errors before proceeding with deployment."
    echo ""
    echo "Common fixes:"
    echo "- Create missing .env files"
    echo "- Install missing prerequisites (Docker, Docker Compose, Nginx)"
    echo "- Fix port conflicts"
    echo "- Update configuration files"
    exit 1
fi
