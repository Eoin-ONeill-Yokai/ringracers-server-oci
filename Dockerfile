FROM alpine:latest

# Ref: https://github.com/STJr/Kart-Public/releases
ARG RINGRACERS_VERSION=2.4
ARG RINGRACERS_USER=ringracers
ENV RINGRACERS_DIRECTORY=/usr/share/games/RingRacers
ENV RINGRACERS_CONFIG_DIRECTORY=/home/${RINGRACERS_USER}/.ringracers
ENV RINGRACERS_MODS_DIRECTORY=${RINGRACERS_CONFIG_DIRECTORY}/addons
# Usually 5029, but we don't want overlap with SRB2Kart. Also, it should be within range of IANA's Dynamic / Private Port Ranges. 
ENV RINGRACERS_PORT_FWD=50291
ENV RINGRACERS_ENABLE_SSHD=0
ENV RINGRACERS_SSH_FWD=50293
ENV RINGRACERSWADDIR=${RINGRACERS_DIRECTORY}

ENV SERVER_NAME="^5Ring Racers ^4Docker ^6Image"
ENV SERVER_MOTD="As seen on GitHub and GitLab!"
ENV SERVER_CONTACT="Matrix Space: https://matrix.to/#/#galaxy-raceways:matrix.org"
ENV SERVER_ADVERTISE="No"

# https://github.com/KartKrewDev/RingRacers/releases/download/v2.4/Dr.Robotnik.s-Ring-Racers-v2.4-Assets.zip
# Ref: https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=ringracers-data
RUN set -ex \
    && apk add --no-cache --virtual .build-deps curl \
    && mkdir -p /ringracers-data \
    && curl -L -o /tmp/ringracers-v${RINGRACERS_VERSION//./}-Assets.zip https://github.com/KartKrewDev/RingRacers/releases/download/v${RINGRACERS_VERSION}/Dr.Robotnik.s-Ring-Racers-v${RINGRACERS_VERSION}-Assets.zip \
    && unzip -d /ringracers-data /tmp/ringracers-v${RINGRACERS_VERSION//./}-Assets.zip \
    && find /ringracers-data \
    && find /ringracers-data/models -type d -exec chmod 0755 {} \; \
    && mkdir -p /usr/share/games \
    && mv /ringracers-data $RINGRACERS_DIRECTORY \
    && apk del .build-deps

# Ref: https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=srb2kart
RUN set -ex \
    && apk add --no-cache --virtual .build-deps \
        bash \
        build-base \
        cmake \ 
        curl-dev \
        curl-static \
        gcc \
        git \
        gzip \
        libc-dev \
        libogg \
        libogg-dev \
        libpng-dev \
        libpng-static \
        libvorbis \
        libvorbis-dev \
        libvpx \ 
        libvpx-dev \
        libyuv-dev \
        libyuv-static \
        make \
        nghttp2-static \
        ninja \ 
        ninja-build \
        openssl-libs-static \
        opus \
        opus-dev \
        sdl2_mixer-dev \
        sdl2-dev \
        upx \
        zlib-dev \
        zlib-static \
    && git clone --depth=1 -b v${RINGRACERS_VERSION} https://github.com/KartKrewDev/RingRacers.git /src/ringracers \
    && (cd /src/ringracers \
        && mkdir -p ./build \
        && cd ./build \
        && cmake --preset ninja-release .. \
        && cd .. \
        && cmake --build --preset=ninja-release) \
    && find /src/ringracers -name ringracers_v${RINGRACERS_VERSION} \
    && cp /src/ringracers/build/ninja-release/bin/ringracers_v${RINGRACERS_VERSION} ${RINGRACERS_DIRECTORY}/ringracers_v${RINGRACERS_VERSION} \
    # Symlink to short-hand version number. Could be used to manage multiple versions..
    && ln -s ${RINGRACERS_DIRECTORY}/ringracers_v${RINGRACERS_VERSION} ${RINGRACERS_DIRECTORY}/ringracers \
    && apk del .build-deps \
    && rm -rf /src/ringracers

# Add RINGRACERS_DIRECTORY to path for easy reference...
ENV PATH="$PATH:${RINGRACERS_DIRECTORY}"

RUN apk add --no-cache \
        coreutils \
        shadow \
        bash \
        gettext

# Add script that auto-loads mods from specific `addons` folder, see RINGRACERS_MODS_DIRECTORY
COPY ./start-ringracers-server.sh /usr/bin/start-ringracers-server.sh
RUN set -ex \
    && chmod a+x /usr/bin/start-ringracers-server.sh

# Add a template for auto generating a default configuration based on environment variables..
RUN mkdir -p /etc/ringracers/
COPY ./ringserv.cfg.template /etc/ringracers/ringserv.cfg.template

RUN mkdir -p /data

RUN apk add --no-cache \
        curl-dev \
        curl-static \
        libogg \
        libogg-dev \
        libpng-dev \
        libpng-static \
        libvorbis \
        libvorbis-dev \
        libvpx \ 
        libvpx-dev \
        nginx \
        opus \
        opus-dev \
        sdl2 \
        sdl2_mixer-dev \
        sdl2-dev \
        zip

# User setup
RUN adduser -D -u 10001 -g 10001 ${RINGRACERS_USER} \
    && ln -s /data /home/${RINGRACERS_USER}/.ringracers \
    && chown -Rh ${RINGRACERS_USER} /home/${RINGRACERS_USER} \
    && chown -R ${RINGRACERS_USER} /data \
    && chown -R ${RINGRACERS_USER} ${RINGRACERS_DIRECTORY}


# Direct download location definition
COPY ./direct-download.conf.template /etc/nginx/http.d/direct-download.conf.template
RUN mkdir -p /var/www/html
RUN chown -R ${RINGRACERS_USER}:www-data /etc/nginx/http.d/direct-download.conf.template
RUN ln -s /data/addons /var/www/html/repo
RUN chown -h ${RINGRACERS_USER} /var/www/html/repo

# Disable nginx user and set up for use as non-root user
RUN mkdir -p /var/cache/nginx && chown -R ${RINGRACERS_USER} /var/cache/nginx && \
    mkdir -p /var/log/nginx && chown -R ${RINGRACERS_USER} /var/log/nginx && \
    mkdir -p /var/lib/nginx && chown -R ${RINGRACERS_USER} /var/lib/nginx && \
    mkdir -p /run/nginx && touch /run/nginx/nginx.pid && chown -R ${RINGRACERS_USER} /run/nginx/nginx.pid && \
    chown -R ${RINGRACERS_USER} /etc/nginx && \
    chmod -R 777 /etc/nginx/http.d

RUN sed -i 's/user nginx;/#user nginx;/g' /etc/nginx/nginx.conf

# Don't forget to remove the default nginx
RUN rm /etc/nginx/http.d/default.conf

## Install rcon-cli -- this should give access to rcon commands internally. 
RUN apk add --no-cache rcon-cli

##  Setup for sftp.. We will use this for easy key-only remote file access. See sftp for more details.
RUN apk add --no-cache openssh

# Create and add user to group sftp
RUN groupadd sftp && usermod -aG sftp ${RINGRACERS_USER}

# Configure group user sftp
RUN echo "Port ${RINGRACERS_SSH_FWD}" >> /etc/ssh/sshd_config  && \
    echo "HostKey ~/.ssh/private/ssh_host_rsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey ~/.ssh/private/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey ~/.ssh/private/ssh_host_ed25519_key" >> /etc/ssh/sshd_config && \
    echo "PidFile ~/sshd.pid" >> /etc/ssh/sshd_config && \
    echo "Match Group sftp" >> /etc/ssh/sshd_config && \
    echo "  X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "  AllowTcpForwarding no" >> /etc/ssh/sshd_config && \
# Cannot ChrootDirectory when running as user level. User level access should be ok though..
#     echo "  ChrootDirectory ${RINGRACERS_CONFIG_DIRECTORY}" >> /etc/ssh/sshd_config && \
# We actually might want non-sftp access as well... Maybe make this configurable?
#     echo "  ForceCommand internal-sftp" >> /etc/ssh/sshd_config && \
    echo "  PasswordAuthentication no" >> /etc/ssh/sshd_config

# Symlink and give permission to keys...
RUN ln -s /keys /home/${RINGRACERS_USER}/.ssh && \
    mkdir -p /keys && \
    chown -R ${RINGRACERS_USER} /keys

# User context switch
USER ${RINGRACERS_USER}
RUN mkdir -p ${RINGRACERS_MODS_DIRECTORY}
WORKDIR ${RINGRACERS_DIRECTORY}

ENV FASTDL_PORT=8421

# Port definition
EXPOSE $RINGRACERS_PORT_FWD/udp
EXPOSE $FASTDL_PORT/tcp
EXPOSE $RINGRACERS_PORT_FWD/tcp

STOPSIGNAL SIGINT
ENTRYPOINT ["start-ringracers-server.sh"]
CMD ["-dedicated"]
