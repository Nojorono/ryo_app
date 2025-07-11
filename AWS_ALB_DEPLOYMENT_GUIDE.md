# RYO AWS ALB Multi-Port Production Deployment Guide

## 🎯 Architecture Overview

```
Internet
    ↓
AWS Application Load Balancer (ALB)
    ↓
┌─────────────────────────────────────────────────────────────┐
│                     EC2 Instance                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                 Nginx (Host)                            ││
│  │  ┌─────────────┬─────────────┬─────────────┐            ││
│  │  │   :8082     │    :8080    │    :5433    │            ││
│  │  │  Backend    │  Frontend   │  Database   │            ││
│  │  └─────────────┴─────────────┴─────────────┘            ││
│  └──────────────────────┬──────────────────────────────────┘│
│                         │                                   │
│  ┌─────────────────────▼──────────────────────────────────┐ │
│  │                 Docker                                 │ │
│  │  ┌─────────────┬─────────────┬─────────────┐          │ │
│  │  │   :8082     │    :8080    │    :5433    │          │ │
│  │  │ Django API  │ React App   │ PostgreSQL  │          │ │
│  │  │ (Backend)   │ (Frontend)  │ (Database)  │          │ │
│  │  └─────────────┴─────────────┴─────────────┘          │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📋 ALB Target Groups Configuration

| Target Group | Port | Health Check | Purpose |
|-------------|------|--------------|---------|
| ryo-backend-tg | 8082 | /health-check | Django API |
| ryo-frontend-tg | 8080 | /health-check | React App |
| ryo-database-tg | 5433 | /health-check | Database Admin (Optional) |

## 🚀 Deployment Steps

### Step 1: Pre-deployment Setup
```bash
cd scripts/
chmod +x make-executable.sh
./make-executable.sh
```

### Step 2: Configure for AWS ALB
Update the following files with your ALB DNS name:
- `ryo_app/.env`
- `ryo_app/frontend/src/utils/API.tsx`
- `admin-dashboard/src/utils/API.tsx`

### Step 3: Deploy
```bash
./deploy-aws-alb.sh
```

### Step 4: Configure AWS ALB

#### 4.1 Create Target Groups
```bash
# Backend Target Group
aws elbv2 create-target-group \
    --name ryo-backend-tg \
    --protocol HTTP \
    --port 8082 \
    --vpc-id vpc-xxxxxxxx \
    --health-check-path /health-check \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3

# Frontend Target Group
aws elbv2 create-target-group \
    --name ryo-frontend-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id vpc-xxxxxxxx \
    --health-check-path /health-check \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3

# Database Target Group (Optional)
aws elbv2 create-target-group \
    --name ryo-database-tg \
    --protocol HTTP \
    --port 5433 \
    --vpc-id vpc-xxxxxxxx \
    --health-check-path /health-check \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3
```

#### 4.2 Register EC2 Instances
```bash
# Register EC2 instance with target groups
aws elbv2 register-targets \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-backend-tg/xxxxx \
    --targets Id=i-xxxxxxxxx,Port=8082

aws elbv2 register-targets \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-frontend-tg/xxxxx \
    --targets Id=i-xxxxxxxxx,Port=8080

aws elbv2 register-targets \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-database-tg/xxxxx \
    --targets Id=i-xxxxxxxxx,Port=5433
```

#### 4.3 Create ALB Listeners
```bash
# Backend Listener (Port 8082)
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/ryo-alb/xxxxx \
    --protocol HTTP \
    --port 8082 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-backend-tg/xxxxx

# Frontend Listener (Port 8080)
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/ryo-alb/xxxxx \
    --protocol HTTP \
    --port 8080 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-frontend-tg/xxxxx

# Database Listener (Port 5433) - Optional
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/ryo-alb/xxxxx \
    --protocol HTTP \
    --port 5433 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-database-tg/xxxxx
```

## 🔐 Security Group Configuration

### ALB Security Group
```bash
# Allow inbound traffic to ALB
aws ec2 authorize-security-group-ingress \
    --group-id sg-alb-xxxxxxxx \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id sg-alb-xxxxxxxx \
    --protocol tcp \
    --port 8082 \
    --cidr 0.0.0.0/0

# Database port (restrict to specific IPs)
aws ec2 authorize-security-group-ingress \
    --group-id sg-alb-xxxxxxxx \
    --protocol tcp \
    --port 5433 \
    --cidr 10.0.0.0/8
```

### EC2 Security Group
```bash
# Allow ALB to reach EC2 instances
aws ec2 authorize-security-group-ingress \
    --group-id sg-ec2-xxxxxxxx \
    --protocol tcp \
    --port 8080 \
    --source-group sg-alb-xxxxxxxx

aws ec2 authorize-security-group-ingress \
    --group-id sg-ec2-xxxxxxxx \
    --protocol tcp \
    --port 8082 \
    --source-group sg-alb-xxxxxxxx

aws ec2 authorize-security-group-ingress \
    --group-id sg-ec2-xxxxxxxx \
    --protocol tcp \
    --port 5433 \
    --source-group sg-alb-xxxxxxxx

# SSH access
aws ec2 authorize-security-group-ingress \
    --group-id sg-ec2-xxxxxxxx \
    --protocol tcp \
    --port 22 \
    --cidr your-ip/32
```

## 📝 Configuration Files

### Environment Variables (.env)
```env
# AWS ALB Configuration
ALB_DNS_NAME=ryo-alb-123456789.us-east-1.elb.amazonaws.com
API_BASE_URL=http://ryo-alb-123456789.us-east-1.elb.amazonaws.com:8082
FRONTEND_URL=http://ryo-alb-123456789.us-east-1.elb.amazonaws.com:8080
DATABASE_URL=ryo-alb-123456789.us-east-1.elb.amazonaws.com:5433

# Django Settings
ALLOWED_HOSTS=*,ryo-alb-123456789.us-east-1.elb.amazonaws.com
CORS_ALLOWED_ORIGINS=http://ryo-alb-123456789.us-east-1.elb.amazonaws.com:8080
```

### Frontend API Configuration
```typescript
// API URLs through AWS ALB multi-port setup
const localURL = 'http://ryo-alb-123456789.us-east-1.elb.amazonaws.com:8082';
const stagingURL = 'http://ryo-alb-123456789.us-east-1.elb.amazonaws.com:8082';
```

### Docker Compose Port Mapping
```yaml
services:
  backend:
    ports:
      - "127.0.0.1:8082:8080"  # For ALB target group port 8082
  
  frontend:
    ports:
      - "127.0.0.1:8080:80"    # For ALB target group port 8080
  
  db:
    ports:
      - "127.0.0.1:5433:5432"  # For ALB target group port 5433
```

## 🧪 Testing

### Local Testing
```bash
# Test backend
curl http://localhost:8082/health-check
curl http://localhost:8082/api/health/

# Test frontend
curl http://localhost:8080/health-check
curl http://localhost:8080/

# Test database proxy
curl http://localhost:5433/health-check
```

### ALB Testing
```bash
# Replace with your ALB DNS name
ALB_DNS="ryo-alb-123456789.us-east-1.elb.amazonaws.com"

# Test backend through ALB
curl http://$ALB_DNS:8082/health-check
curl http://$ALB_DNS:8082/api/health/

# Test frontend through ALB
curl http://$ALB_DNS:8080/health-check
curl http://$ALB_DNS:8080/

# Test database proxy through ALB
curl http://$ALB_DNS:5433/health-check
```

## 📊 Monitoring

### ALB Metrics
- TargetResponseTime
- RequestCount
- HTTPCode_Target_2XX_Count
- HTTPCode_Target_4XX_Count
- HTTPCode_Target_5XX_Count
- HealthyHostCount
- UnHealthyHostCount

### EC2 Monitoring
```bash
# Check Nginx status
sudo systemctl status nginx

# Check Docker services
docker-compose ps

# Check port usage
sudo netstat -tlnp | grep -E ':(8080|8082|5433)'

# View logs
sudo tail -f /var/log/nginx/ryo-*-access.log
docker-compose logs -f
```

## 🚨 Troubleshooting

### Common Issues

1. **ALB Health Check Failures**
   ```bash
   # Check if Nginx is serving health checks
   curl http://localhost:8082/health-check
   curl http://localhost:8080/health-check
   curl http://localhost:5433/health-check
   
   # Check Nginx error logs
   sudo tail -f /var/log/nginx/error.log
   ```

2. **Target Registration Issues**
   ```bash
   # Check target group health
   aws elbv2 describe-target-health \
       --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-backend-tg/xxxxx
   ```

3. **Port Conflicts**
   ```bash
   # Check what's using the ports
   sudo ss -tlnp | grep -E ':(8080|8082|5433)'
   ```

4. **CORS Issues**
   - Verify CORS_ALLOWED_ORIGINS includes ALB DNS name
   - Check browser developer tools for CORS errors
   - Verify Nginx CORS headers

### Log Locations
- Nginx: `/var/log/nginx/ryo-*-*.log`
- Docker: `docker-compose logs [service]`
- ALB: CloudWatch Logs (if configured)

## 🔄 Scaling

### Auto Scaling Group Configuration
```bash
# Create launch template for additional EC2 instances
aws ec2 create-launch-template \
    --launch-template-name ryo-app-template \
    --launch-template-data '{
        "ImageId": "ami-xxxxxxxx",
        "InstanceType": "t3.medium",
        "SecurityGroupIds": ["sg-ec2-xxxxxxxx"],
        "UserData": "base64-encoded-user-data"
    }'

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name ryo-app-asg \
    --launch-template LaunchTemplateName=ryo-app-template,Version=1 \
    --min-size 1 \
    --max-size 3 \
    --desired-capacity 2 \
    --target-group-arns arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-backend-tg/xxxxx \
                        arn:aws:elasticloadbalancing:region:account:targetgroup/ryo-frontend-tg/xxxxx \
    --health-check-type ELB \
    --health-check-grace-period 300
```

## 💰 Cost Optimization

1. **Use appropriate instance types**
   - Development: t3.micro or t3.small
   - Production: t3.medium or higher

2. **ALB vs Classic Load Balancer**
   - ALB supports multiple ports/target groups
   - More cost-effective for multi-service architecture

3. **Auto Scaling**
   - Scale based on CPU/memory utilization
   - Use scheduled scaling for predictable traffic

This setup provides a robust, scalable architecture for your RYO application using AWS ALB with multiple target groups, allowing independent scaling and monitoring of each component.
