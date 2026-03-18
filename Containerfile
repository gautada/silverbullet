# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=docker.io/gautada/debian:latest
ARG SILVERBULLET_VERSION=2.5.2
ARG SILVERBULLET_ARCH=linux-x86_64
ARG SILVERBULLET_SHA256=""
ARG SILVERBULLET_DOWNLOAD_URL="https://github.com/silverbulletmd/silverbullet/releases/download/${SILVERBULLET_VERSION}/silverbullet-server-${SILVERBULLET_ARCH}.zip"

FROM ${BASE_IMAGE}

ARG SILVERBULLET_VERSION
ARG SILVERBULLET_ARCH
ARG SILVERBULLET_SHA256
ARG SILVERBULLET_DOWNLOAD_URL
ARG APP_USER="silverbullet"

LABEL org.opencontainers.image.title="silverbullet"
LABEL org.opencontainers.image.description="SilverBullet knowledge space server built on the gautada/debian base image."
LABEL org.opencontainers.image.source="https://github.com/gautada/silverbullet"
LABEL org.opencontainers.image.version="${SILVERBULLET_VERSION}"
LABEL org.opencontainers.image.licenses="MIT"

ENV SILVERBULLET_VERSION=${SILVERBULLET_VERSION} \
    SILVERBULLET_ARCH=${SILVERBULLET_ARCH} \
    SILVERBULLET_BIND=0.0.0.0 \
    SILVERBULLET_PORT=3000 \
    SILVERBULLET_SPACE=/mnt/volumes/data/space \
    SB_FOLDER=/mnt/volumes/data/space

# Install runtime deps that are not part of the base image yet.
RUN set -eux \
 && apt-get update \
 && apt-get install --yes --no-install-recommends unzip \
 && rm -rf /var/lib/apt/lists/*

# Download and install the requested SilverBullet server build.
RUN set -eux \
 && tmp_zip="/tmp/silverbullet.zip" \
 && curl -fsSL "${SILVERBULLET_DOWNLOAD_URL}" -o "${tmp_zip}" \
 && if [ -n "${SILVERBULLET_SHA256}" ]; then echo "${SILVERBULLET_SHA256}  ${tmp_zip}" | sha256sum -c - ; fi \
 && unzip -q "${tmp_zip}" -d /opt \
 && install -m 0755 /opt/silverbullet /usr/local/bin/silverbullet \
 && rm -rf "${tmp_zip}" /opt/silverbullet

# Rename the default debian user to match the container purpose and ensure ownership.
RUN set -eux \
 && groupmod --new-name "${APP_USER}" debian \
 && usermod --login "${APP_USER}" --move-home /home/${APP_USER} debian \
 && usermod -aG privileged "${APP_USER}" \
 && chown -R "${APP_USER}:${APP_USER}" /home/${APP_USER} \
 && chown -R "${APP_USER}:${APP_USER}" /mnt/volumes/backup \
 && chown -R "${APP_USER}:${APP_USER}" /mnt/volumes/configuration \
 && chown -R "${APP_USER}:${APP_USER}" /mnt/volumes/data \
 && chown -R "${APP_USER}:${APP_USER}" /mnt/volumes/secrets

# Copy runtime assets: service definition, health probe, and metadata scripts.
COPY services/silverbullet/run /etc/services.d/silverbullet/run
COPY health/silverbullet-check.sh /etc/container/health.d/silverbullet-check
COPY scripts/container-version.sh /usr/bin/container-version

RUN chmod +x /etc/services.d/silverbullet/run \
    /etc/container/health.d/silverbullet-check \
    /usr/bin/container-version

EXPOSE 3000/tcp
