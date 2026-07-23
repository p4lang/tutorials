#!/bin/bash

# SPDX-FileCopyrightText: 2026 An Nguyen
#
# SPDX-License-Identifier: Apache-2.0

# Run PTF tests for the basic tunnel exercise.
# Tests run against the solution P4 program.

set -e
BINDIR=$(realpath ../../bin)

sudo "${BINDIR}"/veth_setup.sh

set -x

# ---- compile ----
mkdir -p build logs
p4c --target bmv2 \
    --arch v1model \
    --p4runtime-files build/basic_tunnel.p4info.txtpb \
    -o build \
    solution/basic_tunnel.p4

/bin/rm -f ss-log.txt

# ---- start switch ----
sudo simple_switch_grpc \
     --log-file ss-log \
     --log-flush \
     --dump-packet-data 10000 \
     -i 0@veth0 \
     -i 1@veth2 \
     -i 2@veth4 \
     -i 3@veth6 \
     -i 4@veth8 \
     -i 5@veth10 \
     -i 6@veth12 \
     -i 7@veth14 \
     --no-p4 &

echo ""
echo "Started simple_switch_grpc. Waiting 2 seconds before starting PTF test..."
sleep 2

# ---- run tests ----
sudo ${P4_EXTRA_SUDO_OPTS} `which ptf` \
    -i 0@veth1 \
    -i 1@veth3 \
    -i 2@veth5 \
    -i 3@veth7 \
    -i 4@veth9 \
    -i 5@veth11 \
    -i 6@veth13 \
    -i 7@veth15 \
    --test-params="grpcaddr='localhost:9559';p4info='build/basic_tunnel.p4info.txtpb';config='build/basic_tunnel.json'" \
    --test-dir ptf

echo ""
echo "PTF test finished. Waiting 2 seconds before killing simple_switch_grpc..."
sleep 2

# ---- cleanup ----
sudo pkill --signal 9 --list-name simple_switch


echo ""
echo "Cleaning up veth interfaces..."
sudo "${BINDIR}"/veth_teardown.sh

echo ""
echo "Verifying no simple_switch_grpc processes remain..."
sleep 2
ps axguwww | grep simple_switch
