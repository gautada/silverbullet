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
    && apt-get install --yes --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

# Pin Chromium to 141.0.7390.122-1~deb13u1 -- the last build before the
# 142.0.7444.x series, which introduced the CDP field
# (clientSecurityState.localNetworkAccessRequestPolicy) that
# chromiumoxide (SilverBullet's Rust CDP client) cannot parse. Causes
# "WS Invalid message: data did not match any variant of untagged enum
# Message" and a WebSocket reset on the first real page load.
# Confirmed via snapshot.debian.org/package/chromium/141.0.7390.122-1~deb13u1/
#
# Installed by direct hash-addressed download rather than apt snapshot-date
# pinning: snapshot.debian.org's /file/<sha1> URLs are permanent regardless
# of archive retention, so no dated Release file to keep valid.
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) \
            CHROMIUM_SHA=4e60a372a1a2cdd4174e13f484b23d378a19b261; \
            CHROMIUM_COMMON_SHA=e53aba6c913ec2692564e0330557932f288e2a5d; \
            CHROMIUM_SANDBOX_SHA=f5b905ab1c0a648315861642609fb80d0d4dcbe9; \
            ;; \
        arm64) \
            CHROMIUM_SHA=276789af81bf869da5c5e3017f16491601686edd; \
            CHROMIUM_COMMON_SHA=4360059f40f5c05dc2ac0fe245e90b85c005755f; \
            CHROMIUM_SANDBOX_SHA=76957128f9b98d31924e7a7970038c721f1dcb7e; \
            ;; \
        *) \
            echo "No pinned Chromium 141 build recorded for arch ${ARCH}" >&2; \
            exit 1; \
            ;; \
    esac; \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates curl; \
    curl -fsSL -o /tmp/chromium.deb "https://snapshot.debian.org/file/${CHROMIUM_SHA}"; \
    curl -fsSL -o /tmp/chromium-common.deb "https://snapshot.debian.org/file/${CHROMIUM_COMMON_SHA}"; \
    curl -fsSL -o /tmp/chromium-sandbox.deb "https://snapshot.debian.org/file/${CHROMIUM_SANDBOX_SHA}"; \
    apt-get install -y --no-install-recommends /tmp/chromium-sandbox.deb /tmp/chromium-common.deb /tmp/chromium.deb; \
    apt-mark hold chromium chromium-common chromium-sandbox; \
    rm -f /tmp/chromium.deb /tmp/chromium-common.deb /tmp/chromium-sandbox.deb; \
    rm -rf /var/lib/apt/lists/*

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
# -----
ENV XDG_DATA_HOME=/home/${USER}/.local/share
ENV XDG_CONFIG_HOME=/home/${USER}/.config
ENV XDG_STATE_HOME=/home/${USER}/.local/state
ENV XDG_CACHE_HOME=/home/${USER}/.cache
RUN mkdir -p ${XDG_DATA_HOME} ${XDG_CONFIG_HOME} ${XDG_STATE_HOME} ${XDG_CACHE_HOME} \
 && chown ${USER}:${USER} -R /home/${USER}

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
COPY /etc/services.d/silverbullet/run /etc/services.d/silverbullet/run
RUN chmod +x /etc/services.d/silverbullet/run


# ╭――――――――――――――――――――╮
# │ CONTAINER          │
# ╰――――――――――――――――――――╯
EXPOSE 3000/tcp
WORKDIR /home/${USER}
