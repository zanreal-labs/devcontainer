#!/bin/bash
set -e

echo "Setting up Traefik reverse proxy..."

DOMAIN="${DOMAIN:-app.localhost}"
ROUTES="${ROUTES:-}"
DEFAULTAPP="${DEFAULTAPP:-}"
CONFIG_DIR="/usr/local/share/traefik"

mkdir -p "$CONFIG_DIR"
chmod 777 "$CONFIG_DIR"

# ── Placeholder dynamic.yml (overwritten by traefik-start at runtime) ────────
echo "http:" > "$CONFIG_DIR/dynamic.yml"
chmod 666 "$CONFIG_DIR/dynamic.yml"

# ── Save feature options for runtime use ─────────────────────────────────────
cat > "$CONFIG_DIR/feature.env" <<ENV
DEFAULT_DOMAIN="${DOMAIN}"
ROUTES="${ROUTES}"
DEFAULTAPP="${DEFAULTAPP}"
ENV

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

# ── Start script (generates dynamic.yml at runtime) ─────────────────────────
cat > /usr/local/bin/traefik-start <<'SCRIPT'
#!/bin/bash
set -e

CONFIG_DIR="/usr/local/share/traefik"
source "$CONFIG_DIR/feature.env"

# TRAEFIK_DOMAIN env var overrides the default domain
DOMAIN="${TRAEFIK_DOMAIN:-$DEFAULT_DOMAIN}"

# Fix: Docker bind mount may have created dynamic.yml as a directory
if [ -d "$CONFIG_DIR/dynamic.yml" ]; then
  sudo rm -rf "$CONFIG_DIR/dynamic.yml"
fi

# ── Generate dynamic.yml ─────────────────────────────────────────────────────
{
  echo "http:"
  echo "  routers:"

  IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
  for route in "${ROUTE_ARRAY[@]}"; do
    route="$(echo "$route" | xargs)"
    [ -z "$route" ] && continue
    APP_NAME="${route%%:*}"
    APP_PORT="${route##*:}"

    if [ "$APP_NAME" = "$DEFAULTAPP" ]; then
      cat <<BLOCK
    ${APP_NAME}:
      rule: "Host(\`${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: ${APP_NAME}
      tls: {}
BLOCK
    else
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

# ── Start Traefik ────────────────────────────────────────────────────────────
echo "Starting Traefik reverse proxy..."
docker compose -f "$CONFIG_DIR/docker-compose.yml" up -d
echo ""
echo "  Routes (domain: ${DOMAIN}):"

for route in "${ROUTE_ARRAY[@]}"; do
  route="$(echo "$route" | xargs)"
  [ -z "$route" ] && continue
  APP_NAME="${route%%:*}"
  APP_PORT="${route##*:}"

  if [ "$APP_NAME" = "$DEFAULTAPP" ]; then
    echo "    https://${DOMAIN} → :${APP_PORT} (${APP_NAME})"
  else
    echo "    https://${APP_NAME}.${DOMAIN} → :${APP_PORT}"
  fi
done
SCRIPT
chmod +x /usr/local/bin/traefik-start

# ── Stop script ──────────────────────────────────────────────────────────────
cat > /usr/local/bin/traefik-stop <<'SCRIPT'
#!/bin/bash
set -e
echo "Stopping Traefik..."
docker compose -f /usr/local/share/traefik/docker-compose.yml down
SCRIPT
chmod +x /usr/local/bin/traefik-stop

echo "Traefik configured (default domain: ${DOMAIN})"
echo "  Override at runtime with: TRAEFIK_DOMAIN=myapp.test"
