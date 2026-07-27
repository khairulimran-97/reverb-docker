#!/bin/sh
set -e
if [ -z "$APP_KEY" ]; then
    export APP_KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
    echo "⚠️  Generated ephemeral APP_KEY. Set APP_KEY in env for persistence."
fi

# Without a shared Redis, each instance keeps its own connection state and
# clients silently miss events broadcast through a different one.
if [ "$REVERB_SCALING_ENABLED" = "true" ]; then
    : "${REDIS_HOST:?REVERB_SCALING_ENABLED=true requires REDIS_HOST}"
    export REDIS_CLIENT="${REDIS_CLIENT:-phpredis}"
    export REDIS_PORT="${REDIS_PORT:-6379}"
    export REVERB_SCALING_CHANNEL="${REVERB_SCALING_CHANNEL:-reverb}"

    if [ "$REDIS_CLIENT" = "phpredis" ] && ! php -m | grep -qx redis; then
        echo "❌ REDIS_CLIENT=phpredis but the redis extension is missing." >&2
        exit 1
    fi

    php -r '
        $h = getenv("REDIS_HOST"); $p = (int) getenv("REDIS_PORT") ?: 6379;
        $pw = getenv("REDIS_PASSWORD");
        try {
            $r = new Redis();
            $r->connect($h, $p, 3.0);
            if ($pw !== false && $pw !== "" && $pw !== "null") { $r->auth($pw); }
            $r->ping();
        } catch (Throwable $e) {
            fwrite(STDERR, "❌ Redis unreachable at {$h}:{$p} — ".$e->getMessage()."\n");
            exit(1);
        }
    '
    echo "✅ Scaling enabled — Redis ${REDIS_HOST}:${REDIS_PORT}, channel ${REVERB_SCALING_CHANNEL}"
else
    echo "ℹ️  Single-instance mode. Set REVERB_SCALING_ENABLED=true for multiple containers."
fi

php artisan config:cache >/dev/null 2>&1 || true
exec "$@"
