#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

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

# Print commands and exit on errors
set -xe

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y upgrade
apt-get install -y \
  git \
  ubuntu-desktop-minimal

# These are probably installed by install-p4dev-v8.sh script, probably
# because they are a dependency of something else that script does
# explicitly install.

#KERNEL=$(uname -r)
#  linux-headers-$KERNEL \
#  libboost-filesystem-dev \
#  libboost-program-options-dev \
#  libboost-test-dev \
#  libevent-dev \
#  libffi-dev \
#  libjudy-dev \
#  libpython3-dev \
#  python3-dev \
#  python3-setuptools \

# Add user account named 'p4'
useradd -m -d /home/p4 -s /bin/bash p4
echo "p4:p4" | chpasswd
echo "p4 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99_p4
chmod 440 /etc/sudoers.d/99_p4
usermod -aG vboxsf p4

# Note that a system installed starting similar to Ubuntu Server, and
# then the package ubuntu-desktop-minimal is installed, might end up
# with two different system services running on it, which can
# significantly increase the boot time, e.g. by 2 minutes.

# + https://askubuntu.com/questions/1217252/boot-process-hangs-at-systemd-networkd-wait-online/1501504#1501504

sudo systemctl disable systemd-networkd.service

# Do this last!
sudo reboot
