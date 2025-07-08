#!/bin/bash
# filepath: ryo_app/setup.sh

echo "🚀 RYO App Setup Script"
echo "======================"

# Add backend repository as submodule
echo "📦 Adding backend as submodule..."
git submodule add https://github.com/Nojorono/voucher_be.git backend

# Add frontend as submodule  
echo "📦 Adding frontend as submodule..."
git submodule add https://github.com/Nojorono/voucher_fe.git frontend

# Initialize and update submodules
echo "🔄 Initializing submodules..."
git submodule update --init --recursive
git submodule update --remote

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh

# Copy environment file if not exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
fi

echo "✅ Setup completed!"
echo "📋 Next steps:"
echo "   1. Update .env with your configuration"
echo "   2. Run: docker-compose up -d --build"
echo "   3. Access: http://localhost (backend), http://localhost:3000 (frontend)"
echo "   4. For NGINX: ./scripts/deploy-nginx.sh"
echo "   5. For Docker cleanup: ./scripts/docker-cleanup-restart.sh"
echo "   6. For status check: ./scripts/check-status.sh"