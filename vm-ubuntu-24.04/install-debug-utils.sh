#! /bin/bash

# Copyright 2024 Andy Fingerhut

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
