# Zephyr EC build environment.
#
# Mirrors FrameworkComputer/EmbeddedController/container/Dockerfile:
# Debian bookworm, Zephyr SDK 0.16.9 (ARM only), and the u-boot binman
# revision that packs RO/RW images.
#
# Expected bind mounts (see build-zephyr.sh):
#   /work/src/platform/ec               <- chrome-ec checkout
#   /work/src/third_party/zephyr/main   <- chromiumos/third_party/zephyr
#   /work/src/third_party/zephyr/cmsis  <- chromiumos/third_party/zephyr/cmsis
FROM debian:bookworm-slim

ARG ZEPHYR_SDK_VERSION=0.16.9
ARG ZEPHYR_SDK_MINIMAL_SHA256=b433f19b334cd15f4d7696a958dda214a7737cf41432900d076adce4253782a5
ARG ZEPHYR_SDK_ARM_SHA256=81162a8326e3cb82fcc53f20528aa7abec29a0bf8376fa009e0c887ba864aaf8
ARG UBOOT_REV=923f25080339770806369e41767f8d0464f2b451

RUN apt-get update && apt-get install -y --no-install-recommends \
        binutils \
        ca-certificates \
        cmake \
        curl \
        device-tree-compiler \
        file \
        gcc \
        git \
        libc6-dev \
        make \
        ninja-build \
        python3 \
        python3-colorama \
        python3-dateutil \
        python3-docopt \
        python3-libfdt \
        python3-packaging \
        python3-pyelftools \
        python3-pykwalify \
        python3-ruamel.yaml \
        python3-setuptools \
        python3-yaml \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}

RUN set -eux; \
    base="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}"; \
    cd /tmp; \
    curl -fsSLo sdk.tar.xz "${base}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64_minimal.tar.xz"; \
    curl -fsSLo arm.tar.xz "${base}/toolchain_linux-x86_64_arm-zephyr-eabi.tar.xz"; \
    echo "${ZEPHYR_SDK_MINIMAL_SHA256}  sdk.tar.xz" | sha256sum -c -; \
    echo "${ZEPHYR_SDK_ARM_SHA256}  arm.tar.xz" | sha256sum -c -; \
    tar -xf sdk.tar.xz -C /opt; \
    tar -xf arm.tar.xz -C "${ZEPHYR_SDK_INSTALL_DIR}"; \
    rm -f sdk.tar.xz arm.tar.xz

# binman (plus dtoc/u_boot_pylib it imports). binman's main.py resolves its
# siblings via realpath, so a symlink on PATH is enough.
RUN set -eux; \
    mkdir -p /opt/u-boot/tools; \
    curl -fsSL "https://chromium.googlesource.com/chromiumos/third_party/u-boot/+archive/${UBOOT_REV}/tools.tar.gz" \
        | tar -xz -C /opt/u-boot/tools; \
    ln -s /opt/u-boot/tools/binman/binman /usr/local/bin/binman

COPY zmake-wrapper.sh /usr/local/bin/zmake

# zmake locates the checkout by looking for a .repo directory. Setting
# COREBOOT_SDK_ROOT stops zmake from trying to download the coreboot SDK.
RUN mkdir -p /work/.repo /work/src/platform/ec /work/src/third_party/zephyr \
    && mkdir -m 1777 /home/builder \
    && git config --system --add safe.directory '*'

ENV CROS_WORKON_SRCROOT=/work \
    COREBOOT_SDK_ROOT=/nonexistent \
    HOME=/home/builder

WORKDIR /work/src/platform/ec
CMD ["bash"]
