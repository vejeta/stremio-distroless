# Incus Support for Stremio Secure Containers

This directory contains configurations for running Stremio using **Incus** (https://linuxcontainers.org/incus/), the community-driven fork of LXD.

## What is Incus?

Incus is a modern, secure, and powerful container and virtual machine manager:

- **System Containers**: Full OS containers (not just application containers)
- **Virtual Machines**: KVM-based VMs with same management interface
- **Security**: Strong isolation with AppArmor, seccomp, and user namespaces
- **Clustering**: Built-in cluster support for production
- **Storage**: ZFS, Btrfs, LVM, dir backends
- **Networking**: Advanced networking with OVN integration

## Incus vs Docker/Podman

| Feature | Docker/Podman | Incus |
|---------|---------------|-------|
| **Use Case** | Application containers | System containers + VMs |
| **Init System** | Single process (PID 1) | Full systemd/OpenRC |
| **Lifespan** | Ephemeral (typically) | Long-running (typically) |
| **Image Format** | OCI images | Incus images (+ OCI import) |
| **Networking** | Bridge/host | Full networking stack |
| **Security** | Namespace isolation | Namespace + optional VM isolation |
| **Management** | Per-container | Centralized cluster management |

## Why Use Incus for Stremio?

**Advantages**:
1. **Full System Container**: Run Stremio with complete systemd environment
2. **Better Hardware Access**: Native device passthrough (GPU, audio)
3. **Persistent State**: Designed for long-running containers
4. **Snapshot/Restore**: Built-in snapshots and live migration
5. **VM Option**: Can run as full VM for maximum isolation

**Disadvantages**:
1. **Heavier**: More resource usage than Docker
2. **Complexity**: More features = steeper learning curve
3. **Image Size**: Full OS vs minimal distroless

## Installation

### Install Incus

```bash
# Debian/Ubuntu
sudo apt install incus incus-client

# Arch Linux
sudo pacman -S incus

# From source
https://github.com/lxc/incus
```

### Initialize Incus

```bash
# Interactive setup
sudo incus admin init

# Quick setup with defaults
sudo incus admin init --auto

# Add your user to incus group
sudo usermod -aG incus-admin $USER
newgrp incus-admin
```

## Usage Options

### Option 1: Import OCI Image (Recommended)

Convert our Docker/OCI image to Incus:

```bash
# Build the Docker image first (Wolfi or Debian variant)
cd wolfi/
docker build -t stremio-secure:wolfi -f Dockerfile .

# Export as tarball
docker save stremio-secure:wolfi -o stremio-secure.tar

# Import into Incus
incus image import stremio-secure.tar --alias stremio-secure

# Launch container
incus launch stremio-secure stremio-gui \
  --device X0:unix-char,source=/tmp/.X11-unix/X0 \
  --device dri:unix-char,path=/dev/dri/card0 \
  --device render:unix-char,path=/dev/dri/renderD128 \
  --device snd:unix-char,path=/dev/snd \
  -c security.nesting=false \
  -c security.privileged=false

# Set environment
incus config set stremio-gui environment.DISPLAY=:0

# Execute Stremio
incus exec stremio-gui -- /app/bin/stremio
```

### Option 2: System Container with Full OS

Create a full Debian/Wolfi system container:

```bash
# Launch Debian trixie base
incus launch images:debian/trixie stremio-system

# Add custom repository and install
incus exec stremio-system -- bash <<'EOF'
echo "deb https://debian.vejeta.com trixie main" > /etc/apt/sources.list.d/vejeta.list
apt update
apt install -y stremio
EOF

# Configure hardware access
incus config device add stremio-system X0 proxy \
  listen=unix:/tmp/.X11-unix/X0 \
  connect=unix:/tmp/.X11-unix/X0 \
  bind=container \
  security.uid=1000 \
  security.gid=1000

incus config device add stremio-system gpu gpu

incus config device add stremio-system audio unix-char \
  source=/dev/snd \
  path=/dev/snd

# Start Stremio
incus exec stremio-system -- sudo -u ubuntu DISPLAY=:0 stremio
```

### Option 3: Virtual Machine (Maximum Isolation)

Run Stremio in a full KVM virtual machine:

```bash
# Create VM
incus launch images:debian/trixie stremio-vm --vm \
  -c limits.cpu=4 \
  -c limits.memory=4GiB

# GPU passthrough (requires compatible hardware)
incus config device add stremio-vm gpu gpu

# Install Stremio in VM
incus exec stremio-vm -- bash <<'EOF'
echo "deb https://debian.vejeta.com trixie main" > /etc/apt/sources.list.d/vejeta.list
apt update && apt install -y stremio
EOF

# Access via console or SSH
incus console stremio-vm
```

## Security Configuration

### Incus Security Profile

Create a security-hardened profile:

```bash
# Create profile
incus profile create stremio-secure

# Configure security settings
incus profile set stremio-secure \
  security.nesting=false \
  security.privileged=false \
  security.idmap.isolated=true \
  security.syscalls.intercept.mknod=true \
  security.syscalls.intercept.setxattr=true

# AppArmor confinement
incus profile set stremio-secure \
  raw.apparmor="profile stremio-secure flags=(attach_disconnected,mediate_deleted) {
    #include <abstractions/base>
    #include <abstractions/nameservice>

    # Deny dangerous capabilities
    deny capability sys_admin,
    deny capability sys_module,
    deny capability sys_rawio,

    # Allow hardware access
    /dev/dri/** rw,
    /dev/snd/** rw,

    # Allow X11
    /tmp/.X11-unix/* rw,
  }"

# Resource limits
incus profile set stremio-secure \
  limits.cpu=2 \
  limits.memory=2GiB \
  limits.processes=200

# Launch with secure profile
incus launch stremio-secure my-stremio --profile stremio-secure
```

### Seccomp Profile

```bash
# Create seccomp policy (whitelist approach)
cat > /etc/incus/seccomp/stremio.policy <<'EOF'
2
blacklist
[all]
reject_force_umount  # Remove
chmod                # Remove for read-only enforcement
chown                # Remove
EOF

# Apply to container
incus config set stremio-gui raw.seccomp - < /etc/incus/seccomp/stremio.policy
```

## Advanced Features

### Snapshots and Backups

```bash
# Create snapshot
incus snapshot create stremio-gui clean-state

# Restore snapshot
incus snapshot restore stremio-gui clean-state

# Export snapshot
incus export stremio-gui stremio-backup.tar.gz

# Import on another host
incus import stremio-backup.tar.gz
```

### Clustering

```bash
# Initialize cluster on first node
incus cluster enable node1

# Join cluster from other nodes
incus cluster join node1

# Migrate container between nodes
incus move stremio-gui node2:stremio-gui
```

### Resource Monitoring

```bash
# Show resource usage
incus info stremio-gui

# Monitor in real-time
incus monitor stremio-gui

# Detailed metrics
incus query /1.0/containers/stremio-gui/state
```

## Integration with Existing Infrastructure

### Using with Our Secure Launcher Scripts

You can run our security-hardened launcher scripts inside Incus:

```bash
# Copy scripts into container
incus file push shared/scripts/launch-stremio-secure.sh \
  stremio-system/home/ubuntu/

# Execute
incus exec stremio-system -- \
  sudo -u ubuntu bash /home/ubuntu/launch-stremio-secure.sh
```

### Combining Incus VM + Docker Inside

Maximum isolation: Incus VM running Docker inside:

```bash
# Create VM with nested virtualization
incus launch images:debian/trixie docker-host --vm \
  -c security.nesting=true

# Install Docker inside
incus exec docker-host -- apt install -y docker.io

# Run our Docker image inside the VM
incus exec docker-host -- docker run -it stremio-secure:wolfi
```

## Comparison with Other Runtimes

| Runtime | Isolation Level | Overhead | Best For |
|---------|----------------|----------|----------|
| **Docker** | Namespace | Low | Application containers |
| **Podman** | Namespace (rootless) | Low | Rootless app containers |
| **Incus (container)** | Namespace + AppArmor | Medium | System containers |
| **Incus (VM)** | Full KVM virtualization | High | Maximum isolation |
| **OCI (runc/crun)** | Namespace | Minimal | Direct runtime control |

## Troubleshooting

### X11 Not Working

```bash
# Allow X11 forwarding
xhost +local:

# Check DISPLAY variable
incus exec stremio-gui -- env | grep DISPLAY

# Verify X11 socket mount
incus config device show stremio-gui
```

### GPU Not Accessible

```bash
# Check GPU device
incus config device add stremio-gui gpu gpu

# Verify DRM devices
incus exec stremio-gui -- ls -la /dev/dri/

# Check permissions
incus exec stremio-gui -- id
```

### Audio Not Working

```bash
# Add PulseAudio socket
incus config device add stremio-gui audio disk \
  source=/run/user/1000/pulse \
  path=/run/user/65532/pulse

# Or use direct ALSA access
incus config device add stremio-gui audio unix-char \
  source=/dev/snd \
  path=/dev/snd
```

## Security Considerations

**Incus Advantages**:
- Strong default AppArmor profiles
- Built-in seccomp policies
- User namespace isolation by default
- No privileged daemon (unlike Docker)

**Additional Hardening**:
```bash
# Disable container nesting
incus config set stremio-gui security.nesting=false

# Prevent privilege escalation
incus config set stremio-gui security.privileged=false

# Enable seccomp notification
incus config set stremio-gui security.syscalls.intercept.mknod=true

# Limit kernel features
incus config set stremio-gui linux.kernel_modules=false
```

## References

- [Incus Official Documentation](https://linuxcontainers.org/incus/docs/latest/)
- [Incus GitHub Repository](https://github.com/lxc/incus)
- [LXC/Incus Security](https://linuxcontainers.org/incus/docs/latest/security/)
- [Incus vs LXD Comparison](https://discuss.linuxcontainers.org/t/comparing-incus-and-lxd/)

## Why Incus Matters for This Project

Including Incus support demonstrates:

1. **Runtime Flexibility**: Same security principles across all major container technologies
2. **Understanding Trade-offs**: Knowing when to use app containers vs system containers
3. **Production Readiness**: Incus is used in production for long-running workloads
4. **Advanced Skills**: Shows expertise beyond just Docker basics
5. **Linux Ecosystem**: Integration with linuxcontainers.org projects

This makes the project valuable for:
- Enterprise environments using Incus/LXC
- Users wanting full OS containers
- Scenarios requiring live migration
- High-security environments needing VM-level isolation
