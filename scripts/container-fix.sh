#!/bin/bash

# Comprehensive Container Fix Script
echo "🔧 RYO Container Fix & Troubleshooting"
echo "======================================"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "Choose fix option:"
echo "1. Use simple Dockerfile (recommended)"
echo "2. Fix startup script permissions and retry"
echo "3. Run containers without health checks"
echo "4. Debug container interactively"
echo "5. Complete clean restart"
echo ""
read -p "Enter option (1-5): " option

case $option in
    1)
        print_status "Using simple Dockerfile without complex startup..."
        
        # Stop existing containers
        docker-compose down --remove-orphans
        
        # Create temporary docker-compose with simple Dockerfile
        cat > docker-compose.simple.yml << 'EOF'
version: '3.8'

services:
  backend:
    build:
      context: ./core
      dockerfile: Dockerfile.simple
    container_name: ryo_backend_simple
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY:-django-insecure-please-change-this-key}
      - PSQL_NAME=${PSQL_NAME:-mkt_ryo}
      - PSQL_USER=${PSQL_USER:-jagoan2025}
      - PSQL_PASSWORD=${PSQL_PASSWORD:-Jag0db@2025}
      - PSQL_HOST=${PSQL_HOST:-10.0.29.40}
      - PSQL_PORT=${PSQL_PORT:-5432}
    volumes:
      - ./core/media:/app/media
      - static_volume:/app/staticfiles
    ports:
      - "8081:8080"
    networks:
      - ryo-network
    restart: unless-stopped

  frontend:
    build:
      context: ./admin-dashboard
      dockerfile: Dockerfile.simple
    container_name: ryo_frontend_simple
    ports:
      - "3001:80"
    restart: unless-stopped
    networks:
      - ryo-network

volumes:
  static_volume:

networks:
  ryo-network:
    driver: bridge
EOF
        
        print_status "Building with simple configuration..."
        docker-compose -f docker-compose.simple.yml build --no-cache
        docker-compose -f docker-compose.simple.yml up -d
        ;;
        
    2)
        print_status "Fixing startup script permissions..."
        chmod +x core/start.sh core/start-simple.sh
        
        # Replace complex startup script with simple one
        cp core/start-simple.sh core/start.sh
        
        print_status "Rebuilding with fixed startup script..."
        docker-compose down --remove-orphans
        docker-compose build --no-cache backend
        docker-compose up -d
        ;;
        
    3)
        print_status "Removing health checks and retrying..."
        
        # Create docker-compose without health checks
        cat > docker-compose.nohealth.yml << 'EOF'
version: '3.8'

services:
  backend:
    build:
      context: ./core
      dockerfile: Dockerfile.postgresql
    container_name: ryo_backend_nohealth
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY:-django-insecure-please-change-this-key}
      - PSQL_NAME=${PSQL_NAME:-mkt_ryo}
      - PSQL_USER=${PSQL_USER:-jagoan2025}
      - PSQL_PASSWORD=${PSQL_PASSWORD:-Jag0db@2025}
      - PSQL_HOST=${PSQL_HOST:-10.0.29.40}
      - PSQL_PORT=${PSQL_PORT:-5432}
    volumes:
      - ./core/media:/app/media
      - static_volume:/app/staticfiles
    ports:
      - "8081:8080"
    networks:
      - ryo-network
    restart: unless-stopped

  frontend:
    build:
      context: ./admin-dashboard
      dockerfile: Dockerfile
    container_name: ryo_frontend_nohealth
    ports:
      - "3001:80"
    restart: unless-stopped
    networks:
      - ryo-network

volumes:
  static_volume:

networks:
  ryo-network:
    driver: bridge
EOF
        
        docker-compose down --remove-orphans
        docker-compose -f docker-compose.nohealth.yml up -d
        ;;
        
    4)
        print_status "Running backend container interactively for debugging..."
        docker-compose down
        
        print_status "Building backend..."
        docker-compose build backend
        
        print_status "Running container with bash to debug..."
        docker run --rm -it \
            --name debug_backend \
            -e DEBUG=False \
            -e PSQL_NAME=mkt_ryo \
            -e PSQL_USER=jagoan2025 \
            -e PSQL_PASSWORD="Jag0db@2025" \
            -e PSQL_HOST=10.0.29.40 \
            -e PSQL_PORT=5432 \
            program_backend /bin/bash
        ;;
        
    5)
        print_status "Complete clean restart..."
        
        # Stop everything
        docker-compose down --remove-orphans
        docker stop $(docker ps -q) 2>/dev/null || true
        
        # Remove images
        docker rmi program_backend program_frontend 2>/dev/null || true
        
        # Clean system
        docker system prune -f
        
        # Wait
        sleep 5
        
        # Use alternative ports and simple setup
        print_status "Using alternative ports and simple configuration..."
        docker-compose -f docker-compose.alt.yml build --no-cache
        docker-compose -f docker-compose.alt.yml up -d
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_status "Waiting for containers to start..."
sleep 10

print_status "Checking container status..."
docker ps | grep ryo || docker ps -a | grep ryo

echo ""
print_status "Testing endpoints (if containers are running)..."
curl -s -I http://localhost:8081/health/ 2>/dev/null | head -1 || echo "Backend not responding on 8081"
curl -s -I http://localhost:8080/health/ 2>/dev/null | head -1 || echo "Backend not responding on 8080"
curl -s -I http://localhost:3001 2>/dev/null | head -1 || echo "Frontend not responding on 3001"
curl -s -I http://localhost:3000 2>/dev/null | head -1 || echo "Frontend not responding on 3000"

print_success "Container fix process completed!"
echo ""
echo "📋 If containers are running:"
echo "- Backend: http://localhost:8081 or http://localhost:8080"
echo "- Frontend: http://localhost:3001 or http://localhost:3000"
