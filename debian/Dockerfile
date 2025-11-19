# Secure Stremio Container - Debian Variant with Google Distroless
# Multi-stage build following security best practices
# Packages from: https://debian.vejeta.com

# Stage 1: Builder - Debian trixie (testing/stable) with build tools
FROM debian:trixie-slim AS builder

# Multi-architecture support
ARG TARGETARCH
# Map Docker arch to Debian multiarch triplet
# amd64 -> x86_64-linux-gnu, arm64 -> aarch64-linux-gnu
RUN echo "Building for architecture: ${TARGETARCH}"

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
    # Install Stremio and explicit runtime dependencies (from stremio.yaml)
    apt-get install -y --no-install-recommends \
        stremio \
        librsvg2-2 \
        librsvg2-common \
        libmpv2 \
        libmpv-dev \
        nodejs \
        qtbase5-dev \
        libqt5gui5 \
        libqt5core5t64 \
        libqt5widgets5t64 \
        qtdeclarative5-dev \
        libqt5qml5 \
        libqt5quick5 \
        qtwebengine5-dev \
        libqt5webengine5 \
        libqt5webenginecore5 \
        libqt5webenginewidgets5 \
        qml-module-qtquick-dialogs \
        qml-module-qtquick-controls \
        qml-module-qtquick-window2 \
        qml-module-qtwebengine \
        qml-module-qtwebchannel \
        libgl1 \
        libegl1 \
        libgbm1 \
        libglx0 \
        mesa-vulkan-drivers \
        libxcb-glx0 \
        libxcb-render0 \
        libxcb-shape0 \
        libxcb-xinerama0 \
        libxcb-randr0 \
        libxcb-xfixes0 \
        libxcb-shm0 \
        libxcb-icccm4 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-render-util0 \
        libx11-xcb1 \
        libxcb-sync1 \
        libxcb-xkb1 \
        libxcb-xinput0 \
        libxcb-util1 && \
    # Note: Explicitly installing all runtime dependencies ensures distroless copy works
    # Clean up to reduce layer size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create directory structure
RUN mkdir -p /app/bin /app/lib /app/share /app/share/drirc.d

# Copy Stremio binary and required libraries
# stremio-wrapper is a bash script that calls /usr/libexec/stremio/stremio
# We need the actual binary, not the wrapper script (distroless has no bash)
RUN set -eux; \
    # Determine Debian multiarch triplet based on target architecture
    case "${TARGETARCH}" in \
        amd64) DEB_ARCH="x86_64-linux-gnu" ;; \
        arm64) DEB_ARCH="aarch64-linux-gnu" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    echo "Using Debian architecture: ${DEB_ARCH}"; \
    cp -a /usr/libexec/stremio/stremio /app/bin/ && \
    # Copy application-specific shared libraries (exclude base system libs)
    # Distroless already provides libc, libm, libpthread, libdl, etc.
    # No need to copy base system libs - builder and runtime both use same glibc version
    ldd /app/bin/stremio | grep "=>" | awk '{print $3}' | \
    grep -v -E '(libc\.so|libm\.so|libpthread\.so|libdl\.so|librt\.so|libresolv\.so|ld-linux.*)' | \
    xargs -I {} cp -v {} /app/lib/ || true && \
    # Copy Qt plugin dependencies recursively
    # Qt plugins are loaded dynamically at runtime and have their own dependencies
    echo "Copying Qt plugin dependencies..." && \
    find /usr/lib/${DEB_ARCH}/qt5/plugins -name '*.so' -type f 2>/dev/null | while read plugin; do \
        ldd "$plugin" 2>/dev/null | grep "=>" | awk '{print $3}' | \
        grep -v -E '(libc\.so|libm\.so|libpthread\.so|libdl\.so|librt\.so|libresolv\.so|ld-linux.*|linux-vdso)' || true; \
    done | sort -u | xargs -I {} cp -v {} /app/lib/ 2>/dev/null || true && \
    # Copy OpenGL/GLX/EGL libraries explicitly (required by Qt xcb plugin)
    echo "Copying OpenGL/GLX/EGL libraries..." && \
    cp -v /lib/${DEB_ARCH}/libGL.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libGLdispatch.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libGLX.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libEGL.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libEGL_mesa.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libgbm.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libGLX_mesa.so.* /app/lib/ 2>/dev/null || true && \
    # Copy Mesa Gallium driver and dependencies (CRITICAL for GLX)
    echo "Copying Mesa Gallium and DRM libraries..." && \
    cp -v /lib/${DEB_ARCH}/libgallium-*.so /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libdrm.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libdrm_amdgpu.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libdrm_intel.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libdrm_nouveau.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libdrm_radeon.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libexpat.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libxshmfence.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libXxf86vm.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libelf.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libLLVM*.so /app/lib/ 2>/dev/null || true && \
    # Copy LLVM and Gallium dependencies
    echo "Copying LLVM and Gallium dependencies..." && \
    cp -v /lib/${DEB_ARCH}/libzstd.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libsensors.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libffi.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libedit.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libz3.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libxml2.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libpciaccess.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libtinfo.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/libbsd.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /lib/${DEB_ARCH}/liblzma.so.* /app/lib/ 2>/dev/null || true && \
    # Copy symlinks too
    cp -av /usr/lib/${DEB_ARCH}/libGL.so.1 /app/lib/ 2>/dev/null || true && \
    cp -av /usr/lib/${DEB_ARCH}/libGLdispatch.so.0 /app/lib/ 2>/dev/null || true && \
    cp -av /usr/lib/${DEB_ARCH}/libGLX.so.0 /app/lib/ 2>/dev/null || true && \
    cp -av /usr/lib/${DEB_ARCH}/libEGL.so.1 /app/lib/ 2>/dev/null || true && \
    cp -av /usr/lib/${DEB_ARCH}/libgbm.so.1 /app/lib/ 2>/dev/null || true && \
    cp -av /usr/lib/${DEB_ARCH}/libdrm.so.2 /app/lib/ 2>/dev/null || true && \
    # Copy libxcb extension libraries (CRITICAL for GLX)
    echo "Copying libxcb GLX extension libraries..." && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-glx.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-render.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-shape.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-xinerama.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-randr.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-xfixes.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-shm.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-icccm.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-image.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-keysyms.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-render-util.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libX11-xcb.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-sync.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-xkb.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-xinput.so.* /app/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/${DEB_ARCH}/libxcb-util.so.* /app/lib/ 2>/dev/null || true && \
    # Copy Qt plugins (using architecture-specific path)
    cp -a /usr/lib/${DEB_ARCH}/qt5 /app/lib/ || true && \
    # Copy Mesa drivers (using architecture-specific path)
    mkdir -p /app/lib/dri && \
    cp -a /usr/lib/${DEB_ARCH}/dri/*.so /app/lib/dri/ || true && \
    # Copy Mesa configuration files (CRITICAL for GLX)
    echo "Copying Mesa configuration..." && \
    cp -a /usr/share/drirc.d/* /app/share/drirc.d/ 2>/dev/null || true

# Stage 2: Runtime - Google Distroless with glibc (Debian 13/trixie)
FROM gcr.io/distroless/base-debian13:nonroot

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

# Set library path for runtime linking (multi-arch compatible)
ENV LD_LIBRARY_PATH=/app/lib
ENV QT_PLUGIN_PATH=/app/lib/qt5/plugins
ENV LIBVA_DRIVERS_PATH=/app/lib/dri
ENV VDPAU_DRIVER_PATH=/app/lib/vdpau
ENV DRIRC_CONFIGDIR=/app/share/drirc.d

# X11 and display settings
ENV DISPLAY=:0
ENV QT_X11_NO_MITSHM=1
ENV QTWEBENGINE_DISABLE_SANDBOX=1

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
