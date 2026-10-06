#! /bin/bash

# SPDX-FileCopyrightText: 2024 Andy Fingerhut
# Copyright 2024 Andy Fingerhut
#
# SPDX-License-Identifier: Apache-2.0

# Various packages that are useful when running exercises
# in the p4lang/tutorials repo.

sudo apt-get install -y \
  ca-certificates \
  iproute2 \
  libpcap-dev \
  tcpdump \
  wget \
  xterm \
  xcscope-el

# Install Wireshark and tshark on Ubuntu system without having to
# answer _any_ questions interactively, except perhaps providing your
# password when prompted by 'sudo'.

# https://askubuntu.com/questions/1275842/install-wireshark-without-confirm

echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install wireshark tshark
