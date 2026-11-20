# =============================================================================
# DaanAR Laravel API Railway Dockerfile
# =============================================================================
# Runs Laravel behind Apache with the extensions required by the CMS.
# =============================================================================

FROM php:8.4-apache

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

ENV PORT=8080
COPY docker/daanar.conf /etc/apache2/sites-available/000-default.conf
RUN mkdir -p storage/app/public storage/logs storage/framework/cache/data \
        storage/framework/sessions storage/framework/views bootstrap/cache \
    && composer run-script post-autoload-dump --no-interaction \
    && php artisan storage:link \
    && chown -R www-data:www-data storage bootstrap/cache \
    && a2enmod rewrite \
    && printf '%s\n' 'Listen ${PORT}' > /etc/apache2/ports.conf \
    && apache2ctl -t

EXPOSE 8080

# The mounted storage directory replaces the directory prepared at build time.
CMD mkdir -p storage/app/public storage/logs storage/framework/cache/data \
        storage/framework/sessions storage/framework/views \
    && find storage -xdev \( ! -user www-data -o ! -group www-data \) \
        -exec chown -h www-data:www-data {} + \
    && runuser -u www-data -- php artisan migrate --force \
    && exec apache2-foreground
