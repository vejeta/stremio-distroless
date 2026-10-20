#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Juan Manuel Méndez Rey <vejeta@gmail.com>
#
# Run the image as users are told to (read-only, no capabilities, a data volume)
# and check that the streaming server answers; then that the image has no shell.
# Usage: images/stremio-server/test.sh <image>
set -eu
image=${1:?usage: test.sh <image>}
name=stremio-server-test-$$
data=$(mktemp -d)
chmod 777 "$data"
trap 'docker logs "$name" 2>&1 | tail -40; docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$data"' EXIT

# DOCKER_RUN_ARGS: extra options, e.g. a proxy (-e HTTPS_PROXY=... -e NODE_USE_ENV_PROXY=1)
# shellcheck disable=SC2086
docker run -d --name "$name" ${DOCKER_RUN_ARGS:-} \
  --read-only --cap-drop=ALL --security-opt=no-new-privileges:true \
  --tmpfs /tmp:rw,noexec,nosuid,size=512m \
  -v "$data:/home/nonroot/.stremio-server" \
  -p 127.0.0.1:11470:11470 \
  "$image" >/dev/null

# the first start downloads server.js, then the server starts
ok=
for i in $(seq 1 150); do
  if curl -fsS -m 5 http://127.0.0.1:11470/settings -o "$data/settings.json" 2>/dev/null; then ok=1; break; fi
  [ "$(docker inspect -f '{{.State.Running}}' "$name")" = true ] || break
  sleep 2
done
[ -n "$ok" ] || { echo "FAIL: the server did not answer on port 11470"; exit 1; }
grep -q '"options"' "$data/settings.json"
echo "ok: the server answers"

# server.js was downloaded into the volume, not shipped in the image
ls "$data"/server-*.js
echo "ok: server.js is in the data volume"

# it keeps running (it has crashed before on a missing ps)
sleep 20
[ "$(docker inspect -f '{{.State.Running}}' "$name")" = true ] || { echo "FAIL: the server stopped"; exit 1; }
echo "ok: still running"

# distroless: no shell, not root
if docker exec "$name" /bin/sh -c true 2>/dev/null; then echo "FAIL: the image has a shell"; exit 1; fi
[ "$(docker inspect -f '{{.Config.User}}' "$image")" = 65532 ] || { echo "FAIL: not running as nonroot"; exit 1; }
echo "ok: no shell, runs as 65532"
