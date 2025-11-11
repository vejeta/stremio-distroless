# Stremio with Podman

This directory contains specific configurations for running Stremio using **Podman**, an alternative to Docker that provides rootless containers with enhanced security.

## Advantages of Podman over Docker

1. **Rootless by default**: No privileged daemon required
2. **Daemonless**: Simpler and more secure fork/exec architecture
3. **Docker-compatible**: Uses the same command syntax
4. **systemd integration**: Easy service management
5. **Native pods**: Support for Kubernetes-style pods

## Requirements

```bash
# Install Podman (Fedora/RHEL/CentOS)
sudo dnf install podman

# Install Podman (Ubuntu/Debian)
sudo apt install podman

# Install Podman (Arch Linux)
sudo pacman -S podman
```

## Basic Usage

### Launch Stremio GUI

```bash
chmod +x launch-stremio-podman.sh
./launch-stremio-podman.sh
```

### Management with Podman Compose

```bash
# Install podman-compose
pip3 install podman-compose

# Launch services
podman-compose -f podman-compose.yml up -d

# View logs
podman-compose -f podman-compose.yml logs -f

# Stop services
podman-compose -f podman-compose.yml down
```

## Security Features

- ✅ Rootless execution (no root privileges)
- ✅ Automatic user namespaces
- ✅ No privileged daemon
- ✅ All capabilities dropped
- ✅ Read-only filesystem
- ✅ Resource limits enforced
- ✅ SELinux enabled by default (if available)

## systemd Integration

Podman allows generating systemd units to manage containers as services:

```bash
# Generate systemd unit
podman generate systemd --name stremio-podman --files

# Move to user directory
mkdir -p ~/.config/systemd/user/
mv container-stremio-podman.service ~/.config/systemd/user/

# Enable and start
systemctl --user enable container-stremio-podman.service
systemctl --user start container-stremio-podman.service

# Check status
systemctl --user status container-stremio-podman.service
```

## Pods (Container Grouping)

Podman supports pods natively, allowing container grouping:

```bash
# Create pod
podman pod create --name stremio-pod -p 11470:11470 -p 12470:12470

# Run containers in the pod
podman run -d --pod stremio-pod ghcr.io/vejeta/stremio-distroless:server
```

## Troubleshooting

### Permission errors on /dev/dri

```bash
# Add user to video groups
sudo usermod -aG video $USER
sudo usermod -aG render $USER

# Re-login to apply changes
```

### X11 not working

```bash
# Allow local X11 connections
xhost +local:

# Verify DISPLAY
echo $DISPLAY
```

## Comparison: Docker vs Podman

| Feature | Docker | Podman |
|---------|--------|--------|
| Daemon | Yes (privileged) | No |
| Rootless | Complex setup | Default |
| Pods | No | Yes |
| systemd | Third-party | Native |
| OCI Compatible | Yes | Yes |
| CLI Compatible | - | Yes (alias docker=podman) |

## References

- [Podman Official Documentation](https://docs.podman.io/)
- [Rootless Containers](https://rootlesscontaine.rs/)
- [Podman vs Docker](https://docs.podman.io/en/latest/Introduction.html)
