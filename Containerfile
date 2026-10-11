ARG BASE_IMAGE=ghcr.io/ublue-os/aurora
ARG BASE_TAG=latest
ARG DRIVER_COMMIT=b08d0745e1b78d6949d5a231d91351e73ddf8079

FROM ${BASE_IMAGE}:${BASE_TAG} AS builder
ARG DRIVER_COMMIT

# Install kernel-devel matching the exact kernel pre-installed in the base image, plus pahole for ABI check
RUN set -ouex pipefail && \
    KVER=$(ls /usr/lib/modules | head -n1) && \
    echo "Compiling driver for kernel ${KVER}" && \
    dnf install -y \
        kernel-devel-${KVER} \
        gcc \
        make \
        git \
        python3 \
        dwarves \
        binutils \
        elfutils-libelf-devel && \
    git clone https://github.com/armin-haghi/imac-cs8409-linux-audio.git /tmp/cs8409 && \
    cd /tmp/cs8409 && \
    git checkout "${DRIVER_COMMIT}" && \
    make KVER=${KVER} && \
    # Gate 1: Run ABI layout verification against target kernel
    mkdir -p /boot && \
    [ -f /usr/lib/modules/${KVER}/vmlinuz ] && ln -sf /usr/lib/modules/${KVER}/vmlinuz /boot/vmlinuz-${KVER} || true && \
    python3 verify-abi.py --kver ${KVER} && \
    mkdir -p /build-out && \
    cp snd-hda-codec-cs8409.ko /build-out/

FROM ${BASE_IMAGE}:${BASE_TAG}

# Copy compiled module and system configs
COPY --from=builder /build-out/snd-hda-codec-cs8409.ko /tmp/snd-hda-codec-cs8409.ko
COPY system_files/ /

# Place module in updates/ (takes precedence over stock in-tree driver) and run validation gates
RUN set -ouex pipefail && \
    KVER=$(ls /usr/lib/modules | head -n1) && \
    mkdir -p /usr/lib/modules/${KVER}/updates/ && \
    zstd -f /tmp/snd-hda-codec-cs8409.ko -o /usr/lib/modules/${KVER}/updates/snd-hda-codec-cs8409.ko.zst && \
    rm -f /tmp/snd-hda-codec-cs8409.ko && \
    # Gate 2: Symbol resolution check (depmod -e reports any unresolved symbols)
    depmod -e -a ${KVER} && \
    # Gate 3: Vermagic check
    modinfo -F vermagic /usr/lib/modules/${KVER}/updates/snd-hda-codec-cs8409.ko.zst | grep -q "${KVER}" && \
    # Gate 4: Module precedence check (must resolve to updates/, not kernel/)
    test "$(modinfo -b / -k ${KVER} -n snd-hda-codec-cs8409 | grep -o 'updates/')" = "updates/" && \
    # Gate 5: Modprobe configuration check
    grep -q "dsp_driver=1" /usr/lib/modprobe.d/cs8409.conf && \
    # Gate 6: Cosign public key presence check
    test -f /etc/pki/containers/aurora-imac.pub && \
    # Gate 7: Bootc container structural linting
    bootc container lint
