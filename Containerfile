ARG BASE_IMAGE=ghcr.io/ublue-os/aurora
ARG BASE_TAG=latest

FROM ${BASE_IMAGE}:${BASE_TAG} AS builder

# Install kernel-devel matching the exact kernel pre-installed in the base image
RUN set -ouex pipefail && \
    KVER=$(ls /usr/lib/modules | head -n1) && \
    echo "Compiling driver for kernel ${KVER}" && \
    dnf install -y \
        kernel-devel-${KVER} \
        gcc \
        make \
        git \
        python3 \
        elfutils-libelf-devel && \
    git clone https://github.com/armin-haghi/imac-cs8409-linux-audio.git /tmp/cs8409 && \
    cd /tmp/cs8409 && \
    make KVER=${KVER} && \
    mkdir -p /build-out && \
    cp snd-hda-codec-cs8409.ko /build-out/

FROM ${BASE_IMAGE}:${BASE_TAG}

# Copy compiled module and system configs
COPY --from=builder /build-out/snd-hda-codec-cs8409.ko /tmp/snd-hda-codec-cs8409.ko
COPY system_files/ /

# Place module in updates/ (takes precedence over stock in-tree driver) and update dependencies
RUN set -ouex pipefail && \
    KVER=$(ls /usr/lib/modules | head -n1) && \
    mkdir -p /usr/lib/modules/${KVER}/updates/ && \
    zstd -f /tmp/snd-hda-codec-cs8409.ko -o /usr/lib/modules/${KVER}/updates/snd-hda-codec-cs8409.ko.zst && \
    rm -f /tmp/snd-hda-codec-cs8409.ko && \
    depmod -a ${KVER} && \
    bootc container lint
