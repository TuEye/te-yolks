FROM  --platform=$TARGETOS/$TARGETARCH node:12-buster-slim

LABEL author="TuEye"

## add container user
USER  root
RUN   useradd -m -d /home/container -s /bin/bash container

ENV   DEBIAN_FRONTEND=noninteractive

RUN			dpkg --add-architecture i386 \
        && echo "deb http://archive.debian.org/debian/ buster main contrib non-free" > /etc/apt/sources.list \
        && echo "deb http://archive.debian.org/debian/ buster-proposed-updates main contrib non-free" >> /etc/apt/sources.list \
        && echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list \
        && apt-get update \
        && apt-get upgrade -y \
        && apt install -y \
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
            build-essential \
            libtool \
            iputils-ping \
            libnss3 \
            tini

RUN         npm install --global npm@latest typescript ts-node @types/node

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
