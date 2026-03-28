<!--
SPDX-FileCopyrightText: 2018 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Implementing ECN

## Introduction

The objective of this tutorial is to extend basic L3 forwarding with
an implementation of Explicit Congestion Notification (ECN).

ECN allows end-to-end notification of network congestion without
dropping packets.  If an end-host supports ECN, it puts the value of 1
or 2 in the `ipv4.ecn` field.  For such packets, each switch may
change the value to 3 if the queue size is larger than a threshold.
The receiver copies the value to sender, and the sender can lower the
rate.

As before, we have already defined the control plane rules for
routing, so you only need to implement the data plane logic of your P4
program.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`ecn.p4`, which initially implements L3 forwarding. Your job (in the
next step) will be to extend it to properly append set the ECN bits

Before that, let's compile the incomplete `ecn.p4` and bring up a
network in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `ecn.p4`, and
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
capture packets at `h2`, we should see the right ECN value.

![Setup](setup.png)

3. You should now see a Mininet command prompt. Open four terminals
for `h1`, `h11`, `h2`, `h22`, respectively:
   ```bash
   mininet> xterm h1 h11 h2 h22
   ```
4. In `h2`'s XTerm, start the server that captures packets:
   ```bash
   ./receive.py
   ```  
5. in `h22`'s XTerm, start the iperf UDP server:
   ```bash
   iperf -s -u
   ```

**Note:** Since we want packets sent by `h1` to at least sometimes experience long packet queues in switch `s1`, its important to have a synchronized and simultaneous flow of packets, which will be done via 6th and 7th step.<br> Hence, at first, type both (6th & 7th) commands together in the respective Xterm windows and later press the Enter button (`h1` and then `h11`) immediately for both Xterm windows, to clog up the traffic effectively.

   
6. In `h1`'s XTerm, send one packet per second to `h2` using send.py
say for 30 seconds:
   ```bash
   ./send.py 10.0.2.2 "P4 is cool" 30
   ```
   The message "P4 is cool" should be received in `h2`'s xterm,
7. In `h11`'s XTerm, start iperf client sending for 15 seconds
   ```bash
   iperf -c 10.0.2.22 -t 15 -u
   ```
8. At `h2`, the `ipv4.tos` field (DiffServ+ECN) is always 1
9. type `exit` to close each XTerm window

Your job is to extend the code in `ecn.p4` to implement the ECN logic
for setting the ECN flag.

## Step 2: Implement ECN

The `ecn.p4` file contains a skeleton P4 program with key pieces of
logic replaced by `TODO` comments.  These should guide your
implementation---replace each `TODO` with logic implementing the
missing piece.

First we have to change the ipv4_t header by splitting the TOS field
into DiffServ and ECN fields.  Remember to update the checksum block
accordingly.  Then, in the egress control block we must compare the
queue length with ECN_THRESHOLD. If the queue length is larger than
the threshold, the ECN flag will be set.  Note that this logic should
happen only if the end-host declared supporting ECN by setting the
original ECN to 1 or 2.

A complete `ecn.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`) and IPv4 (`ipv4_t`).
2. Parsers for Ethernet, IPv4,
3. An action to drop a packet, using `mark_to_drop()`.
4. An action (called `ipv4_forward`), which will:
	1. Set the egress port for the next hop.
	2. Update the ethernet destination address with the address of
           the next hop.
	3. Update the ethernet source address with the address of the switch.
	4. Decrement the TTL.
5. An egress control block that checks the ECN and
`standard_metadata.enq_qdepth` and sets the ipv4.ecn.
6. A deparser that selects the order in which fields inserted into the outgoing
   packet.
7. A `package` instantiation supplied with the parser, control,
  checksum verification and recomputation and deparser.

## Step 3: Run your solution

Follow the instructions from Step 1. This time, when your message from
`h1` is delivered to `h2`, you should see `tos` values change from 1
to 3 as the queue builds up.  `tos` may change back to 1 when iperf
finishes and the queue depletes.

To easily track the `tos` values you may want to redirect the output
of `h2` to a file by running the following for `h2`
   ```bash
   ./receive.py > h2.log
   ```
and just print the `tos` values `grep tos h2.log` in a separate window
```
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
```

### Food for thought

How can we let the user configure the threshold? (lookout in the top segment of p4 code or search for ECN_THRESHOLD )

### Troubleshooting

There are several ways that problems might manifest:

1. `ecn.p4` fails to compile.  In this case, `make` will report the
   error emitted from the compiler and stop.
2. `ecn.p4` compiles but does not support the control plane rules in
   the `sX-runtime.json` files that `make` tries to install using
   a Python controller. In this case, `make` will log the controller output
   in the `logs` directory. Use these error messages to fix your `ecn.p4`
   implementation.
3. `ecn.p4` compiles, and the control plane rules are installed, but
   the switch does not process packets in the desired way.  The
   `logs/sX.log` files contain trace messages
   describing how each switch processes each packet.  The output is
   detailed and can help pinpoint logic errors in your implementation.
   The `build/<switch-name>-<interface-name>.pcap` also contains the
   pcap of packets on each interface. Use `tcpdump -r <filename> -xxx`
   to print the hexdump of the packets.
4. `ecn.p4` compiles and all rules are installed. Packets go through
   and the logs show that the queue length was not high enough to set
   the ECN bit.  Then either lower the threshold in the p4 code or
   reduce the link bandwidth in `topology.json`
5. When running the traffic from `h1` to `h2` at 1 packet/second (send.py), note that this flow only lasts for 30 seconds. Therefore, it is crucial to start the high-rate traffic from `h11` to 
   `h22` within **10 seconds** after starting the `h1` to `h2` flow.<br>  
   If you wait the full 30 seconds (or close to it) before starting the high-rate traffic, the `h1` to `h2` flow will have already finished. In that case, it will not experience queuing delay, 
   which could significantly change the expected results of your experiment i.e. `tos` value will remain `0x1`, and would never hit the expected `0x3` spike.
   
   To overcome this issue, use a larger duration value (e.g., 60) when calling `send.py`, to make the `h1` → `h2` flow last longer and increase the chance of overlapping with congestion from the 
   high-rate flow i.e.    
   ```bash
   ./send.py 10.0.2.2 "P4 is cool" 60
   ```

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background.  Use the following command to clean up
these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move onto the next assignment
[Multi-Hop Route Inspection](../mri)

## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All excercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
