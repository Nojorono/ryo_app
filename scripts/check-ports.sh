#!/bin/bash

# Quick Port Check Script
echo "🔍 Quick Port Check"
echo "=================="

echo "Checking port 8080 (Backend):"
if command -v lsof >/dev/null 2>&1; then
    lsof -i:8080 2>/dev/null || echo "Port 8080 is free"
elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp | grep :8080 || echo "Port 8080 is free"
else
    echo "Cannot check ports (lsof/netstat not available)"
fi

echo ""
echo "Checking port 3000 (Frontend):"
if command -v lsof >/dev/null 2>&1; then
    lsof -i:3000 2>/dev/null || echo "Port 3000 is free"
elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp | grep :3000 || echo "Port 3000 is free"
fi

echo ""
echo "Docker containers status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔧 Quick fixes:"
echo "1. Kill process: sudo kill -9 \$(lsof -ti:8080)"
echo "2. Stop Docker: docker-compose down"
echo "3. Use alt ports: bash fix-port-conflict.sh"
