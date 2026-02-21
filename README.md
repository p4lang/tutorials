
[comment]: # (SPDX-License-Identifier:  Apache-2.0)

# P4 Tutorial

* [Introduction](#introduction)
* [Presentation](#presentation)
* [P4 Documentation](#p4-documentation)
* [P4sim](#p4sim--a-simple-p4-behavioral-simulator)
* [Obtaining required software](#obtaining-required-software)
     * [To build the virtual machine](#to-build-a-virtual-machine-with-the-p4-development-tools)
     * [Accessing the VM](#download-a-virtual-machine-with-the-p4-development-tools-already-installed)
     * [To install P4 development tools on an existing system](#to-install-p4-development-tools-on-an-existing-system)
* [How to Contribute](#how-to-contribute)
* [Older tutorials](#older-tutorials)

If you are reading this while not attending a live P4 tutorial class,
see [below](#older-tutorials) for links to information about recently
given live classes.


## Introduction

Welcome to the P4 Tutorial! We've prepared a set of exercises to help
you get started with P4 programming, organized into several modules:

1. Introduction and Language Basics
   - [Basic Forwarding](./exercises/basic)<br>
     <small>In this exercise, you'll learn to implement basic IPv4 packet forwarding using P4. By extending the provided `basic.p4` skeleton, you'll develop logic for updating MAC addresses, decrementing TTL values, and forwarding packets based on predefined rules. Through practical implementation and testing on a fat-tree topology in Mininet, you'll gain insights into designing and deploying data plane logic for network switches.</small>
   
   - [Basic Tunneling](./exercises/basic_tunnel)<br>
     <small>In this exercise, you enhance an IP router implemented in P4 by adding basic tunneling support, enabling encapsulation of IP packets for customized forwarding. By introducing a new tunnel header type, you modify the switch code to handle encapsulated packets and define forwarding rules based on destination IDs. Through static control plane entries, the switch routes encapsulated packets, showcasing P4's versatility in customizing packet processing and network functionality.</small>

2. P4Runtime and the Control Plane
   - [P4Runtime](./exercises/p4runtime)<br>
     <small>This exercise involves implementing a control plane using P4Runtime to send flow entries to switches for tunneling traffic between hosts. Students modify the provided P4 program and controller script to establish connections, push P4 programs, install tunnel ingress rules, and read tunnel counters, enhancing their understanding of P4Runtime and network forwarding logic.</small>

   - [Flowcache](./exercises/flowcache)<br>
     <small> This exercise implements a program named flowcache.p4, which handles the PacketIn and PacketOut mechanisms, along with an idle timeout mechanism for table entries. In the data plane, packets are sent to the P4Runtime controller using the PacketIn. Upon receiving these packets, the controller adds an entry to the flow table. While the controller computes and installs the flow rule, PacketOut are sent to forward the packets to its destination. Once a flow entry is installed and no packets match it, the idle timeout start. Once a flow entry is installed and no packets match it, the idle timeout starts. When the timer expires, an IdleTimeoutNotification message is sent to the controller, which is responsible for reinstalling the expired flow entry.</small>

3. Monitoring and Debugging
   - [Explicit Congestion Notification](./exercises/ecn)<br>
     <small>In this tutorial, you'll enhance a basic L3 forwarding P4 program with Explicit Congestion Notification (ECN) support, enabling end-to-end notification of network congestion without packet drops. By modifying the `ecn.p4` file, you'll implement ECN logic such as updating the ECN flag based on queue length thresholds and configuring static rules for proper ECN handling, followed by testing the solution in Mininet to verify packet forwarding and ECN flag manipulation.</small>

   - [Multi-Hop Route Inspection](./exercises/mri)<br>
     <small>This tutorial aims to augment basic L3 forwarding with a simplified version of In-Band Network Telemetry (INT) called Multi-Hop Route Inspection (MRI). It guides users through extending a skeleton P4 program, `mri.p4`, to append an ID and queue length to the header stack of every packet, enabling tracking of the packet's path and queue lengths.</small>

4. Advanced Behavior
   - [Source Routing](./exercises/source_routing)<br>
     <small>This exercise aims to implement source routing, where the source host specifies the route for each packet through a stack of output ports. After configuring the P4 program, `source_routing.p4`, packets should be routed according to the specified port numbers in the stack, enabling end-to-end delivery based on the predetermined path.</small>

   - [Calculator](./exercises/calc)<br>
     <small>This tutorial guides you through implementing a basic calculator using a custom protocol header in P4. The P4 program, `calc.p4`, parses incoming calculator packets, performs the specified operation on the operands, and returns the result to the sender, enabling basic arithmetic calculations in a network switch.</small>

   - [Load Balancing](./exercises/load_balance)<br>
     <small>This exercise guides you in implementing load balancing using Equal-Cost Multipath Forwarding in a P4 program named `load_balance.p4`. It utilizes a hash function to distribute packets between two destination hosts based on a 5-tuple hash, enabling efficient traffic distribution across the network.</small>

   - [Quality of Service](./exercises/qos)<br>
     <small>This tutorial focuses on implementing Quality of Service (QoS) using Differentiated Services (Diffserv) in a P4 program named `qos.p4`. It extends basic L3 forwarding to classify and manage network traffic, providing QoS on modern IP networks by setting DiffServ flags based on traffic classes and priority.</small>

   - [Multicasting](./exercises/multicast)<br> 
     <small>This exercise involves writing a P4 program to enable a network switch to multicast packets to multiple output ports based on the destination MAC address. It requires the implementation of logic to handle multicast packets, including defining actions for packet forwarding and configuring the control plane to manage packet processing rules. Through practical implementation and testing in a Mininet environment, participants learn to enhance network traffic management and efficiency through multicast communication.</small>

5. Stateful Packet Processing
   - [Firewall](./exercises/firewall)<br>
     <small>This exercise focuses on implementing a basic stateful firewall using a P4 program named `firewall.p4`. The firewall is designed to allow communication between internal and external hosts based on predefined rules, utilizing a bloom filter for stateful packet inspection and filtering.</small>

   - [Link Monitoring](./exercises/link_monitor)<br>
     <small>This exercise focuses on implementing link monitoring within a network using P4 programming. By extending the basic IPv4 forwarding exercise, the program enables the measurement of link utilization by processing source-routed probe packets. Through the manipulation of probe packet headers and the maintenance of register arrays, the solution facilitates accurate monitoring of link utilization, which can be invaluable for network management and optimization.</small>

## Presentation

The slides are available [online](https://bit.ly/p4d2-2018-spring) and
in the [P4_tutorial.pdf](./P4_tutorial.pdf) in the tutorial directory.

A P4 Cheat Sheet is also available [online](https://drive.google.com/file/d/1Z8woKyElFAOP6bMd8tRa_Q4SA1cd_Uva/view?usp=sharing)
which contains various examples that you can refer to.

## P4 Documentation

The documentation for P4_16 and P4Runtime is available [here](https://p4.org/specifications/)

All exercises in this repository use the v1model architecture, the documentation for which is available at:
1. The BMv2 Simple Switch target document accessible [here](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md) talks mainly about the v1model architecture.
2. The include file `v1model.p4` has extensive comments and can be accessed [here](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4).

## Obtaining required software

If you are starting this tutorial at one of the proctored tutorial events,
then we've already provided you with a virtual machine that has all of
the required software installed. Ask an instructor for a USB stick with
the VM image.

Otherwise, to complete the
[exercises](https://github.com/p4lang/tutorials/tree/master/exercises),
you will need to do one of the following:

+ Download and run a virtual machine with the P4 development tools
  already installed.
+ Build a virtual machine, compiling and installing the P4 development
  tools within it.
+ Install the P4 development tools on an existing system with a
  supported version of Ubuntu Linux.
+ Install P4 development tools and also
  [P4sim](https://github.com/HapCommSys/p4sim).
  + Note: No instructions have been written yet on how to run the
    tutorials exercises using P4sim.  If your goal is to learn from
    doing the exercises, we recommend you ignore P4sim for now.

See the appropriate section below for more details on your choice.

If you have a Windows, Mac, or Linux system with a 64-bit Intel/AMD
processor architecture, or an Apple Silicon Mac, and are willing to
install and use VirtualBox to run a Linux virtual machine, then the
first option above is the quickest way to get started, followed by the
second option.  If you prefer not to use VirtualBox for some reason,
or prefer to use an existing system with a supported version of Ubuntu
Linux installed, the third option may be best for you.

### Download a virtual machine with the P4 development tools already installed

You will need a Windows, Mac, or Linux system with a 64-bit Intel/AMD
processor architecture, or an Apple Silicon Mac, with
[VirtualBox](https://virtualbox.org) installed on it.  See the table
[here](https://github.com/jafingerhut/p4-guide/blob/master/bin/README-install-troubleshooting.md)
for a list of virtual machine images that you can download, then use
VirtualBox's File->Import Appliance menu item to add the virtual
machine to those on your system.

There is one user account:
+ Username: p4 | Password: p4

### To build a virtual machine with the P4 development tools.

See the instructions [here](vm-ubuntu-24.04/README.md).

### To install P4 development tools on an existing system

There are instructions and scripts in another Github repository that
can, starting from a freshly installed Ubuntu 22.04, or 24.04 Linux
system with enough RAM and free disk space, install all of the
necessary P4 development tools to run the exercises in this
repository.  You can find those instructions and scripts
[here](https://github.com/jafingerhut/p4-guide/blob/master/bin/README-install-troubleshooting.md)
(note that you must clone a copy of that entire repository in order
for its install scripts to work).

### Install P4 development tools and also P4sim

[P4sim](https://github.com/HapCommSys/p4sim) is a lightweight,
dependency-free P4 packet-processing simulator designed for learning
and experimentation.  Unlike BMv2 or P4-DPDK, P4sim does **not**
emulate a full switch pipeline.  Instead, it provides a minimal
execution environment that evaluates P4 parser, control, and deparser
logic on user-provided packets.

P4sim is intended for:

* Running P4 programs without installing large data plane frameworks
* Quickly testing parser and control-flow behavior
* Understanding how P4 programs process packets step-by-step

P4sim is **not** a performance model and does not aim to replicate
full-featured switch behavior (such as multitable pipelines, extern
objects, or architecture-specific metadata).  It is mainly a
**teaching and debugging tool**.

To learn more or try P4sim examples, see:
[`P4sim/README.md`](./doc/P4sim/README.md)

# How to Contribute

We value and welcome new contributions. To get started, kindly look at our [Contribution Guidelines](CONTRIBUTING.md).

# Older tutorials

Multiple live tutorial classes have been given using the example code
in this repository for hands-on exercises.  For example, there is one
each April or May at the P4 workshop at Stanford University in
California, and there have been several at networking conferences such
as ACM SIGCOMM.

Please [create an issue](https://github.com/p4lang/tutorials/issues)
for this tutorials repository if you know a public link for classroom
video recordings and/or pre-built VM images that currently do not have
such a link.


## ACM SIGCOMM August 2019 Tutorial on Programming the Network Data Plane

You can find more information about the ACM SIGCOMM August 2019 Tutorial on Programming the Network Data Plane [here](https://p4.org/events/2019-08-23-p4-tutorial/)

The page linked above has a link to download a pre-built VM image used
for this class, as well as instructions to build one yourself from a
particular branch of this repository.


## P4 Developer Day, April 2019

You can find more information about the P4 Developer Day held in April 2019 [here](https://p4.org/p4-developer-day-2019/)

Both a beginner and advanced class were taught at this event.  The
page linked above contains instructions to download and install a
pre-built Linux VM that was used during the classes.


## P4 Developer Day, November 2017

This [link](https://www.youtube.com/watch?v=3DJeqS_dl_o&list=PLf7HGRMAlJBzGC58GcYpimyIs7D0nuSoo) plays the first welcome video of a 
series of 6 videos of tutorials given at this event.

More information about this event can be found
[here](https://p4.org/p4-developer-day-fall-2017/).
