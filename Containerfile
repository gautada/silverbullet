# syntax=docker/dockerfile:1.7
# ------------------------------------------------------------- [STAGE] BUILD
FROM docker.io/library/golang:1.25-trixie AS builder
ARG SILVERBULLET_VERSION=2.5.2
# Install build dependencies and Deno (required for frontend/plug build)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
     build-essential \
     git \
     make \
     ca-certificates \
     curl \
     unzip \
 && curl -fsSL https://deno.land/install.sh | sh \
 && ln -s /root/.deno/bin/deno /usr/local/bin/deno \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git config --global advice.detachedHead false \
 && git clone --branch "${SILVERBULLET_VERSION}" --depth 1 \
              https://github.com/silverbulletmd/silverbullet.git .

# Build the silverbullet binary (Makefile calls deno task build + go build)
RUN make build

# hadolint ignore=DL3007
FROM docker.io/gautada/debian:latest AS container
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
# RUN apt-get update \
#  && apt-get install --yes --no-install-recommends unzip \
#  && apt-get clean \
#  && rm -rf /var/lib/apt/lists/*

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
# Rename the base debian user to librarian.
ARG USER=librarian
RUN /usr/sbin/usermod -l $USER debian \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER debian \
 && /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

COPY --from=builder /build/silverbullet /usr/local/bin/silverbullet


# ╭――――――――――――――――――――╮
# │ VERSION            │
# ╰――――――――――――――――――――╯
# Override container-version to return the SilverBullet version.
COPY scripts/container-version.sh /usr/bin/container-version
RUN chmod +x /usr/bin/container-version
#
# # ╭――――――――――――――――――――╮
# # │ HEALTH             │
# # ╰――――――――――――――――――――╯
# # silverbullet-running: verifies silverbullet is responding on port 3000.
# COPY health/silverbullet-check.sh /etc/container/health.d/silverbullet-running
# RUN chmod +x /etc/container/health.d/silverbullet-running

# ╭――――――――――――――――――――╮
# │ ENTRYPOINT         │
# ╰――――――――――――――――――――╯
# s6 service definition: starts silverbullet via the run script.
COPY services/silverbullet/run /etc/services.d/silverbullet/run
RUN chmod +x /etc/services.d/silverbullet/run

EXPOSE 3000/tcp
WORKDIR /mnt/volumes/data/space
