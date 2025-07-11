#!/bin/bash

# RYO AWS ALB Monitoring and Management Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/path/to/ryo_app"  # Update this path
ALB_DNS_NAME="your-alb-dns-name.us-east-1.elb.amazonaws.com"

echo -e "${BLUE}🔍 RYO AWS ALB Monitoring & Management${NC}"
echo "====================================="

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to check service status
check_local_services() {
    echo -e "\n${BLUE}🐳 Local Docker Services${NC}"
    
    if [[ ! -d "$PROJECT_DIR" ]]; then
        print_error "Project directory not found: $PROJECT_DIR"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        print_error "docker-compose.yml not found in $PROJECT_DIR"
        return 1
    fi
    
    echo "Running containers:"
    docker-compose ps
    
    # Check if containers are healthy
    local containers=$(docker-compose ps --services)
    for container in $containers; do
        local status=$(docker-compose ps $container | tail -n +3 | awk '{print $3}')
        if [[ "$status" == "Up" ]]; then
            print_status "$container container is running"
        else
            print_error "$container container status: $status"
        fi
    done
}

# Function to check Nginx status
check_nginx_status() {
    echo -e "\n${BLUE}🌐 Nginx Status${NC}"
    
    if systemctl is-active --quiet nginx; then
        print_status "Nginx is running"
    else
        print_error "Nginx is not running"
        return 1
    fi
    
    # Check if Nginx is listening on required ports
    local ports=("8080" "8082" "5433")
    for port in "${ports[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            print_status "Nginx listening on port $port"
        else
            print_error "Nginx not listening on port $port"
        fi
    done
}

# Function to test local endpoints
test_local_endpoints() {
    echo -e "\n${BLUE}🧪 Local Endpoint Tests${NC}"
    
    # Test backend
    print_info "Testing backend endpoints..."
    if timeout 5 curl -s -f http://localhost:8082/health-check >/dev/null 2>&1; then
        print_status "Backend health check (8082): OK"
    else
        print_error "Backend health check (8082): Failed"
    fi
    
    if timeout 5 curl -s -f http://localhost:8082/api/health/ >/dev/null 2>&1; then
        print_status "Backend API health (8082): OK"
    else
        print_error "Backend API health (8082): Failed"
    fi
    
    # Test frontend
    print_info "Testing frontend endpoints..."
    if timeout 5 curl -s -f http://localhost:8080/health-check >/dev/null 2>&1; then
        print_status "Frontend health check (8080): OK"
    else
        print_error "Frontend health check (8080): Failed"
    fi
    
    if timeout 5 curl -s -f http://localhost:8080/ >/dev/null 2>&1; then
        print_status "Frontend root (8080): OK"
    else
        print_error "Frontend root (8080): Failed"
    fi
    
    # Test database proxy
    print_info "Testing database proxy..."
    if timeout 5 curl -s -f http://localhost:5433/health-check >/dev/null 2>&1; then
        print_status "Database proxy health check (5433): OK"
    else
        print_error "Database proxy health check (5433): Failed"
    fi
}

# Function to test ALB endpoints
test_alb_endpoints() {
    echo -e "\n${BLUE}🌩️ ALB Endpoint Tests${NC}"
    
    print_info "Testing ALB endpoints for: $ALB_DNS_NAME"
    
    # Test backend through ALB
    print_info "Testing backend through ALB..."
    if timeout 10 curl -s -f http://$ALB_DNS_NAME:8082/health-check >/dev/null 2>&1; then
        print_status "ALB → Backend health check: OK"
    else
        print_error "ALB → Backend health check: Failed"
    fi
    
    if timeout 10 curl -s -f http://$ALB_DNS_NAME:8082/api/health/ >/dev/null 2>&1; then
        print_status "ALB → Backend API: OK"
    else
        print_error "ALB → Backend API: Failed"
    fi
    
    # Test frontend through ALB
    print_info "Testing frontend through ALB..."
    if timeout 10 curl -s -f http://$ALB_DNS_NAME:8080/health-check >/dev/null 2>&1; then
        print_status "ALB → Frontend health check: OK"
    else
        print_error "ALB → Frontend health check: Failed"
    fi
    
    if timeout 10 curl -s -f http://$ALB_DNS_NAME:8080/ >/dev/null 2>&1; then
        print_status "ALB → Frontend root: OK"
    else
        print_error "ALB → Frontend root: Failed"
    fi
    
    # Test database proxy through ALB
    print_info "Testing database proxy through ALB..."
    if timeout 10 curl -s -f http://$ALB_DNS_NAME:5433/health-check >/dev/null 2>&1; then
        print_status "ALB → Database proxy: OK"
    else
        print_error "ALB → Database proxy: Failed"
    fi
}

# Function to show resource usage
show_resource_usage() {
    echo -e "\n${BLUE}📊 Resource Usage${NC}"
    
    # CPU and Memory
    echo "System Resources:"
    free -h
    echo ""
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Usage: " 100 - $1"%"}'
    
    # Disk space
    echo ""
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print "Root: " $3 "/" $2 " (" $5 " used)"}'
    
    # Network connections
    echo ""
    echo "Active Connections:"
    ss -tuln | grep -E ':(8080|8082|5433)' | wc -l | awk '{print "Connections on ALB ports: " $1}'
    
    # Docker stats
    if command -v docker >/dev/null 2>&1; then
        echo ""
        echo "Docker Container Resources:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi
}

# Function to show logs
show_logs() {
    local service=$1
    local lines=${2:-20}
    
    case $service in
        "nginx")
            echo -e "\n${BLUE}📝 Nginx Logs (last $lines lines)${NC}"
            echo "Backend logs (8082):"
            sudo tail -n $lines /var/log/nginx/ryo-backend-8082-access.log 2>/dev/null || echo "No backend access logs"
            echo ""
            echo "Frontend logs (8080):"
            sudo tail -n $lines /var/log/nginx/ryo-frontend-8080-access.log 2>/dev/null || echo "No frontend access logs"
            echo ""
            echo "Database logs (5433):"
            sudo tail -n $lines /var/log/nginx/ryo-database-5433-access.log 2>/dev/null || echo "No database access logs"
            echo ""
            echo "Nginx Error Logs:"
            sudo tail -n $lines /var/log/nginx/error.log
            ;;
        "backend")
            echo -e "\n${BLUE}📝 Backend Logs (last $lines lines)${NC}"
            cd "$PROJECT_DIR"
            docker-compose logs --tail=$lines backend
            ;;
        "frontend")
            echo -e "\n${BLUE}📝 Frontend Logs (last $lines lines)${NC}"
            cd "$PROJECT_DIR"
            docker-compose logs --tail=$lines frontend
            ;;
        "database")
            echo -e "\n${BLUE}📝 Database Logs (last $lines lines)${NC}"
            cd "$PROJECT_DIR"
            docker-compose logs --tail=$lines db
            ;;
        "all")
            show_logs nginx $lines
            show_logs backend $lines
            show_logs frontend $lines
            show_logs database $lines
            ;;
        *)
            print_error "Unknown service: $service. Use: nginx, backend, frontend, database, or all"
            ;;
    esac
}

# Function to restart services
restart_services() {
    local service=$1
    
    case $service in
        "nginx")
            echo -e "\n${BLUE}🔄 Restarting Nginx${NC}"
            sudo systemctl restart nginx
            print_status "Nginx restarted"
            ;;
        "docker")
            echo -e "\n${BLUE}🔄 Restarting Docker services${NC}"
            cd "$PROJECT_DIR"
            docker-compose restart
            print_status "Docker services restarted"
            ;;
        "backend")
            echo -e "\n${BLUE}🔄 Restarting Backend${NC}"
            cd "$PROJECT_DIR"
            docker-compose restart backend
            print_status "Backend restarted"
            ;;
        "frontend")
            echo -e "\n${BLUE}🔄 Restarting Frontend${NC}"
            cd "$PROJECT_DIR"
            docker-compose restart frontend
            print_status "Frontend restarted"
            ;;
        "database")
            echo -e "\n${BLUE}🔄 Restarting Database${NC}"
            cd "$PROJECT_DIR"
            docker-compose restart db
            print_status "Database restarted"
            ;;
        "all")
            restart_services nginx
            restart_services docker
            ;;
        *)
            print_error "Unknown service: $service. Use: nginx, docker, backend, frontend, database, or all"
            ;;
    esac
}

# Function to check ALB target health (requires AWS CLI)
check_alb_target_health() {
    echo -e "\n${BLUE}🎯 ALB Target Group Health${NC}"
    
    if ! command -v aws >/dev/null 2>&1; then
        print_warning "AWS CLI not installed. Cannot check ALB target health."
        return 1
    fi
    
    print_info "Checking ALB target group health..."
    
    # You would need to set these based on your actual target group ARNs
    local backend_tg_arn=""
    local frontend_tg_arn=""
    local database_tg_arn=""
    
    if [[ -n "$backend_tg_arn" ]]; then
        echo "Backend Target Group Health:"
        aws elbv2 describe-target-health --target-group-arn "$backend_tg_arn" --output table
    fi
    
    if [[ -n "$frontend_tg_arn" ]]; then
        echo "Frontend Target Group Health:"
        aws elbv2 describe-target-health --target-group-arn "$frontend_tg_arn" --output table
    fi
    
    if [[ -n "$database_tg_arn" ]]; then
        echo "Database Target Group Health:"
        aws elbv2 describe-target-health --target-group-arn "$database_tg_arn" --output table
    fi
}

# Health check function
health_check() {
    echo -e "\n${BLUE}🏥 ALB Health Check Summary${NC}"
    
    local issues=0
    
    # Check Nginx
    if ! check_nginx_status >/dev/null 2>&1; then
        ((issues++))
    fi
    
    # Check Docker services
    if ! check_local_services >/dev/null 2>&1; then
        ((issues++))
    fi
    
    # Check local endpoints
    test_local_endpoints || ((issues++))
    
    # Check ALB endpoints if DNS name is configured
    if [[ "$ALB_DNS_NAME" != "your-alb-dns-name.us-east-1.elb.amazonaws.com" ]]; then
        test_alb_endpoints || ((issues++))
    else
        print_warning "ALB DNS name not configured. Skipping ALB tests."
    fi
    
    # Check disk space
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        print_error "Disk usage is high: $disk_usage%"
        ((issues++))
    elif [[ $disk_usage -gt 80 ]]; then
        print_warning "Disk usage is elevated: $disk_usage%"
    else
        print_status "Disk usage is normal: $disk_usage%"
    fi
    
    echo ""
    if [[ $issues -eq 0 ]]; then
        print_status "All health checks passed! ✨"
    else
        print_error "$issues issue(s) detected. See details above."
    fi
    
    return $issues
}

# Main menu
case "${1:-}" in
    "health"|"check")
        health_check
        ;;
    "logs")
        show_logs "${2:-all}" "${3:-20}"
        ;;
    "restart")
        restart_services "${2:-all}"
        ;;
    "resources"|"stats")
        show_resource_usage
        ;;
    "nginx")
        check_nginx_status
        show_logs nginx 10
        ;;
    "docker")
        check_local_services
        ;;
    "local")
        test_local_endpoints
        ;;
    "alb")
        test_alb_endpoints
        ;;
    "target-health")
        check_alb_target_health
        ;;
    *)
        echo "Usage: $0 {health|logs|restart|resources|nginx|docker|local|alb|target-health}"
        echo ""
        echo "Commands:"
        echo "  health       - Run full health check"
        echo "  logs         - Show logs (usage: logs [service] [lines])"
        echo "  restart      - Restart services (usage: restart [service])"
        echo "  resources    - Show resource usage"
        echo "  nginx        - Check Nginx status and logs"
        echo "  docker       - Check Docker containers"
        echo "  local        - Test local endpoints"
        echo "  alb          - Test ALB endpoints"
        echo "  target-health - Check ALB target group health (requires AWS CLI)"
        echo ""
        echo "Examples:"
        echo "  $0 health"
        echo "  $0 logs backend 50"
        echo "  $0 restart nginx"
        echo "  $0 alb"
        exit 1
        ;;
esac
