# Ubuntu 16.04 (gcc-arm-none-eabi 4.9.3, host gcc 5.4)
FROM ubuntu:16.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc make pkg-config \
    libftdi-dev libncurses5-dev libusb-1.0-0-dev \
    gcc-arm-none-eabi libnewlib-arm-none-eabi \
    python git ca-certificates \
    && ln -sf python2 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
