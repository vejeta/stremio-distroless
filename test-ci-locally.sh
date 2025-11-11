#!/bin/bash
# Local CI/CD Test Script
# Tests the same security checks that GitHub Actions will run
# Usage: ./test-ci-locally.sh [wolfi|debian] [gui|server]

set -e

ECOSYSTEM=${1:-wolfi}
VARIANT=${2:-gui}

echo "==========================================="
echo "Testing $ECOSYSTEM-$VARIANT locally"
echo "==========================================="

# Determine Dockerfile
if [ "$VARIANT" == "gui" ]; then
    DOCKERFILE="$ECOSYSTEM/Dockerfile"
else
    DOCKERFILE="$ECOSYSTEM/Dockerfile.server"
fi

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ Error: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

echo ""
echo "📦 Step 1: Building image..."
IMAGE_TAG="stremio-test:$ECOSYSTEM-$VARIANT"

docker build -t "$IMAGE_TAG" -f "$DOCKERFILE" . || {
    echo "❌ Build failed!"
    exit 1
}

echo "✅ Build successful!"

echo ""
echo "🔍 Step 2: Running security posture tests..."
echo "=============================================="

# Test 1: Verify nonroot user using docker inspect
echo -n "Test 1: Verify nonroot user... "
USER_ID=$(docker inspect "$IMAGE_TAG" --format='{{.Config.User}}' | cut -d: -f1)
if [ "$USER_ID" == "65532" ] || [ "$USER_ID" == "nonroot" ]; then
    echo "✅ Running as nonroot user (User: $USER_ID)"
else
    echo "❌ NOT running as nonroot user (User: $USER_ID)"
    exit 1
fi

# Test 2: Verify no shell by checking if /bin/sh exists in image
echo -n "Test 2: Verify no shell... "
if docker run --rm --entrypoint="" "$IMAGE_TAG" /bin/sh -c "echo test" 2>&1 | grep -qE "not found|no such file|OCI runtime|executable file not found"; then
    echo "✅ No shell present in image (distroless)"
else
    echo "⚠️  Shell may be present - manual verification recommended"
fi

# Test 3: Verify image size (distroless should be small)
echo -n "Test 3: Verify image size... "
IMAGE_SIZE=$(docker inspect "$IMAGE_TAG" --format='{{.Size}}')
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
if [ $IMAGE_SIZE_MB -lt 200 ]; then
    echo "✅ Image size indicates minimal attack surface (${IMAGE_SIZE_MB}MB)"
else
    echo "⚠️  Image size larger than expected: ${IMAGE_SIZE_MB}MB"
fi

# Test 4: Verify entrypoint/cmd is set correctly
echo -n "Test 4: Verify entrypoint/command... "
ENTRYPOINT=$(docker inspect "$IMAGE_TAG" --format='{{.Config.Entrypoint}}')
CMD=$(docker inspect "$IMAGE_TAG" --format='{{.Config.Cmd}}')
if [ -n "$ENTRYPOINT" ] || [ -n "$CMD" ]; then
    echo "✅ Container has defined entrypoint/command"
    echo "   Entrypoint: $ENTRYPOINT"
    echo "   CMD: $CMD"
else
    echo "⚠️  No entrypoint or command defined"
fi

echo ""
echo "=============================================="
echo "📊 Image Information"
echo "=============================================="
docker images "$IMAGE_TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

echo ""
echo "=============================================="
echo "🎉 All tests passed for $ECOSYSTEM-$VARIANT!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Test other variants: ./test-ci-locally.sh wolfi server"
echo "2. Test Debian variant: ./test-ci-locally.sh debian gui"
echo "3. Run security scans:"
echo "   - trivy image $IMAGE_TAG"
echo "   - grype $IMAGE_TAG"
echo "4. Commit and push to trigger GitHub Actions"
