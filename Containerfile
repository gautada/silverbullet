# syntax=docker/dockerfile:1.7

# hadolint ignore=DL3007
FROM docker.io/gautada/debian:latest AS container

ARG IMAGE_NAME=silverbullet
ARG SILVERBULLET_VERSION=2.10.0
ARG SILVERBULLET_ARCH=""
ARG SILVERBULLET_SHA256=""

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="${IMAGE_NAME}"
LABEL org.opencontainers.image.description="A SilverBullet knowledge space server container."
LABEL org.opencontainers.image.source="https://github.com/gautada/silverbullet"
LABEL org.opencontainers.image.license="MIT"
LABEL org.opencontainers.image.version="${SILVERBULLET_VERSION}"

# ╭――――――――――――――――――――╮
# │ PACKAGES           │
# ╰――――――――――――――――――――╯
# Chromium enables SilverBullet's headless-browser runtime API.
# hadolint ignore=DL3008
RUN set -eux \
    && apt-get update \
    && apt-get install --yes --no-install-recommends unzip chromium \
    && rm -rf /var/lib/apt/lists/*

ENV CHROMIUM_PATH=/usr/bin/chromium

# Map the native pipeline architecture to the upstream release asset and its
# pinned checksum. SILVERBULLET_ARCH/SILVERBULLET_SHA256 remain overridable for
# deliberate custom builds.
# hadolint ignore=DL4006
RUN set -eux \
    && machine_arch="$(uname -m)" \
    && release_arch="${SILVERBULLET_ARCH}" \
    && if [ -z "${release_arch}" ]; then \
         case "${machine_arch}" in \
           x86_64|amd64) release_arch="linux-x86_64" ;; \
           aarch64|arm64) release_arch="linux-aarch64" ;; \
           *) echo "Unsupported architecture: ${machine_arch}" >&2; exit 1 ;; \
         esac; \
       fi \
    && case "${release_arch}" in \
         amd64|x86_64|linux-x86_64) \
           release_arch="linux-x86_64"; \
           pinned_sha256="ca33f7de3bae2f2e7d95cdd2cca1a023e51267388c9dbc8ff5acc33b1cbd5a7d" \
           ;; \
         arm64|aarch64|linux-aarch64) \
           release_arch="linux-aarch64"; \
           pinned_sha256="3e4dab63447caf7feb04ffc033e3f0cf170aace110768b2a294c995e272a3347" \
           ;; \
         *) echo "Unsupported SILVERBULLET_ARCH: ${release_arch}" >&2; exit 1 ;; \
       esac \
    && expected_sha256="${SILVERBULLET_SHA256:-${pinned_sha256}}" \
    && archive="/tmp/silverbullet.zip" \
    && curl -fsSL \
         "https://github.com/silverbulletmd/silverbullet/releases/download/${SILVERBULLET_VERSION}/silverbullet-server-${release_arch}.zip" \
         -o "${archive}" \
    && echo "${expected_sha256}  ${archive}" | sha256sum -c - \
    && unzip -q "${archive}" -d /tmp/silverbullet-release \
    && install -m 0755 /tmp/silverbullet-release/silverbullet /usr/local/bin/silverbullet \
    && rm -rf "${archive}" /tmp/silverbullet-release \
    && /usr/local/bin/silverbullet version

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
# Rename the base debian user to librarian.
ARG USER=librarian
# hadolint ignore=DL4006
RUN /usr/sbin/usermod -l $USER debian \
    && /usr/sbin/usermod -d /home/$USER -m $USER \
    && /usr/sbin/groupmod -n $USER debian \
    && /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

# ╭――――――――――――――――――――╮
# │ VERSION + HEALTH   │
# ╰――――――――――――――――――――╯
COPY scripts/container-version.sh /usr/bin/container-version
COPY health/silverbullet-check.sh /etc/container/health.d/silverbullet-check
RUN chmod +x /usr/bin/container-version \
    /etc/container/health.d/silverbullet-check

# ╭――――――――――――――――――――╮
# │ ENTRYPOINT         │
# ╰――――――――――――――――――――╯
COPY services/silverbullet/run /etc/services.d/silverbullet/run
RUN chmod +x /etc/services.d/silverbullet/run

EXPOSE 3000/tcp
WORKDIR /mnt/volumes/data/space
