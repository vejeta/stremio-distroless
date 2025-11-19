#!/bin/bash
# Secure Stremio GUI Launcher with Read-Only Filesystem
# Based on proven working configuration from stremio-nonroot-secure.sh
# GPLv3 License - https://github.com/vejeta/stremio-distroless

set -e

# Configuration
IMAGE="${STREMIO_IMAGE:-ghcr.io/vejeta/stremio-distroless:wolfi-0.0.1-gui}"
VOLUME_NAME="${STREMIO_VOLUME:-stremio-data}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if X11 is available
    if [ -z "$DISPLAY" ]; then
        print_error "DISPLAY environment variable is not set. X11 is required for GUI."
        exit 1
    fi

    # Check if /tmp/.X11-unix exists
    if [ ! -d /tmp/.X11-unix ]; then
        print_error "/tmp/.X11-unix not found. X11 server may not be running."
        exit 1
    fi

    print_info "Prerequisites check passed!"
}

detect_hardware() {
    print_info "Detecting hardware groups..."

    # Detect user/group IDs
    USER_UID=$(id -u)
    USER_GID=$(id -g)

    # Detect GPU groups
    if [ -e /dev/dri/card0 ]; then
        VIDEO_GID=$(stat -c "%g" /dev/dri/card0)
        GPU_AVAILABLE=true
        print_info "GPU available (video group: $VIDEO_GID)"
    else
        VIDEO_GID=""
        GPU_AVAILABLE=false
        print_warn "GPU device /dev/dri/card0 not found"
    fi

    if [ -e /dev/dri/renderD128 ]; then
        RENDER_GID=$(stat -c "%g" /dev/dri/renderD128)
        print_info "Render device available (render group: $RENDER_GID)"
    else
        RENDER_GID=""
        print_warn "Render device /dev/dri/renderD128 not found"
    fi

    # Detect audio group
    if getent group audio &> /dev/null; then
        AUDIO_GID=$(getent group audio | cut -d: -f3)
        AUDIO_AVAILABLE=true
        print_info "Audio group detected (GID: $AUDIO_GID)"
    else
        AUDIO_GID=""
        AUDIO_AVAILABLE=false
        print_warn "Audio group not found"
    fi

    print_info "User UID:GID = $USER_UID:$USER_GID"
}

setup_x11_auth() {
    print_info "Setting up X11 authentication..."

    # Generate X11 authentication file for container
    XAUTH_TMP="/tmp/.docker-stremio-$USER_UID.xauth"
    touch "$XAUTH_TMP"
    xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH_TMP" nmerge - 2>/dev/null || {
        print_warn "Could not generate X11 auth file, trying fallback method"
        rm -f "$XAUTH_TMP"
        if command -v xhost &> /dev/null; then
            xhost +local:docker > /dev/null 2>&1
            print_info "Using xhost +local:docker as fallback"
        fi
    }
}

create_volume() {
    if ! docker volume inspect "$VOLUME_NAME" &> /dev/null; then
        print_info "Creating Docker volume: $VOLUME_NAME"
        docker volume create "$VOLUME_NAME"
    else
        print_info "Using existing Docker volume: $VOLUME_NAME"
    fi
}

launch_container() {
    print_info "Launching Stremio GUI container..."
    print_info "Image: $IMAGE"
    print_info "Volume: $VOLUME_NAME"

    # Base Docker run command
    CMD="docker run --rm -it"
    CMD="$CMD --name stremio-wolfi-gui"

    # User and groups (using host user for proper permissions)
    CMD="$CMD --user $USER_UID:$USER_GID"

    if [ -n "$VIDEO_GID" ]; then
        CMD="$CMD --group-add $VIDEO_GID"
    fi

    if [ -n "$RENDER_GID" ]; then
        CMD="$CMD --group-add $RENDER_GID"
    fi

    if [ -n "$AUDIO_GID" ]; then
        CMD="$CMD --group-add $AUDIO_GID"
    fi

    # Security hardening
    CMD="$CMD --security-opt=no-new-privileges:true"
    CMD="$CMD --cap-drop=ALL"
    CMD="$CMD --read-only"

    # CRITICAL: Shared IPC namespace for Qt SingleApplication instance locking
    CMD="$CMD --ipc=host"

    # Network mode (host for better service integration)
    CMD="$CMD --network host"

    # Environment variables
    CMD="$CMD -e DISPLAY=$DISPLAY"
    CMD="$CMD -e HOME=/home/nonroot"

    if [ -f "$XAUTH_TMP" ]; then
        CMD="$CMD -e XAUTHORITY=/tmp/.Xauthority"
    fi

    # PulseAudio support (if available)
    if [ "$AUDIO_AVAILABLE" = true ] && [ -S "/run/user/$USER_UID/pulse/native" ]; then
        CMD="$CMD -e PULSE_SERVER=unix:/tmp/pulse-socket"
        CMD="$CMD -v /run/user/$USER_UID/pulse/native:/tmp/pulse-socket:ro"
        print_info "PulseAudio socket mounted"
    fi

    # Tmpfs mounts (based on working configuration)
    # /tmp with noexec for security, but large size for QtWebEngine
    CMD="$CMD --tmpfs /tmp:rw,noexec,nosuid,size=2g"

    # /home/nonroot with exec flag (Qt may need to execute temp files)
    # Using host UID/GID for proper permissions
    CMD="$CMD --tmpfs /home/nonroot:rw,exec,nosuid,uid=$USER_UID,gid=$USER_GID,size=256m"

    # X11 display access
    CMD="$CMD -v /tmp/.X11-unix:/tmp/.X11-unix:rw"

    if [ -f "$XAUTH_TMP" ]; then
        CMD="$CMD -v $XAUTH_TMP:/tmp/.Xauthority:ro"
    fi

    # GPU devices
    if [ "$GPU_AVAILABLE" = true ]; then
        CMD="$CMD --device /dev/dri:/dev/dri"
    fi

    # Audio devices
    if [ "$AUDIO_AVAILABLE" = true ] && [ -e /dev/snd ]; then
        CMD="$CMD --device /dev/snd:/dev/snd"
    fi

    # Persistent storage volume
    CMD="$CMD -v $VOLUME_NAME:/home/nonroot/.stremio-server:rw"

    # Container image
    CMD="$CMD $IMAGE"

    print_info "Running command:"
    echo "$CMD"
    echo ""

    # Execute
    eval "$CMD"
}

cleanup() {
    if [ -f "$XAUTH_TMP" ]; then
        print_info "Cleaning up X11 authentication file..."
        rm -f "$XAUTH_TMP"
    fi
}

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Secure launcher for Stremio GUI (Wolfi variant) with read-only filesystem.
Based on proven working configuration.

OPTIONS:
    --image IMAGE       Docker image to use (default: ghcr.io/vejeta/stremio-distroless:wolfi-0.0.1-gui)
    --volume NAME       Volume name for persistent data (default: stremio-data)
    --help              Show this help message

ENVIRONMENT VARIABLES:
    STREMIO_IMAGE       Override default image
    STREMIO_VOLUME      Override default volume name

EXAMPLES:
    # Basic usage
    $0

    # Use custom image
    $0 --image my-registry/stremio:latest

KEY FEATURES (From Working Configuration):
    - Shared IPC namespace (--ipc=host) - CRITICAL for single instance
    - Host networking (--network host) - Better service integration
    - Dynamic user/group detection - Proper file permissions
    - Audio support - PulseAudio + /dev/snd
    - GPU acceleration - /dev/dri devices
    - X11 authentication - Secure display access
    - Read-only root filesystem - Security hardening

TROUBLESHOOTING:
    - Multiple windows? Check --ipc=host is present
    - No audio? Check PulseAudio socket: /run/user/\$UID/pulse/native
    - No GPU? Check /dev/dri/card0 permissions
    - Display fails? Check X11 authentication or use: xhost +local:docker

For more information: https://github.com/vejeta/stremio-distroless
EOF
}

# Main
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image)
                IMAGE="$2"
                shift 2
                ;;
            --volume)
                VOLUME_NAME="$2"
                shift 2
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Trap cleanup on exit
    trap cleanup EXIT

    echo "============================================"
    echo "  Stremio Secure GUI Launcher (Wolfi)"
    echo "  Working Configuration"
    echo "============================================"
    echo ""

    check_prerequisites
    detect_hardware
    setup_x11_auth
    create_volume
    launch_container
}

main "$@"
