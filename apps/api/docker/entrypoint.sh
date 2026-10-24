#!/bin/sh
set -e

# Default PORT if Render does not supply it
PORT="${PORT:-10000}"

# Inject actual PORT into nginx configuration
sed -i "s/\${PORT}/$PORT/g" /etc/nginx/http.d/default.conf

# Create necessary storage directories if missing
mkdir -p /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/framework/cache \
         /var/www/html/storage/logs \
         /var/www/html/bootstrap/cache

# Ensure correct permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Run database migrations if configured
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    php artisan migrate --force || true
fi

# Cache configuration and routes for production performance
if [ -n "$APP_KEY" ]; then
    echo "Caching routes and configuration..."
    php artisan config:cache || true
    php artisan route:cache || true
fi

echo "Starting PHP-FPM..."
php-fpm -D

echo "Starting Nginx on port $PORT..."
exec nginx -g "daemon off;"
