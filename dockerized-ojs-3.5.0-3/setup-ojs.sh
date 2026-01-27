#!/bin/bash
# OJS Setup Script - Prepares configuration before starting containers
# Run this once before 'docker compose up'

set -e

PKP_CONF="./volumes/config/pkp.config.inc.php"

echo "=========================================="
echo "OJS Setup - Configuration Preparation"
echo "=========================================="
echo ""

# Function to generate app_key if not present
generate_app_key() {
    if [ -f "$PKP_CONF" ]; then
        # Check if app_key is empty
        current_key=$(grep "^app_key = " "$PKP_CONF" 2>/dev/null | sed 's/app_key = //' | tr -d ' ' || echo "")
        
        if [ -z "$current_key" ] || [ "$current_key" = "" ]; then
            echo "✓ Generating application encryption key..."
            # Generate a random 32-byte key and base64 encode it
            new_key="base64:$(openssl rand -base64 32)"
            
            # Update the config file
            sed -i "s|^app_key =.*|app_key = $new_key|" "$PKP_CONF"
            echo "  App key generated: ${new_key:0:30}..."
        else
            echo "✓ App key already configured"
        fi
    else
        echo "✗ Config file not found at $PKP_CONF"
        exit 1
    fi
}

# Function to ensure database configuration matches .env
configure_from_env() {
    if [ -f ".env" ]; then
        echo "✓ Loading database configuration from .env..."
        
        # Read values directly from .env without sourcing (to avoid PKP_CONF override)
        DB_HOST_VAL=$(grep "^DB_HOST=" .env | cut -d'=' -f2 | tr -d '"' || echo "db")
        DB_USER_VAL=$(grep "^DB_USER=" .env | cut -d'=' -f2 | tr -d '"' || echo "pkp")
        DB_PASS_VAL=$(grep "^DB_PASS=" .env | cut -d'=' -f2 | tr -d '"' || echo "changeMePlease")
        DB_NAME_VAL=$(grep "^DB_NAME=" .env | cut -d'=' -f2 | tr -d '"' || echo "pkp")
        
        # Update database configuration
        sed -i "s|^host =.*|host = ${DB_HOST_VAL}|" "$PKP_CONF"
        echo "  Database host: ${DB_HOST_VAL}"
        
        sed -i "s|^username =.*|username = ${DB_USER_VAL}|" "$PKP_CONF"
        echo "  Database user: ${DB_USER_VAL}"
        
        sed -i "s|^password =.*|password = ${DB_PASS_VAL}|" "$PKP_CONF"
        echo "  Database password: [HIDDEN]"
        
        sed -i "s|^name =.*|name = ${DB_NAME_VAL}|" "$PKP_CONF"
        echo "  Database name: ${DB_NAME_VAL}"
    else
        echo "⚠ .env file not found, skipping database configuration"
    fi
}

# Run setup
generate_app_key
echo ""
configure_from_env

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "You can now start the containers with:"
echo "  docker compose up -d"
echo ""
