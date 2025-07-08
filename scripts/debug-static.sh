#!/bin/bash
# filepath: d:\kerjaan\Marketing\RYO\program\debug-static.sh

echo "🔍 Debug Static Files"
echo "===================="

echo "1. Container status:"
docker-compose ps

echo "2. Static files directory:"
docker exec ryo_backend ls -la /app/

echo "3. Staticfiles directory contents:"
docker exec ryo_backend ls -la /app/staticfiles/

echo "4. Admin static files:"
docker exec ryo_backend find /app/staticfiles -name "*.css" | head -10

echo "5. Django settings check:"
docker exec ryo_backend python manage.py shell -c "
from django.conf import settings
import os
print(f'STATIC_URL: {settings.STATIC_URL}')
print(f'STATIC_ROOT: {settings.STATIC_ROOT}')
print(f'Static root exists: {os.path.exists(settings.STATIC_ROOT)}')
print(f'Static root contents: {os.listdir(settings.STATIC_ROOT) if os.path.exists(settings.STATIC_ROOT) else \"Not found\"}')
"

echo "6. Force collect static files:"
docker exec ryo_backend python manage.py collectstatic --noinput --clear --verbosity=2

echo "7. Test static file access:"
docker exec ryo_backend python manage.py shell -c "
import os
from django.conf import settings
static_file = os.path.join(settings.STATIC_ROOT, 'admin', 'css', 'base.css')
print(f'Looking for: {static_file}')
print(f'File exists: {os.path.exists(static_file)}')
if os.path.exists(static_file):
    print(f'File size: {os.path.getsize(static_file)} bytes')
"

echo "8. Check Django URLs configuration:"
docker exec ryo_backend python manage.py shell -c "
from django.conf import settings
from django.urls import get_resolver
resolver = get_resolver()
print('URL patterns:')
for pattern in resolver.url_patterns:
    print(f'  {pattern}')
"

echo "9. Test HTTP access (FIXED PORT):"
echo "Testing with port 8080 (correct port):"
curl -v http://localhost:8080/staticfiles/admin/css/base.css

echo ""
echo "10. Test admin page:"
curl -I http://localhost:8080/admin/