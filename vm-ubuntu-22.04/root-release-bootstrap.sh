#!/bin/bash

# Print commands and exit on errors
set -xe

export DEBIAN_FRONTEND=noninteractive

# Atom install steps came from this page on 2020-May-11:
# https://flight-manual.atom.io/getting-started/sections/installing-atom/#platform-linux

echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" | sudo tee /etc/apt/sources.list.d/atom.list
wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | apt-key add -

# Add repository with P4 packages
# https://build.opensuse.org/project/show/home:p4lang

echo "deb https://download.opensuse.org/repositories/home:/p4lang/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/home:p4lang.list
wget -qO - "https://download.opensuse.org/repositories/home:/p4lang/xUbuntu_22.04/Release.key" | apt-key add -

apt-get update -qq

apt-get -qq -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
apt-get install -qq -y --no-install-recommends --fix-missing\
  atom \
  ca-certificates \
  curl \
  emacs \
  git \
  iproute2 \
  lubuntu-desktop \
  net-tools \
  python3 \
  python3-pip \
  tcpdump \
  unzip \
  valgrind \
  vim \
  wget \
  xcscope-el \
  xterm \
  p4lang-p4c \
  p4lang-bmv2 \
  p4lang-pi

sudo pip3 install -U scapy ptf psutil grpcio
