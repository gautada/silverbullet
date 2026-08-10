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
# Pin to a specific pre-142 build via snapshot.debian.org
# RUN echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20251001T000000Z trixie main" > /etc/apt/sources.list.d/chromium-pin.list \
#     && apt-get update \
#     && apt-get install -y chromium=<exact-version-string> \
#     && apt-mark hold chromium

# Pin Chromium to the last version before Chrome 142 introduced the
# clientSecurityState.localNetworkAccessRequestPolicy CDP field, which
# chromiumoxide (SilverBullet's CDP client) cannot parse -- causes
# "WS Invalid message: data did not match any variant of untagged enum
# Message" and a WebSocket reset on first real page load.
# See: https://developer.chrome.com/blog/local-network-access (Chrome 142, 2025-10-28)
ARG CHROME_FOR_TESTING_VERSION=141.0.7390.107

RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
        curl unzip \
        # Chrome-for-Testing's Linux build still needs these shared libs \
        # normally pulled in by the full 'chromium' apt package: \
        libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
        libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
        libgbm1 libasound2 libpango-1.0-0 libcairo2 libatspi2.0-0 \
    && curl -fsSL -o /tmp/chrome.zip \
        "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_FOR_TESTING_VERSION}/linux64/chrome-linux64.zip" \
    && unzip -q /tmp/chrome.zip -d /opt \
    && mv /opt/chrome-linux64 /opt/chromium-pinned \
    && ln -sf /opt/chromium-pinned/chrome /usr/bin/chromium \
    && rm -rf /tmp/chrome.zip /var/lib/apt/lists/*

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
