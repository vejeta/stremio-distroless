#!/bin/bash
# Secure Stremio Launcher with Security Hardening
# Based on Chainguard best practices and capability dropping
# GPLv3 License - https://github.com/vejeta/docker-stremio-wolfi

set -euo pipefail

# ============================================================================
# Security Configuration
# ============================================================================

# Get current user UID/GID for user namespace mapping
USER_UID="${UID:-$(id -u)}"
USER_GID="${GID:-$(id -g)}"

# Create temporary X11 authentication file
XAUTH_TMP="${TMPDIR:-/tmp}/.docker-stremio.xauth.$$"
touch "$XAUTH_TMP"
chmod 600 "$XAUTH_TMP"

# Generate container-specific X11 credentials
# This prevents exposing host's full X11 authentication
xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH_TMP" nmerge - 2>/dev/null || true

# Cleanup on exit
trap 'rm -f "$XAUTH_TMP"' EXIT INT TERM

# ============================================================================
# Device Group Detection
# ============================================================================

# Detect video/GPU group membership for hardware acceleration
VIDEO_GROUPS=""
if [ -e /dev/dri/card0 ]; then
    VIDEO_GID=$(stat -c '%g' /dev/dri/card0)
    VIDEO_GROUPS="${VIDEO_GROUPS}--group-add=${VIDEO_GID} "
fi

if [ -e /dev/dri/renderD128 ]; then
    RENDER_GID=$(stat -c '%g' /dev/dri/renderD128)
    VIDEO_GROUPS="${VIDEO_GROUPS}--group-add=${RENDER_GID} "
fi

# Detect audio group for PulseAudio/PipeWire
AUDIO_GROUPS=""
if [ -e "/run/user/${USER_UID}/pulse/native" ]; then
    PULSE_GID=$(stat -c '%g' "/run/user/${USER_UID}/pulse/native")
    AUDIO_GROUPS="--group-add=${PULSE_GID}"
fi

# ============================================================================
# Container Image Selection
# ============================================================================

IMAGE_NAME="${STREMIO_IMAGE:-ghcr.io/vejeta/stremio-wolfi:latest}"

echo "🔒 Launching Stremio with security hardening..."
echo "   User: ${USER_UID}:${USER_GID}"
echo "   Display: ${DISPLAY}"
echo "   Image: ${IMAGE_NAME}"

# ============================================================================
# Docker Run with Security Hardening
# ============================================================================

docker run --rm -it \
    `# ---- Security Hardening ----` \
    --security-opt=no-new-privileges:true \
    --cap-drop=ALL \
    --read-only \
    --security-opt seccomp=unconfined \
    \
    `# ---- User Namespace Mapping ----` \
    --user "${USER_UID}:${USER_GID}" \
    ${VIDEO_GROUPS} \
    ${AUDIO_GROUPS} \
    \
    `# ---- Writable Mounts (with restrictions) ----` \
    --tmpfs /tmp:rw,noexec,nosuid,size=1g \
    --mount type=tmpfs,destination=/home/nonroot/.config,tmpfs-mode=0700 \
    -v "${HOME}/.stremio-server:/home/nonroot/.stremio-server:rw" \
    \
    `# ---- X11 Display with Limited Auth ----` \
    -e DISPLAY="${DISPLAY}" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    -v "${XAUTH_TMP}:/tmp/.docker.xauth:ro" \
    -e XAUTHORITY=/tmp/.docker.xauth \
    \
    `# ---- PulseAudio/PipeWire Socket ----` \
    -v "/run/user/${USER_UID}/pulse:/run/user/${USER_UID}/pulse:ro" \
    -e PULSE_SERVER="unix:/run/user/${USER_UID}/pulse/native" \
    \
    `# ---- Device Access (GPU/Audio) ----` \
    --device /dev/dri:/dev/dri:rw \
    --device /dev/snd:/dev/snd:rw \
    \
    `# ---- Network Configuration ----` \
    --network=host \
    \
    `# ---- Qt/Environment Variables ----` \
    -e QT_X11_NO_MITSHM=1 \
    -e QT_QUICK_BACKEND=software \
    \
    `# ---- Resource Limits ----` \
    --memory="2g" \
    --memory-swap="2g" \
    --cpus="2.0" \
    --pids-limit=200 \
    \
    `# ---- Container Name ----` \
    --name stremio-secure-$$ \
    \
    "${IMAGE_NAME}" "$@"

echo "✅ Stremio exited successfully"
