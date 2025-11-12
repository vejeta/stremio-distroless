# Stremio Secure Container - Wolfi-based Multi-stage Build
# Following Chainguard best practices for minimal attack surface
# GPLv3 License - https://github.com/vejeta/stremio-distroless

# ============================================================================
# Stage 1: Builder - Contains tools needed for setup and configuration
# ============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# Add custom Wolfi APK repository from SourceForge
# This repository contains Stremio and multimedia dependencies
RUN apk add --no-cache wget

# Add repository URL
RUN echo "https://downloads.sourceforge.net/project/wolfi" >> /etc/apk/repositories

# Download repository signing key
RUN wget -O /etc/apk/keys/vejeta-wolfi.rsa.pub \
    'https://downloads.sourceforge.net/project/wolfi/keys/vejeta-wolfi.rsa.pub'

# Install build dependencies and Stremio with multimedia support
# Using --no-cache to avoid storing package cache in the image
RUN apk update && apk add --no-cache \
    stremio \
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

# Create directory structure in builder stage
# (cannot create directories in distroless runtime)
RUN mkdir -p /app /home/nonroot/.stremio-server && \
    chown -R 65532:65532 /app /home/nonroot

# ============================================================================
# Stage 2: Runtime - Distroless minimal image for production
# ============================================================================
FROM cgr.dev/chainguard/glibc-dynamic:latest

# Metadata following OCI image spec
LABEL org.opencontainers.image.title="Stremio Secure Container"
LABEL org.opencontainers.image.description="Secure Stremio container based on Wolfi Linux with minimal attack surface"
LABEL org.opencontainers.image.vendor="vejeta"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.source="https://github.com/vejeta/stremio-distroless"
LABEL org.opencontainers.image.documentation="https://github.com/vejeta/stremio-distroless/blob/main/README.md"

# Copy directory structure and files from builder
# Distroless images cannot run shell commands, so all setup must be done in builder
COPY --from=builder --chown=65532:65532 /app /app
COPY --from=builder --chown=65532:65532 /home/nonroot /home/nonroot
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /usr/share /usr/share
COPY --from=builder /etc/ssl /etc/ssl

# Switch to nonroot user (UID 65532)
# This user has no shell and minimal permissions
USER 65532:65532

# Environment variables for security
ENV HOME=/home/nonroot
ENV USER=nonroot
ENV DISPLAY=:0
ENV QT_X11_NO_MITSHM=1
ENV QT_QUICK_BACKEND=software

# Expose Stremio server port (if needed)
EXPOSE 11470

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/stremio", "--version"]

# Working directory
WORKDIR /home/nonroot

# Volume for persistent data
VOLUME ["/home/nonroot/.stremio-server"]

# Run Stremio as nonroot user
# Note: In production, use the secure launcher script instead
CMD ["/app/stremio"]
