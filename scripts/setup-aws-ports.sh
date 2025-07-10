#!/bin/bash
# setup-aws-ports.sh

echo "🚀 Setting up RYO App on AWS (Backend: 8082, Frontend: 8081)"
echo "=========================================================="

# 1. Install Nginx if needed
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing Nginx..."
    sudo apt update
    sudo apt install nginx -y
    sudo systemctl enable nginx
fi

# 2. Create directories
echo "📁 Creating directories..."
sudo mkdir -p /var/www/ryo-app/staticfiles
sudo chown -R $USER:$USER /var/www/ryo-app
sudo chmod -R 755 /var/www/ryo-app

# 3. Deploy Nginx configuration
echo "⚙️ Deploying Nginx configuration..."
sudo cp /nginx/ryo-backend-aws.conf /etc/nginx/sites-available/ryo-backend-aws
sudo ln -sf /etc/nginx/sites-available/ryo-backend-aws /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 4. Test nginx configuration
echo "🧪 Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Configuration is valid"
    sudo systemctl restart nginx
else
    echo "❌ Configuration error"
    exit 1
fi

# 5. Deploy Docker containers
echo "🐳 Deploying Docker containers..."
docker-compose -f docker-compose-aws.yml down
docker-compose -f docker-compose-aws.yml up -d --build

# 6. Wait for containers
echo "⏳ Waiting for containers to start..."
sleep 30

# 7. Copy static files
echo "📁 Copying static files..."
docker run --rm -v ryo_app_static_volume:/app/staticfiles -v /var/www/ryo-app/staticfiles:/backup alpine sh -c "cp -r /app/staticfiles/* /backup/ 2>/dev/null || true"
sudo chown -R www-data:www-data /var/www/ryo-app/staticfiles
sudo chmod -R 644 /var/www/ryo-app/staticfiles
sudo find /var/www/ryo-app/staticfiles -type d -exec chmod 755 {} \;

echo ""
echo "✅ Setup completed!"
echo ""
echo "🌐 Access points:"
echo "   Backend API:    http://10.0.3.222:8082/api/"
echo "   Backend Admin:  http://10.0.3.222:8082/admin/"
echo "   Backend Health: http://10.0.3.222:8082/health/"
echo "   Frontend:       http://10.0.3.222:8080/"
echo ""
echo "🧪 Test commands:"
echo "   curl -I http://10.0.3.222:8082/health/"
echo "   curl -I http://10.0.3.222:8082/admin/"
echo "   curl -I http://10.0.3.222:8080/"