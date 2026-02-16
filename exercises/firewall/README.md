
[comment]: # (SPDX-License-Identifier:  Apache-2.0)

# Implementing A Basic Stateful Firewall

## Introduction

The objective of this exercise is to write a P4 program that
implements a simple stateful firewall. To do this, we will use
a bloom filter. This exercise builds upon the basic exercise
so be sure to complete that one before trying this one.

We will use the pod-topology for this exercise, which consists of
four hosts connected to four switches, which are wired up as they
would be in a single pod of a fat tree topology.

![topology](./firewall-topo.png)

Switch s1 will be configured with a P4 program that implements a
simple stateful firewall (`firewall.p4`), the rest of the switches will run the
basic IPv4 router program (`basic.p4`) from the previous exercise.

The firewall on s1 should have the following functionality:
* Hosts h1 and h2 are on the internal network and can always
  connect to one another.
* Hosts h1 and h2 can freely connect to h3 and h4 on the
  external network.
* Hosts h3 and h4 can only reply to connections once they have been
  established from either h1 or h2, but cannot initiate new
  connections to hosts on the internal network.

**Note**: This stateful firewall is implemented 100% in the dataplane
using a simple bloom filter. Thus there is some probability of
hash collisions that would let unwanted flows to pass through.

Our P4 program will be written for the V1Model architecture implemented
on P4.org's bmv2 software switch. The architecture file for the V1Model
can be found at: /usr/local/share/p4c/p4include/v1model.p4. This file
desribes the interfaces of the P4 programmable elements in the architecture,
the supported externs, as well as the architecture's standard metadata
fields. We encourage you to take a look at it.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the
> reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`firewall.p4`. Your job will be to extend this skeleton program to
properly implement the firewall.

Before that, let's compile the incomplete `firewall.p4` and bring
up a switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make run
   ```
   This will:
   * compile `firewall.p4`, and
   * start the pod-topo in Mininet and configure all switches with
   the appropriate P4 program + table entries, and
   * configure all hosts with the commands listed in
   [pod-topo/topology.json](./pod-topo/topology.json)

2. You should now see a Mininet command prompt. Try to run some iperf
   TCP flows between the hosts. TCP flows within the internal
   network should work:
   ```bash
   mininet> iperf h1 h2
   ```

   TCP flows from hosts in the internal network to the outside hosts
   should also work:
   ```bash
   mininet> iperf h1 h3
   ```

   TCP flows from the outside hosts to hosts inside the
   internal network should NOT work. However, since the firewall is not
   implemented yet, the following should work:
   ```bash
   mininet> iperf h3 h1
   ```

3. Type `exit` to leave the Mininet command line.
   Then, to stop mininet:
   ```bash
   make stop
   ```
   And to delete all pcaps, build files, and logs:
   ```bash
   make clean
   ```

### A note about the control plane

A P4 program defines a packet-processing pipeline, but the rules
within each table are inserted by the control plane. When a rule
matches a packet, its action is invoked with parameters supplied by
the control plane as part of the rule.

In this exercise, we have already implemented the the control plane
logic for you. As part of bringing up the Mininet instance, the
`make` command will install packet-processing rules in the tables of
each switch. These are defined in the `sX-runtime.json` files, where
`X` corresponds to the switch number.

**Important:** We use P4Runtime to install the control plane rules. The
content of files `sX-runtime.json` refer to specific names of tables, keys, and
actions, as defined in the P4Info file produced by the compiler (look for the
file `build/firewall.p4.p4info.txtpb` after executing `make run`). Any changes in the P4
program that add or rename tables, keys, or actions will need to be reflected in
these `sX-runtime.json` files.

## Step 2: Implement Firewall

The `firewall.p4` file contains a skeleton P4 program with key pieces of
logic replaced by `TODO` comments. Your implementation should follow
the structure given in this file --- replace each `TODO` with logic
implementing the missing piece.

**High-level Approach:** We will use a bloom filter with two hash functions
to check if a packet coming into the internal network is a part of
an already established TCP connection. We will use two different register
arrays for the bloom filter, each to be updated by a hash function.
Using different register arrays makes our design amenable to high-speed
P4 targets that typically allow only one access to a register array per packet.

A complete `firewall.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`), IPv4 (`ipv4_t`) and TCP (`tcp_t`).
2. Parsers for Ethernet, IPv4 and TCP that populate `ethernet_t`, `ipv4_t` and `tcp_t` fields.
3. An action to drop a packet, using `mark_to_drop()`.
4. An action (called `compute_hashes`) to compute the bloom filter's two hashes using hash
algorithms `crc16` and `crc32`. The hashes will be computed on the packet 5-tuple consisting
of IPv4 source and  destination addresses, source and destination port numbers and
the IPv4 protocol type.
5. An action (`ipv4_forward`) and a table (`ipv4_lpm`) that will perform basic
IPv4 forwarding (adopted from `basic.p4`).
6. An action (called `set_direction`) that will simply set a one-bit direction variable
as per the action's parameter.
7. A table (called `check_ports`) that will read the ingress and egress port of a packet
(after IPv4 forwarding) and invoke `set_direction`. The direction will be set to `1`,
if the packet is incoming into the internal network. Otherwise, the direction will be set to `0`.
To achieve this, the file `pod-topo/s1-runtime.json` contains the appropriate control plane
entries for the `check_ports` table.
8. A control that will:
    1. First apply the table `ipv4_lpm` if the packet has a valid IPv4 header.
    2. Then if the TCP header is valid, apply the `check_ports` table to determine the direction.
    3. Apply the `compute_hashes` action to compute the two hash values which are the bit positions
    in the two register arrays of the bloom filter (`reg_pos_one` and `reg_pos_two`).
    When the direction is `1` i.e. the packet is incoming into the internal network,
    `compute_hashes` will be invoked by swapping the source and destination IPv4 addresses
    and the source and destination ports. This is to check against bloom filter's set bits
    when the TCP connection was initially made from the internal network.
    4. **TODO:** If the TCP packet is going out of the internal network and is a SYN packet,
    set both the bloom filter arrays at the computed bit positions (`reg_pos_one` and `reg_pos_two`).
    Else, if the TCP packet is entering the internal network,
    read both the bloom filter arrays at the computed bit positions and drop the packet if
    either is not set.
9. A deparser that emits the Ethernet, IPv4 and TCP headers in the right order.
10. A `package` instantiation supplied with the parser, control, and deparser.
    > In general, a package also requires instances of checksum verification
    > and recomputation controls. These are not necessary for this tutorial
    > and are replaced with instantiations of empty controls.


## Step 3: Run your solution

Follow the instructions from Step 1. This time, the `iperf` flow between
h3 and h1 should be blocked by the firewall.

### Food for thought

You may have noticed that in this simple stateful firewall, we are adding
new TCP connections to the bloom filter (based on outgoing SYN packets).
However, we are not removing them in case of TCP connection teardown
(FIN packets). How would you implement the removal of TCP connections that are
no longer active?

Things to consider:
 - Can we simply set the bloom filter array bits to `0` on
 receiving a FIN packet? What happens when there is one hash collision in
 the bloom filter arrays between two _active_ TCP connections?
 - How can we modify our bloom filter structure so that the deletion
 operation can be properly supported?

### Troubleshooting

There are several problems that might manifest as you develop your program:

1. `firewall.p4` might fail to compile. In this case, `make run` will
report the error emitted from the compiler and halt.

2. `firewall.p4` might compile but fail to support the control plane
rules in the `s1-runtime.json` file that `make run` tries to install
using P4Runtime. In this case, `make run` will report errors if control
plane rules cannot be installed. Use these error messages to fix your
`firewall.p4` implementation.

3. `firewall.p4` might compile, and the control plane rules might be
installed, but the switch might not process packets in the desired
way. The `logs/sX.log` files contain detailed logs that describe
how each switch processes each packet. The output is detailed and can
help pinpoint logic errors in your implementation.

#### Cleaning up Mininet

In the latter two cases above, `make run` may leave a Mininet instance
running in the background. Use the following command to clean up
these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move on to [Link Monitoring](../link_monitor).


## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All excercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
