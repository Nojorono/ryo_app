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

echo "Testing frontend on port 3000..."
curl -s -I http://localhost:3000 2>/dev/null | head -1 || echo "❌ Frontend not responding"

echo ""
echo "📊 Docker Images:"
docker images | grep -E "(ryo|program)" || echo "No RYO images found"

echo ""
echo "🔧 If backend is failing, try:"
echo "1. docker-compose stop backend && docker-compose rm -f backend"
echo "2. docker-compose build --no-cache backend"
echo "3. docker-compose up -d backend"
echo "4. docker-compose logs -f backend"