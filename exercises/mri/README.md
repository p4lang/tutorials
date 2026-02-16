
[comment]: # (SPDX-License-Identifier:  Apache-2.0)

# Implementing MRI

## Introduction

The objective of this tutorial is to extend basic L3 forwarding with a
scaled-down version of In-Band Network Telemetry (INT), which we call
Multi-Hop Route Inspection (MRI).

MRI allows users to track the path and the length of queues that every
packet travels through.  To support this functionality, you will need
to write a P4 program that appends an ID and queue length to the
header stack of every packet.  At the destination, the sequence of
switch IDs correspond to the path, and each ID is followed by the
queue length of the port at switch.

As before, we have already defined the control plane rules, so you
only need to implement the data plane logic of your P4 program.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`mri.p4`, which initially implements L3 forwarding. Your job (in the
next step) will be to extend it to properly prepend the MRI custom
headers.

Before that, let's compile the incomplete `mri.p4` and bring up a
switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `mri.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`) configured
     in a triangle. There are 5 hosts. `h1` and `h11` are connected to `s1`.
     `h2` and `h22` are connected to `s2` and `h3` is connected to `s3`.
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, etc
     (`10.0.<Switchid>.<hostID>`).
   * The control plane programs the P4 tables in each switch based on
     `sx-runtime.json`

2. We want to send a low rate traffic from `h1` to `h2` and a high
   rate iperf traffic from `h11` to `h22`.  The link between `s1` and
   `s2` is common between the flows and is a bottleneck because we
   reduced its bandwidth to 512kbps in topology.json.  Therefore, if we
   capture packets at `h2`, we should see high queue size for that
   link.

![Setup](setup.png)

3. You should now see a Mininet command prompt. Open four terminals
   for `h1`, `h11`, `h2`, `h22`, respectively:
   ```bash
   mininet> xterm h1 h11 h2 h22
   ```
3. In `h2`'s xterm, start the server that captures packets:
   ```bash
   ./receive.py
   ```
4. in `h22`'s xterm, start the iperf UDP server:
   ```bash
   iperf -s -u
   ```

5. In `h1`'s xterm, send one packet per second to `h2` using send.py
   say for 30 seconds:
   ```bash
   ./send.py 10.0.2.2 "P4 is cool" 30
   ```
   The message "P4 is cool" should be received in `h2`'s xterm,
6. In `h11`'s xterm, start iperf client sending for 15 seconds
   ```bash
   iperf -c 10.0.2.22 -t 15 -u
   ```
7. At `h2`, the MRI header has no hop info (`count=0`)
8. type `exit` to close each xterm window

You should see the message received at host `h2`, but without any
information about the path the message took.  Your job is to extend
the code in `mri.p4` to implement the MRI logic to record the path.

### A note about the control plane

P4 programs define a packet-processing pipeline, but the rules
governing packet processing are inserted into the pipeline by the
control plane.  When a rule matches a packet, its action is invoked
with parameters supplied by the control plane as part of the rule.

In this exercise, the control plane logic has already been
implemented.  As part of bringing up the Mininet instance, the
`make` script will install packet-processing rules in the tables of
each switch. These are defined in the `sX-runtime.json` files, where
`X` corresponds to the switch number.

## Step 2: Implement MRI

The `mri.p4` file contains a skeleton P4 program with key pieces of
logic replaced by `TODO` comments.  These should guide your
implementation---replace each `TODO` with logic implementing the
missing piece.

MRI will require two custom headers. The first header, `mri_t`,
contains a single field `count`, which indicates the number of switch
IDs that follow. The second header, `switch_t`, contains switch ID and
Queue depth fields of each switch hop the packet goes through.

One of the biggest challenges in implementing MRI is handling the
recursive logic for parsing these two headers. We will use a
`parser_metadata` field, `remaining`, to keep track of how many
`switch_t` headers we need to parse.  In the `parse_mri` state, this
field should be set to `hdr.mri.count`.  In the `parse_swtrace` state,
this field should be decremented. The `parse_swtrace` state will
transition to itself until `remaining` is 0.

The MRI custom headers will be carried inside an IP Options
header. The IP Options header contains a field, `option`, which
indicates the type of the option. We will use a special type 31 to
indicate the presence of the MRI headers.

Beyond the parser logic, you will add a table in egress, `swtrace` to
store the switch ID and queue depth, and actions that increment the
`count` field, and append a `switch_t` header.

A complete `mri.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`), IPv4 (`ipv4_t`),
   IP Options (`ipv4_option_t`), MRI (`mri_t`), and Switch (`switch_t`).
2. Parsers for Ethernet, IPv4, IP Options, MRI, and Switch that will
populate `ethernet_t`, `ipv4_t`, `ipv4_option_t`, `mri_t`, and
`switch_t`.
3. An action to drop a packet, using `mark_to_drop()`.
4. An action (called `ipv4_forward`), which will:
	1. Set the egress port for the next hop.
	2. Update the ethernet destination address with the address of
	the next hop.
	3. Update the ethernet source address with the address of the switch.
	4. Decrement the TTL.
5. An ingress control that:
    1. Defines a table that will read an IPv4 destination address, and
       invoke either `drop` or `ipv4_forward`.
    2. An `apply` block that applies the table.
6. At egress, an action (called `add_swtrace`) that will add the
   switch ID and queue depth.
8. An egress control that applies a table (`swtrace`) to store the
   switch ID and queue depth, and calls `add_swtrace`.
9. A deparser that selects the order in which fields inserted into the outgoing
   packet.
10. A `package` instantiation supplied with the parser, control,
    checksum verification and recomputation and deparser.

## Step 3: Run your solution

Follow the instructions from Step 1.  This time, when your message
 from `h1` is delivered to `h2`, you should see the sequence of
 switches through which the packet traveled plus the corresponding
 queue depths.  The expected output will look like the following,
 which shows the MRI header, with a `count` of 2, and switch ids
 (`swids`) 2 and 1.  The queue depth at the common link (from s1 to
 s2) is high.

```
got a packet
###[ Ethernet ]###
  dst       = 00:04:00:02:00:02
  src       = f2:ed:e6:df:4e:fa
  type      = 0x800
###[ IP ]###
     version   = 4L
     ihl       = 10L
     tos       = 0x0
     len       = 42
     id        = 1
     flags     =
     frag      = 0L
     ttl       = 62
     proto     = udp
     chksum    = 0x60c0
     src       = 10.0.1.1
     dst       = 10.0.2.2
     \options   \
      |###[ MRI ]###
      |  copy_flag = 0L
      |  optclass  = control
      |  option    = 31L
      |  length    = 20
      |  count     = 2
      |  \swtraces  \
      |   |###[ SwitchTrace ]###
      |   |  swid      = 2
      |   |  qdepth    = 0
      |   |###[ SwitchTrace ]###
      |   |  swid      = 1
      |   |  qdepth    = 17
###[ UDP ]###
        sport     = 1234
        dport     = 4321
        len       = 18
        chksum    = 0x1c7b
###[ Raw ]###
           load      = 'P4 is cool'

```

### Food for thought
The maximum queue depth and queue rate of each switch can be configured using `simple_switch_CLI`. Connect to the CLI of switch `s1` using the following command on your host machine:
```bash
simple_switch_CLI --thrift-port 9090
```

Then, set the maximum queue depth and rate using the following commands:
```bash
set_queue_rate 50
set_queue_depth 100
```

Feel free to experiment with different values for each switch and observe the changes in the MRI header.

How does the `qdepth` header change with different queue depths and rates?

### Troubleshooting

There are several ways that problems might manifest:

1. `mri.p4` fails to compile. In this case, `make` will report the
   error emitted from the compiler and stop.

2. `mri.p4` compiles but does not support the control plane rules in
   the `sX-runtime.json` files that `make` tries to install using a
   Python controller. In this case, `make` will log the controller
   output in the `logs` directory.  Use these error messages to fix
   your `mri.p4` implementation.

3. `mri.p4` compiles, and the control plane rules are installed, but
   the switch does not process packets in the desired way. The
   `logs/sX.log` files contain trace messages
   describing how each switch processes each packet. The output is
   detailed and can help pinpoint logic errors in your implementation.
   The `build/<switch-name>-<interface-name>.pcap` also contains the
   pcap of packets on each interface. Use `tcpdump -r <filename> -xxx`
   to print the hexdump of the packets.

4. `mri.p4` compiles and all rules are installed. Packets go through
    and the logs show that the queue length is always 0.  Then either
    reduce the link bandwidth in `topology.json`.

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background.  Use the following command to clean up
these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move on to [Source
Routing](../source_routing).

## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All excercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
