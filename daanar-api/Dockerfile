# =============================================================================
# DaanAR Laravel API Railway Dockerfile
# =============================================================================
# Uses the official PHP 8.4 CLI image with all required extensions installed,
# because Railway's Nixpacks/FrankenPHP builder does NOT load gd, intl, bcmath,
# or zip even when declared in nixpacks.toml.
# =============================================================================

FROM php:8.4-cli

# Install system dependencies for PHP extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    libicu-dev \
    libzip-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions that Filament/Laravel requires
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        gd \
        intl \
        bcmath \
        zip \
        xml \
        fileinfo \
        opcache

# Set PHP configuration
RUN echo "upload_max_filesize=350M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size=350M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "memory_limit=1024M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_execution_time=600" >> /usr/local/etc/php/conf.d/uploads.ini

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy composer files first (for layer caching)
COPY composer.json composer.lock ./

# Install PHP dependencies (production only)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Copy the rest of the application
COPY . .

# Run post-install scripts (package discovery, filament upgrade)
RUN composer run-script post-autoload-dump --no-interaction 2>/dev/null || true

# Create storage link and set permissions
RUN php artisan storage:link 2>/dev/null || true \
    && chmod -R 775 storage bootstrap/cache \
    && mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views

# Expose port
EXPOSE 8080

# Start command: clear caches, run migrations, seed, then serve
CMD php artisan route:clear && \
    php artisan config:clear && \
    php artisan view:clear && \
    php artisan migrate --force && \
    php artisan db:seed --force && \
    php artisan admin:reset-password && \
    php artisan storage:link 2>/dev/null; \
    php artisan serve --host 0.0.0.0 --port 8080
