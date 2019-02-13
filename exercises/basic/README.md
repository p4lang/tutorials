# Implementing Basic Forwarding

## Introduction

The objective of this exercise is to write a P4 program that
implements basic forwarding. To keep things simple, we will just
implement forwarding for IPv4.

With IPv4 forwarding, the switch must perform the following actions
for every packet: (i) update the source and destination MAC addresses,
(ii) decrement the time-to-live (TTL) in the IP header, and (iii)
forward the packet out the appropriate port.
 
Your switch will have a single table, which the control plane will
populate with static rules. Each rule will map an IP address to the
MAC address and output port for the next hop. We have already defined
the control plane rules, so you only need to implement the data plane
logic of your P4 program.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the
> reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`basic.p4`, which initially drops all packets. Your job will be to
extend this skeleton program to properly forward IPv4 packets.

Before that, let's compile the incomplete `basic.p4` and bring
up a switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `basic.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`)
     configured in a triangle, each connected to one host (`h1`, `h2`,
     and `h3`).
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, and `10.0.3.3`.

2. You should now see a Mininet command prompt. Open two terminals
for `h1` and `h2`, respectively:
   ```bash
   mininet> xterm h1 h2
   ```
3. Each host includes a small Python-based messaging client and
server. In `h2`'s xterm, start the server:
   ```bash
   ./receive.py
   ```
4. In `h1`'s xterm, send a message to `h2`:
   ```bash
   ./send.py 10.0.2.2 "P4 is cool"
   ```
   The message will not be received.
5. Type `exit` to leave each xterm and the Mininet command line.
   Then, to stop mininet:
   ```bash
   make stop
   ```
   And to delete all pcaps, build files, and logs:
   ```bash
   make clean
   ```

The message was not received because each switch is programmed
according to `basic.p4`, which drops all packets on arrival.
Your job is to extend this file so it forwards packets.

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
file `build/basic.p4info` after executing `make`). Any changes in the P4
program that add or rename tables, keys, or actions will need to be reflected in
these `sX-runtime.json` files.

## Step 2: Implement L3 forwarding

The `basic.p4` file contains a skeleton P4 program with key pieces of
logic replaced by `TODO` comments. Your implementation should follow
the structure given in this file---replace each `TODO` with logic
implementing the missing piece.

A complete `basic.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`) and IPv4 (`ipv4_t`).
2. **TODO:** Parsers for Ethernet and IPv4 that populate `ethernet_t` and `ipv4_t` fields.
3. An action to drop a packet, using `mark_to_drop()`.
4. **TODO:** An action (called `ipv4_forward`) that:
	1. Sets the egress port for the next hop. 
	2. Updates the ethernet destination address with the address of the next hop. 
	3. Updates the ethernet source address with the address of the switch. 
	4. Decrements the TTL.
5. **TODO:** A control that:
    1. Defines a table that will read an IPv4 destination address, and
       invoke either `drop` or `ipv4_forward`.
    2. An `apply` block that applies the table.   
6. **TODO:** A deparser that selects the order
    in which fields inserted into the outgoing packet.
7. A `package` instantiation supplied with the parser, control, and deparser.
    > In general, a package also requires instances of checksum verification
    > and recomputation controls. These are not necessary for this tutorial
    > and are replaced with instantiations of empty controls.

## Step 3: Run your solution

Follow the instructions from Step 1. This time, your message from
`h1` should be delivered to `h2`.

### Food for thought

The "test suite" for your solution---sending a message from `h1` to
`h2`---is not very robust. What else should you test to be confident
of your implementation?

> Although the Python `scapy` library is outside the scope of this tutorial,
> it can be used to generate packets for testing. The `send.py` file shows how
> to use it.

Other questions to consider:
 - How would you enhance your program to support next hops?
 - Is this program enough to replace a router?  What's missing?

### Troubleshooting

There are several problems that might manifest as you develop your program:

1. `basic.p4` might fail to compile. In this case, `make` will
report the error emitted from the compiler and halt.

2. `basic.p4` might compile but fail to support the control plane
rules in the `s1-runtime.json` through `s3-runtime.json` files that
`make` tries to install using P4Runtime. In this case, `make` will
report errors if control plane rules cannot be installed. Use these error
messages to fix your `basic.p4` implementation.

3. `basic.p4` might compile, and the control plane rules might be
installed, but the switch might not process packets in the desired
way. The `/tmp/p4s.<switch-name>.log` files contain detailed logs
that describing how each switch processes each packet. The output is
detailed and can help pinpoint logic errors in your implementation.

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background. Use the following command to clean up
these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! In the next exercise we
will build on top of this and add support for a basic tunneling
protocol: [basic_tunnel](../basic_tunnel)!

