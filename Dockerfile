FROM php:8.5-alpine

RUN apk add --no-cache git unzip tini \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS linux-headers \
    && docker-php-ext-install pcntl sockets \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN adduser -D -u 100 -g 101 reverb

WORKDIR /app
RUN composer create-project laravel/laravel:^13.0 . --prefer-dist --no-dev --no-interaction \
    && composer require laravel/reverb:^1.7 --no-interaction \
    && composer clear-cache \
    && chown -R reverb:reverb /app

COPY --chown=reverb:reverb docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER reverb
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD nc -z localhost 8080 || exit 1
ENTRYPOINT ["/sbin/tini", "--", "docker-entrypoint.sh"]
CMD ["php", "artisan", "reverb:start", "--host=0.0.0.0", "--port=8080"]
