# RYO AWS ALB Multi-Port Architecture - Final Summary

## 🎯 Architecture Overview

```
Internet
    ↓
AWS Application Load Balancer (ALB)
├── Port 8082 → Backend Target Group  ────┐
├── Port 8080 → Frontend Target Group ────┤
└── Port 5433 → Database Target Group ────┤
                                           ↓
                                    EC2 Instance
                                           ↓
                               Nginx (Ubuntu Host)
                    ┌──────────┬──────────┬──────────┐
                    │   :8082  │   :8080  │   :5433  │
                    │ Backend  │Frontend  │Database  │
                    │  Proxy   │  Proxy   │  Proxy   │
                    └────┬─────┴────┬─────┴────┬─────┘
                         ↓          ↓          ↓
                   Docker Services
              ┌──────────┬──────────┬──────────┐
              │   :8082  │   :8080  │   :5433  │
              │ Django   │ React    │PostgreSQL│
              │   API    │   App    │ Database │
              └──────────┴──────────┴──────────┘
```

## 📊 Port Mapping Summary

| Component | ALB Port | EC2 Nginx Port | Docker Port | Purpose |
|-----------|----------|----------------|-------------|---------|
| Backend | 8082 | 8082 | 127.0.0.1:8082 | Django API |
| Frontend | 8080 | 8080 | 127.0.0.1:8080 | React App |
| Database | 5433 | 5433 | 127.0.0.1:5433 | PostgreSQL Admin |

## 🔧 Configuration Files Updated

### 1. Docker Compose (`ryo_app/docker-compose.yml`)
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

### 2. Environment Variables (`ryo_app/.env`)
```env
# AWS ALB Configuration
ALB_DNS_NAME=your-alb-dns-name.us-east-1.elb.amazonaws.com
API_BASE_URL=http://your-alb-dns-name.us-east-1.elb.amazonaws.com:8082
FRONTEND_URL=http://your-alb-dns-name.us-east-1.elb.amazonaws.com:8080
DATABASE_URL=your-alb-dns-name.us-east-1.elb.amazonaws.com:5433
```

### 3. Frontend API Config (`ryo_app/frontend/src/utils/API.tsx`)
```typescript
const localURL = 'http://your-alb-dns-name.us-east-1.elb.amazonaws.com:8082';
const stagingURL = 'http://your-alb-dns-name.us-east-1.elb.amazonaws.com:8082';
```

### 4. Nginx Configuration (`nginx-configs/aws-alb-multiport.conf`)
- Listens on ports 8080, 8082, 5433
- Proxies to respective Docker containers
- Includes health check endpoints for ALB
- CORS headers configured for cross-port communication

### 5. Vite Development Config (`ryo_app/frontend/vite.config.js`)
```javascript
proxy: {
  '/api': {
    target: 'http://localhost:8082',  // Direct to backend for development
    changeOrigin: true,
    secure: false,
  },
  // ... other proxy configurations
}
```

## 🚀 Deployment Scripts

### 1. **`deploy-aws-alb.sh`** - Main deployment script
- Updates ALB DNS name in all configuration files
- Deploys Nginx configuration for multi-port setup
- Starts Docker services with correct port mapping
- Tests local and ALB connectivity

### 2. **`monitor-aws-alb.sh`** - Monitoring and troubleshooting
- Health checks for all services
- Tests both local and ALB endpoints
- Resource monitoring
- Log viewing and service management

### 3. **`verify-deployment.sh`** - Pre-deployment verification
- Validates all configuration files
- Checks port availability
- Verifies environment variables

## 🔍 Testing Endpoints

### Local Testing (Direct to EC2)
```bash
# Backend
curl http://localhost:8082/health-check
curl http://localhost:8082/api/health/

# Frontend  
curl http://localhost:8080/health-check
curl http://localhost:8080/

# Database Proxy
curl http://localhost:5433/health-check
```

### ALB Testing (Through Load Balancer)
```bash
ALB_DNS="your-alb-dns-name.us-east-1.elb.amazonaws.com"

# Backend through ALB
curl http://$ALB_DNS:8082/health-check
curl http://$ALB_DNS:8082/api/health/

# Frontend through ALB
curl http://$ALB_DNS:8080/health-check
curl http://$ALB_DNS:8080/

# Database proxy through ALB
curl http://$ALB_DNS:5433/health-check
```

## 🔐 AWS Configuration Required

### ALB Target Groups
1. **ryo-backend-tg** (Port 8082)
   - Health check: `/health-check`
   - Targets: EC2 instances on port 8082

2. **ryo-frontend-tg** (Port 8080)
   - Health check: `/health-check`
   - Targets: EC2 instances on port 8080

3. **ryo-database-tg** (Port 5433)
   - Health check: `/health-check`
   - Targets: EC2 instances on port 5433

### Security Groups
- **ALB Security Group**: Allow inbound 8080, 8082, 5433 from 0.0.0.0/0
- **EC2 Security Group**: Allow inbound 8080, 8082, 5433 from ALB Security Group

### ALB Listeners
- Port 8082 → ryo-backend-tg
- Port 8080 → ryo-frontend-tg  
- Port 5433 → ryo-database-tg

## 📝 Quick Start Commands

```bash
# 1. Make scripts executable
cd scripts/
./make-executable.sh

# 2. Verify configuration
./verify-deployment.sh

# 3. Deploy for AWS ALB
./deploy-aws-alb.sh

# 4. Monitor and test
./monitor-aws-alb.sh health

# 5. Test ALB connectivity
./monitor-aws-alb.sh alb
```

## 🎯 Benefits of This Architecture

1. **Service Isolation**: Each service has its own ALB port and target group
2. **Independent Scaling**: Scale backend, frontend, and database access independently
3. **Health Monitoring**: ALB monitors each service separately
4. **Load Distribution**: Distribute traffic based on service type
5. **Security**: Database access can be restricted to admin users only
6. **Flexibility**: Easy to add/remove services or change routing rules

## 🔄 Traffic Flow

1. **User Access Frontend**: `http://alb-dns:8080` → ALB → EC2:8080 → Nginx → Docker Frontend
2. **Frontend → Backend API**: `http://alb-dns:8082/api/*` → ALB → EC2:8082 → Nginx → Docker Backend
3. **Admin Database Access**: `http://alb-dns:5433` → ALB → EC2:5433 → Nginx → Docker Database

This architecture provides maximum flexibility and scalability for your RYO application while maintaining security and performance through AWS ALB's advanced load balancing features.

**✅ Your RYO application is now configured for AWS ALB multi-port deployment!**
