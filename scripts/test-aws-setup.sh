#!/bin/bash
# test-aws-setup.sh

echo "🧪 Testing AWS Setup (Backend: 8082, Frontend: 8080)"
echo "================================================="

echo "1. Testing Nginx status..."
sudo systemctl status nginx --no-pager

echo ""
echo "2. Testing backend health (port 8082)..."
curl -I http://10.0.3.222:8082/health/

echo ""
echo "3. Testing backend admin (port 8082)..."
curl -I http://10.0.3.222:8082/admin/

echo ""
echo "4. Testing backend API (port 8082)..."
curl -I http://10.0.3.222:8082/api/

echo ""
echo "5. Testing static files (port 8082)..."
curl -I http://10.0.3.222:8082/staticfiles/admin/css/base.css

echo ""
echo "6. Testing frontend (port 8080)..."
curl -I http://10.0.3.222:8080/

echo ""
echo "7. Testing direct container access..."
echo "--- Backend container (internal port 8080) ---"
curl -I http://localhost:8080/health/ 2>/dev/null || echo "Backend container not accessible"

echo ""
echo "--- Frontend container (internal port 3000) ---"
curl -I http://localhost:3000/ 2>/dev/null || echo "Frontend container not accessible"

echo ""
echo "8. Checking container status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "9. Checking port bindings..."
sudo netstat -tlnp | grep -E ':8080|:8082|:3000'

echo ""
echo "✅ Testing completed!"