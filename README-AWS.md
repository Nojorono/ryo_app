# RYO App AWS Deployment Guide

## Overview
Konfigurasi ini dirancang untuk deploy aplikasi RYO di AWS EC2 dengan Application Load Balancer (ALB).

## Architecture
```
Internet → ALB → EC2 (10.0.3.222) → Docker Containers
                                   ├── Nginx (ports 8080, 8082)
                                   ├── Frontend (React)
                                   ├── Backend (Django)
                                   └── Database (PostgreSQL)
```

## Port Configuration
- **Frontend**: Port 8080 (untuk ALB target group)
- **Backend**: Port 8082 (untuk ALB target group)
- **Database**: Port 5433 (internal, tidak diexpose ke ALB)

## Prerequisites
1. AWS EC2 instance dengan IP private 10.0.3.222
2. Docker dan Docker Compose terinstall
3. ALB sudah dikonfigurasi dengan target groups

## Deployment Steps

### 1. Clone dan Setup
```bash
cd /opt
sudo git clone <repository-url> ryo-app
cd ryo-app/ryo_app
sudo chown -R $USER:$USER .
```

### 2. Environment Configuration
```bash
cp .env.aws.example .env
# Edit .env sesuai kebutuhan
nano .env
```

### 3. Create Required Directories
```bash
sudo mkdir -p /var/www/ryo-app/staticfiles
sudo mkdir -p /var/log/nginx
sudo chown -R $USER:$USER /var/www/ryo-app
```

### 4. Deploy Application
```bash
chmod +x deploy-aws.sh
./deploy-aws.sh
```

## ALB Target Group Configuration

### Frontend Target Group
- **Target**: 10.0.3.222:8080
- **Protocol**: HTTP
- **Health Check Path**: /health
- **Health Check Port**: 8080
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 3
- **Timeout**: 5 seconds
- **Interval**: 30 seconds

### Backend Target Group  
- **Target**: 10.0.3.222:8082
- **Protocol**: HTTP
- **Health Check Path**: /health
- **Health Check Port**: 8082
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 3
- **Timeout**: 5 seconds
- **Interval**: 30 seconds

## ALB Listener Rules

### Frontend Rule
- **Condition**: Host header atau path pattern untuk frontend
- **Action**: Forward to frontend target group

### Backend Rule
- **Condition**: Path pattern `/api/*`, `/admin/*`, `/staticfiles/*`, `/media/*`
- **Action**: Forward to backend target group

## Monitoring

### Container Status
```bash
docker-compose -f docker-compose-aws.yml ps
```

### View Logs
```bash
# All services
docker-compose -f docker-compose-aws.yml logs -f

# Specific service
docker-compose -f docker-compose-aws.yml logs -f nginx
docker-compose -f docker-compose-aws.yml logs -f backend
docker-compose -f docker-compose-aws.yml logs -f frontend
```

### Health Checks
```bash
# Frontend health
curl http://10.0.3.222:8080/health

# Backend health  
curl http://10.0.3.222:8082/health

# API test
curl http://10.0.3.222:8082/api/
```

## Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   docker-compose -f docker-compose-aws.yml logs <service-name>
   ```

2. **Static files not loading**
   ```bash
   # Check static files directory
   ls -la /var/www/ryo-app/staticfiles/
   
   # Collect static files manually
   docker-compose -f docker-compose-aws.yml exec backend python manage.py collectstatic --noinput
   ```

3. **Database connection issues**
   ```bash
   # Check database container
   docker-compose -f docker-compose-aws.yml logs db
   
   # Test database connection
   docker-compose -f docker-compose-aws.yml exec backend python manage.py dbshell
   ```

4. **CORS issues**
   - Check CORS_ALLOWED_ORIGINS in .env
   - Verify frontend URL in nginx configuration

### Restart Services
```bash
# Restart all
docker-compose -f docker-compose-aws.yml restart

# Restart specific service
docker-compose -f docker-compose-aws.yml restart nginx
```

### Update Application
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose -f docker-compose-aws.yml down
docker-compose -f docker-compose-aws.yml up --build -d
```

## Security Considerations

1. **Database**: Hanya accessible dari localhost (127.0.0.1:5433)
2. **Environment Variables**: Gunakan AWS Secrets Manager untuk production
3. **SSL/TLS**: Configure SSL termination di ALB level
4. **Security Groups**: Buka hanya port 8080 dan 8082 untuk ALB

## Performance Optimization

1. **Static Files**: Served directly oleh Nginx dengan caching
2. **Gzip Compression**: Enabled untuk semua text-based content
3. **Keep-alive**: Configured untuk optimal connection reuse
4. **Health Checks**: Lightweight endpoints untuk ALB monitoring

## Scaling

Untuk horizontal scaling:
1. Create AMI dari EC2 instance yang sudah configured
2. Launch additional instances dari AMI
3. Add instances ke ALB target groups
4. Ensure database dapat handle multiple connections

## Support

Untuk troubleshooting lebih lanjut, check:
- CloudWatch Logs untuk ALB access logs
- EC2 system logs
- Docker container logs
- Nginx error logs
