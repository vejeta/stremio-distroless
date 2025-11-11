# Stremio Secure Container - Wolfi-based Multi-stage Build
# Following Chainguard best practices for minimal attack surface
# GPLv3 License - https://github.com/vejeta/stremio-distroless

# ============================================================================
# Stage 1: Debian builder to get Stremio package
# ============================================================================
FROM debian:trixie-slim AS deb-extractor

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    wget https://dl.strem.io/linux/v4.4.168/stremio_4.4.168-1_amd64.deb -O /tmp/stremio.deb && \
    dpkg-deb -x /tmp/stremio.deb /extracted && \
    rm /tmp/stremio.deb

# Stage 2: Wolfi builder for additional dependencies
# ============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# Install multimedia dependencies available in Wolfi
RUN apk update && apk add --no-cache \
    ca-certificates \
    glibc \
    libgcc \
    libstdc++ \
    && rm -rf /var/cache/apk/*

# Copy Stremio from Debian extractor
COPY --from=deb-extractor /extracted/opt/stremio /opt/stremio
COPY --from=deb-extractor /extracted/usr /usr

# ============================================================================
# Stage 3: Runtime - Distroless minimal image for production
# ============================================================================
FROM cgr.dev/chainguard/glibc-dynamic:latest

# Metadata following OCI image spec
LABEL org.opencontainers.image.title="Stremio Secure Container"
LABEL org.opencontainers.image.description="Secure Stremio container based on Wolfi Linux with minimal attack surface"
LABEL org.opencontainers.image.vendor="vejeta"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.source="https://github.com/vejeta/stremio-distroless"
LABEL org.opencontainers.image.documentation="https://github.com/vejeta/stremio-distroless/blob/main/README.md"

# Copy Stremio and dependencies from builder
# Note: Chainguard distroless images already run as nonroot (65532:65532)
# and don't support USER root operations
COPY --from=builder --chown=65532:65532 /opt/stremio/stremio /app/stremio
COPY --from=builder /opt/stremio /app/stremio-data
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /usr/share /usr/share

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
