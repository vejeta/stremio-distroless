# Creating Releases and Tags

This guide describes how to create and publish releases for the Stremio Distroless project.

## Quick Release Process

### 1. Create and Push Tag from Main

**IMPORTANT**: Tags must be created and pushed from the `main` branch.

```bash
# Switch to main and update
git checkout main
git pull origin main

# Create annotated tag (use semantic versioning)
git tag -a v1.0.0 -m "Release v1.0.0: Brief description"

# Push tag to trigger automated build
git push origin v1.0.0
```

### 2. Semantic Versioning

Follow [semver](https://semver.org/) conventions:
- **MAJOR** (v1.0.0, v2.0.0): Breaking changes
- **MINOR** (v1.1.0, v1.2.0): New features, backward compatible
- **PATCH** (v1.0.1, v1.0.2): Bug fixes, backward compatible

### 3. Monitor Build

1. Go to: `https://github.com/vejeta/stremio-distroless/actions`
2. Verify all builds complete (typically 30-45 minutes):
   - wolfi-gui (amd64 + arm64)
   - wolfi-server (amd64 + arm64)
   - debian-gui (amd64 + arm64)
   - debian-server (amd64 + arm64)

### 4. Verify Published Images

```bash
# Check multi-arch manifest
docker manifest inspect ghcr.io/vejeta/stremio-distroless:wolfi-gui-v1.0.0

# Pull and test
docker pull ghcr.io/vejeta/stremio-distroless:wolfi-gui-v1.0.0
```

## Published Image Tags

Each release creates the following tags:

```
ghcr.io/vejeta/stremio-distroless:wolfi-gui-v1.0.0
ghcr.io/vejeta/stremio-distroless:wolfi-server-v1.0.0
ghcr.io/vejeta/stremio-distroless:debian-gui-v1.0.0
ghcr.io/vejeta/stremio-distroless:debian-server-v1.0.0
```

Plus `latest` tags for each variant when building from `main`.

## Container Image Cleanup

### Automated Cleanup

The repository includes `.github/workflows/cleanup-images.yml` that:
- Runs automatically every Sunday at 2 AM UTC
- Deletes untagged, SHA-tagged, and branch-tagged images
- **Preserves**: Semantic version releases (v1.0.0) and latest tags
- **Removes**: Development builds, SHA tags, branch tags

### Manual Cleanup Trigger

**Via GitHub UI:**
1. Go to: `https://github.com/vejeta/stremio-distroless/actions/workflows/cleanup-images.yml`
2. Click "Run workflow"
3. Check "Dry run" to preview (recommended)
4. Click "Run workflow"

**Via GitHub CLI:**
```bash
# Dry run (preview only)
gh workflow run cleanup-images.yml -f dry_run=true

# Execute cleanup
gh workflow run cleanup-images.yml
```

### Manual Cleanup (Web UI)

1. Go to: `https://github.com/vejeta/stremio-distroless/pkgs/container/stremio-distroless`
2. Select versions to delete
3. Click "Delete"

**Keep**: Semantic version releases, latest tags
**Delete**: SHA-tagged images, branch tags, untagged manifests

## Storage Limits

- **Free tier**: 500 MB storage
- **Per release**: ~640 MB (4 variants × 2 architectures)
- **Recommendation**: Clean up after each release

## Quick Reference

```bash
# Create release
git checkout main && git pull
git tag -a v1.0.0 -m "Release v1.0.0: Description"
git push origin v1.0.0

# Trigger cleanup
gh workflow run cleanup-images.yml -f dry_run=true  # preview
gh workflow run cleanup-images.yml                   # execute

# List all images
gh api /users/vejeta/packages/container/stremio-distroless/versions | \
  jq -r '.[] | .metadata.container.tags[]' | sort -u
```

## Troubleshooting

**Tag already exists:**
```bash
git tag -d v1.0.0                    # delete local
git push origin --delete v1.0.0      # delete remote
git tag -a v1.0.0 -m "New message"  # recreate
git push origin v1.0.0              # push
```

**Build fails:** Check GitHub Actions logs and fix issues before recreating tag.

**Storage full:** Run cleanup workflow manually to free space.
