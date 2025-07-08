# RYO Application Suite

Complete RYO application with backend API, admin dashboard, and database integration.

## 🏗️ Architecture

- **Backend**: Django REST API (Python)
- **Frontend**: React Admin Dashboard
- **Database**: PostgreSQL
- **Deployment**: Docker Compose
- **Web Server**: NGINX

## 🚀 Quick Start

### One-Command Setup

```bash
# Clone with all submodules
git clone --recursive https://github.com/Nojorono/ryo_app.git
cd ryo_app

# Run setup script
./setup.sh

# Start application
docker-compose up -d --build

## to use NGINX ##
cd nginx 
cp * /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/ 