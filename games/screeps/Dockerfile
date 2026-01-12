FROM  --platform=$TARGETOS/$TARGETARCH screepers/screeps-launcher

LABEL author="TuEye"

ENV   DEBIAN_FRONTEND=noninteractive

## add container user
USER  root
RUN   useradd -m -d /home/container -s /bin/bash container

RUN         dpkg --add-architecture i386 \
            && apt update \
            && apt upgrade -y \
            && apt install -y ca-certificates tini

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
