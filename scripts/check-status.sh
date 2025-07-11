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
echo "Testing backend health..."
curl -s -I http://localhost/health/ 2>/dev/null | head -1 || echo "❌ Backend not responding"

echo "Testing frontend..."
curl -s -I http://localhost:3000 2>/dev/null | head -1 || echo "❌ Frontend not responding"

echo ""
echo "📊 Docker Images:"
docker images | grep -E "(ryo|program)" || echo "No RYO images found"

echo ""
echo "🔧 If containers are not running, try:"
echo "1. docker-compose up -d"
echo "2. docker-compose build --no-cache && docker-compose up -d"
echo "3. bash docker-cleanup-restart.sh"
