#!/bin/bash

# SPDX-FileCopyrightText: 2021 Contributors to the P4 Project
#
# SPDX-License-Identifier: Apache-2.0

# Print commands and exit on errors
set -xe

export DEBIAN_FRONTEND=noninteractive

# Atom editor no longer installed, as it is no longer maintained by
# its developers, in favor of VSCode.
# https://github.blog/2022-06-08-sunsetting-atom/

# Add repository with P4 packages
# https://build.opensuse.org/project/show/home:p4lang

echo "deb https://download.opensuse.org/repositories/home:/p4lang/xUbuntu_20.04/ /" | sudo tee /etc/apt/sources.list.d/home:p4lang.list
wget -qO - "https://download.opensuse.org/repositories/home:/p4lang/xUbuntu_20.04/Release.key" | apt-key add -

apt-get update -qq

apt-get -qq -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
apt-get install -qq -y --no-install-recommends --fix-missing\
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

sudo pip3 install -U scapy==2.5.0 ptf psutil grpcio
