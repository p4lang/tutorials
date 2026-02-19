<!--
SPDX-FileCopyrightText: 2024 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Introduction

Detailed steps are given later to create a new virtual machine (VM)
running Ubuntu Linux on a Windows, macOS, or Linux system in one of
these ways, listed in order from fewest steps required, to most steps
required:

+ using VirtualBox and Vagrant
+ using VirtualBox and an ISO disk image with an Ubuntu Desktop Linux installer
+ using VirtualBox and an ISO disk image with an Ubuntu Server Linux installer

| Your host system | Using VirtualBox and Vagrant | Using VirtualBox and ISO installer for Ubuntu Desktop | Using VirtualBox and ISO installer for Ubuntu Server |
| ---------------- | ---------------------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| Windows or Linux system with 64-bit Intel or AMD processor | works | works | works |
| macOS system with 64-bit Intel processor | works | works | works |
| macOS system with Apple Silicon CPU | not supported as of 2024-Dec-28 | no ISO installer for Ubuntu Desktop exists for ARM64 CPUs as of 2024-Dec-28 | works with VirtualBox 7.1.0 or later, and ISO installer for Ubuntu for ARM64 CPUs |

There are many other ways that will work, e.g. start up a new Ubuntu
Linux virtual machine on a cloud service like Amazon Web Services,
Google Cloud, or Microsoft Azure.  Or install Ubuntu Linux on a bare
metal system.  Details of these other methods are not documented here.

The `install.sh` script mentioned later will work on several supported
versions of Ubuntu Linux, even if you do not install the Ubuntu GNOME
desktop, but note that there are portions of the tutorials,
e.g. `xterm` commands, and `wireshark`, that require a graphical
desktop.

All of the detailed instructions below require first installing
[VirtualBox](https://virtualbox.org) on your host system.


# Creating a VM using VirtualBox and Vagrant

Follow the steps [here](README-create-vm-using-vagrant.md).


# Creating a VM using VirtualBox and an ISO installer disk image

Follow the steps
[here](README-create-vm-using-iso-installer.md).


# Installing open source P4 development tools on the VM

Log in as user `p4` (password `p4`).  Create a terminal window.

In that terminal, run these commands:

```bash
cd
git clone https://github.com/p4lang/tutorials
mkdir src
cd src
../tutorials/vm-ubuntu-24.04/install.sh |& tee log.txt
```

*Note* that installing these tools can take several hours, depending
upon the speed of your computer and Internet connection.  If
everything appears to have gone well, you can save some disk space by
running this script, which removes some binary files that are not
needed to run the tools:

```bash
../tutorials/vm-ubuntu-24.04/clean.sh
```
