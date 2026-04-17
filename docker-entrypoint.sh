#!/bin/sh
set -e
if [ -z "$APP_KEY" ]; then
    export APP_KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
    echo "⚠️  Generated ephemeral APP_KEY. Set APP_KEY in env for persistence."
fi
php artisan config:cache >/dev/null 2>&1 || true
exec "$@"
