#!/bin/bash
# filepath: d:\kerjaan\Marketing\RYO\program\ryo_app\scripts\fix-static-complete.sh

echo "🔧 Complete Static Files Fix"
echo "============================"

echo "1. Stop all containers..."
docker-compose down

echo "2. Check current urls.py configuration..."
if docker exec ryo_backend cat /app/core/urls.py 2>/dev/null | grep "static("; then
    echo "✅ Static URL patterns found in urls.py"
else
    echo "❌ Static URL patterns missing - will fix this"
fi

echo "3. Update urls.py to ensure static serving..."
cat > temp_urls_fix.py << 'EOF'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

def health_check(request):
    """Health check endpoint"""
    try:
        response_data = {
            "status": "healthy", 
            "service": "ryo-backend",
            "static_url": getattr(settings, 'STATIC_URL', '/static/'),
            "static_root": getattr(settings, 'STATIC_ROOT', '/app/staticfiles'),
            "debug": getattr(settings, 'DEBUG', False),
        }
        return JsonResponse(response_data)
    except Exception as e:
        return JsonResponse({
            "status": "error",
            "message": str(e),
            "service": "ryo-backend"
        }, status=500)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health_check),
    path('api/', include('api.urls')),
    path('office/', include('office.urls')),
    path('retailer/', include('retailer.urls')),
    path('wholesales/', include('wholesales.urls')),
]

# CRITICAL: Static files serving - ensure this works in all cases
if settings.DEBUG:
    # Development - serve static files via Django
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    # Production - still serve via Django since we don't have nginx handling it
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Debug print on startup
import sys
if 'runserver' in sys.argv or 'gunicorn' in sys.argv[0]:
    print("🔍 Static URL Configuration:")
    print(f"  STATIC_URL: {settings.STATIC_URL}")
    print(f"  STATIC_ROOT: {settings.STATIC_ROOT}")
    print(f"  MEDIA_URL: {settings.MEDIA_URL}")
    print(f"  MEDIA_ROOT: {settings.MEDIA_ROOT}")
    print(f"  DEBUG: {settings.DEBUG}")
    print(f"  Total URL patterns: {len(urlpatterns)}")
EOF

echo "4. Start containers..."
docker-compose up -d --build

echo "5. Wait for containers to be ready..."
sleep 20

echo "6. Copy fixed urls.py to container..."
docker cp temp_urls_fix.py ryo_backend:/app/core/urls.py

echo "7. Fix settings.py media configuration..."
docker exec ryo_backend python -c "
import os
settings_path = '/app/core/settings.py'
with open(settings_path, 'r') as f:
    content = f.read()

# Ensure MEDIA_URL is always defined
if 'MEDIA_URL = ' not in content:
    content += '''
# Media files configuration
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
'''

with open(settings_path, 'w') as f:
    f.write(content)
print('✅ Fixed MEDIA_URL in settings.py')
"

echo "8. Restart backend to apply changes..."
docker-compose restart backend

echo "9. Wait for restart..."
sleep 15

echo "10. Force collect static files..."
docker exec ryo_backend python manage.py collectstatic --noinput --clear --verbosity=2

echo "11. Test static file serving..."
echo "Testing admin CSS file:"
curl -I http://localhost:8081/staticfiles/admin/css/base.css

echo ""
echo "Testing admin login page:"
curl -I http://localhost:8081/admin/

echo ""
echo "12. Test with debug endpoint..."
docker exec ryo_backend python manage.py shell -c "
from django.test import Client
from django.conf import settings
import os

client = Client()

# Test static file
response = client.get('/staticfiles/admin/css/base.css')
print(f'Static file response: {response.status_code}')
if response.status_code == 200:
    print('✅ Static files working in Django!')
else:
    print(f'❌ Static files failed: {response.status_code}')

# Check file exists
static_file = os.path.join(settings.STATIC_ROOT, 'admin', 'css', 'base.css')
print(f'File exists: {os.path.exists(static_file)}')

# Check URL patterns
from django.urls import get_resolver
resolver = get_resolver()
print(f'Total URL patterns: {len(resolver.url_patterns)}')
for i, pattern in enumerate(resolver.url_patterns[-3:]):
    print(f'  Last patterns {i}: {pattern}')
"

echo ""
echo "13. Cleanup temp file..."
rm -f temp_urls_fix.py

echo ""
echo "✅ Complete static files fix applied!"
echo "Now test admin at: http://localhost:8081/admin/"