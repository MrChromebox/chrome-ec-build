# Ubuntu 16.04 (gcc-arm-none-eabi 4.9.3, host gcc 5.4)
FROM ubuntu:16.04

# Futility for CONFIG_RWSIG boards (e.g. fizz --full → ec.bin). Modern
# vboot_reference does not build on xenial; pin an R69-era tree that does.
ARG VBOOT_REF=release-R69-10895.B

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc make pkg-config \
    libftdi-dev libncurses5-dev libusb-1.0-0-dev \
    gcc-arm-none-eabi libnewlib-arm-none-eabi \
    libssl-dev libssl1.0.0 uuid-dev \
    python git ca-certificates \
    && ln -sf python2 /usr/bin/python \
    && git clone --depth 1 -b "$VBOOT_REF" \
         https://chromium.googlesource.com/chromiumos/platform/vboot_reference \
         /tmp/vboot_reference \
    && make -C /tmp/vboot_reference -j"$(nproc)" futil USE_FLASHROM=0 \
    && install -m 0755 /tmp/vboot_reference/build/futility/futility /usr/local/bin/futility \
    && rm -rf /tmp/vboot_reference \
    && apt-get purge -y --auto-remove libssl-dev uuid-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
