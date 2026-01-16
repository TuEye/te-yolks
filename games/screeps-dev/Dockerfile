FROM  --platform=$TARGETOS/$TARGETARCH debian:bullseye-slim

LABEL author="TuEye"

## add container user
USER  root
RUN   useradd -m -d /home/container -s /bin/bash container

ENV   DEBIAN_FRONTEND=noninteractive
ENV   NPM_VERSION=8

# Base packages
RUN dpkg --add-architecture i386 \
    #&& echo "deb http://archive.debian.org/debian/ buster main contrib non-free" > /etc/apt/sources.list \
    #&& echo "deb http://archive.debian.org/debian/ buster-proposed-updates main contrib non-free" >> /etc/apt/sources.list \
    #&& echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list \
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
        redis-server \
    && rm -rf /var/lib/apt/lists/*
    
# MongoDB install
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc  \
    | gpg -o /usr/share/keyrings/mongodb-server.gpg --dearmor \
     && echo "deb [ signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/7.0 main" \
        > /etc/apt/sources.list.d/mongodb-org.list \
     && apt-get update \
     && apt-get install -y --no-install-recommends mongodb-org \
     && rm -rf /var/lib/apt/lists/*

# Node.js Install
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key \
    | gpg -o /usr/share/keyrings/nodesource.gpg --dearmor \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_12.x bullseye main" \
       > /etc/apt/sources.list.d/nodejs.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm -g install npm@$NPM_VERSION

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
