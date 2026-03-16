[comment]: # (SPDX-License-Identifier:  Apache-2.0)

# Implementing ACL Firewall with Traffic Monitoring Counters

## Introduction

In this exercise, you will extend the basic IPv4 router that you completed in
the previous assignment with two important features found in real network
switches. The basic switch forwards packets based on the destination IP
address. Your job is to add a stateless ACL firewall that blocks packets from
specific source IP addresses, and to add traffic monitoring counters that track
forwarded and dropped packets in real time.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the reference.

The starter code for this assignment is in a file called `acl_with_counters.p4`
and contains a complete IPv4 parser and checksum logic. Your job is to
implement the actions, tables, counters, and the apply block.

### A note about the control plane

A P4 program defines a packet-processing pipeline, but the rules within each
table are inserted by the control plane. When a rule matches a packet, its
action is invoked with parameters supplied by the control plane as part of
the rule.

For this exercise, we have already added the necessary static control plane
entries. As part of bringing up the Mininet instance, the `make run` command
will install packet-processing rules in the tables of the switch. These are
defined in the `s1-runtime.json` file.

The `s1-runtime.json` file contains:
- **Four LPM forwarding rules** mapping each host's IP to its output port
- **One ACL rule** that blocks all packets sourced from `h3` (`10.0.3.3`).
  The rule passes `index: 3` to the `acl_drop` action so that the counter
  tracks blocked packets at slot 3.

**Important:** We use P4Runtime to install the control plane rules. The content
of `s1-runtime.json` refers to specific names of tables, keys, and actions, as
defined in the P4Info file produced by the compiler (look for the file
`build/acl_with_counters.p4.p4info.txtpb` after executing `make run`). Any
changes in the P4 program that add or rename tables, keys, or actions will
need to be reflected in `s1-runtime.json`.

## Step 1: Implement the ACL Firewall with Counters

The `acl_with_counters.p4` file contains comments marked with `TODO` which
indicate the functionality that you need to implement. A complete
implementation of the `acl_with_counters.p4` switch will be able to block
packets from specific source IPs, forward all remaining packets to the correct
output port, and count both forwarded and dropped packets per rule.

Your job will be to do the following:

1. **TODO:** Complete the parser. In the `start` state, extract the Ethernet
header and transition to `parse_ipv4` if `etherType == TYPE_IPV4`, otherwise
accept. In `parse_ipv4`, extract the IPv4 header and transition to accept.

2. **TODO:** Declare three indirect counters, each with 1024 slots counting
`packets_and_bytes`:
   - `ipv4_counter` — tracks forwarded packets and bytes per output port.
     The slot index is the egress port number.
   - `drop_counter` — tracks packets dropped due to no matching forwarding
     rule. Always uses slot 0.
   - `acl_drop_counter` — tracks packets blocked by the ACL. The slot index
     is provided by the control plane via the `index` action parameter.

3. **TODO:** Implement the `drop` action. It should increment `drop_counter`
at slot 0 and mark the packet for dropping.

4. **TODO:** Implement the `acl_drop` action. It takes a `bit<32> index`
parameter provided by the control plane. It should increment `acl_drop_counter`
at the given index and mark the packet for dropping.

5. **TODO:** Implement the `ipv4_forward` action. It should set the output
port, update the destination MAC to the next hop MAC address, update the source
MAC to the old destination MAC, decrement the TTL by 1, and increment
`ipv4_counter` using the egress port number as the slot index.

6. **TODO:** Add the key field to the `acl_filter` table. It should perform
an exact match on `hdr.ipv4.srcAddr`.

7. **TODO:** Add the key field to the `ipv4_lpm` table. It should perform an
LPM match on `hdr.ipv4.dstAddr`.

8. **TODO:** Implement the `apply` block inside `MyIngress`. It should first
apply the `acl_filter` table. If the action was `acl_drop`, stop processing
the packet. Otherwise, apply the `ipv4_lpm` table for forwarding.

9. **TODO:** Complete the deparser. Emit the Ethernet header first, then the
IPv4 header. Remember that the deparser will only emit a header if it is valid.
A header's implicit validity bit is set by the parser upon extraction, so
there is no need to check validity here.

## Step 2: Run your solution

1. In your shell, run:
   ```bash
   make run
   ```
   This will:
   * compile `acl_with_counters.p4`, and
   * start a Mininet instance with one switch (`s1`) connected to four hosts
     (`h1`, `h2`, `h3`, `h4`).
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, `10.0.3.3`,
     and `10.0.4.4`.

2. You should now see a Mininet command prompt. Test that allowed traffic
works between `h1` and `h2`:
   ```bash
   mininet> h1 ping h2 -c 3
   ```
   The ping should succeed with 0% packet loss.

3. Now test that the ACL is blocking traffic from `h3`:
   ```bash
   mininet> h3 ping h1 -c 3
   ```
   The ping should fail with 100% packet loss because `h3`'s source IP
   (`10.0.3.3`) is blocked by the ACL rule in `s1-runtime.json`.

4. To verify the counters are working, open a new terminal and run:
   ```bash
   simple_switch_CLI --thrift-port 9090
   ```
   Then read the counter values:
   ```bash
   RuntimeCmd: counter_read MyIngress.ipv4_counter 1
   RuntimeCmd: counter_read MyIngress.acl_drop_counter 3
   RuntimeCmd: counter_read MyIngress.drop_counter 0
   ```
   You should see non-zero packet and byte counts corresponding to the
   traffic you generated.

5. Type `exit` or `Ctrl-D` to leave the Mininet command line.
   Then clean up:
   ```bash
   make stop
   make clean
   ```

### Food for thought

How would you extend this exercise to support a dynamic ACL where the control
plane can add and remove blocked IPs at runtime without restarting the switch?

Hints:

- The `simple_switch_CLI` supports `table_add` and `table_delete` commands
  that can modify table entries at runtime without recompiling or restarting.
- Think about how you would assign counter slot indices dynamically if the
  control plane is inserting rules on the fly.

### Troubleshooting

There are several problems that might manifest as you develop your program:

1. `acl_with_counters.p4` might fail to compile. In this case, `make run`
will report the error emitted from the compiler and halt.

2. `acl_with_counters.p4` might compile but fail to support the control plane
rules in `s1-runtime.json` that `make run` tries to install using P4Runtime.
In this case, `make run` will report errors if control plane rules cannot be
installed. Use these error messages to fix your implementation or the
forwarding rules.

3. `acl_with_counters.p4` might compile, and the control plane rules might be
installed, but the switch might not process packets in the desired way. The
`logs/s1.log` file contains detailed logs describing how the switch processes
each packet. The output is detailed and can help pinpoint logic errors in your
implementation.

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance running in
the background. Use the following command to clean up these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move onto the next assignment
[basic_tunnel](../basic_tunnel)!

## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json
is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available
[here](https://p4.org/specifications/)

All exercises in this repository use the v1model architecture, the
documentation for which is available at:
1. The BMv2 Simple Switch target document accessible
[here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md)
talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed
[here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
