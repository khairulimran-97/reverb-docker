#!/bin/bash
set -e
DOMAIN=${1:?Usage: reverb-init <domain> <app-id> [image-tag]}
APP_ID=${2:?Usage: reverb-init <domain> <app-id> [image-tag]}
IMAGE_TAG=${3:-latest}

INSTALL_DIR="/opt/reverb"
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

APP_KEY="base64:$(openssl rand -base64 32)"
REVERB_KEY=$(openssl rand -hex 16)
REVERB_SECRET=$(openssl rand -hex 32)
APP_URL="https://$(echo "$DOMAIN" | sed 's/^reverb\.//')"

cat > .env <<EOF
REVERB_DOMAIN=${DOMAIN}
APP_KEY=${APP_KEY}
APP_ENV=production
APP_DEBUG=false
APP_URL=${APP_URL}
REVERB_APP_ID=${APP_ID}
REVERB_APP_KEY=${REVERB_KEY}
REVERB_APP_SECRET=${REVERB_SECRET}
REVERB_HOST=0.0.0.0
REVERB_PORT=8080
REVERB_SCHEME=https
BROADCAST_CONNECTION=reverb
EOF

cat > docker-compose.yml <<EOF
services:
  reverb:
    image: ghcr.io/khairulimran-97/reverb:${IMAGE_TAG}
    container_name: reverb
    restart: unless-stopped
    env_file: .env
    networks: [traefik]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.reverb.rule=Host(\`\${REVERB_DOMAIN}\`)"
      - "traefik.http.routers.reverb.entrypoints=websecure"
      - "traefik.http.routers.reverb.tls.certresolver=letsencrypt"
      - "traefik.http.services.reverb.loadbalancer.server.port=8080"
networks:
  traefik:
    external: true
EOF

chmod 600 .env
echo "✅ Reverb configured for ${DOMAIN}"
echo ""
echo "Add to your Laravel app .env:"
echo "  REVERB_APP_ID=${APP_ID}"
echo "  REVERB_APP_KEY=${REVERB_KEY}"
echo "  REVERB_APP_SECRET=${REVERB_SECRET}"
echo "  REVERB_HOST=${DOMAIN}"
echo "  REVERB_PORT=443"
echo "  REVERB_SCHEME=https"
echo ""
echo "Next: cd ${INSTALL_DIR} && docker compose up -d"
