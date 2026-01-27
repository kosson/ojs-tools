#!/bin/bash
# Post-installation fixer for OJS
# This script fixes the installation after it crashes during the ROR dataset step

set -e

echo "===== OJS Installation Completion Script ====="
echo "This script completes the OJS installation after the ROR dataset crash"
echo ""

# Check if database exists
if ! docker exec pkp_db_ojs mariadb -upkp -pcine4re4re -e "USE pkp; SELECT 1" >/dev/null 2>&1; then
    echo "✗ Database 'pkp' not found. Please run the web installer first."
    exit 1
fi

# Check if versions table exists
if ! docker exec pkp_db_ojs mariadb -upkp -pcine4re4re pkp -e "SHOW TABLES LIKE 'versions'" 2>/dev/null | grep -q "versions"; then
    echo "✗ Tables not created yet. Please run the web installer first."
    exit 1
fi

# Check if version record exists
VERSION_COUNT=$(docker exec pkp_db_ojs mariadb -upkp -pcine4re4re pkp -N -e "SELECT COUNT(*) FROM versions WHERE product='ojs2' AND current=1" 2>/dev/null || echo "0")

if [ "$VERSION_COUNT" -gt "0" ]; then
    echo "✓ Installation is already complete!"
    echo ""
    echo "OJS version information:"
    docker exec pkp_db_ojs mariadb -upkp -pcine4re4re pkp -e "SELECT product, CONCAT(major, '.', minor, '.', revision, '-', build) as version, date_installed FROM versions WHERE current=1"
else
    echo "Completing installation..."
    echo "Inserting version record..."
    
    docker exec pkp_db_ojs mariadb -upkp -pcine4re4re pkp -e "
        INSERT INTO versions (major, minor, revision, build, date_installed, current, product_type, product, product_class_name, lazy_load, sitewide)
        VALUES (3, 5, 0, 3, NOW(), 1, 'core', 'ojs2', '', 0, 1)
        ON DUPLICATE KEY UPDATE current=1;
    "
    
    echo "✓ Version record inserted"
fi

# Update config file to mark as installed
echo "Updating configuration..."
docker exec pkp_app_ojs sed -i 's/^installed = Off/installed = On/' /var/www/html/config.inc.php 2>/dev/null || echo "Config already set to installed"

echo ""
echo "====================================="
echo "✓ OJS installation is now complete!"
echo "====================================="
echo "Access: http://localhost:8080"
echo ""
echo "Login with the credentials you created during web installation"
echo "(If web install didn't complete, use: admin / password you entered)"
