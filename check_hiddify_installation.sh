#!/bin/bash
# Check if HiddifyPanel is installed

echo "=========================================="
echo "Checking HiddifyPanel Installation"
echo "=========================================="
echo ""

# Check 1: Is HiddifyManager installed?
echo "1. Checking for HiddifyManager..."
if [ -d "/opt/hiddify-manager" ]; then
    echo "✓ /opt/hiddify-manager exists"
    ls -la /opt/hiddify-manager/ | head -10
else
    echo "✗ /opt/hiddify-manager not found"
fi

# Check 2: Is there a web server running on port 80/443?
echo ""
echo "2. Checking for web server..."
if netstat -tuln 2>/dev/null | grep -E ":(80|443|9000)" > /dev/null; then
    echo "✓ Web server found on ports:"
    netstat -tuln 2>/dev/null | grep -E ":(80|443|9000)"
else
    echo "✗ No web server found on common ports"
fi

# Check 3: Check for Hiddify installation script
echo ""
echo "3. Checking for Hiddify installation..."
if [ -f "/root/hiddify-manager/install.sh" ] || [ -f "/opt/hiddify-manager/install.sh" ]; then
    echo "✓ Hiddify installation script found"
else
    echo "✗ Hiddify installation script not found"
fi

# Check 4: Check for Docker
echo ""
echo "4. Checking for Docker containers..."
if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker is installed"
    docker ps -a | grep -i hiddify || echo "  No Hiddify containers found"
else
    echo "✗ Docker not installed"
fi

# Check 5: Check for nginx/apache configs
echo ""
echo "5. Checking for web server configs..."
if [ -d "/etc/nginx" ]; then
    echo "✓ Nginx found"
    grep -r "hiddify" /etc/nginx/sites-enabled/ 2>/dev/null | head -3 || echo "  No Hiddify configs in nginx"
fi

if [ -d "/etc/apache2" ]; then
    echo "✓ Apache found"
    grep -r "hiddify" /etc/apache2/ 2>/dev/null | head -3 || echo "  No Hiddify configs in apache"
fi

# Check 6: Check for database
echo ""
echo "6. Checking for database..."
if command -v mysql >/dev/null 2>&1; then
    echo "✓ MySQL found"
    mysql -e "SHOW DATABASES LIKE 'hiddify%';" 2>/dev/null || echo "  Could not connect to MySQL"
fi

if [ -f "/opt/hiddify-manager/hiddify-panel/hiddifypanel.db" ]; then
    echo "✓ SQLite database found"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If HiddifyPanel is not installed, you need to install it first:"
echo ""
echo "Option 1: Install HiddifyManager (recommended)"
echo "  bash <(curl -sSL https://get.hiddify.com/install.sh)"
echo ""
echo "Option 2: Install HiddifyPanel only"
echo "  Follow: https://github.com/hiddify/HiddifyPanel"
echo ""
echo "After installation, run this script again to find the path."

