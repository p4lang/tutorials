# P4 Tutorial

## Introduction

Welcome to the P4 Tutorial! We've prepared a set of exercises to help
you get started with P4 programming, organized into several modules:

1. Introduction and Language Basics
* [Basic Forwarding](./exercises/basic)
* [Basic Tunneling](./exercises/basic_tunnel)

2. P4Runtime and the Control Plane
* [P4Runtime](./exercises/p4runtime)

3. Monitoring and Debugging
* [Explicit Congestion Notification](./exercises/ecn)
* [Multi-Hop Route Inspection](./exercises/mri)

4. Advanced Behavior
* [Source Routing](./exercises/source_routing)
* [Calculator](./exercises/other/calc)
* [Load Balancing](./exercises/load_balance)

## Presentation 

The slides are available [online](http://bit.ly/p4d2-2018-spring) and
in the P4_tutorial.pdf in the tutorial directory.

A P4 Cheat Sheet is also available [online](https://drive.google.com/file/d/1Z8woKyElFAOP6bMd8tRa_Q4SA1cd_Uva/view?usp=sharing)
which contains various examples that you can refer to.
        
## Obtaining required software

If you are starting this tutorial at the Spring 2018 P4 Developer Day,
then we've already provided you with a virtual machine that has all of
the required software installed.

Otherwise, to complete the exercises, you will need to either build a
virtual machine or install several dependencies.

To build the virtual machine:
- Install [Vagrant](https://vagrantup.com) and [VirtualBox](https://virtualbox.org)
- Clone the repository
- `cd vm`
- `vagrant up`
- Log in with username `p4` and password `p4` and issue the command `sudo shutdown -r now`
- When the machine reboots, you should have a graphical desktop machine with the required
software pre-installed.

*Note: Before running the `vagrant up` command, make sure you have enabled virtualization in your environment; otherwise you may get a "VT-x is disabled in the BIOS for both all CPU modes" error. Check [this](https://stackoverflow.com/questions/33304393/vt-x-is-disabled-in-the-bios-for-both-all-cpu-modes-verr-vmx-msr-all-vmx-disabl) for enabling it in virtualbox and/or BIOS for different system configurations.

You will need the script to execute to completion before you can see the `p4` login on your virtual machine's GUI. In some cases, the `vagrant up` command brings up only the default `vagrant` login with the password `vagrant`. Dependencies may or may not have been installed for you to proceed with running P4 programs. Please refer the existing issues to help fix your problem or create a new one if your specific problem isn't addressed there.*

To install dependencies by hand, please reference the [vm](../vm) installation script.
They contain the dependencies, versions, and installation procedure.
You should be able to run them directly on an Ubuntu 16.04 machine. 

It has two installation modes, the **native** method, used in `vagrant`, that creates a graphical environment, wallpaper, icons and pre-configured IDEs, with a dedicated user called `p4` configured to log in automatically. The **quick** method installs what is necessary to complete the tutorial and modifies the minimum of the machine in which it is installed. Only configure `vim` as IDE to develop code `p4`.

- To **native** method (Default): `sudo ./install` or `sudo ./install -n` 

- To **quick** method: `sudo ./install -q`

More info: `./install -h`


