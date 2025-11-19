#!/bin/bash
# Secure Stremio Server Launcher (Headless)
# For server-only deployments without GUI
# GPLv3 License - https://github.com/vejeta/docker-stremio-wolfi

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

USER_UID="${UID:-$(id -u)}"
USER_GID="${GID:-$(id -g)}"
IMAGE_NAME="${STREMIO_SERVER_IMAGE:-ghcr.io/vejeta/stremio-wolfi:server}"

# Server configuration
STREMIO_PORT="${STREMIO_PORT:-11470}"
STREMIO_HTTPS_PORT="${STREMIO_HTTPS_PORT:-12470}"
DATA_DIR="${STREMIO_DATA_DIR:-${HOME}/.stremio-server}"

# Create data directory if it doesn't exist
mkdir -p "${DATA_DIR}"

echo "🔒 Launching Stremio Server (headless) with security hardening..."
echo "   User: ${USER_UID}:${USER_GID}"
echo "   HTTP Port: ${STREMIO_PORT}"
echo "   HTTPS Port: ${STREMIO_HTTPS_PORT}"
echo "   Data: ${DATA_DIR}"
echo "   Image: ${IMAGE_NAME}"

# ============================================================================
# Docker Run with Security Hardening
# ============================================================================

docker run -d \
    `# ---- Security Hardening ----` \
    --security-opt=no-new-privileges:true \
    --cap-drop=ALL \
    --read-only \
    \
    `# ---- User Namespace ----` \
    --user "${USER_UID}:${USER_GID}" \
    \
    `# ---- Writable Mounts ----` \
    --tmpfs /tmp:rw,noexec,nosuid,size=512m \
    -v "${DATA_DIR}:/home/nonroot/.stremio-server:rw" \
    \
    `# ---- Network Ports ----` \
    -p "${STREMIO_PORT}:11470" \
    -p "${STREMIO_HTTPS_PORT}:12470" \
    \
    `# ---- Environment ----` \
    -e NODE_ENV=production \
    \
    `# ---- Resource Limits ----` \
    --memory="1g" \
    --memory-swap="1g" \
    --cpus="1.5" \
    --pids-limit=100 \
    \
    `# ---- Container Name ----` \
    --name stremio-server \
    \
    `# ---- Health Check ----` \
    --health-cmd="curl -f http://localhost:11470/ || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    \
    `# ---- Restart Policy ----` \
    --restart=unless-stopped \
    \
    "${IMAGE_NAME}" "$@"

echo "Stremio Server started successfully"
echo ""
echo "Access the server at:"
echo "  HTTP:  http://localhost:${STREMIO_PORT}"
echo "  HTTPS: https://localhost:${STREMIO_HTTPS_PORT}"
echo ""
echo "To view logs: docker logs -f stremio-server"
echo "To stop: docker stop stremio-server"
