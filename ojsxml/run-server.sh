#!/usr/bin/env bash
cd "$(dirname "$0")"
php -c "$(pwd)/php-cli.ini" -S localhost:8000