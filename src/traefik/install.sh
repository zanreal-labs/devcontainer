#!/bin/bash
set -e

echo "Setting up Traefik reverse proxy..."

DOMAIN="${DOMAIN:-app.localhost}"
ROUTES="${ROUTES:-}"
DEFAULTAPP="${DEFAULTAPP:-}"
CONFIG_DIR="/usr/local/share/traefik"

mkdir -p "$CONFIG_DIR"

# ── Static config (traefik.yml) ──────────────────────────────────────────────
cat > "$CONFIG_DIR/traefik.yml" <<'YAML'
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true
YAML

# ── Dynamic config (dynamic.yml) ─────────────────────────────────────────────
{
  echo "http:"
  echo "  routers:"

  IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
  for route in "${ROUTE_ARRAY[@]}"; do
    route="$(echo "$route" | xargs)"  # trim whitespace
    [ -z "$route" ] && continue
    APP_NAME="${route%%:*}"
    APP_PORT="${route##*:}"

    if [ "$APP_NAME" = "$DEFAULTAPP" ]; then
      # Default app gets root domain only
      cat <<BLOCK
    ${APP_NAME}:
      rule: "Host(\`${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: ${APP_NAME}
      tls: {}
BLOCK
    else
      # Non-default apps get subdomain
      cat <<BLOCK
    ${APP_NAME}:
      rule: "Host(\`${APP_NAME}.${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: ${APP_NAME}
      tls: {}
BLOCK
    fi
  done

  echo ""
  echo "  services:"

  for route in "${ROUTE_ARRAY[@]}"; do
    route="$(echo "$route" | xargs)"
    [ -z "$route" ] && continue
    APP_NAME="${route%%:*}"
    APP_PORT="${route##*:}"

    cat <<BLOCK
    ${APP_NAME}:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:${APP_PORT}"
BLOCK
  done
} > "$CONFIG_DIR/dynamic.yml"

# ── Docker Compose ───────────────────────────────────────────────────────────
cat > "$CONFIG_DIR/docker-compose.yml" <<YAML
services:
  traefik:
    image: traefik:v3.3
    container_name: devcontainer-traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${CONFIG_DIR}/dynamic.yml:/etc/traefik/dynamic.yml:ro
YAML

# ── Start script ─────────────────────────────────────────────────────────────
cat > /usr/local/bin/traefik-start <<SCRIPT
#!/bin/bash
set -e
echo "Starting Traefik reverse proxy..."
docker compose -f ${CONFIG_DIR}/docker-compose.yml up -d
echo ""
echo "  Routes:"
SCRIPT

# Add route info to start script
for route in "${ROUTE_ARRAY[@]}"; do
  route="$(echo "$route" | xargs)"
  [ -z "$route" ] && continue
  APP_NAME="${route%%:*}"
  APP_PORT="${route##*:}"

  if [ "$APP_NAME" = "$DEFAULTAPP" ]; then
    echo "echo \"    https://${DOMAIN} → :${APP_PORT} (${APP_NAME})\"" >> /usr/local/bin/traefik-start
  else
    echo "echo \"    https://${APP_NAME}.${DOMAIN} → :${APP_PORT}\"" >> /usr/local/bin/traefik-start
  fi
done

chmod +x /usr/local/bin/traefik-start

# ── Stop script ──────────────────────────────────────────────────────────────
cat > /usr/local/bin/traefik-stop <<SCRIPT
#!/bin/bash
set -e
echo "Stopping Traefik..."
docker compose -f ${CONFIG_DIR}/docker-compose.yml down
SCRIPT
chmod +x /usr/local/bin/traefik-stop

echo "Traefik configured for: ${DOMAIN}"
