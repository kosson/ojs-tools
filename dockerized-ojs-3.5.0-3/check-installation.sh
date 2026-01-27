#!/bin/bash
# OJS Installation Health Check Script

echo "======================================"
echo "OJS Installation Health Check"
echo "======================================"
echo ""

# Load database credentials from .env file
if [ -f ".env" ]; then
    DB_ROOT_PASS=$(grep "^MYSQL_ROOT_PASSWORD=" .env | cut -d'=' -f2 | tr -d '"' | sed 's/\${DB_PASS}//' || echo "")
    if [ -z "$DB_ROOT_PASS" ]; then
        DB_ROOT_PASS=$(grep "^DB_PASS=" .env | cut -d'=' -f2 | tr -d '"' || echo "changeMePlease")
    fi
    DB_USER_VAL=$(grep "^DB_USER=" .env | cut -d'=' -f2 | tr -d '"' || echo "pkp")
    DB_PASS_VAL=$(grep "^DB_PASS=" .env | cut -d'=' -f2 | tr -d '"' || echo "changeMePlease")
    DB_NAME_VAL=$(grep "^DB_NAME=" .env | cut -d'=' -f2 | tr -d '"' || echo "pkp")
else
    echo "⚠ Warning: .env file not found, using default credentials"
    DB_ROOT_PASS="changeMePlease"
    DB_USER_VAL="pkp"
    DB_PASS_VAL="changeMePlease"
    DB_NAME_VAL="pkp"
fi

# Check if containers are running
echo "1. Checking containers status..."
if docker compose ps | grep -q "Up"; then
    echo "   ✓ Containers are running"
else
    echo "   ✗ Containers are not running"
    exit 1
fi
echo ""

# Check database connectivity
echo "2. Checking database connectivity..."
if docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASS" -e "SELECT 1;" &>/dev/null; then
    echo "   ✓ Database is accessible"
else
    echo "   ✗ Cannot connect to database"
    exit 1
fi
echo ""

# Check database and tables
echo "3. Checking database schema..."
TABLE_COUNT=$(docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASS" "$DB_NAME_VAL" -e "SHOW TABLES;" 2>/dev/null | wc -l)
if [ "$TABLE_COUNT" -gt 100 ]; then
    echo "   ✓ Database has $TABLE_COUNT tables (installation complete)"
elif [ "$TABLE_COUNT" -gt 0 ]; then
    echo "   ⚠ Database has only $TABLE_COUNT tables (partial installation)"
else
    echo "   ✗ Database is empty (not installed)"
fi
echo ""

# Check config file
echo "4. Checking configuration file..."
INSTALLED=$(docker compose exec -T app grep "^installed = " /var/www/html/config.inc.php 2>/dev/null | awk '{print $3}')
echo "   Installed flag: $INSTALLED"

DB_HOST=$(docker compose exec -T app grep "^host = " /var/www/html/config.inc.php 2>/dev/null | awk '{print $3}')
DB_USER=$(docker compose exec -T app grep "^username = " /var/www/html/config.inc.php 2>/dev/null | awk '{print $3}')
DB_NAME=$(docker compose exec -T app grep "^name = " /var/www/html/config.inc.php 2>/dev/null | awk '{print $3}')

echo "   Database host: $DB_HOST"
echo "   Database user: $DB_USER"
echo "   Database name: $DB_NAME"

if [ "$DB_HOST" = "db" ] && [ "$DB_USER" = "pkp" ] && [ "$DB_NAME" = "pkp" ]; then
    echo "   ✓ Database configuration is correct"
else
    echo "   ✗ Database configuration is incorrect"
fi
echo ""

# Check file permissions
echo "5. Checking file permissions..."
CACHE_PERMS=$(docker compose exec -T app stat -c '%a' /var/www/html/cache 2>/dev/null)
FILES_PERMS=$(docker compose exec -T app stat -c '%a' /var/www/files 2>/dev/null)
PUBLIC_PERMS=$(docker compose exec -T app stat -c '%a' /var/www/html/public 2>/dev/null)

echo "   cache/: $CACHE_PERMS"
echo "   files/: $FILES_PERMS"
echo "   public/: $PUBLIC_PERMS"

if [ "$CACHE_PERMS" -ge 755 ] && [ "$FILES_PERMS" -ge 755 ]; then
    echo "   ✓ Permissions look good"
else
    echo "   ⚠ Some directories may have permission issues"
fi
echo ""

# Check Apache errors
echo "6. Checking recent Apache/PHP errors..."
docker compose logs app --tail 20 2>&1 | grep -i "error\|fatal\|warning" | tail -5
echo ""

# Check PHP version and modules
echo "7. Checking PHP configuration..."
PHP_VERSION=$(docker compose exec -T app php -v 2>/dev/null | head -1)
echo "   $PHP_VERSION"
echo ""

# Test database connection from app
echo "8. Testing database connection from app container..."
DB_TEST=$(docker compose exec -T app php -r "
\$mysqli = new mysqli('db', '$DB_USER_VAL', '$DB_PASS_VAL', '$DB_NAME_VAL');
if (\$mysqli->connect_error) {
    echo 'Connection failed: ' . \$mysqli->connect_error;
    exit(1);
} else {
    echo 'Connection successful';
    \$mysqli->close();
}
" 2>&1)
echo "   $DB_TEST"
echo ""

# Check if site is responding
echo "9. Testing HTTP response..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null)
echo "   HTTP Status Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "   ✓ Site is responding"
elif [ "$HTTP_CODE" = "500" ]; then
    echo "   ✗ Server error (500)"
else
    echo "   ⚠ Unexpected status code"
fi
echo ""

# Check for common issues
echo "10. Checking for common issues..."

# Check if config is writable
CONFIG_WRITABLE=$(docker compose exec -T app test -w /var/www/html/config.inc.php && echo "yes" || echo "no")
if [ "$CONFIG_WRITABLE" = "yes" ]; then
    echo "    ⚠ config.inc.php is writable (should be read-only after install)"
else
    echo "    ✓ config.inc.php is read-only"
fi

# Check cache size
CACHE_SIZE=$(docker compose exec -T app du -sh /var/www/html/cache 2>/dev/null | awk '{print $1}')
echo "    Cache size: $CACHE_SIZE"

echo ""
echo "======================================"
echo "Health Check Complete"
echo "======================================"
