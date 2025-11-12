# APK Repository Signing Keys

This directory contains public keys used to verify package signatures from custom APK repositories.

## Supply Chain Security

Including signing keys in the repository provides:

- **Auditability**: All key changes are tracked in Git history
- **Reproducibility**: Builds work offline without external dependencies
- **Transparency**: Keys are reviewed in pull requests
- **Traceability**: Clear chain of custody via Git commits
- **Immutability**: Git provides cryptographic verification of key history

This approach follows industry best practices from:
- [SLSA Framework](https://slsa.dev/) (Supply chain Levels for Software Artifacts)
- [Chainguard Supply Chain Security](https://www.chainguard.dev/unchained)
- [Reproducible Builds Project](https://reproducible-builds.org/)

## vejeta-wolfi.rsa.pub

**Purpose**: Signs packages in the custom Wolfi APK repository

**Repository**: https://sourceforge.net/projects/wolfi/files/x86_64/

**Verification**:
```bash
# Verify key fingerprint (SHA256)
sha256sum keys/vejeta-wolfi.rsa.pub

# Expected: 3a69e5ba1f59249cf4babaa29941d21ed3be5fae2c810ba34d00b10c4c5bd3b2
```

## Key Rotation

When rotating keys:

1. Add new key to this directory with descriptive name (e.g., `vejeta-wolfi-2025.rsa.pub`)
2. Update Dockerfiles to copy both old and new keys
3. Re-sign repository packages with new key
4. After transition period, remove old key
5. Document rotation in Git commit message

## Verifying Key Authenticity

Before accepting a key change in a pull request:

1. Verify the key fingerprint matches the expected value
2. Cross-reference with official source (SourceForge project page)
3. Check that packages signed with this key are already in use
4. Ensure the commit is signed by a trusted maintainer

## Usage in Dockerfiles

```dockerfile
# Copy pre-verified signing key from repository
COPY keys/vejeta-wolfi.rsa.pub /etc/apk/keys/vejeta-wolfi.rsa.pub

# Add repository
RUN echo "https://downloads.sourceforge.net/project/wolfi" >> /etc/apk/repositories

# Install packages (signature will be automatically verified)
RUN apk update && apk add --no-cache stremio-server
```

## References

- [Alpine APK Keys](https://git.alpinelinux.org/aports/tree/main/alpine-keys)
- [Debian Archive Signing Keys](https://ftp-master.debian.org/keys.html)
- [SLSA Requirements](https://slsa.dev/spec/v1.0/requirements)
