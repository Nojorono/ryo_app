#!/bin/bash

# Quick Docker Status Check
echo "🐳 Docker Status Check"
echo "===================="

echo "📋 Container Status:"
docker-compose ps

echo ""
echo "🔍 Container Logs (last 10 lines):"
echo "--- Backend ---"
docker-compose logs --tail=10 backend 2>/dev/null || echo "Backend not running"

echo ""
echo "--- Frontend ---"
docker-compose logs --tail=10 frontend 2>/dev/null || echo "Frontend not running"

echo ""
echo "🌐 Test Endpoints:"
echo "Testing backend health on port 8081..."
curl -s -I http://localhost:8081/health/ 2>/dev/null | head -1 || echo "❌ Backend not responding"

echo "Testing backend API on port 8081..."
curl -s -I http://localhost:8081/api/ 2>/dev/null | head -1 || echo "❌ Backend API not responding"

echo "Testing backend Admin Page on port 8081..."
curl -s -I http://localhost:8081/4dm1n^/ 2>/dev/null | head -1 || echo "❌ Backend Admin not responding"

echo "Testing frontend on port 3000..."
curl -s -I http://localhost:3000 2>/dev/null | head -1 || echo "❌ Frontend not responding"

echo ""
echo "🌐 Domain Tests (if domains are configured):"
echo "Testing frontend domain..."
curl -s -I http://ryo.kcsi.id 2>/dev/null | head -1 || echo "❌ Frontend domain not accessible"

echo "Testing backend domain..."
curl -s -I http://apiryo.kcsi.id 2>/dev/null | head -1 || echo "❌ Backend domain not accessible"

echo "Testing backend API via domain..."
curl -s -I http://apiryo.kcsi.id/api/ 2>/dev/null | head -1 || echo "❌ Backend API via domain not accessible"

echo "Testing backend Admin via domain..."
curl -s -I http://apiryo.kcsi.id/4dm1n^/ 2>/dev/null | head -1 || echo "❌ Backend Admin via domain not accessible"

echo "Testing static files via domain..."
curl -s -I http://apiryo.kcsi.id/staticfiles/admin/css/base.css 2>/dev/null | head -1 || echo "❌ Static files not accessible"

echo ""
echo "📊 System Information:"
echo "--- Docker Images ---"
docker images | grep -E "(ryo|program)" || echo "No RYO images found"

echo ""
echo "--- Database Status ---"
echo "Testing PostgreSQL connection on port 5433..."
nc -z localhost 5433 && echo "✅ Database port accessible" || echo "❌ Database port not accessible"

echo ""
echo "--- Network Information ---"
echo "Active Docker networks:"
docker network ls | grep ryo || echo "No RYO networks found"

echo ""
echo "--- Port Usage ---"
echo "Checking port usage:"
sudo netstat -tlnp | grep -E ':(3000|8081|5433)' || echo "No RYO ports in use"

echo ""
echo "🔧 Troubleshooting Commands:"
echo "If backend is failing:"
echo "1. docker-compose stop backend && docker-compose rm -f backend"
echo "2. docker-compose build --no-cache backend"
echo "3. docker-compose up -d backend"
echo "4. docker-compose logs -f backend"
echo ""
echo "If frontend is failing:"
echo "1. docker-compose stop frontend && docker-compose rm -f frontend"
echo "2. docker-compose build --no-cache frontend"
echo "3. docker-compose up -d frontend"
echo ""
echo "For static files issues:"
echo "1. docker-compose exec backend python manage.py collectstatic --noinput"
echo "2. sudo chown -R www-data:www-data /path/to/staticfiles"
echo ""
echo "For CORS issues:"
echo "1. Check Django CORS_ALLOWED_ORIGINS in settings.py"
echo "2. Check Nginx CORS headers configuration"
echo ""
echo "Quick restart all services:"
echo "docker-compose down && docker-compose up -d --build"
