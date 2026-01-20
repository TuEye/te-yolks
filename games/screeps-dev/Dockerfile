# syntax=docker/dockerfile:1.6
FROM --platform=$TARGETOS/$TARGETARCH ghcr.io/pelican-eggs/yolks:debian

LABEL author="TuEye"

ARG TARGETOS
ARG TARGETARCH
ARG MONGO_DEBIAN_CODENAME=bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    NVM_DIR=/opt/nvm \
    NODE_VERSION=12 \
    PYENV_ROOT=/opt/pyenv \
    PYTHON2_VERSION=2.7.18

# Make pyenv available for all users by default (no pyenv init needed).
# Keep pyenv and nvm-based Node available for all users by default.
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${NVM_DIR}/current/bin:${PATH}"

## add container user
USER root
RUN set -eux; \
    if ! id -u container >/dev/null 2>&1; then \
      useradd -m -d /home/container -s /bin/bash container; \
    fi

# Base packages (+ build deps for pyenv / python2 from source)
# Note: BuildKit cache mounts accelerate apt significantly without polluting final layers.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        iproute2 \
        git \
        sqlite3 \
        libsqlite3-dev \
        ca-certificates \
        dnsutils \
        tzdata \
        zip \
        tar \
        curl \
        gnupg \
        perl \
        build-essential \
        libtool \
        iputils-ping \
        libnss3 \
        tini \
        redis-server \
        # --- python-build / pyenv deps ---
        autoconf \
        bison \
        patch \
        xz-utils \
        tk-dev \
        libreadline-dev \
        libbz2-dev \
        zlib1g-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libffi-dev \
        liblzma-dev \
        libgdbm-dev \
        libgdbm-compat-dev \
        uuid-dev \
        libssl-dev \
        libexpat1-dev

# --- pyenv (system-wide) via the officially supported installer (pyenv.run) ---
# Ensure PYENV_ROOT is respected; if the installer still used /root/.pyenv, move it.
RUN set -eux; \
    rm -rf "${PYENV_ROOT}"; \
    export PYENV_ROOT="${PYENV_ROOT}"; \
    curl -fsSL https://pyenv.run | bash; \
    if [ -d /root/.pyenv ] && [ ! -d "${PYENV_ROOT}/bin" ]; then \
      rm -rf "${PYENV_ROOT}"; \
      mv /root/.pyenv "${PYENV_ROOT}"; \
    fi; \
    test -x "${PYENV_ROOT}/bin/pyenv"; \
    "${PYENV_ROOT}/bin/pyenv" --version; \
    chmod -R a+rX "${PYENV_ROOT}"

# --- Python 2.7.18 (prebuilt at image build-time) ---
# BuildKit cache: python-build downloads land in $PYENV_ROOT/cache.
RUN --mount=type=cache,target=/opt/pyenv/cache,sharing=locked \
    set -eux; \
    "${PYENV_ROOT}/bin/pyenv" install -v "${PYTHON2_VERSION}"; \
    "${PYENV_ROOT}/bin/pyenv" global "${PYTHON2_VERSION}"; \
    "${PYENV_ROOT}/bin/pyenv" rehash; \
    ln -sf "${PYENV_ROOT}/versions/${PYTHON2_VERSION}/bin/python" /usr/local/bin/python2; \
    ln -sf "${PYENV_ROOT}/versions/${PYTHON2_VERSION}/bin/python" /usr/local/bin/python2.7; \
    echo "${PYENV_ROOT}/versions/${PYTHON2_VERSION}/lib" > /etc/ld.so.conf.d/pyenv-python2.conf; \
    ldconfig; \
    chmod -R a+rX "${PYENV_ROOT}"

# MongoDB install (skip on non-amd64)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    if [ "${TARGETARCH}" = "amd64" ]; then \
      curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
        | gpg -o /usr/share/keyrings/mongodb-server.gpg --dearmor; \
      echo "deb [ signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/debian ${MONGO_DEBIAN_CODENAME}/mongodb-org/7.0 main" \
        > /etc/apt/sources.list.d/mongodb-org.list; \
      apt-get update; \
      apt-get install -y --no-install-recommends mongodb-org; \
    else \
      echo "[build] Skipping mongodb-org install for TARGETARCH=${TARGETARCH}"; \
    fi

# Node.js 12 via nvm (system-wide)
RUN set -eux; \
    mkdir -p "${NVM_DIR}"; \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; \
    /bin/bash -lc ". \"${NVM_DIR}/nvm.sh\"; \
      nvm install \"${NODE_VERSION}\"; \
      nvm alias default \"${NODE_VERSION}\"; \
      nvm use --default; \
      node -v; \
      nvm install-latest-npm; \
      node_ver=\"\$(nvm version \"${NODE_VERSION}\")\"; \
      ln -sfn \"${NVM_DIR}/versions/node/\${node_ver}\" \"${NVM_DIR}/current\""; \
    chmod -R a+rX "${NVM_DIR}"

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

STOPSIGNAL SIGINT

COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
