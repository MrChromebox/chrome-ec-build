# Ubuntu 20.04 (gcc-arm-none-eabi 9.x).
FROM ubuntu:20.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc make git ca-certificates pkg-config \
    libftdi1-dev libusb-1.0-0-dev \
    gcc-arm-none-eabi libnewlib-arm-none-eabi \
    vboot-kernel-utils \
    python2 \
    && ln -sf python2 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
