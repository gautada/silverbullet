# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=docker.io/gautada/debian:latest
FROM ${BASE_IMAGE} AS container

ARG IMAGE_NAME=silverbullet

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="${IMAGE_NAME}"
LABEL org.opencontainers.image.description="A SilverBullet knowledge space server container."
LABEL org.opencontainers.image.source="https://github.com/gautada/silverbullet"
LABEL org.opencontainers.image.license="MIT"

# ╭――――――――――――――――――――╮
# │ PACKAGES           │
# ╰――――――――――――――――――――╯
# unzip: required to extract the silverbullet server binary
RUN apt-get update \
 && apt-get install --yes --no-install-recommends unzip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
# Rename the base debian user to silverbullet.
ARG USER=silverbullet
RUN /usr/sbin/usermod -l $USER debian \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER debian \
 && /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

# ╭――――――――――――――――――――╮
# │ CONTAINER          │
# ╰――――――――――――――――――――╯
# Download and install the SilverBullet binary from GitHub releases.
WORKDIR /app
ARG SILVERBULLET_VERSION
ENV SILVERBULLET_VERSION=${SILVERBULLET_VERSION:-unknown}
RUN if [ "$SILVERBULLET_VERSION" = "unknown" ]; then \
    SILVERBULLET_VERSION=$(curl -sL "https://api.github.com/repos/silverbulletmd/silverbullet/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'); \
    fi \
 && curl -fsSL "https://github.com/silverbulletmd/silverbullet/releases/download/${SILVERBULLET_VERSION}/silverbullet-server-linux-x86_64.zip" -o /tmp/silverbullet.zip \
 && unzip -q /tmp/silverbullet.zip -d /opt \
 && install -m 0755 /opt/silverbullet /usr/local/bin/silverbullet \
 && rm -rf /tmp/silverbullet.zip /opt/silverbullet \
 && mkdir -p /mnt/volumes/data/space \
 && chown -R $USER:$USER /app /home/$USER /mnt/volumes/data/space

# ╭――――――――――――――――――――╮
# │ VERSION            │
# ╰――――――――――――――――――――╯
# Override container-version to return the SilverBullet version.
COPY scripts/container-version.sh /usr/bin/container-version
RUN chmod +x /usr/bin/container-version

# ╭――――――――――――――――――――╮
# │ HEALTH             │
# ╰――――――――――――――――――――╯
# silverbullet-running: verifies silverbullet is responding on port 3000.
COPY health/silverbullet-check.sh /etc/container/health.d/silverbullet-running
RUN chmod +x /etc/container/health.d/silverbullet-running

# ╭――――――――――――――――――――╮
# │ ENTRYPOINT         │
# ╰――――――――――――――――――――╯
# s6 service definition: starts silverbullet via the run script.
COPY services/silverbullet/run /etc/services.d/silverbullet/run
RUN chmod +x /etc/services.d/silverbullet/run

EXPOSE 3000/tcp
WORKDIR /mnt/volumes/data/space
