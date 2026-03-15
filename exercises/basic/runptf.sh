#!/bin/bash
# Run PTF tests for the basic forwarding exercise.
# Tests run against the solution P4 program.

set -e

# ---- veth setup ----
echo "Creating veth interfaces..."
for i in 0 1 2 3 4 5 6 7; do
    intf0="veth$(( i * 2 ))"
    intf1="veth$(( i * 2 + 1 ))"
    if ! ip link show $intf0 &>/dev/null; then
        sudo ip link add name $intf0 type veth peer name $intf1
        sudo ip link set dev $intf0 up
        sudo ip link set dev $intf1 up
        sudo sysctl -q net.ipv6.conf.$intf0.disable_ipv6=1
        sudo sysctl -q net.ipv6.conf.$intf1.disable_ipv6=1
    fi
done

set -x

# ---- compile ----
mkdir -p build
p4c --target bmv2 \
    --arch v1model \
    --p4runtime-files build/basic.p4info.txtpb \
    -o build \
    solution/basic.p4

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
    --test-params="grpcaddr='localhost:9559';p4info='build/basic.p4info.txtpb';config='build/basic.json'" \
    --test-dir ptf

echo ""
echo "PTF test finished. Waiting 2 seconds before killing simple_switch_grpc..."
sleep 2

# ---- cleanup ----
sudo pkill --signal 9 --list-name simple_switch

echo ""
echo "Cleaning up veth interfaces..."
for i in 0 1 2 3 4 5 6 7; do
    intf0="veth$(( i * 2 ))"
    if ip link show $intf0 &>/dev/null; then
        sudo ip link del $intf0
    fi
done

echo ""
echo "Verifying no simple_switch_grpc processes remain..."
sleep 2
ps axguwww | grep simple_switch
