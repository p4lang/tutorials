#!/bin/bash
# Run PTF tests for the basic forwarding exercise.
# Tests run against the solution P4 program.

# Path to p4runtime_shell_utils and testlib
T="`realpath ~/p4-guide/testlib`"
if [ x"${PYTHONPATH}" == "x" ]
then
    P="${T}"
else
    P="${T}:${PYTHONPATH}"
fi

set -x

# Compile the solution P4 program into build directory
mkdir -p build
p4c --target bmv2 \
    --arch v1model \
    --p4runtime-files build/basic.p4info.txtpb \
    -o build \
    solution/basic.p4

/bin/rm -f ss-log.txt

# Start simple_switch_grpc with no P4 program loaded (loaded via P4Runtime)
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
echo "Started simple_switch_grpc.  Waiting 2 seconds before starting PTF test ..."
sleep 2

# Run PTF tests
sudo ${P4_EXTRA_SUDO_OPTS} `which ptf` \
    --pypath "$P" \
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
echo "PTF test finished.  Waiting 2 seconds before killing simple_switch_grpc ..."
sleep 2
sudo pkill --signal 9 --list-name simple_switch
echo ""
echo "Verifying that there are no simple_switch_grpc processes running any longer in 4 seconds ..."
sleep 4
ps axguwww | grep simple_switch
