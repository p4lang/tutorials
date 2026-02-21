
[comment]: # (SPDX-License-Identifier:  Apache-2.0)

## Introduction

The goal of this exercise is to write a P4 program that implements the `PacketIn` and `PacketOut` mechanisms, along with an idle timeout mechanism for table entries. The control plane uses P4Runtime to configure and manage the data plane. The P4 program `flowcache.p4` contains one ingress table (`flow_cache`) and two counters (`ingressPktOutCounter`, `egressPktInCounter`).

The action `flow_unknown` in the `flow_cache` table triggers the generation of a PacketIn when no flow rules match the packet. The PacketIn is then forwarded to the controller via P4Runtime. Upon receiving these packets, the controller adds an entry to the flow table with action `cached_action`. While the controller computes and installs the flow rule, PacketOut messages are sent via P4Runtime to the data plane in order to forward the packets to their destination.

Once a flow entry is installed and no packets match it, the idle timeout start. Once a flow entry is installed and no packets match it, the idle timeout starts. When the timer expires, an IdleTimeoutNotification message is sent to the controller.

The Counters `ingressPktOutCounter` and `egressPktInCounter` are used to verify whether `PacketIn` and `PacketOut` messages are sent or received.

You will use the starter program, `mycontroller.py`, and a few helper
libraries in the `p4runtime_lib` directory to create the table entries
necessary to forward traffic between hosts.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the
> reference.

## Step 1: Run the (incomplete) starter code

The starter code for this assignment is in files called `flowcache.p4` and `mycontroller.py`. Your job will be to finalize the P4 program to properly implement the `PacketIn` and `PacketOut` idle timeout mechanismes.

First, you need to define the fields in the `packet_in` and `packet_out` headers; otherwise, you’ll get compilation errors. The `packet_in` header should contain three fields: `input_port`, `punt_reason`, and `opcode`. The `packet_out` header should include: `opcode`, `reserved1`, and `operand0` (which represents the egress port in this case). You can see how these header fields are configured and used in the P4 code. More details about `packet_in` and `packet_out` are available in Section 6.4.6 of the [P4Runtime Spec](https://p4.org/specifications/).

After defining the `packet_in` and `packet_out` headers, compile the new P4 program, start the network, and use `mycontroller.py` to install the flowcache pipeline in the data plane.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `flowcache.p4`,
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`)
     configured in a triangle, each connected to one host (`h1`, `h2`, `h3`), and
   * assign IPs of `10.0.1.1`, `10.0.2.2`, `10.0.3.3` to the respective hosts.

2. You should now see a Mininet command prompt. Start a ping between h1 and h2:
   ```bash
   mininet> h1 ping h2
   ```
   Because there are no rules on the switches, you should **not** receive any
   replies yet. You should leave the ping running in this shell.

3. Open another shell and run the starter code:
   ```bash
   cd ~/tutorials/exercises/flowcache
   ./mycontroller.py
   ```
   This will install the `flowcache.p4`  program on the switches, and it will wait for notifications from the data plane.
4. Press `Ctrl-C` to the second shell to stop `mycontroller.py`

Each switch currently has no flow rules. So, as soon as a packet is received, it will be sent to the control plane within a PacketIn. Your job is to write the functions that handle PacketIn, PacketOut, and idle timeout mechanisms. Then, you can verify that PacketIn and PacketOut are working by reading the counters.

### Potential Issues

If you see the following error message when running `mycontroller.py`, then
the gRPC server is not running on one or more switches.

```
p4@p4:~/tutorials/exercises/flowcache$ ./mycontroller.py
...
grpc._channel._Rendezvous: <_Rendezvous of RPC that terminated with (StatusCode.UNAVAILABLE, Connect Failed)>
```

You can check to see which of gRPC ports are listening on the machine by running:
```bash
sudo netstat -lpnt
```

The easiest solution is to enter `Ctrl-D` or `exit` in the `mininet>` prompt,
and re-run `make`.

### A note about the control plane

A P4 program defines a packet-processing pipeline, but the rules
within each table are inserted by the control plane. In this case,
`mycontroller.py` implements our control plane, instead of installing static
table entries like we have in the previous exercises.

**Important:** A P4 program also defines the interface between the
switch pipeline and control plane. This interface is defined in the
`flow_cache.p4info` file. The table entries that you build in `mycontroller.py`
refer to specific tables, keys, and actions by name, and we use a P4Info helper
to convert the names into the IDs that are required for P4Runtime. Any changes
in the P4 program that add or rename tables, keys, or actions will need to be
reflected in your table entries.

### Notes on the CPU port, PacketIn and PacketOut messages, and controller metadata

You _MUST NOT_ associate the CPU port number with an interface,
i.e. it would cause problems if you added a command line option
`-i 510@veth16` to the example command line above.  The CPU port is
special in that effectively one end is connected to the BMv2 switch
on the CPU port, and the other end is always connected to the
P4Runtime API server code that runs within the `simple_switch_grpc`
process.

All packets sent by your P4 code to the CPU port go to this P4Runtime
API server, are sent via a `PacketIn` message from the server to your
controller (which is a P4Runtime API client) over the P4Runtime API
gRPC connection, and become `PacketIn` messages to your controller
program.  The controller metadata header, if you have one, must be the
_first_ header when the packet is sent to the CPU port by your P4
program.

All `PacketOut` messages from your controller program go over the
P4Runtime API grPC connection to the P4Runtime API server code running
inside of the `simple_switch_grpc` process, and are then sent into the
CPU port for your P4 program to process.  The controller metadata
header, if any, will always be the _first_ header of the packet as
seen by your P4 parser.

## Step 2: Implement flowcache control messages handling

The `mycontroller.py` file is a basic controller plane that does the following:
1. Establishes a gRPC connection to the switches for the P4Runtime service.
2. Pushes the P4 program to each switch.
3. Receives `PacketIn` messages and generates flow rules to provide connectivity among all hosts.
4. Sends `PacketOut` messages to forward the packets to their destination while the corresponding flow rules are not yet installed.
5. Handles the `IdleTimeoutNotification`.
6. Reads `PacketIn` and `PacketOut` ingress and egress counters periodically.

It also contains comments marked with `TODO` which indicate the functionality
that you need to implement.

Your job will be to write functions that will handle the `PacketIn`, `PacketOut` and idle timeout mechanismes.

![topology](../basic_tunnel/topo.png)

In this exercise, you will be interacting with some of the classes and methods in
the `p4runtime_lib` directory. Here is a summary of each of the files in the directory:
- `helper.py`
  - Contains the `P4InfoHelper` class which is used to parse the `p4info` files.
  - Provides translation methods from entity name to and from ID number.
  - Builds P4 program-dependent sections of P4Runtime table entries.
- `switch.py`
  - Contains the `SwitchConnection` class which grabs the gRPC client stub, and
    establishes connections to the switches.
  - Provides helper methods that construct the P4Runtime protocol buffer messages
    and makes the P4Runtime gRPC service calls.
- `bmv2.py`
  - Contains `Bmv2SwitchConnection` which extends `SwitchConnections` and provides
    the BMv2-specific device payload to load the P4 program.
- `convert.py`
  - Provides convenience methods to encode and decode from friendly strings and
    numbers to the byte strings required for the protocol buffer messages.
  - Used by `helper.py`


## Step 3: Run your solution

Follow the instructions from Step 1. If your Mininet network is still running,
you will just need to run the following in your second shell:
```bash
./mycontroller.py
```

You should start to see ICMP replies in your Mininet prompt, and you should start to
see the values for all counters start to increment.

### Extra Credit and Food for Thought

You might notice that the rules that are printed by `mycontroller.py` contain the entity
IDs rather than the table names. You can use the P4Info helper to translate these IDs
into entry names.

The current mechanism for triggering the deletion of a stale flow rule can be improved. 
As shown in the code of `mycontroller.py`, a notification database is maintained to track 
the flow rules. Thanks to this, the deletion of a single flow rule is performed only once. 
However, there is a need for a mechanism to ensure that the deletion is triggered only once. 
Without this safeguard, errors may occur when attempting to delete the same flow rule multiple 
times or when trying to delete a flow rule that no longer exists. To address this issue, 
you can provide and experiment with different approaches.

If you are interested, you can find the protocol buffer and gRPC definitions here:
- [P4Runtime](https://github.com/p4lang/p4runtime/blob/main/proto/p4/v1/p4runtime.proto)
- [P4Info](https://github.com/p4lang/p4runtime/blob/main/proto/p4/config/v1/p4info.proto)

#### Cleaning up Mininet

If the Mininet shell crashes, it may leave a Mininet instance
running in the background. Use the following command to clean up:
```bash
make clean
```

#### Running the reference solution

To run the reference solution, you should run the following command from the
`~/tutorials/exercises/p4runtime` directory:
```bash
solution/mycontroller.py
```

## Next Steps

Congratulations, your implementation works! Move onto the next assignment
[Explicit Congestion Notification](../ecn)

## Relevant Documentation

Documentation on the Usage of Gateway (gw) and ARP Commands in topology.json is [here](https://github.com/p4lang/tutorials/tree/master/exercises/basic#the-use-of-gateway-gw-and-arp-commands-in-topologyjson)

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All excercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).
