<!--
SPDX-FileCopyrightText: 2024 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Creating a VM using VirtualBox and an ISO disk image with an Ubuntu Server Linux 24.04 installer

In the initial boot menu, the default choice "Try or Install Ubuntu"
should be highlighted.  Press return to continue.

Choose language.  See on-screen instructions for moving the choice
around.

Choose keyboard language.

On the page "Choose the type of installation", I leave the default
choice "Ubuntu Server" selected with an "X" as is.  I press return for
selecting "Done" at the bottom of the screen.

Network Configuration: press return for Done.

Proxy address: I do not need one for my home network, so press return
for Done.

Ubuntu archive mirror configuration: Wait a few seconds for it to test
access to the default mirror archive.  Press return for Done, assuming
that it successfully finds a mirror system to connect to.

Guided storage configuration: This can be nerve-wracking for a new
user if you are installing multiple OS's on a physical system, but
here we have created a new virtual disk just for this guest OS's full
use, so we want to allocate all of that virtual disk for this OS's
purposes.  Leave the default "X" checked on "Use an entire disk".

I usually press tab until the cursor is on the "X" next to "Set up
this disk as an LLVM group", and press the space key to uncheck that
box.  Press tab a couple more times to select "Done" near bottom of
screen, then return to proceed.

Storage configuration: Look over the info on the screen if you are
curious, but I just press return to proceed.

A "Confirm destructive action" "window" pops up.  Again, this is where
I get nervious if I am ever installing Linux on a physical system
where I want another OS to remain on a different disk partition, but
VirtualBox is restricting this VM so that it can only see the virtual
disk(s) that VirtualBox created it, and nothing else in the host OS
file system, so confidently proceed by pressing tab to highlight the
"Continue" choice, and press return.

Enter your full name, desired system name, user name, password,
etc. pressing tab to advance through the different boxes.  When ready,
press tab until "Done" is highlighted at the bottom, then press
return.

Here you might see an "Upgrade to Ubuntu Pro" configuration page.  I
always continue without upgrading to Ubuntu Pro.

SSH Configuration: I do not install an openSSH server, tab to
highlight Done, and press return to continue.

Featured server snaps: I press tab until "Done" is highlighted at the
bottom, then return to proceed, as none of the snaps presented are
things I typically want to install.  Any of them can be installed
later after the base OS is installed, with appropriate install
commands.

Updating system: This can take many minutes to complete.  Grab a cup
of coffee.  Work on something else.  Check back occasionally.  You can
tell this step is done when the top of the screen says "Installation
complete!".  Press tab to highlight "Reboot Now" near bottom of screen
and press return to proceed.

If the screen says "Please remove the installation medium, then press
ENTER:", just press return/enter key to proceed.

You will see many boot progress messages appear, and hopefully in
under 1 minute you will see a login prompt that looks like:

```
<your-system-name> login:
```

Enter your user name and password to log in.

Update any of the base OS packages that have newer versions available
with these commands:

```bash
sudo apt update
sudo apt upgrade
```

Press return if prompted to confirm the installation of new packages.

If you want to install the default Ubuntu GUI desktop:

```bash
sudo apt-get install ubuntu-desktop-minimal
```

That downloads hundreds of MBytes of packages and installs them.  When
it is complete, enter the following command to reboot the system:

```bash
sudo reboot
```

It might "pause" during the boot messages for several minutes, before
you see a GUI login window.  The first command below disables a
redundant network system service, one that significantly slows down
the system boot process if you leave it enabled.

```bash
sudo systemctl disable systemd-networkd.service
sudo apt-get install git
```

Proceed to the section titled [Installing open source P4 development
tools on the
VM](README.md#installing-open-source-p4-development-tools-on-the-vm).
