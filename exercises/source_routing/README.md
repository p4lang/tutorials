<!--
SPDX-FileCopyrightText: 2018 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Implementing Source Routing

## Introduction

The objective of this exercise is to implement source routing.  With
source routing, the source host guides each switch in the network to
send the packet to a specific port. The host puts a stack of output
ports in the packet. In this example, we just put the stack after
Ethernet header and select a special etherType to indicate that.  Each
switch pops an item from the stack and forwards the packet according
to the specified port number.

Your switch must parse the source routing stack. Each item has a bos
(bottom of stack) bit and a port number. The bos bit is 1 only for the
last entry of stack.  Then at ingress, it should pop an entry from the
stack and set the egress port accordingly. The last hop may also
revert back the etherType to `TYPE_IPV4`.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the
> reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`source_routing.p4`, which initially drops all packets. Your job (in
the next step) will be to extend it to properly to route packets.

Before that, let's compile the incomplete `source_routing.p4` and
bring up a network in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `source_routing.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`) configured
     in a triangle, each connected to one host (`h1`, `h2`, `h3`).
     Check the network topology using the `net` command in mininet.
     You can also change the topology in topology.json
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, etc
     (`10.0.<Switchid>.<hostID>`).

![Setup](setup.png)

2. You should now see a Mininet command prompt. Open two terminals for
   `h1` and `h2`, respectively:
   ```bash
   mininet> xterm h1 h2
   ```
3. Each host includes a small Python-based messaging client and
   server. In `h2`'s xterm, start the server:
   ```bash
   ./receive.py
   ```
4. In `h1`'s xterm, send a message from the client:
   ```bash
   ./send.py 10.0.2.2
   ```

5. Type a list of port numbers. say `2 3 2 2 1`.  This should send the
   packet through `h1`, `s1`, `s2`, `s3`, `s1`, `s2`, and
   `h2`. However, `h2` will not receive the message.

6. Type `q` to exit send.py and type `exit` to leave each xterm and
   the Mininet command line.

The message was not received because each switch is programmed with
`source_routing.p4`, which drops all packets on arrival.  You can
verify this by looking at `logs/s1.log`.  Your job is to extend
the P4 code so packets are delivered to their destination.

## Step 2: Implement source routing

The `source_routing.p4` file contains a skeleton P4 program with key
pieces of logic replaced by `TODO` comments. These should guide your
implementation---replace each `TODO` with logic implementing the
missing piece.

A complete `source_routing.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`) and IPv4
   (`ipv4_t`) and Source Route (`srcRoute_t`).
2. **TODO:** Parsers for Ethernet and Source Route that populate
   `ethernet` and `srcRoutes` fields.
3. An action to drop a packet, using `mark_to_drop()`.
4. **TODO:** An action (called `srcRoute_nhop`), which will:
	1. Set the egress port for the next hop.
	2. remove the first entry of srcRoutes
5. A control with an `apply` block that:
    1. checks the existence of source routes.
    2. **TODO:** if statement to change etherent.etherType if it is the last hop
    3. **TODO:** call srcRoute_nhop action
6. A deparser that selects the order in which fields inserted into the outgoing
   packet.
7. A `package` instantiation supplied with the parser, control, and deparser.
    > In general, a package also requires instances of checksum verification
    > and recomputation controls.  These are not necessary for this tutorial
    > and are replaced with instantiations of empty controls.

## Step 3: Run your solution

Follow the instructions from Step 1. This time, your message from `h1`
should be delivered to `h2`.

Check the `ttl` of the IP header. Each hop decrements `ttl`.  The port
sequence `2 3 2 2 1`, forces the packet to have a loop, so the `ttl`
should be 59 at `h2`.  Can you find the port sequence for the shortest
path?

### Food for thought
* Can we change the program to handle both IPv4 forwarding and source
routing at the same time?
* How would you enhance your program to let the first switch add the
path, so that source routing would be transparent to end-hosts?

### Troubleshooting

There are several ways that problems might manifest:

1. `source_routing.p4` fails to compile. In this case, `make` will
   report the error emitted from the compiler and stop.
2. `source_routing.p4` compiles but switches or mininet do not start.
   Do you have another instance of mininet running? Did the previous
   run of mininet crash?  if yes, check "Cleaning up Mininet" bellow.
3. `source_routing.p4` compiles but the switch does not process
   packets in the desired way. The `logs/sX.log`
   files contain trace messages describing how each switch processes
   each packet. The output is detailed and can help pinpoint logic
   errors in your implementation.  The
   `<switch-name>-<interface-name>_<direction>.pcap` files contain pcap captures
   of all packets sent and received on each interface. Use `tcpdump -r <filename> -xxx` to
   print the hexdump of the packets.

#### Cleaning up Mininet

In the cases above, `make` may leave a Mininet instance running in
the background. Use the following command to clean up these
instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move on to
[Calculator](../calc).


## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All excercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
