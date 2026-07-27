# Reverb Docker

Reusable [Laravel Reverb](https://reverb.laravel.com/) WebSocket server image, shipped as a multi-arch container for multi-project use.

- **Image:** `ghcr.io/khairulimran-97/reverb`
- **Stack:** PHP 8.5 · Laravel 13 · Reverb 1.7+ · Alpine
- **Platforms:** `linux/amd64`, `linux/arm64`

The image bakes a minimal Laravel app with Reverb installed so you don't need to ship your full application to run the WebSocket server. Your Laravel app connects to it remotely via the shared `REVERB_APP_*` credentials.

## Quick start

On your deployment server (Traefik with a `traefik` external network assumed):

```bash
# Install the bootstrap helper
sudo curl -fsSL https://raw.githubusercontent.com/khairulimran-97/reverb-docker/main/scripts/reverb-init.sh \
  -o /usr/local/bin/reverb-init && sudo chmod +x /usr/local/bin/reverb-init

# Bootstrap: <reverb-domain> <app-id> [image-tag]
sudo reverb-init reverb.example.com my-app-1 v1.0.0

# Start it
cd /opt/reverb && docker compose up -d
```

The script writes `/opt/reverb/.env` and `/opt/reverb/docker-compose.yml`, and prints the `REVERB_APP_*` values to copy into your Laravel app's `.env`.

## Pulling from GHCR

Public packages don't need auth. For private packages:

```bash
echo "$GHCR_PAT" | docker login ghcr.io -u <your-username> --password-stdin
```

Create the PAT with `read:packages` scope.

## Environment variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `APP_KEY` | Recommended | auto-generated (ephemeral) | `base64:…` — set for persistence across restarts |
| `APP_ENV` | No | `production` | |
| `APP_DEBUG` | No | `false` | |
| `APP_URL` | Yes* | — | Base URL of your Laravel app. Required for private channel auth. |
| `REVERB_APP_ID` | Yes | — | App identifier shared with your Laravel app |
| `REVERB_APP_KEY` | Yes | — | Public key shared with your Laravel app |
| `REVERB_APP_SECRET` | Yes | — | Secret shared with your Laravel app |
| `REVERB_HOST` | No | `0.0.0.0` | Bind host inside the container |
| `REVERB_PORT` | No | `8080` | Bind port inside the container |
| `REVERB_SCHEME` | No | `https` | `http` locally, `https` behind TLS |
| `BROADCAST_CONNECTION` | No | `reverb` | |
| `REVERB_SCALING_ENABLED` | No | `false` | Set `true` to run **several containers** behind one domain |
| `REDIS_HOST` | If scaling | — | Required when scaling is enabled |
| `REDIS_PORT` | No | `6379` | |
| `REDIS_PASSWORD` | No | — | |
| `REDIS_CLIENT` | No | `phpredis` | The extension is built in |
| `REVERB_SCALING_CHANNEL` | No | `reverb` | Must match across all containers |

## Running several containers

One container needs nothing extra. To run several behind the same domain they
must share a Redis backplane, or each keeps its own connection state and clients
silently miss events broadcast through a different one.

```yaml
x-reverb: &reverb
  image: ghcr.io/khairulimran-97/reverb:1.1
  environment:
    REVERB_APP_ID: my-app
    REVERB_APP_KEY: ...
    REVERB_APP_SECRET: ...
    REVERB_SCALING_ENABLED: "true"
    REDIS_HOST: redis
    REDIS_PASSWORD: ...

services:
  reverb-1: { <<: *reverb, container_name: reverb-1 }
  reverb-2: { <<: *reverb, container_name: reverb-2 }
  reverb-3: { <<: *reverb, container_name: reverb-3 }
```

With scaling enabled the container pings Redis at startup and **exits** if it is
unreachable — a misconfigured backplane otherwise looks healthy while dropping
cross-instance events.

Your Laravel *application* should use the public-facing values:

```env
REVERB_APP_ID=<same as server>
REVERB_APP_KEY=<same as server>
REVERB_APP_SECRET=<same as server>
REVERB_HOST=reverb.example.com
REVERB_PORT=443
REVERB_SCHEME=https
```

## Version pinning & upgrades

Pin a tag in `docker-compose.yml`:

```yaml
image: ghcr.io/khairulimran-97/reverb:v1.0.0   # exact
image: ghcr.io/khairulimran-97/reverb:1.0      # minor
image: ghcr.io/khairulimran-97/reverb:latest   # main branch
```

Upgrade:

```bash
cd /opt/reverb
sed -i 's|reverb:v1.0.0|reverb:v1.1.0|' docker-compose.yml
docker compose pull && docker compose up -d
```

## Local testing

```bash
docker run --rm -p 8080:8080 \
  -e REVERB_APP_ID=test \
  -e REVERB_APP_KEY=testkey \
  -e REVERB_APP_SECRET=testsecret \
  ghcr.io/khairulimran-97/reverb:latest
```

## Troubleshooting

- **Traefik network name** — The compose file assumes an external network literally named `traefik`. If yours is different (e.g. `proxy`), edit `/opt/reverb/docker-compose.yml` and match the `networks:` section.
- **Private channel auth failures** — Make sure `APP_URL` on the Reverb container matches your Laravel app's public URL. Reverb calls back to `APP_URL/broadcasting/auth` to authorize private/presence channels.
- **`denied` / `unauthorized` pulling from GHCR** — Either the package is private (needs `docker login ghcr.io` with a `read:packages` PAT) or it hasn't been made public yet. Publish as public at: <https://github.com/users/khairulimran-97/packages/container/reverb/settings>
- **`APP_KEY` changes on each restart** — You didn't set `APP_KEY` in `.env`. The entrypoint logs a warning when it generates an ephemeral one.
- **WebSocket upgrade fails behind Traefik** — Ensure the router uses `entrypoints=websecure` and `tls.certresolver=letsencrypt` (or your resolver), and that port `8080` is the loadbalancer target — Traefik handles the WebSocket upgrade automatically.

## License

MIT
