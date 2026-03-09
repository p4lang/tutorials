FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG BEHAVIORAL_MODEL_VERSION=main
ARG PI_VERSION=main
ARG P4C_VERSION=main

# Step 1: Install all build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake bison build-essential clang cmake curl flex g++ git \
    libboost-dev libboost-filesystem-dev libboost-graph-dev \
    libboost-iostreams-dev libboost-program-options-dev libboost-system-dev \
    libboost-test-dev libboost-thread-dev libbz2-dev libevent-dev libffi-dev \
    libfl-dev libgc-dev libgflags-dev libgmp-dev libgrpc++-dev libgrpc-dev \
    libelf-dev liblzma-dev libpcap-dev libprotobuf-dev libreadline-dev \
    libssl-dev libtool libtool-bin llvm make net-tools patchelf pkg-config \
    protobuf-compiler protobuf-compiler-grpc python3-dev python3-pip \
    python3-venv tcpdump unzip valgrind wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Step 2: Build Thrift 0.16.0
RUN git clone --depth 1 --branch v0.16.0 https://github.com/apache/thrift.git thrift-0.16.0 \
    && cd thrift-0.16.0 \
    && ./bootstrap.sh \
    && ./configure --with-cpp --with-python --without-java --without-ruby \
       --without-nodejs --without-go --without-erlang --without-lua \
       --without-php --without-swift --without-rs --without-dotnetcore \
       --without-haskell --without-perl --without-c_glib --without-d \
       --without-qt5 \
    && make -j$(nproc) \
    && make install \
    && cd /build && rm -rf thrift-0.16.0

# Step 3: Build nanomsg 1.0.0
RUN git clone --depth 1 --branch 1.0.0 https://github.com/nanomsg/nanomsg.git nanomsg-1.0.0 \
    && cd nanomsg-1.0.0 \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
    && make -j$(nproc) \
    && make install \
    && cd /build && rm -rf nanomsg-1.0.0

RUN ldconfig

# Step 5: Build PI
RUN git clone https://github.com/p4lang/PI.git \
    && cd PI \
    && if [ "$PI_VERSION" != "main" ]; then git checkout $PI_VERSION; fi \
    && git submodule update --init --recursive \
    && ./autogen.sh \
    && ./configure --with-proto --without-internal-rpc --without-cli --without-bmv2 \
    && make -j$(nproc) \
    && make install \
    && cd /build && rm -rf PI

RUN ldconfig

# Step 6: Build behavioral-model
# Patches are from vm-ubuntu-24.04/patches/ in the tutorials repo.
# Build context must be set to the tutorials/ root:
#   docker build -f bindist/Dockerfile -t p4-bindist .
COPY vm-ubuntu-24.04/patches/behavioral-model-support-fedora.patch /build/patches/
COPY vm-ubuntu-24.04/patches/behavioral-model-support-venv.patch /build/patches/
RUN git clone https://github.com/p4lang/behavioral-model.git \
    && cd behavioral-model \
    && if [ "$BEHAVIORAL_MODEL_VERSION" != "main" ]; then git checkout $BEHAVIORAL_MODEL_VERSION; fi \
    && git submodule update --init --recursive \
    && patch -p1 < /build/patches/behavioral-model-support-fedora.patch \
    && patch -p1 < /build/patches/behavioral-model-support-venv.patch \
    && ./autogen.sh \
    && ./configure --with-pi --with-thrift --enable-debugger \
    && make -j$(nproc) \
    && make install-strip \
    && cd /build && rm -rf behavioral-model

RUN ldconfig

# Step 7: Build p4c with static linking
RUN git clone --recurse-submodules https://github.com/p4lang/p4c.git \
    && cd p4c \
    && if [ "$P4C_VERSION" != "main" ]; then git checkout $P4C_VERSION && git submodule update --init --recursive; fi \
    && mkdir build && cd build \
    && cmake .. \
       -DCMAKE_BUILD_TYPE=Release \
       -DSTATIC_BUILD_WITH_DYNAMIC_GLIBC=ON \
       -DENABLE_TEST_TOOLS=OFF \
       -DCMAKE_INSTALL_PREFIX=/usr/local \
    && make -j$(nproc) \
    && make install \
    && cd /build && rm -rf p4c

# Step 8: Collect artifacts into bindist
RUN mkdir -p /build/bindist/p4-bindist-ubuntu2404-x86_64/{bin,lib,share}

# Copy p4c binaries
RUN for bin in p4c p4c-bm2-ss p4c-bm2-psa p4c-bm2-pna p4c-dpdk p4c-ebpf \
               p4c-ubpf p4c-pna-p4tc p4c-graphs p4test; do \
        cp /usr/local/bin/$bin /build/bindist/p4-bindist-ubuntu2404-x86_64/bin/ 2>/dev/null || true; \
    done

# Copy behavioral-model binaries
RUN cp /usr/local/bin/simple_switch /build/bindist/p4-bindist-ubuntu2404-x86_64/bin/ \
    && cp /usr/local/bin/simple_switch_grpc /build/bindist/p4-bindist-ubuntu2404-x86_64/bin/ \
    && cp /usr/local/bin/simple_switch_CLI /build/bindist/p4-bindist-ubuntu2404-x86_64/bin/

# Copy bundled shared libraries (not available via apt on Ubuntu 24.04)
RUN cp -a /usr/local/lib/libthrift*.so* /build/bindist/p4-bindist-ubuntu2404-x86_64/lib/ \
    && cp -a /usr/local/lib/libnanomsg*.so* /build/bindist/p4-bindist-ubuntu2404-x86_64/lib/ \
    && cp -a /usr/local/lib/libpi*.so* /build/bindist/p4-bindist-ubuntu2404-x86_64/lib/ \
    && cp -a /usr/local/lib/libbm*.so* /build/bindist/p4-bindist-ubuntu2404-x86_64/lib/ \
    && cp -a /usr/local/lib/libsimpleswitch*.so* /build/bindist/p4-bindist-ubuntu2404-x86_64/lib/ \
    && cp -a /usr/local/lib/libruntimestubs*.so* /build/bindist/p4-bindist-ubuntu2404-x86_64/lib/

# Copy p4c share files
RUN cp -r /usr/local/share/p4c /build/bindist/p4-bindist-ubuntu2404-x86_64/share/

# Fix RPATHs on behavioral-model binaries
RUN for bin in simple_switch simple_switch_grpc; do \
        patchelf --set-rpath '$ORIGIN/../lib' /build/bindist/p4-bindist-ubuntu2404-x86_64/bin/$bin; \
    done

# Copy install script
COPY bindist/install.sh /build/bindist/p4-bindist-ubuntu2404-x86_64/install.sh
RUN chmod +x /build/bindist/p4-bindist-ubuntu2404-x86_64/install.sh

# Create the tarball
RUN cd /build/bindist \
    && tar czf p4-bindist-ubuntu2404-x86_64.tar.gz p4-bindist-ubuntu2404-x86_64/

# Final stage: just the tarball
FROM scratch
COPY --from=builder /build/bindist/p4-bindist-ubuntu2404-x86_64.tar.gz /
