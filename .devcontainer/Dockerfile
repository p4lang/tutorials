FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

# Install basic tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    gnupg \
    python-is-python3 \
    python3 \
    python3-pip \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install P4 packages
# https://github.com/p4lang/p4c#ubuntu
# https://build.opensuse.org/project/show/home:p4lang
ARG VERSION_ID=20.04
RUN echo "deb http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/home:p4lang.list
RUN curl -L "http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/Release.key" | apt-key add -
RUN apt-get update && apt-get install -y --no-install-recommends \
    p4lang-pi \
    p4lang-bmv2 \
    p4lang-p4c \
    && rm -rf /var/lib/apt/lists/*

# Install Mininet
# https://github.com/mininet/mininet/blob/master/INSTALL
WORKDIR /home
RUN git clone https://github.com/mininet/mininet.git \
    && cd mininet \
    && git checkout master
RUN apt-get update \
    && PYTHON=python3 mininet/util/install.sh -n \
    && rm -rf /var/lib/apt/lists/*

# Upgrade grpcio to fix an issue similar to this:
# https://github.com/ray-project/ray/issues/22518
RUN pip3 install --upgrade grpcio

# Install other tools required to run exercises
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install \
    psutil
