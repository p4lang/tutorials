<!--
SPDX-FileCopyrightText: 2020 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Implementing QOS

## Introduction

The objective of this tutorial is to extend basic L3 forwarding with
an implementation of Quality of Service (QOS) using Differentiated Services.

Diffserv is simple and scalable. It classifies and manages network traffic and provides QOS on modern IP networks.

As before, we have already defined the control plane rules for
routing, so you only need to implement the data plane logic of your P4
program.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`qos.p4`, which initially implements L3 forwarding. Your job (in the
next step) will be to extend it to properly set the `diffserv` bits.

Before that, let's compile the incomplete `qos.p4` and bring up a
network in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `qos.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`) configured
     in a triangle. There are 5 hosts. `h1` and `h11` are connected to `s1`.
     `h2` and `h22` are connected to `s2` and `h3` is connected to `s3`.
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, etc
     (`10.0.<Switchid>.<hostID>`).
   * The control plane programs the P4 tables in each switch based on
     `sx-runtime.json`

2. We want to send traffic from `h1` to `h2`. If we
capture packets at `h2`, we should see the right diffserv value.

![Setup](setup.png)

3. You should now see a Mininet command prompt. Open two terminals
for `h1` and `h2`, respectively:
   ```bash
   mininet> xterm h1 h2
   ```
4. In `h2`'s XTerm, start the server that captures packets:
   ```bash
   ./receive.py
   ```
5. In `h1`'s XTerm, send one packet per second to `h2` using send.py
say for 30 seconds.
   To send UDP:
   ```bash
   ./send.py --p=UDP --des=10.0.2.2 --m="P4 is cool" --dur=30
   ```
   To send TCP:
   ```bash
   ./send.py --p=TCP --des=10.0.2.2 --m="P4 is cool" --dur=30
   ```
   The message "P4 is cool" should be received in `h2`'s xterm,
6. At `h2`, the `ipv4.tos` field (DiffServ+ECN) is always 1
7. type `exit` to close each XTerm window

Your job is to extend the code in `qos.p4` to implement the diffserv logic
for setting the diffserv flag.

## Step 2: Implement Diffserv

The `qos.p4` file contains a skeleton P4 program with key pieces of
logic replaced by `TODO` comments.  These should guide your
implementation---replace each `TODO` with logic implementing the
missing piece.

First we have to change the ipv4_t header by splitting the TOS field
into DiffServ and ECN fields.  Remember to update the checksum block
accordingly.  Then, in the ingress control block we must compare the
protocol in IP header with IP protocols. Based on the traffic classes
and priority, the `diffserv` flag will be set.

A complete `qos.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`) and IPv4 (`ipv4_t`).
2. Parsers for Ethernet, IPv4,
3. An action to drop a packet, using `mark_to_drop()`.
4. An action (called `ipv4_forward`), which will:
	1. Set the egress port for the next hop.
	2. Update the ethernet destination address with the address of
           the next hop.
	3. Update the ethernet source address with the address of the switch.
	4. Decrement the TTL.
5. An ingress control block that checks the protocols and sets the ipv4.diffserv.
6. A deparser that selects the order in which headers are inserted into the outgoing
   packet.
7. A `package` instantiation supplied with the parser, control,
  checksum verification and recomputation and deparser.

## Step 3: Run your solution

Follow the instructions from Step 1. This time, when your message from
`h1` is delivered to `h2`, you should see `tos` values change from 0x1
to  0xb9 for UDP and 0xb1 for TCP. It depends upon the action you choose
in Ingress processing.

To easily track the `tos` values you may want to redirect the output
of `h2` to a file by running the following for `h2`
   ```bash
   ./receive.py > h2.log
   ```
and just print the `tos` values `grep tos h2.log` in a separate window
```
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb9
     tos       = 0xb1
     tos       = 0xb1
     tos       = 0xb1
     tos       = 0xb1
     tos       = 0xb1
     tos       = 0xb1
     tos       = 0xb1
     tos       = 0xb1

```

### Food for thought

How can we let the user use other protocols?

### Troubleshooting

There are several ways that problems might manifest:

1. `qos.p4` fails to compile.  In this case, `make` will report the
   error emitted from the compiler and stop.
2. `qos.p4` compiles but does not support the control plane rules in
   the `sX-runtime.json` files that `make` tries to install using
   a Python controller. In this case, `make` will log the controller output
   in the `logs` directory. Use these error messages to fix your `qos.p4`
   implementation.
3. `qos.p4` compiles, and the control plane rules are installed, but
   the switch does not process packets in the desired way.  The
   `logs/sX.log` files contain trace messages
   describing how each switch processes each packet.  The output is
   detailed and can help pinpoint logic errors in your implementation.
   The `build/<switch-name>-<interface-name>.pcap` also contains the
   pcap of packets on each interface. Use `tcpdump -r <filename> -xxx`
   to print the hexdump of the packets.

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background.  Use the following command to clean up
these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move on to [Multicasting](../multicast).


## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All excercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
