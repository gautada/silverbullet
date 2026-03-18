# SilverBullet container

A SilverBullet knowledge space server container that inherits the
[`gautada/debian`](https://github.com/gautada/debian) base image conventions:

- s6-based process supervision
- Standard health hooks via `/etc/container/health.d`
- Version reporting through `/usr/bin/container-version`
- Shared volume layout under `/mnt/volumes/*`

## Building

```sh
git clone https://github.com/gautada/silverbullet.git
cd silverbullet
podman build \
  --build-arg SILVERBULLET_VERSION=2.5.2 \
  --build-arg SILVERBULLET_ARCH=linux-x86_64 \
  -t ghcr.io/gautada/silverbullet:2.5.2 \
  -f Containerfile .
```

### Key build arguments

| Argument | Default | Description |
| --- | --- | --- |
| `BASE_IMAGE` | `docker.io/gautada/debian:latest` | Base layer for all tooling |
| `SILVERBULLET_VERSION` | `2.5.2` | Release tag bundled into the image |
| `SILVERBULLET_ARCH` | `linux-x86_64` | Release artifact to download (`linux-aarch64` also available) |
| `SILVERBULLET_SHA256` | _(empty)_ | Optional checksum gate for the downloaded artifact |

## Runtime configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `SILVERBULLET_BIND` | `0.0.0.0` | Interface the HTTP server binds to |
| `SILVERBULLET_PORT` | `3000` | Listening port (container exposes TCP/3000) |
| `SILVERBULLET_SPACE` | `/mnt/volumes/data/space` | Location of the mounted SilverBullet space |
| `SB_FOLDER` | mirrors `SILVERBULLET_SPACE` | Passed to the binary for backwards compatibility |
| `SB_USER` | _(unset)_ | Optional `username:password` basic auth credential pair recommended by upstream |

### Volumes

Mount `/mnt/volumes/data` to persist your notes. The service script creates the
space directory when absent and runs the server as the `silverbullet` user to
match the base image's least-privilege policy.

Example run command:

```sh
podman run -d --name silverbullet \
  -p 3000:3000 \
  -e SB_USER=admin:supersecret \
  -v $PWD/space:/mnt/volumes/data \
  ghcr.io/gautada/silverbullet:2.5.2
```

## Health + version reporting

The `/etc/container/health.d/silverbullet-check` probe uses `curl` against the
local HTTP endpoint for liveness/readiness/startup probes and additionally runs
`silverbullet version` during the CI `test` probe. The standard
`/usr/bin/container-health` entry points leverage this script automatically.

`/usr/bin/container-version` now returns the bundled SilverBullet release tag,
allowing CI/CD to assert image contents.

## Development workflow

1. Create a feature branch from `dev` following the `nyx/<issue>-<slug>` format.
2. Implement changes inside the branch and run the shared pre-commit runner:

   ```sh
   curl -sSfL https://raw.githubusercontent.com/gautada/cicd/main/bin/pre-commit | bash
   ```

3. Push the branch and open a PR targeting `dev`.
