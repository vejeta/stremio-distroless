# OCI Runtime Configuration

This directory contains configurations for running Stremio using the **OCI (Open Container Initiative)** runtime standard directly, without Docker or Podman.

## What is OCI Runtime?

OCI defines standards for:
- **Image Spec**: Container image format
- **Runtime Spec**: Container configuration and execution
- **Distribution Spec**: Image distribution

Compatible runtimes include:
- **runc**: Reference implementation (used by Docker)
- **crun**: Runtime written in C (faster, used by Podman)
- **youki**: Runtime written in Rust
- **gVisor (runsc)**: Runtime with additional sandbox

## Advantages of Direct OCI Runtime

1. **Maximum control**: Granular security configuration
2. **No abstraction**: Direct access to runtime capabilities
3. **Portability**: Compatible with any OCI runtime
4. **Optimization**: Specific configuration for use cases

## Requirements

```bash
# Install runc (most common)
sudo apt install runc  # Debian/Ubuntu
sudo dnf install runc  # Fedora/RHEL
sudo pacman -S runc    # Arch Linux

# Or install crun (faster)
sudo apt install crun  # Debian/Ubuntu
sudo dnf install crun  # Fedora/RHEL
```

## File Structure

```
oci/
├── config.json          # OCI Runtime Spec configuration
├── rootfs/              # Container root filesystem
│   ├── app/
│   ├── usr/
│   ├── etc/
│   └── home/
├── create-bundle.sh     # Script to create OCI bundle
└── README-oci.md       # This documentation
```

## Basic Usage

### 1. Create OCI Bundle

```bash
# Extract Docker image to OCI format
mkdir -p rootfs
docker export $(docker create ghcr.io/vejeta/stremio-distroless:server) | tar -C rootfs -xf -

# Or use skopeo (recommended)
skopeo copy docker://ghcr.io/vejeta/stremio-distroless:server oci:stremio-bundle:latest
umoci unpack --image stremio-bundle:latest bundle
```

### 2. Run with runc

```bash
# Create container
sudo runc create --bundle . stremio-container

# Start container
sudo runc start stremio-container

# View state
sudo runc state stremio-container

# Stop and delete
sudo runc kill stremio-container
sudo runc delete stremio-container
```

### 3. Run with crun (rootless)

```bash
# crun supports rootless execution natively
crun run --bundle . stremio-container

# View logs
crun ps

# Stop
crun kill stremio-container SIGTERM
crun delete stremio-container
```

## Security Features in config.json

The `config.json` file implements multiple security layers:

### 1. User Namespaces
```json
"namespaces": [
  {"type": "pid"},
  {"type": "network"},
  {"type": "ipc"},
  {"type": "uts"},
  {"type": "mount"},
  {"type": "user"}
]
```

### 2. Dropped Capabilities
```json
"capabilities": {
  "bounding": [],
  "effective": [],
  "inheritable": [],
  "permitted": [],
  "ambient": []
}
```

### 3. Read-Only Filesystem
```json
"root": {
  "path": "rootfs",
  "readonly": true
}
```

### 4. Seccomp Profile
Allows only necessary syscalls, blocking all others by default.

### 5. Resource Limits
```json
"resources": {
  "memory": {"limit": 1073741824},  // 1GB
  "cpu": {"quota": 150000, "period": 100000},  // 1.5 CPU
  "pids": {"limit": 100}
}
```

### 6. Masked Paths
Hides sensitive system information:
- `/proc/kcore`
- `/proc/keys`
- `/sys/firmware`

## systemd Integration

Create systemd unit for automatic management:

```ini
[Unit]
Description=Stremio Server OCI Container
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/runc run --bundle /opt/stremio-oci --detach stremio-server
ExecStop=/usr/bin/runc kill stremio-server SIGTERM
ExecStopPost=/usr/bin/runc delete stremio-server
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
```

## Runtime Comparison

| Runtime | Language | Speed | Rootless | Features |
|---------|----------|-------|----------|----------|
| runc | Go | Medium | Yes* | OCI reference |
| crun | C | Fast | Yes | Low memory usage |
| youki | Rust | Fast | Yes | Rust security |
| runsc (gVisor) | Go | Slow | Yes | Extra sandbox |
| Kata | Rust/Go | Medium | No | Lightweight VM |

*Requires additional configuration

## Troubleshooting

### Error: "operation not permitted"
```bash
# Check user namespace
cat /proc/sys/kernel/unprivileged_userns_clone
# Should be: 1

# Enable if necessary (Debian/Ubuntu)
echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone
```

### Error: "failed to create shim task"
```bash
# Verify runc is installed correctly
runc --version

# Reinstall if necessary
sudo apt reinstall runc
```

### Debugging
```bash
# Run with detailed logs
runc --debug run --bundle . stremio-container 2>&1 | tee runtime.log

# Verify configuration
runc spec --validate
```

## References

- [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec)
- [runc Documentation](https://github.com/opencontainers/runc)
- [crun Documentation](https://github.com/containers/crun)
- [OCI Image Tools](https://github.com/opencontainers/image-tools)

## Useful Tools

```bash
# skopeo: Manipulate OCI/Docker images
skopeo inspect docker://ghcr.io/vejeta/stremio-distroless:server

# umoci: Unpack OCI images
umoci unpack --image stremio:latest bundle

# buildah: Build OCI images without daemon
buildah bud -t stremio-distroless .

# ctr: containerd client
ctr images pull ghcr.io/vejeta/stremio-distroless:server
```
