FROM  --platform=$TARGETOS/$TARGETARCH node:12-buster-slim

LABEL author="TuEye"

## add container user
USER  root
RUN   useradd -m -d /home/container -s /bin/bash container

ENV   DEBIAN_FRONTEND=noninteractive
ENV   PYTHON_VERSION=2.7.18
ENV   NPM_VERSION=8

# Base packages
RUN dpkg --add-architecture i386 \
    && echo "deb http://archive.debian.org/debian/ buster main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian/ buster-proposed-updates main contrib non-free" >> /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
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
        build-essential \
        libtool \
        iputils-ping \
        libnss3 \
        tini \
        #python \
        make \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev \
        libssl-dev \
        redis-server \
    && rm -rf /var/lib/apt/lists/*
    
# MongoDB 4.4 repo + install (Debian 10 / Buster)
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc \
    | gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor \
     && echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" \
        > /etc/apt/sources.list.d/mongodb-org-4.4.list \
     && apt-get update \
     && apt-get install -y --no-install-recommends mongodb-org \
     && rm -rf /var/lib/apt/lists/*

# Install Python with pyenv
ENV PYENV_ROOT=/opt/.pyenv
ENV PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH

RUN set -ex \
    && curl -fsSL https://pyenv.run | bash \
    && pyenv update \
    && pyenv install $PYTHON_VERSION \
    && pyenv global $PYTHON_VERSION \
    && pyenv rehash

# NPM Update
RUN npm -g install npm@$NPM_VERSION

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
