# Secure Stremio Containers - Multi-Ecosystem Implementation

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Wolfi](https://img.shields.io/badge/Ecosystem-Wolfi_APK-green.svg)](https://github.com/wolfi-dev)
[![Debian](https://img.shields.io/badge/Ecosystem-Debian_DEB-red.svg)](https://www.debian.org/)
[![Security](https://img.shields.io/badge/Security-Distroless-orange.svg)](https://www.chainguard.dev/)
[![OCI](https://img.shields.io/badge/Standard-OCI-blue.svg)](https://opencontainers.org/)

**Security-hardened Stremio containers demonstrating consistent security principles across multiple Linux ecosystems and container runtimes.**

This project implements identical security postures using:
- **Package Ecosystems**: Wolfi (APK) and Debian (DEB)
- **Base Images**: Chainguard Distroless and Google Distroless
- **Container Runtimes**: Docker, Podman, OCI (runc/crun), and Incus

## About This Project

**Current Maintainer**: Juan Manuel Méndez Rey (vejeta)
**Debian Package**: Submitted to [Debian Mentors](https://mentors.debian.net) (pending official maintainer status)

This repository demonstrates applying consistent security hardening principles regardless of the underlying distribution. The implementation covers:

- Multi-ecosystem packaging (APK and DEB formats)
- Distroless container best practices (Chainguard and Google approaches)
- Comprehensive security scanning (Trivy, Grype, SBOM generation)
- Multi-runtime support (Docker, Podman, OCI, Incus/LXC)

**Package Sources**:
- **Wolfi APK**: https://sourceforge.net/projects/wolfi/ (amd64/aarch64) (built via [wolfi-packages](https://github.com/vejeta/wolfi-packages))
- **Debian DEB**: https://debian.vejeta.com (amd64/aarch64) (submitted to Debian Mentors)

Feedback and contributions are welcome.

## Key Features

### Security Hardening (All Variants)

- **Distroless Runtime**: No shell, no package manager, no debugging tools in final image
- **Multi-stage Builds**: Build dependencies completely separated from runtime
- **Nonroot Execution**: UID 65532 (standard nonroot user)
- **Zero Capabilities**: All Linux capabilities dropped, hardware access via Unix groups
- **Read-only Filesystem**: Immutable root with selective writable mounts
- **User Namespace Mapping**: Secure host-to-container UID/GID mapping
- **Resource Limits**: Strict memory, CPU, and process constraints
- **SBOM**: Software Bill of Materials generated for every build
- **CVE Scanning**: Automated Trivy and Grype vulnerability detection

### Ecosystem Coverage

| Feature | Wolfi Variant | Debian Variant |
|---------|---------------|----------------|
| **Package Format** | APK | DEB |
| **Build Tool** | melange | dpkg-buildpackage |
| **Base Image** | cgr.dev/chainguard/wolfi-base | debian:trixie-slim |
| **Runtime Image** | cgr.dev/chainguard/glibc-dynamic | gcr.io/distroless/base-debian12 |
| **CVE Updates** | Nightly automatic | Debian security team |
| **SBOM** | Built-in | Generated with Syft |
| **Image Size** | ~50MB | ~80MB |
| **Architectures** | amd64, aarch64 | amd64, aarch64 |
| **Package Source** | sourceforge.net/projects/wolfi | debian.vejeta.com |

### Runtime Support

| Runtime | Type | Use Case | Security Features |
|---------|------|----------|-------------------|
| **Docker** | App containers | Standard containerization | Namespace isolation, cgroups |
| **Podman** | App containers (rootless) | Rootless execution | Daemonless, user namespaces |
| **OCI (runc/crun)** | Direct runtime | Maximum control | No daemon, direct kernel interface |
| **Incus/LXC** | System containers/VMs | Long-running workloads | AppArmor, seccomp, optional VM isolation |

## Quick Start

### Option 1: Use Pre-built Images (Recommended)

Pull and run multi-architecture images directly from GitHub Container Registry. Docker automatically selects the correct architecture (amd64 or aarch64).

#### Wolfi GUI (Desktop Application)

```bash
# Pull the image (amd64 or aarch64 automatically selected)
docker pull ghcr.io/vejeta/stremio-distroless:wolfi-gui-latest

# Option 1: Use the secure launcher script (recommended)
./shared/scripts/launch-stremio-gui-secure.sh

# Option 2: Manual docker run with all required tmpfs mounts
docker run --rm -it \
  --cap-drop=ALL \
  --read-only \
  --security-opt=no-new-privileges \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g \
  --tmpfs /home/nonroot/.local:rw,nosuid,nodev,uid=65532,gid=65532,size=256m \
  --tmpfs /home/nonroot/.cache:rw,nosuid,nodev,uid=65532,gid=65532,size=256m \
  --tmpfs /home/nonroot/.pki:rw,nosuid,nodev,uid=65532,gid=65532,size=16m \
  --shm-size=512m \
  --device /dev/dri:/dev/dri:rw \
  --group-add=$(stat -c '%g' /dev/dri/card0) \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v stremio-data:/home/nonroot/.stremio-server:rw \
  ghcr.io/vejeta/stremio-distroless:wolfi-gui-latest
```

**Note**: QtWebEngine (Chromium-based) requires writable directories for cache, local storage, and NSS database. The tmpfs mounts above provide these while maintaining read-only root filesystem security. See [Read-Only Filesystem Requirements](#read-only-filesystem-requirements) for details.

#### Wolfi Server (Headless Streaming)

```bash
# Pull the server image
docker pull ghcr.io/vejeta/stremio-distroless:wolfi-server-latest

# Run headless server
docker run --rm -d \
  --name stremio-server \
  --cap-drop=ALL \
  --read-only \
  -p 11470:11470 -p 12470:12470 \
  -v stremio-server-cache:/home/nonroot/.stremio-server:rw \
  ghcr.io/vejeta/stremio-distroless:wolfi-server-latest
```

#### Debian GUI (Desktop Application)

```bash
# Pull Debian variant
docker pull ghcr.io/vejeta/stremio-distroless:debian-gui-latest

# Run with security hardening
docker run --rm -it \
  --cap-drop=ALL \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  --device /dev/dri:/dev/dri:rw \
  --group-add=$(stat -c '%g' /dev/dri/card0) \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v stremio-data:/home/nonroot/.stremio-server:rw \
  ghcr.io/vejeta/stremio-distroless:debian-gui-latest
```

#### Debian Server (Headless Streaming)

```bash
# Pull Debian server variant
docker pull ghcr.io/vejeta/stremio-distroless:debian-server-latest

# Run headless server
docker run --rm -d \
  --name stremio-server \
  --cap-drop=ALL \
  --read-only \
  -p 11470:11470 -p 12470:12470 \
  -v stremio-server-cache:/home/nonroot/.stremio-server:rw \
  ghcr.io/vejeta/stremio-distroless:debian-server-latest
```

### Option 2: Build Locally

```bash
# Build Wolfi GUI
docker build -t stremio-secure:wolfi-gui -f wolfi/Dockerfile .

# Build Wolfi Server
docker build -t stremio-secure:wolfi-server -f wolfi/Dockerfile.server .

# Build Debian GUI
docker build -t stremio-secure:debian-gui -f debian/Dockerfile .

# Build Debian Server
docker build -t stremio-secure:debian-server -f debian/Dockerfile.server .
```

### Option 3: Podman (Rootless, Recommended for Security)

```bash
# Pull and run with Podman (daemonless, rootless)
podman pull ghcr.io/vejeta/stremio-distroless:wolfi-gui-latest

podman run --rm -it \
  --cap-drop=ALL \
  --read-only \
  --device /dev/dri \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  ghcr.io/vejeta/stremio-distroless:wolfi-gui-latest
```

### Option 4: Use Secure Launcher Scripts

```bash
# Copy shared launcher
cp shared/scripts/launch-stremio-secure.sh .
chmod +x launch-stremio-secure.sh

# Edit to select variant (wolfi or debian)
./launch-stremio-secure.sh
```

## Read-Only Filesystem Requirements

### Why Read-Only?

Running containers with read-only root filesystems is a security best practice that:
- **Prevents runtime modifications**: Attackers cannot modify binaries or add malicious code
- **Ensures immutability**: Container behavior is predictable and repeatable
- **Reduces attack surface**: No persistent changes possible to the container filesystem
- **Complies with security standards**: Meets CIS Docker Benchmark recommendations

### QtWebEngine Cache Requirements

Stremio GUI uses QtWebEngine (Chromium-based), which requires writable directories for:

| Directory | Purpose | Recommended Size | Required |
|-----------|---------|------------------|----------|
| `/home/nonroot/.cache` | Browser cache, compiled shaders | 256MB | Yes |
| `/home/nonroot/.local` | Local storage, databases, IndexedDB | 256MB | Yes |
| `/home/nonroot/.pki` | NSS certificate database | 16MB | Yes |
| `/tmp` | Temporary files, XDG runtime | 1GB | Yes |
| `/dev/shm` | Shared memory for Chromium | 512MB+ | Yes |

**Without these mounts**, you'll see errors like:
```
Cannot create directory /home/nonroot/.local/share/Smart Code ltd/Stremio/QtWebEngine/Default
Error: FILE_ERROR_ACCESS_DENIED
Failed to create directory: /home/nonroot/.cache/Smart Code ltd/Stremio/QtWebEngine/Default/Cache
```

### tmpfs vs Persistent Volumes

**tmpfs mounts** (in-memory, temporary):
- Use for: Cache, temporary data, runtime directories
- Advantages: Fast, automatically cleaned on container restart, no disk I/O
- Disadvantages: Data lost on restart, uses RAM

**Persistent volumes**:
- Use for: User settings, watch history, server configuration
- Location: `/home/nonroot/.stremio-server`
- Survives container restarts

### Shared Memory Requirements

Chromium-based applications (like QtWebEngine) use shared memory (`/dev/shm`) for:
- Inter-process communication (IPC)
- Canvas rendering
- Video decoding buffers

**Docker's default `/dev/shm` is only 64MB**, which is insufficient for:
- HD/4K video streaming
- Content-heavy web pages
- Multiple tabs/windows

**Symptoms of insufficient shared memory**:
```
Bus error (SIGBUS)
Segmentation fault
Browser crashes
```

**Solution**: Increase with `--shm-size=512m` or higher.

### Security vs Functionality Trade-offs

| Feature | Security Impact | Functionality Impact | Recommendation |
|---------|----------------|----------------------|----------------|
| Read-only root | ✅ High security | ⚠️ Requires tmpfs mounts | Use with tmpfs |
| Writable tmpfs | ⚠️ Reduced security | ✅ Full functionality | Limit sizes |
| noexec on tmpfs | ✅ Prevents code execution | ❌ Breaks JIT compilation | Don't use on /tmp |
| nosuid on tmpfs | ✅ Prevents privilege escalation | ✅ No impact | Always use |
| Large /dev/shm | ⚠️ More memory available | ✅ Better performance | Use 512MB-1GB |

### Using XDG Environment Variables (Alternative)

You can redirect cache locations using XDG Base Directory Spec:

```bash
docker run --rm -it \
  -e XDG_CACHE_HOME=/tmp/cache \
  -e XDG_DATA_HOME=/tmp/data \
  -e XDG_RUNTIME_DIR=/tmp/runtime \
  --tmpfs /tmp:rw,nosuid,nodev,uid=65532,gid=65532,size=1g \
  ...
```

This consolidates all writable directories into a single `/tmp` tmpfs mount.

### Troubleshooting

**Problem**: `Cannot create directory` errors
**Solution**: Ensure all tmpfs mounts are present with correct uid/gid (65532:65532)

**Problem**: SIGBUS or bus errors
**Solution**: Increase `--shm-size` to 512m or 1g

**Problem**: "Read-only file system" errors
**Solution**: Check if the directory should be in tmpfs or persistent volume

**Problem**: Container runs out of memory
**Solution**: Reduce tmpfs sizes or increase container memory limits

For more details, see the [launch-stremio-gui-secure.sh](shared/scripts/launch-stremio-gui-secure.sh) script which implements all best practices.

## Repository Structure

```
docker-stremio-wolfi/
├── wolfi/                      # Wolfi (APK) variant
│   ├── Dockerfile              # GUI with Chainguard distroless
│   ├── Dockerfile.server       # Headless server
│   └── docker-compose.yml
├── debian/                     # Debian (DEB) variant
│   ├── Dockerfile              # GUI with Google distroless
│   ├── Dockerfile.server       # Headless server
│   └── docker-compose.yml
├── shared/
│   ├── scripts/                # Cross-ecosystem launcher scripts
│   │   ├── launch-stremio-secure.sh
│   │   └── launch-stremio-server.sh
│   └── security/               # Security profiles
│       ├── seccomp-profile.json
│       └── apparmor-profile
├── podman/                     # Podman-specific configs
│   ├── launch-stremio-podman.sh
│   ├── podman-compose.yml
│   └── README-podman.md
├── oci/                        # OCI runtime configs (runc/crun)
│   ├── config.json
│   └── README-oci.md
├── incus/                      # Incus/LXC support
│   ├── metadata.yaml
│   └── README-incus.md
└── .github/workflows/
    └── build-and-scan.yml      # Multi-ecosystem CI/CD with security scanning
```

## Security Architecture

### Zero Capabilities with Group-Based Hardware Access

Instead of granting dangerous Linux capabilities, we use **Unix group membership** for hardware access.

```bash
# INSECURE: Granting capabilities
docker run --cap-add=SYS_ADMIN ...  # Can modify kernel!

# SECURE: Drop ALL capabilities, use groups
docker run --cap-drop=ALL \
  --group-add=$(stat -c '%g' /dev/dri/card0) \      # video group
  --group-add=$(stat -c '%g' /dev/dri/renderD128) \ # render group
  --device /dev/dri:/dev/dri:rw
```

**How it works**:

1. **Drop ALL Linux capabilities**: Container has zero kernel-level powers
   - No CAP_SYS_ADMIN (system administration)
   - No CAP_NET_RAW (packet manipulation)
   - No CAP_SETUID (user ID changes)
   - No CAP_DAC_OVERRIDE (bypass file permissions)

2. **Dynamically detect hardware group ownership**:
   ```bash
   VIDEO_GID=$(stat -c '%g' /dev/dri/card0)       # Typically 44
   RENDER_GID=$(stat -c '%g' /dev/dri/renderD128) # Typically 109
   AUDIO_GID=$(stat -c '%g' /dev/snd/controlC0)   # Typically 29
   ```

3. **Add container user to groups**: Kernel grants access via Discretionary Access Control (DAC)

4. **Benefits**:
   - Standard Unix permission model
   - Cannot escape container boundaries
   - Minimal attack surface
   - No privileged operations required

**Implementation**: `shared/scripts/launch-stremio-secure.sh`
**Reference**: https://gist.github.com/vejeta/859f100ef74b87eadf7f7541ead2a2b1

### Distroless Runtime Strategy

Both ecosystems use distroless final images:

```dockerfile
# Wolfi approach (Chainguard)
FROM cgr.dev/chainguard/wolfi-base AS builder
RUN apk add stremio libvpx qt5-qtwebengine ...

FROM cgr.dev/chainguard/glibc-dynamic:latest  # Distroless!
COPY --from=builder /usr/bin/stremio /app/
# No shell, no apk, no package manager → Attacker cannot install backdoors

# Debian approach (Google)
FROM debian:trixie-slim AS builder
RUN apt-get install stremio libqt5webengine5 ...

FROM gcr.io/distroless/base-debian12:nonroot  # Distroless!
COPY --from=builder /usr/bin/stremio /app/
# No shell, no apt, no dpkg → Same attack surface reduction
```

**Attack Surface Comparison**:

| Attack Vector | Traditional Image | Distroless (This Project) |
|---------------|-------------------|---------------------------|
| Shell access for command execution | Possible | Impossible (no /bin/sh) |
| Installing malicious packages | Possible | Impossible (no package manager) |
| Modifying system files | Possible | Prevented (read-only FS) |
| Exploiting package manager bugs | Exposed | Not present |
| Debug tool exploitation | Available | Not present |

### Security Scanning Pipeline

GitHub Actions automatically scans every build:

```yaml
# .github/workflows/build-and-scan.yml

- Trivy vulnerability scanner (Aqua Security)
- Grype vulnerability scanner (Chainguard/Anchore)
- SBOM generation (SPDX format via Syft)
- SARIF upload to GitHub Security tab
- Automated weekly scans
```

**View Results**: Check the "Security" tab after CI runs

### Read-Only Filesystem

```bash
docker run --read-only \                           # Root FS immutable
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \          # Temp files (no exec)
  -v data:/home/nonroot/.stremio-server:rw \       # App data only
  stremio-secure:wolfi
```

Prevents:
- Runtime file modification attacks
- Persistence of malicious code
- Unauthorized binary execution in root FS

### Resource Limits

Prevents resource exhaustion attacks:

```bash
docker run \
  --memory="2g" \             # RAM limit
  --memory-swap="2g" \        # Prevent swap abuse
  --cpus="2.0" \              # CPU limit
  --pids-limit=200 \          # Fork bomb prevention
  stremio-secure
```

## Ecosystem Comparison

### When to Choose Wolfi

**Advantages**:
- Smallest image size (~50MB vs ~80MB)
- Nightly CVE patches (< 24-hour window)
- Built-in SBOM with every package
- Designed-for-containers from ground up
- Chainguard's security-first philosophy

**Best for**:
- Cloud-native deployments
- Kubernetes environments
- Maximum security posture
- Minimal attack surface requirements

### When to Choose Debian

**Advantages**:
- Broader package ecosystem
- Longer track record and stability
- Official Debian project integration
- Familiar to enterprise teams
- Extensive documentation

**Best for**:
- Enterprise environments
- Compliance requirements (Debian's reputation)
- Teams familiar with DEB ecosystem
- Gradual migration from traditional deployments

### Security Posture: Identical

Both variants implement the same security layers:
- Distroless runtime
- Nonroot user (UID 65532)
- Zero capabilities
- Read-only filesystem
- Resource limits
- Multi-stage builds
- SBOM generation
- CVE scanning

**Demonstrated Principle**: Security is about architecture, not just tooling.

## Multi-Runtime Support

### Docker - Standard Containerization

See: [Quick Start](#quick-start)

### Podman - Rootless Containers

See: [podman/README-podman.md](podman/README-podman.md)

**Key Advantage**: No privileged daemon, native rootless support

### OCI Runtime - Direct Execution

See: [oci/README-oci.md](oci/README-oci.md)

**Runtimes**: runc, crun, youki, gVisor
**Key Advantage**: Maximum control, no abstraction layer

### Incus - System Containers & VMs

See: [incus/README-incus.md](incus/README-incus.md)

**Key Advantages**:
- Full system containers (not just apps)
- KVM-based VMs for maximum isolation
- Live migration and clustering
- Built-in snapshots and backups

## Building Images

### Prerequisites

- Docker 20.10+ or Podman 3.0+
- Internet connection (for base images and packages)

### Wolfi Variant

```bash
# GUI
docker build -t stremio-wolfi:gui -f wolfi/Dockerfile .

# Server
docker build -t stremio-wolfi:server -f wolfi/Dockerfile.server .
```

Packages fetched from: https://sourceforge.net/projects/wolfi/ (amd64/aarch64)

### Multi-Architecture Support

All images support both **amd64** (x86_64) and **aarch64** (ARM64) architectures. Docker automatically selects the correct architecture for your platform:

```bash
# On amd64 system
docker build -t stremio-wolfi:gui -f wolfi/Dockerfile .  # Builds amd64 image

# On aarch64 system (e.g., Raspberry Pi 4, Apple Silicon)
docker build -t stremio-wolfi:gui -f wolfi/Dockerfile .  # Builds aarch64 image

# Force specific architecture using buildx
docker buildx build --platform linux/arm64 -t stremio-wolfi:gui-arm64 -f wolfi/Dockerfile .
docker buildx build --platform linux/amd64 -t stremio-wolfi:gui-amd64 -f wolfi/Dockerfile .

# Build multi-arch manifest (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -t stremio-wolfi:gui -f wolfi/Dockerfile . --push
```

### Debian Variant

```bash
# GUI
docker build -t stremio-debian:gui -f debian/Dockerfile .

# Server
docker build -t stremio-debian:server -f debian/Dockerfile.server .
```

Packages fetched from: https://debian.vejeta.com

### Security Scanning Locally

```bash
# Trivy
trivy image stremio-wolfi:gui

# Grype
grype stremio-wolfi:gui

# Generate SBOM
syft stremio-wolfi:gui -o spdx-json > sbom.json
```

## CI/CD Pipeline

GitHub Actions automatically:

1. **Builds** both ecosystems (Wolfi + Debian) × (GUI + Server) = 4 variants
2. **Scans** with Trivy and Grype
3. **Generates** SBOM in SPDX format
4. **Uploads** SARIF to GitHub Security tab
5. **Creates** comparison reports across ecosystems
6. **Runs weekly** even without code changes

**Workflow**: `.github/workflows/build-and-scan.yml`

## Security Hardening Checklist

- [x] Distroless runtime (no shell, no package manager)
- [x] Nonroot user (UID 65532)
- [x] Multi-stage build (build tools separated)
- [x] Zero Linux capabilities
- [x] Group-based hardware access (DAC, not capabilities)
- [x] Read-only root filesystem
- [x] Temporary directories with noexec
- [x] User namespace mapping
- [x] Resource limits (memory, CPU, PIDs)
- [x] SBOM generation (supply chain security)
- [x] Automated CVE scanning (Trivy + Grype)
- [x] Seccomp profiles (syscall filtering)
- [x] AppArmor profiles (available for Incus)
- [x] Network isolation options
- [x] Health checks
- [x] Minimal attack surface (< 100MB images)

## Comparison with Other Implementations

This project was inspired by [tsaridas/stremio-docker](https://github.com/tsaridas/stremio-docker).

### Key Differences

| Feature | tsaridas/stremio-docker | This Project |
|---------|------------------------|--------------|
| **Stremio Version** | stremio-web (web-based) | Stremio 4.4.169 (binary) |
| **Base** | Alpine (single ecosystem) | Wolfi + Debian (multi-ecosystem) |
| **Runtime** | Alpine with tools | Distroless (no shell/pkg mgr) |
| **Package Manager** | apk in final image | Removed (distroless) |
| **Shell** | /bin/sh present | No shell (distroless) |
| **Security Scanning** | Manual | Automated (Trivy + Grype) |
| **SBOM** | Manual generation | Automatic (every build) |
| **Ecosystems** | APK only | APK + DEB |
| **Architectures** | Multiple (incl. armv7, arm64) | amd64, aarch64 |
| **Runtimes** | Docker | Docker, Podman, OCI, Incus |

### When to Use tsaridas/stremio-docker

- Prefer Alpine ecosystem familiarity
- Want proven, stable solution
- Need to debug inside container (has shell)
- Need additional architecture support beyond amd64/aarch64

### When to Use This Project

- Require maximum security (distroless)
- Work in compliance/security-sensitive environment
- Want automated CVE scanning
- Need SBOM for supply chain security
- Prefer multiple ecosystem options (Wolfi or Debian)
- Want rootless container support (Podman)
- Need runtime flexibility (Docker/Podman/OCI/Incus)

## Published Container Images

**Registry**: GitHub Container Registry (ghcr.io)

Container images are automatically built and published for all variants:

```bash
# Pull pre-built images from ghcr.io
docker pull ghcr.io/vejeta/stremio-distroless:wolfi-gui
docker pull ghcr.io/vejeta/stremio-distroless:wolfi-server
docker pull ghcr.io/vejeta/stremio-distroless:debian-gui
docker pull ghcr.io/vejeta/stremio-distroless:debian-server

# Run directly without building
docker run -it --rm \
  --cap-drop=ALL \
  --read-only \
  --device /dev/dri \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  ghcr.io/vejeta/stremio-distroless:wolfi-gui
```

### Available Tags

Images are tagged automatically on every push:

- **Branch tags**: `main`, `develop`
- **Git SHA**: `sha-abc1234`
- **Semantic versions**: `v1.0.0`, `1.0.0`, `1.0` (when tagged)
- **Latest**: `latest` (only for main branch)

**Tag format**: `<ecosystem>-<variant>[-<branch/version>]`

Examples:
```bash
# Latest stable release
ghcr.io/vejeta/stremio-distroless:wolfi-server-latest

# Specific version
ghcr.io/vejeta/stremio-distroless:debian-gui-v1.0.0

# Development branch
ghcr.io/vejeta/stremio-distroless:wolfi-gui-develop

# Specific commit
ghcr.io/vejeta/stremio-distroless:wolfi-server-sha-abc1234
```

### Publishing Criteria

- [x] Multi-ecosystem Dockerfiles (Wolfi + Debian)
- [x] Security scanning pipeline (Trivy + Grype)
- [x] SBOM generation
- [x] Multi-runtime support (Docker, Podman, OCI, Incus)
- [x] Package repository stability confirmed
- [x] Automated publishing to ghcr.io

### Creating a Release

**For maintainers**: To publish a new version, create and push a semantic version tag:

```bash
# Ensure you're on the main branch and up to date
git checkout main
git pull origin main

# Create an annotated tag (e.g., v1.0.0)
git tag -a v1.0.0 -m "Release v1.0.0: First stable release"

# Push the tag to GitHub
git push origin v1.0.0
```

This will automatically:
1. Trigger GitHub Actions workflow
2. Build all 4 container variants (wolfi-gui, wolfi-server, debian-gui, debian-server)
3. Run security scans (Trivy + Grype)
4. Generate SBOMs for all images
5. Publish images to ghcr.io with version tags:
   - `ghcr.io/vejeta/stremio-distroless:wolfi-gui-v1.0.0`
   - `ghcr.io/vejeta/stremio-distroless:wolfi-gui-1.0.0`
   - `ghcr.io/vejeta/stremio-distroless:wolfi-gui-1.0`
   - `ghcr.io/vejeta/stremio-distroless:wolfi-gui-latest` (for main branch)
6. Upload security reports and artifacts to GitHub

**Versioning Scheme**:
```
v0.1.0-beta.1  →  First public testing release
v0.2.0-beta.x  →  Feedback incorporated
v1.0.0         →  First stable release
v1.1.0         →  Feature additions
v1.1.1         →  Bug fixes
```

**View published images**: https://github.com/vejeta/stremio-distroless/pkgs/container/stremio-distroless

## Technical Implementation

This project demonstrates:

1. **Cross-Ecosystem Packaging**: Package maintenance in both APK (Wolfi/melange) and DEB (Debian/debhelper) formats
2. **Security Architecture**: Consistent security principles applied across different base distributions
3. **Supply Chain Security**: SBOM generation, automated CVE scanning, reproducible builds
4. **DevSecOps Integration**: Security scanning integrated into CI/CD pipeline
5. **Container Runtime Support**: Docker, Podman, OCI (runc/crun), and Incus/LXC
6. **Linux Security Mechanisms**: Capabilities, namespaces, cgroups, DAC, syscalls
7. **Open Source Contribution**: Debian package submission through mentors.debian.net

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run security scans locally
5. Submit a pull request

**Testing Checklist**:
```bash
# Build
docker build -t test -f wolfi/Dockerfile .

# Security scan
trivy image test
grype test

# SBOM
syft test -o spdx-json

# Functional test
docker run --rm test --version
```

## References

### Security & Best Practices
- [Chainguard Academy](https://edu.chainguard.dev/)
- [Google Distroless](https://github.com/GoogleContainerTools/distroless)
- [NIST Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

### Container Technologies
- [Docker Security](https://docs.docker.com/engine/security/)
- [Podman Documentation](https://docs.podman.io/)
- [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec)
- [Incus/LXC Documentation](https://linuxcontainers.org/incus/)

### Linux Ecosystems
- [Wolfi Linux](https://github.com/wolfi-dev)
- [Debian](https://www.debian.org/)
- [Debian Mentors](https://mentors.debian.net/)

### Scanning Tools
- [Trivy](https://github.com/aquasecurity/trivy)
- [Grype](https://github.com/anchore/grype)
- [Syft (SBOM)](https://github.com/anchore/syft)

## License

**GNU General Public License v3.0 (GPLv3)**

```
Secure Stremio Containers - Multi-Ecosystem Implementation
Copyright (C) 2025 vejeta

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
```

See [LICENSE](LICENSE) for full text.

### Component Licenses

- **This Project**: GPLv3
- **Wolfi Linux**: Apache 2.0
- **Debian**: DFSG-compliant licenses
- **Chainguard Images**: Apache 2.0
- **Google Distroless**: Apache 2.0
- **Stremio**: Proprietary (binary distribution)

## Trademarks & Disclaimers

- **Stremio** is a trademark of Stremio Ltd.
- This project is **unofficial** and **not endorsed** by Stremio Ltd.
- For official Stremio support: https://www.stremio.com

**Warranty Disclaimer** (GPLv3 §15-16):
```
THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND.
NO LIABILITY FOR DAMAGES ARISING FROM USE OF THIS SOFTWARE.
```

## Contact

- **GitHub Issues**: https://github.com/vejeta/stremio-distroless/issues
- **Security Issues**: Report via GitHub Security Advisories
- **Package Repositories**:
  - Wolfi APK: https://sourceforge.net/projects/wolfi/
  - Debian DEB: https://debian.vejeta.com

---

**Maintained by vejeta** | Demonstrating security-first containerization across multiple Linux ecosystems
