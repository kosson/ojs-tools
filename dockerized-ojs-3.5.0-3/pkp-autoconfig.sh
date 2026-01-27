#!/bin/bash
# OJS Auto-configuration Script
# This script runs before Apache starts to handle automatic configuration

set -e

PKP_CONF="${PKP_CONF:-/var/www/html/config.inc.php}"
TEMP_CONF="/tmp/config.inc.php.tmp"

echo "[Auto-Config] Starting OJS auto-configuration..."

# Wait a moment for volume mounts to be ready
sleep 2

# Function to generate app_key if not present
generate_app_key() {
    if [ -f "$PKP_CONF" ]; then
        # Check if app_key is empty
        current_key=$(grep "^app_key = " "$PKP_CONF" 2>/dev/null | sed 's/app_key = //' | tr -d ' ' || echo "")
        
        if [ -z "$current_key" ] || [ "$current_key" = "" ]; then
            echo "[Auto-Config] Generating application encryption key..."
            # Generate a random 32-byte key and base64 encode it
            new_key="base64:$(openssl rand -base64 32)"
            
            # Copy file to temp, modify it, and replace original
            cp "$PKP_CONF" "$TEMP_CONF"
            sed "s|^app_key =.*|app_key = $new_key|" "$TEMP_CONF" > "$PKP_CONF.new"
            cat "$PKP_CONF.new" > "$PKP_CONF"
            rm "$TEMP_CONF" "$PKP_CONF.new"
            
            echo "[Auto-Config] ✓ App key generated: ${new_key:0:25}..."
        else
            echo "[Auto-Config] ✓ App key already configured"
        fi
    else
        echo "[Auto-Config] ⚠ Config file not found at $PKP_CONF"
    fi
}

# Function to ensure database configuration is correct from environment variables  
configure_database() {
    if [ -f "$PKP_CONF" ] && [ -n "$PKP_DB_HOST" ]; then
        echo "[Auto-Config] Verifying database configuration..."
        
        # Copy to temp file for modifications
        cp "$PKP_CONF" "$TEMP_CONF"
        
        # Only update if values differ from defaults
        current_host=$(grep "^host = " "$TEMP_CONF" | sed 's/host = //' || echo "")
        if [ -n "$PKP_DB_HOST" ] && [ "$current_host" != "$PKP_DB_HOST" ]; then
            sed -i "s|^host =.*|host = $PKP_DB_HOST|" "$TEMP_CONF"
            echo "[Auto-Config]   - Database host: $PKP_DB_HOST"
        fi
        
        current_user=$(grep "^username = " "$TEMP_CONF" | sed 's/username = //' || echo "")
        if [ -n "$PKP_DB_USER" ] && [ "$current_user" != "$PKP_DB_USER" ]; then
            sed -i "s|^username =.*|username = $PKP_DB_USER|" "$TEMP_CONF"
            echo "[Auto-Config]   - Database user: $PKP_DB_USER"
        fi
        
        current_db=$(grep "^name = " "$TEMP_CONF" | sed 's/name = //' || echo "")
        if [ -n "$PKP_DB_NAME" ] && [ "$current_db" != "$PKP_DB_NAME" ]; then
            sed -i "s|^name =.*|name = $PKP_DB_NAME|" "$TEMP_CONF"
            echo "[Auto-Config]   - Database name: $PKP_DB_NAME"
        fi
        
        # Always update password (don't display it)
        if [ -n "$PKP_DB_PASSWORD" ]; then
            sed -i "s|^password =.*|password = $PKP_DB_PASSWORD|" "$TEMP_CONF"
            echo "[Auto-Config]   - Database password: [HIDDEN]"
        fi
        
        # Copy modified file back
        cat "$TEMP_CONF" > "$PKP_CONF"
        rm "$TEMP_CONF"
        
        echo "[Auto-Config] ✓ Database configuration verified"
    fi
}

# Run auto-configuration
generate_app_key
configure_database

echo "[Auto-Config] Auto-configuration complete!"
echo "[Auto-Config] Starting Apache..."
echo ""

# Start Apache in foreground
exec apache2-foreground
