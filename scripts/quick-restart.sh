#!/bin/bash
# filepath: d:\kerjaan\Marketing\RYO\program\quick-restart.sh

echo "🚀 Quick Restart Script for RYO Application"
echo "============================================"

# 1. Stop and clean containers
echo "🛑 Stopping containers..."
docker-compose down --remove-orphans

# 2. Clean docker system
echo "🧹 Cleaning Docker system..."
docker system prune -f

# 3. Start containers with rebuild
echo "🔨 Building and starting containers..."
docker-compose up -d --build

# 4. Wait for containers to be ready
echo "⏳ Waiting for containers to start..."
sleep 15

# 5. Check container status
echo "📊 Container status:"
docker-compose ps

# 6. Wait for PostgreSQL to be ready
echo "🗄️ Waiting for PostgreSQL to be ready..."
sleep 5
docker exec ryo_postgres pg_isready -U jagoan2025 -d mkt_ryo || echo "⚠️ PostgreSQL not ready yet, waiting more..."
sleep 5

# 7. Test PostgreSQL connection
echo "🔍 Testing PostgreSQL connection..."
docker exec ryo_postgres psql -U jagoan2025 -d mkt_ryo -c "SELECT version();" || echo "❌ PostgreSQL connection failed"

# 8. Debug static files
echo "🔍 Debugging static files..."
echo "Static files directory contents:"
docker exec ryo_backend ls -la /app/staticfiles/

echo "Admin static files:"
docker exec ryo_backend ls -la /app/staticfiles/admin/ 2>/dev/null || echo "❌ Admin static files not found"

# 9. Test Django settings
echo "🔧 Checking Django settings..."
docker exec ryo_backend python3 manage.py shell -c "
from django.conf import settings
print(f'STATIC_URL: {settings.STATIC_URL}')
print(f'STATIC_ROOT: {settings.STATIC_ROOT}')
print(f'DEBUG: {settings.DEBUG}')
"

# 10. Test endpoints with correct ports
echo "🌐 Testing endpoints..."

echo "Django admin:"
curl -I http://localhost:8081/admin/ 2>/dev/null || echo "❌ Django admin failed"

echo "Static files test:"
curl -I http://localhost:8081/staticfiles/admin/css/base.css 2>/dev/null || echo "❌ Static files failed"

echo "Frontend:"
curl -I http://localhost:3000/ 2>/dev/null || echo "❌ Frontend failed"

# 12. Test database connectivity
echo "🗄️ Testing database connectivity..."

echo "PostgreSQL container status:"
docker exec ryo_postgres pg_isready -U jagoan2025 -d mkt_ryo && echo "✅ PostgreSQL is ready" || echo "❌ PostgreSQL connection failed"

echo "Database tables:"
docker exec ryo_postgres psql -U jagoan2025 -d mkt_ryo -c "\dt" 2>/dev/null || echo "❌ Database query failed"

echo "Django database connection:"
docker exec ryo_backend python3 manage.py shell -c "
from django.db import connection
try:
    cursor = connection.cursor()
    cursor.execute('SELECT 1')
    print('✅ Django database connection successful')
except Exception as e:
    print(f'❌ Django database connection failed: {e}')
" 2>/dev/null || echo "❌ Django database test failed"

# 13. Final status
echo ""
echo "✅ Setup completed!"
echo "🔗 Access points:"
echo "   - PostgreSQL: localhost:5433 (ryo_postgres container)"
echo "   - Django Admin: http://localhost:8081/admin/ (admin/Admin123!!)"
echo "   - Django API: http://localhost:8081/api/"
echo "   - React Frontend: http://localhost:3000/"
echo ""
echo "📋 Database credentials:"
echo "   Database: mkt_ryo"
echo "   Username: jagoan2025"
echo "   Password: Jag0db@2025"
echo "   Host: localhost (external) / ryo_postgres (internal)"
echo "   Port: 5433 (external) / 5432 (internal)"
echo ""
echo "📋 Django admin credentials:"
echo "   Username: admin"
echo "   Password: Admin123!!"