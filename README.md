# silverbullet

A SilverBullet knowledge-space server based on
[`gautada/debian`](https://github.com/gautada/debian), with Chromium included
for the Runtime API.

The image follows the base image's s6 supervision and shared-volume
conventions. The inherited CI pipeline builds native `amd64` and `arm64`
images and publishes them as one multi-architecture manifest.

## Building

```sh
podman build \
  --arch arm64 \
  --tag localhost/silverbullet:2.10.0 \
  --file Containerfile .
```

The build maps `uname -m` to the matching official SilverBullet server archive
and verifies the release's pinned SHA-256 checksum before installation.

### Build arguments

| Argument | Default | Description |
| --- | --- | --- |
| `SILVERBULLET_VERSION` | `2.10.0` | Upstream release tag |
| `SILVERBULLET_ARCH` | auto-detected | Optional release architecture override (`linux-x86_64` or `linux-aarch64`) |
| `SILVERBULLET_SHA256` | pinned per architecture | Optional checksum override for a deliberate custom build |

## Runtime configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `LIBRARY_SPACE` | `/mnt/volumes/data/space` | Server data root or classic single-space folder |
| `LIBRARY_BIND` | `0.0.0.0` | Interface on which the server listens |
| `LIBRARY_PORT` | `3000` | HTTP port |
| `SILVERBULLET_SPACE` | unset | Alias used when `LIBRARY_SPACE` is unset |
| `SILVERBULLET_BIND` | unset | Alias used when `LIBRARY_BIND` is unset |
| `SILVERBULLET_PORT` | unset | Alias used when `LIBRARY_PORT` is unset |
| `SB_USER` | unset | Optional classic single-space `username:password` authentication |
| `SB_AUTH_TOKEN` | unset | Optional classic single-space bearer token |
| `SB_RUNTIME_API` | auto | Set to `0` to disable the Chromium-backed Runtime API |

`LIBRARY_*` variables remain the preferred container interface because they
are already used by the deployed `:dev` manifest. The service exports
`SB_FOLDER` internally and otherwise lets SilverBullet select its own boot
mode.

### Boot modes and accounts

SilverBullet 2.10 chooses its mode from the contents of `LIBRARY_SPACE`:

- An empty folder with no legacy `SB_*` setting opens the first-run setup
  wizard. It creates the first administrator, `users.json`, and `spaces.json`.
- A folder containing `spaces.json` starts account-managed multi-space mode.
- A non-empty notes folder without `spaces.json` remains classic single-space.
- Setting a legacy option such as `SB_USER` forces classic single-space mode.

To migrate an existing notes folder, keep it unchanged and point a fresh,
empty server data root at it from the setup wizard's **Use an existing folder
on this server** option. This is safer than trying to convert the notes folder
in place and keeps account metadata outside the notes themselves.

## Runtime API

Debian Chromium is installed at `/usr/bin/chromium`, advertised through
`CHROMIUM_PATH`, and launched lazily when the first Runtime API request arrives.
For example:

```sh
curl --data '1 + 1' http://localhost:3000/.runtime/lua
```

The expected response is `{"result":2}`. In account-managed multi-space mode,
the Runtime API is disabled per space by default and must be enabled for the
space in Space Manager. Each enabled space can launch its own Chromium
instance.

## Health and version reporting

The base container's health runner invokes
`/etc/container/health.d/silverbullet-check`. `/usr/bin/container-version`
reports the bundled SilverBullet release using its `version` subcommand.

## Development workflow

1. Create a feature branch from `dev` using the `nyx/<issue>-<slug>` pattern.
2. Run the shared checks before committing:

   ```sh
   curl -sSfL https://raw.githubusercontent.com/gautada/cicd/main/bin/pre-commit | bash
   ```

3. Push the branch and open a pull request against `dev`.
