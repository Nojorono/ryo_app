#!/bin/bash
# filepath: d:\kerjaan\Marketing\RYO\program\ryo_app\scripts\fix-csp-ports.sh

echo "🔧 Fixing CSP and Port Configuration"
echo "===================================="

echo "1. Stopping containers..."
docker-compose down

echo "2. Updating API configuration..."
cat > frontend/src/utils/API.tsx << 'EOF'
const localURL = 'http://localhost:8082';
const stagingURL = 'http://localhost:8082';
// const stagingURL = 'http://10.0.3.222'; // For AWS deployment

export { localURL, stagingURL };
EOF

echo "3. Updating environment variables..."
sed -i 's/8082/8080/g' .env

echo "4. Rebuilding and starting containers..."
docker-compose up -d --build

echo "5. Waiting for containers to start..."
sleep 20

echo "6. Testing API endpoints..."
echo "Testing health endpoint:"
curl -I http://localhost:8082/health/

echo ""
echo "Testing admin endpoint:"
curl -I http://localhost:8082/admin/

echo ""
echo "Testing frontend:"
curl -I http://localhost:3000/

echo ""
echo "✅ Configuration updated!"
echo ""
echo "📋 Updated access points:"
echo "   Backend API: http://localhost:8082/api/"
echo "   Backend Admin: http://localhost:8082/admin/"
echo "   Frontend: http://localhost:3000/"
echo ""
echo "🔄 Please clear browser cache and reload the application"