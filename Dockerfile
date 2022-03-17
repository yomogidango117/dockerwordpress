FROM php:7.3-fpm-alpine

# Environment values
ARG WP_PATH
ARG WP_VERSION
ARG WP_LOCALE

# Initial setup
RUN set -ex; \
# 1) Install initial modules
    apk update; \
    apk add --no-cache \
            wget \
            unzip \
        bash \
        sed \
        ghostscript \
      mysql; \
# 2) Install php extension
  apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    freetype-dev \
    imagemagick-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev; \
  docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr; \
  docker-php-ext-install -j "$(nproc)" \
    bcmath \
    exif \
    gd \
    mysqli \
    opcache \
    zip; \
  pecl install imagick-3.4.4; \
  docker-php-ext-enable imagick; \
  runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )"; \
  apk add --virtual .wordpress-phpexts-rundeps $runDeps; \
  apk del .build-deps; \
# 3) Create custom php.ini
# recommended opacache ini
  { \
    echo "opcache.memory_consumption=128"; \
    echo "opcache.interned_strings_buffer=8"; \
    echo "opcache.max_accelerated_files=4000"; \
    echo "opcache.revalidate_freq=2"; \
    echo "opcache.fast_shutdown=1"; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
# recommend log ini
  { \
    echo "error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR"; \
    echo "display_errors = Off"; \
    echo "display_startup_errors = Off"; \
    echo "log_errors = On"; \
    echo "error_log = /dev/stderr"; \
    echo "log_errors_max_len = 1024"; \
    echo "ignore_repeated_errors = On"; \
    echo "ignore_repeated_source = Off"; \
    echo "html_errors = Off"; \
  } > /usr/local/etc/php/conf.d/error-logging.ini;

# Install Wordpress and plugins
RUN set -ex; \
# download wordpress
    wget "https://${WP_LOCALE}.wordpress.org/wordpress-${WP_VERSION}-${WP_LOCALE}.tar.gz"; \
    tar -xvzf "wordpress-${WP_VERSION}-${WP_LOCALE}.tar.gz" -C ${WP_PATH} --strip=1; \
    rm "wordpress-${WP_VERSION}-${WP_LOCALE}.tar.gz"; \
# download plugins
    wget https://downloads.wordpress.org/plugin/wp-multibyte-patch.2.8.3.zip; \
    unzip *.zip -d ${WP_PATH}/wp-content/plugins/; \
    rm *.zip;

# Copied wordpress config
ADD wp-config.php ${WP_PATH}/wp-config.php

# Change authority
RUN set -ex; \
  chmod -R 0707 \
  ${WP_PATH}/wp-content;
