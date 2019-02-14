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
3. In `h2`'s XTerm, start the server that captures packets:
   ```bash
   ./receive.py
   ```
4. in `h22`'s XTerm, start the iperf UDP server:
   ```bash
   iperf -s -u
   ```
5. In `h1`'s XTerm, send one packet per second to `h2` using send.py
say for 30 seconds:
   ```bash
   ./send.py 10.0.2.2 "P4 is cool" 30
   ```
   The message "P4 is cool" should be received in `h2`'s xterm,
6. In `h11`'s XTerm, start iperf client sending for 15 seconds
   ```bash
   iperf -c 10.0.2.22 -t 15 -u
   ```
7. At `h2`, the `ipv4.tos` field (DiffServ+ECN) is always 1
8. type `exit` to close each XTerm window

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

How can we let the user configure the threshold?

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
   `/tmp/p4s.<switch-name>.log` files contain trace messages
   describing how each switch processes each packet.  The output is
   detailed and can help pinpoint logic errors in your implementation.
   The `build/<switch-name>-<interface-name>.pcap` also contains the
   pcap of packets on each interface. Use `tcpdump -r <filename> -xxx`
   to print the hexdump of the packets.
4. `ecn.p4` compiles and all rules are installed. Packets go through
   and the logs show that the queue length was not high enough to set
   the ECN bit.  Then either lower the threshold in the p4 code or
   reduce the link bandwidth in `topology.json`

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background.  Use the following command to clean up
these instances:

```bash
make stop
```
