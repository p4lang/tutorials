#!/bin/bash

# Print commands and exit on errors
set -xe

# Atom install steps came from this page on 2020-May-11:
# https://flight-manual.atom.io/getting-started/sections/installing-atom/#platform-linux

wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | apt-key add -
sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'
# These commands are done later below
#apt-get update
#apt-get install atom

apt-get update

KERNEL=$(uname -r)
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
apt-get install -y --no-install-recommends --fix-missing\
  atom \
  autoconf \
  automake \
  bison \
  build-essential \
  ca-certificates \
  clang \
  cmake \
  cpp \
  curl \
  emacs \
  flex \
  g++ \
  git \
  iproute2 \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-graph-dev \
  libboost-iostreams-dev \
  libboost-program-options-dev \
  libboost-system-dev \
  libboost-test-dev \
  libboost-thread-dev \
  libelf-dev \
  libevent-dev \
  libffi-dev \
  libfl-dev \
  libgc-dev \
  libgflags-dev \
  libgmp-dev \
  libjudy-dev \
  libpcap-dev \
  libpython3-dev \
  libreadline-dev \
  libssl-dev \
  libtool \
  libtool-bin \
  linux-headers-$KERNEL\
  llvm \
  lubuntu-desktop \
  make \
  net-tools \
  pkg-config \
  python3 \
  python3-dev \
  python3-pip \
  python3-setuptools \
  tcpdump \
  unzip \
  valgrind \
  vim \
  wget \
  xcscope-el \
  xterm

# On a freshly installed Ubuntu 20.04.1 or 18.04.5 system, desktop
# amd64 minimal installation, the Debian package python3-protobuf is
# installed.  This is depended upon by another package called
# python3-macaroonbakery, which in turn is is depended upon by a
# package called gnome-online accounts.  I suspect this might have
# something to do with Ubuntu's desire to make it easy to connect with
# on-line accounts like Google accounts.

# This python3-protobuf package enables one to have a session like
# this with no error, on a freshly installed system:

# $ python3
# >>> import google.protobuf

# However, something about this script doing its work causes a
# conflict between the Python3 protobuf module installed by this
# script, and the one installed by the package python3-protobuf, such
# that the import statement above gives an error.  The package
# google.protobuf.internal is used by the p4lang/tutorials Python
# code, and the only way I know to make this work right now is to
# remove the Debian python3-protobuf package, and then install Python3
# protobuf support using pip3 as done below.

# Experiment starting from a freshly installed Ubuntu 20.04.1 Linux
# desktop amd64 system, minimal install:
# Initially, python3-protobuf package was installed.
# Doing python3 followed 'import' of any of these gave no error:
# + google
# + google.protobuf
# + google.protobuf.internal
# Then did 'sudo apt-get purge python3-protobuf'
# At that point, attempting to import any of the 3 modules above gave an error.
# Then did 'sudo apt-get install python3-pip'
# At that point, attempting to import any of the 3 modules above gave an error.
# Then did 'sudo pip3 install protobuf==3.6.1'
# At that point, attempting to import any of the 3 modules above gave NO error.

sudo apt-get purge -y python3-protobuf || echo "Failed to remove python3-protobuf, probably because there was no such package installed"
sudo pip3 install protobuf==3.18.1

# Starting in 2019-Nov, Python3 version of Scapy is needed for `cd
# p4c/build ; make check` to succeed.
# ply package is needed for ebpf and ubpf backend tests to pass
sudo pip3 install scapy ply

# Things needed for PTF
sudo pip3 install pypcap

# Things needed for `cd tutorials/exercises/basic ; make run` to work:
sudo pip3 install psutil crcmod
