# Stremio Secure Container - Wolfi-based Multi-stage Build
# Following Chainguard best practices for minimal attack surface
# GPLv3 License - https://github.com/vejeta/stremio-distroless

# ============================================================================
# Single-stage build: Minimal Wolfi image for production
# ============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest

# Multi-architecture support
ARG TARGETARCH

# Metadata following OCI image spec
LABEL org.opencontainers.image.title="Stremio Secure Container"
LABEL org.opencontainers.image.description="Secure Stremio container based on Wolfi Linux with minimal attack surface"
LABEL org.opencontainers.image.vendor="vejeta"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.source="https://github.com/vejeta/stremio-distroless"
LABEL org.opencontainers.image.documentation="https://github.com/vejeta/stremio-distroless/blob/main/README.md"

# Add custom Wolfi APK repository from SourceForge
# This repository contains Stremio and multimedia dependencies

# Supply chain security: Use pre-verified key from repository
# Eliminates runtime dependency on external key servers
# Key fingerprint (SHA256): 3a69e5ba1f59249cf4babaa29941d21ed3be5fae2c810ba34d00b10c4c5bd3b2
COPY keys/vejeta-wolfi.rsa.pub /etc/apk/keys/vejeta-wolfi.rsa.pub

# Add repository URL - APK automatically appends /${ARCH} to the URL
# This will resolve to:
#   - https://downloads.sourceforge.net/project/wolfi/x86_64/APKINDEX.tar.gz (amd64)
#   - https://downloads.sourceforge.net/project/wolfi/aarch64/APKINDEX.tar.gz (arm64)
RUN echo "https://downloads.sourceforge.net/project/wolfi" >> /etc/apk/repositories

# Install base dependencies first (from Wolfi and Chainguard repos)
# These are known to work well together
RUN apk update && apk add --no-cache \
    libvpx \
    libass \
    libbluray \
    qt5-qtbase \
    qt5-qtdeclarative \
    qt5-qtquickcontrols \
    qt5-qtwebchannel \
    libxcb \
    vulkan-loader \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Install explicit runtime dependencies from stremio.yaml
# This ensures all required packages are available
RUN apk add --no-cache \
    librsvg \
    mpv-dev \
    nodejs \
    qt5-qtwebengine \
    && rm -rf /var/cache/apk/*

# Install OpenGL/Mesa dependencies for GUI rendering
# Required for Qt GLX initialization and hardware acceleration
RUN apk add --no-cache \
    mesa \
    mesa-gl \
    mesa-gles \
    mesa-egl \
    mesa-gbm \
    mesa-dri-gallium \
    && rm -rf /var/cache/apk/*

# Install Stremio packages from SourceForge in separate layer
# This isolates any trigger issues from the custom packages
RUN apk add --no-cache stremio stremio-server \
    && rm -rf /var/cache/apk/*

# Create directory structure and setup nonroot user
RUN mkdir -p /home/nonroot/.stremio-server && \
    chown -R 65532:65532 /home/nonroot

# Switch to nonroot user (UID 65532)
# This user has minimal permissions
USER 65532:65532

# Environment variables for security and Qt
ENV HOME=/home/nonroot
ENV USER=nonroot
ENV DISPLAY=:0
ENV QT_X11_NO_MITSHM=1

# Expose Stremio server port
EXPOSE 11470

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/usr/bin/stremio", "--version"]

# Working directory
WORKDIR /home/nonroot

# Volume for persistent data
VOLUME ["/home/nonroot/.stremio-server"]

# Run Stremio as nonroot user
CMD ["/usr/bin/stremio"]
