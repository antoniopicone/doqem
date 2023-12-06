FROM alpine:3.17.3

RUN apk update && apk add execline curl qemu-system-x86_64 python3 bash


COPY kernel/kernel512b /kernel
COPY build/rootfs-diff.qcow2 /rootfs-diff.qcow2
COPY build/rootfs.qcow2 /rootfs.qcow2
COPY build/run.sh /run.sh
RUN chmod +x /run.sh

# COPY thorfi/thorfi_client.py /usr/local/bin/
# COPY thorfi/thorfi /usr/local/bin/
# RUN chmod +x /usr/local/bin/thorfi

CMD ["/run.sh"]