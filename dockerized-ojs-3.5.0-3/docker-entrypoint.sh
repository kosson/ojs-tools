#!/bin/bash
# Custom entrypoint for OJS to bypass config file modification issues

set -e

echo "[Custom Entrypoint] Starting OJS..."
echo "SERVERNAME: ${SERVERNAME:-localhost}"
echo "PKP_DB_HOST: ${PKP_DB_HOST:-db}"
echo "PKP_DB_NAME: ${PKP_DB_NAME:-pkp}"

# Ensure all necessary directories exist and have correct permissions
echo "[Custom Entrypoint] Setting up directories and permissions..."
mkdir -p /var/www/files /var/www/html/public /var/www/html/cache \
         /var/www/html/plugins /var/www/html/lib/pkp/cache

# Ensure www-data owns all web directories (ignore errors for read-only mounts)
chown -R www-data:www-data /var/www/files /var/www/html/cache \
                           /var/www/html/public /var/www/html/plugins \
                           /var/www/html/lib/pkp 2>/dev/null || true

# Fix permissions for writable directories
chmod -R 775 /var/www/files /var/www/html/cache /var/www/html/public 2>/dev/null || true

# Generate self-signed SSL certificates if they don't exist
if [ ! -f "/etc/ssl/apache2/server.pem" ]; then
    echo "[Custom Entrypoint] Generating self-signed SSL certificates..."
    mkdir -p /etc/ssl/apache2
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/apache2/server.key \
        -out /etc/ssl/apache2/server.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${SERVERNAME:-localhost}" 2>/dev/null || true
fi

echo "[Custom Entrypoint] Starting Apache..."
# Start Apache in foreground
exec apache2-foreground
