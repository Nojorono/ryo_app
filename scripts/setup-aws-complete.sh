#!/bin/bash
# filepath: d:\kerjaan\Marketing\RYO\ryo_app\scripts\setup-aws-complete.sh

echo "🚀 Complete RYO App AWS Setup & Port Configuration"
echo "=================================================="

# Configuration
BACKEND_PORT=8082
FRONTEND_PORT=8080
INTERNAL_BACKEND_PORT=8081
INTERNAL_FRONTEND_PORT=3000

echo "📋 Configuration:"
echo "   External Backend: $BACKEND_PORT"
echo "   External Frontend: $FRONTEND_PORT"
echo "   Internal Backend: $INTERNAL_BACKEND_PORT"
echo "   Internal Frontend: $INTERNAL_FRONTEND_PORT"
echo ""

# 1. Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.aws.yml down 2>/dev/null || true
docker-compose down 2>/dev/null || true

# 2. Install Nginx if needed
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing Nginx..."
    sudo apt update
    sudo apt install nginx -y
    sudo systemctl enable nginx
fi

# 3. Create directories
echo "📁 Creating directories..."
sudo mkdir -p /var/www/ryo-app/staticfiles
sudo chown -R $USER:$USER /var/www/ryo-app
sudo chmod -R 755 /var/www/ryo-app

# 4. Fix Docker Compose port configuration
echo "🔧 Updating Docker Compose configuration..."
cat > docker-compose.aws.yml << EOF
version: '3.8'

services:
  db:
    image: postgres:15
    container_name: ryo_postgres
    environment:
      POSTGRES_DB: \${PSQL_NAME:-mkt_ryo}
      POSTGRES_USER: \${PSQL_USER:-jagoan2025}
      POSTGRES_PASSWORD: \${PSQL_PASSWORD:-Jag0db@2025}
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ryo-network
    restart: unless-stopped

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: ryo_backend
    env_file:
      - .env
    environment:
      - DEBUG=False
      - ALLOWED_HOSTS=10.0.3.222,localhost,127.0.0.1
    volumes:
      - ./backend/media:/app/media
      - /var/www/ryo-app/staticfiles:/app/staticfiles-host
    ports:
      - "127.0.0.1:$INTERNAL_BACKEND_PORT:8080"
    networks:
      - ryo-network
    depends_on:
      - db
    restart: unless-stopped

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: ryo_frontend
    environment:
      - REACT_APP_API_URL=http://10.0.3.222:$BACKEND_PORT/api
    ports:
      - "127.0.0.1:$INTERNAL_FRONTEND_PORT:80"
    networks:
      - ryo-network
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  ryo-network:
    driver: bridge
EOF

# 5. Update Frontend API configuration
echo "🔧 Updating Frontend API configuration..."
if [ -f "frontend/src/utils/API.tsx" ]; then
    cat > frontend/src/utils/API.tsx << EOF
const localURL = 'http://localhost:$INTERNAL_BACKEND_PORT';
const stagingURL = 'http://10.0.3.222:$BACKEND_PORT'; // For AWS deployment

export { localURL, stagingURL };
EOF
fi

# 6. Create/Update Nginx configuration
echo "⚙️ Creating Nginx configuration..."
sudo tee /etc/nginx/sites-available/ryo-backend-aws << EOF
# Backend server (port $BACKEND_PORT)
server {
    listen $BACKEND_PORT;
    server_name 10.0.3.222 localhost;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options SAMEORIGIN;
    add_header Referrer-Policy strict-origin-when-cross-origin;
    add_header X-Forwarded-Proto \$scheme;

    # CORS headers
    add_header Access-Control-Allow-Origin "http://10.0.3.222:$FRONTEND_PORT";
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
    add_header Access-Control-Allow-Credentials true;

    # Handle preflight requests
    if (\$request_method = 'OPTIONS') {
        return 204;
    }

    # Static files
    location /staticfiles/ {
        alias /var/www/ryo-app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, max-age=31536000";
        try_files \$uri \$uri/ =404;
    }

    # Media files
    location /media/ {
        alias /home/ubuntu/ryo_app/backend/media/;
        expires 1y;
        add_header Cache-Control "public, max-age=31536000";
    }

    # Proxy to Django backend
    location / {
        proxy_pass http://127.0.0.1:$INTERNAL_BACKEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# Frontend server (port $FRONTEND_PORT)
server {
    listen $FRONTEND_PORT;
    server_name 10.0.3.222 localhost;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options SAMEORIGIN;
    add_header Referrer-Policy strict-origin-when-cross-origin;

    # Proxy to React frontend
    location / {
        proxy_pass http://127.0.0.1:$INTERNAL_FRONTEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 7. Enable Nginx site
echo "🔗 Enabling Nginx site..."
sudo ln -sf /etc/nginx/sites-available/ryo-backend-aws /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 8. Test Nginx configuration
echo "🧪 Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    sudo systemctl restart nginx
else
    echo "❌ Nginx configuration error"
    exit 1
fi

# 9. Build and deploy containers
echo "🐳 Building and deploying Docker containers..."
docker-compose -f docker-compose.aws.yml up -d --build

# 10. Wait for containers to start
echo "⏳ Waiting for containers to start..."
sleep 30

# 11. Check container status
echo "📊 Checking container status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 12. Copy static files
echo "📁 Setting up static files..."
# Wait for backend to generate static files
sleep 10

# Copy static files from container to host
docker exec ryo_backend python manage.py collectstatic --noinput --clear 2>/dev/null || true
sudo chown -R www-data:www-data /var/www/ryo-app/staticfiles
sudo chmod -R 644 /var/www/ryo-app/staticfiles
sudo find /var/www/ryo-app/staticfiles -type d -exec chmod 755 {} \;

# 13. Test setup
echo "🧪 Testing setup..."
echo "Testing backend health..."
curl -I http://10.0.3.222:$BACKEND_PORT/health/ 2>/dev/null | head -1

echo "Testing frontend..."
curl -I http://10.0.3.222:$FRONTEND_PORT/ 2>/dev/null | head -1

echo ""
echo "✅ Setup completed!"
echo ""
echo "🌐 Access points:"
echo "   Backend API:    http://10.0.3.222:$BACKEND_PORT/api/"
echo "   Backend Admin:  http://10.0.3.222:$BACKEND_PORT/admin/"
echo "   Backend Health: http://10.0.3.222:$BACKEND_PORT/health/"
echo "   Frontend:       http://10.0.3.222:$FRONTEND_PORT/"
echo ""
echo "🧪 Test commands:"
echo "   curl -I http://10.0.3.222:$BACKEND_PORT/health/"
echo "   curl -I http://10.0.3.222:$BACKEND_PORT/admin/"
echo "   curl -I http://10.0.3.222:$FRONTEND_PORT/"
echo ""
echo "🔄 If you see 502 errors, wait a moment for containers to fully start"
echo "📋 Check logs with: docker logs ryo_backend"