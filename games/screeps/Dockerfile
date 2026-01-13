FROM  --platform=$TARGETOS/$TARGETARCH node:12-buster-slim

LABEL author="TuEye"

## add container user
USER  root
RUN   useradd -m -d /home/container -s /bin/bash container

ENV   DEBIAN_FRONTEND=noninteractive

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
        python \
        redis-server \
    && rm -rf /var/lib/apt/lists/*

# MongoDB 6.0 repo + install (Debian 10 / Buster)
# Quelle der Repo-Zeile: MongoDB Doku v6.0 "Install on Debian" (Buster). 
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
      curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor \
      && echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] http://repo.mongodb.org/apt/debian buster/mongodb-org/6.0 main" > /etc/apt/sources.list.d/mongodb-org-6.0.list \
      && apt-get update \
      && apt-get install -y --no-install-recommends mongodb-org \
      && rm -rf /var/lib/apt/lists/* ; \
    else \
      echo "WARNING: Skipping MongoDB install because TARGETARCH=${TARGETARCH}. Use external MongoDB for this architecture." >&2 ; \
    fi

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
