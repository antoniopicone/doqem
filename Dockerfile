FROM docker:latest as docker

FROM debian:10 as dind_debian

ENV SUDO_GROUP=sudo DOCKER_GROUP=docker DOCKER_TLS_CERTDIR=/certs LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        sudo \
        python3 \
        ca-certificates \
        iptables \
        net-tools \
        openssl \
        pigz \
        xz-utils 
        
RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        libguestfs-tools \
        bash \
        build-essential \
        qemu-utils \
        linux-image-amd64 \
        bash \
        gcc \
        wget

RUN set -eux; \
    apt-get update; \
    apt-get install -y flex bison libelf-dev libssl-dev bc
      
RUN rm -rf /var/lib/apt/lists/*

RUN update-alternatives --set iptables /usr/sbin/iptables-legacy
RUN update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

RUN set -xe \
    && groupadd -r ${DOCKER_GROUP} \
    && sed -i "/^%${SUDO_GROUP}/s/ALL\$/NOPASSWD:ALL/g" /etc/sudoers

RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client

COPY --from=docker /usr/local/bin/ /usr/local/bin/
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
VOLUME /var/lib/docker

COPY vm/kernel /kernel
COPY vm/helpers/make_init.py /make_init.py
COPY vm/helpers/make_run_qemu.py /make_run_qemu.py
# COPY ./thorfi /thorfi 

COPY vm/build.sh /usr/local/bin/build
RUN chmod +x /usr/local/bin/build

COPY vm/doqem_container.Dockerfile /doqem_container.Dockerfile


CMD ["build"]

