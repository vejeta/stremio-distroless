# Secure Stremio Container - Debian Variant with Google Distroless
# Multi-stage build following security best practices
# Packages from: https://debian.vejeta.com

# Stage 1: Builder - Debian trixie (stable) with build tools
FROM debian:trixie-slim AS builder

# Install dependencies and Stremio from custom repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget && \
    # Add custom Debian repository with GPG key verification
    wget -qO - https://debian.vejeta.com/key.gpg | gpg --dearmor -o /usr/share/keyrings/stremio-debian.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/stremio-debian.gpg] https://debian.vejeta.com trixie main non-free" > /etc/apt/sources.list.d/stremio.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        stremio && \
    # Note: stremio package declares all required Qt5, multimedia, and X11 dependencies
    # apt automatically resolves them (including t64-suffixed packages for trixie)
    # Clean up to reduce layer size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create directory structure
RUN mkdir -p /app/bin /app/lib /app/share

# Copy Stremio binary and required libraries
RUN cp -a /usr/bin/stremio /app/bin/ && \
    # Copy all required shared libraries (will be filtered in next stage)
    ldd /usr/bin/stremio | grep "=>" | awk '{print $3}' | xargs -I {} cp -v {} /app/lib/ || true && \
    # Copy Qt plugins
    cp -a /usr/lib/x86_64-linux-gnu/qt5 /app/lib/ || true && \
    # Copy Mesa drivers
    mkdir -p /app/lib/dri && \
    cp -a /usr/lib/x86_64-linux-gnu/dri/*.so /app/lib/dri/ || true

# Stage 2: Runtime - Google Distroless with glibc
FROM gcr.io/distroless/base-debian12:nonroot

# Metadata
LABEL maintainer="vejeta"
LABEL org.opencontainers.image.title="Stremio Secure Container (Debian)"
LABEL org.opencontainers.image.description="Security-hardened Stremio container using Google Distroless"
LABEL org.opencontainers.image.source="https://github.com/vejeta/stremio-distroless"
LABEL org.opencontainers.image.vendor="vejeta"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# Security: Run as nonroot user (65532:65532)
USER 65532:65532

# Copy application from builder
COPY --from=builder --chown=65532:65532 /app /app

# Set library path for runtime linking
ENV LD_LIBRARY_PATH=/app/lib:/app/lib/x86_64-linux-gnu
ENV QT_PLUGIN_PATH=/app/lib/qt5/plugins
ENV LIBVA_DRIVERS_PATH=/app/lib/dri
ENV VDPAU_DRIVER_PATH=/app/lib/vdpau

# X11 and display settings
ENV DISPLAY=:0
ENV QT_X11_NO_MITSHM=1

# Stremio data directory (writable volume mount)
ENV HOME=/home/nonroot
WORKDIR /home/nonroot

# Expose default ports (server mode)
EXPOSE 11470 12470

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/bin/stremio", "--version"]

# Default command
ENTRYPOINT ["/app/bin/stremio"]
CMD ["--help"]
