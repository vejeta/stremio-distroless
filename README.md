# Distroless images from Wolfi Community Packages

[![Images](https://github.com/vejeta/stremio-distroless/actions/workflows/images.yml/badge.svg)](https://github.com/vejeta/stremio-distroless/actions/workflows/images.yml)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)

Container images built with [apko](https://github.com/chainguard-dev/apko)
from [Wolfi](https://wolfi.dev) and
[Wolfi Community Packages](https://github.com/vejeta/wolfi-packages)
(`https://wolfi.vejeta.com`). Each image contains only its packages, with no
shell and no package manager, and runs as a nonroot user. Images are rebuilt
every week with the current packages and signed with cosign.

| Image | What it is |
|-------|------------|
| [`ghcr.io/vejeta/stremio-server`](images/stremio-server/) | Stremio's streaming server, headless: use it from [web.stremio.com](https://web.stremio.com), TVs and phones |

## stremio-server

The streaming server that the Stremio apps talk to, on a home server, a NAS
or a Raspberry Pi (amd64 and arm64).

```bash
docker run -d --name stremio-server --restart unless-stopped \
  --read-only --cap-drop=ALL --security-opt=no-new-privileges:true \
  --tmpfs /tmp:rw,noexec,nosuid,size=512m \
  -v stremio-server:/home/nonroot/.stremio-server \
  -p 11470:11470 -p 12470:12470 \
  ghcr.io/vejeta/stremio-server:latest
```

or `docker compose -f images/stremio-server/compose.yaml up -d`. Then, in
Stremio (web.stremio.com, or an app), Settings → Streaming server URL:
`http://<host>:11470`.

- **server.js is not in the image.** Stremio's server.js is not free
  software, so the image cannot ship it. On the first start the
  [`stremio-server-launcher`](https://github.com/vejeta/wolfi-packages/blob/master/packages/stremio-server-launcher.yaml)
  package downloads it from Stremio, checks its sha256 and keeps it in the
  volume, together with the server's cache and settings. Later starts use
  that copy.
- **Behind a proxy:** pass `-e HTTPS_PROXY=http://proxy:3128 -e NODE_USE_ENV_PROXY=1`.
  Node.js reads the proxy variables only with the second one.
- **Hardware transcoding:** the server tests VA-API, QSV and NVENC at start.
  To use a GPU, pass the device, for example `--device /dev/dri` and
  `--group-add $(getent group render | cut -d: -f3)`. Without one it
  transcodes in software.
- Ports: 11470 (HTTP) and 12470 (HTTPS, `local.strem.io`).

Check the signature:

```bash
cosign verify ghcr.io/vejeta/stremio-server:latest \
  --certificate-identity-regexp 'https://github.com/vejeta/stremio-distroless/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Building

```bash
apko build images/stremio-server/apko.yaml stremio-server:local stremio-server.tar
docker load -i stremio-server.tar
images/stremio-server/test.sh stremio-server:local-amd64
```

`test.sh` runs the image as above and checks that the server downloads
server.js into the volume, answers on port 11470 and keeps running, and that
the image has no shell and runs as 65532. The [Images](.github/workflows/images.yml)
workflow runs it on every change, then publishes to `ghcr.io` from `main`.

The signing key of Wolfi Community Packages is in [`keys/`](keys/), so the
builds do not depend on where it is published.

## History

This repository started as Dockerfiles for the Qt5 Stremio client and server
on Wolfi and Debian, copying binaries into distroless base images. It is now
apko images of packages; the earlier files are in the git history.
