FROM  --platform=$TARGETOS/$TARGETARCH debian:buster

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
            curl \
            jq \
            build-essential \
            make \
            libssl-dev \
            zlib1g-dev \
            libbz2-dev \
            libreadline-dev \
            libsqlite3-dev \
            git \
            libncursesw5-dev \
            xz-utils \
            tk-dev \
            libxml2-dev \
            libxmlsec1-dev \
            libffi-dev \
            liblzma-dev \
            tini
            
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

## Install Python
ENV PYENV_ROOT="/home/container/.pyenv"
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
RUN   curl -fsSL https://pyenv.run | bash \
      && pyenv install 2.7.18 \
      && pyenv global 2.7.18

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
