<!--
SPDX-FileCopyrightText: 2024 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Create VM using ISO installer

## Finding the Linux installer image you want

Download the `.iso` file that installs the version of Linux that you
are interested in.  An Internet search for terms like these works for
me.  You should only pay attention to search results that are on the
ubuntu.com web site.

+ If your system has a 64-bit Intel or AMD CPU
  + Search terms: Ubuntu 24.04 amd64
  + Names of files I found on 2024-Dec-30:
    + ubuntu-24.04.1-desktop-amd64.iso
    + ubuntu-24.04.1-live-server-amd64.iso
+ If you have an Apple Silicon Mac:
  + Search terms: Ubuntu 24.04 arm64
  + Names of files I found on 2024-Dec-30:
    + ubuntu-24.04.1-live-server-arm64.iso

An installer for Ubuntu Desktop leads to fewer steps you need to do in
order to get a GUI Desktop.  As of 2024, I have only been able to find
Ubuntu Server installers for arm64 systems.  It is not difficult to
install that, and then later install the GUI Desktop.


## Creating a new VM

Start VirtualBox.  While there are command line ways to do all of this
with VirtualBox (I believe), I have never used those.  The VirtualBox
GUI takes a few minutes to use when creating a new VM, and installing
the VM takes the computer a while longer.  I estimate around 30 to 45
minutes total time to create a new VM where you install Linux from an
`.iso` file.

A nice thing about VirtualBox is that once you create a VM for the
operating system you want, if you have enough free disk space to keep
around that original VM (which I typically include "base OS" somewhere
in its name), it is very quick (30 seconds or less) to create a copy
of the base OS VM, and then install a bunch of software on that copy.
As long as you leave the original base OS VM there, it will not
change, and you can create copies of it whenever you want to try
experimenting with it.  Did you accidentally mess up the state of some
VM's system-wide configuration files, or install some weird
combination of software that seems to conflict with each other?  You
can abandon that VM image, deleting it whenever you no longer find its
contents useful, and create more clones of the original base OS VM for
further experiments.

In the VirtualBox GUI window:

+ Click the button "New"
+ In the window that appears, give a unique name to your VM,
  e.g. "Ubuntu 24.04 base OS".
+ Select the location of the `.iso` installer file that you
  downloaded.
+ I prefer to check the box "Skip Unattended Installation", and these
  instructions will assume you are doing so, too.
+ Under "Hardware" choose the amount of RAM, number of virtual CPUs,
  and hard disk space you want.
  + In 2024, I rarely want to create a VM with less than 4 GBytes
    (4096 MBytes) of RAM.  I typically select 4 processors, and 60
    GBytes of disk space.  I do _not_ click the "Pre-allocate Full
    Size" check box, since then it would immediately create a file
    that was 60 GBytes in size.  If you do not check that box,
    VirtualBox creates a disk image file that is only as large as it
    needs to be to store the files currently existing within the VM's
    file system, not the full size it might grow to later.
  + With VirtualBox, changing the RAM available to a VM after you
    create it is quick and easy, either increasing it, or decreasing
    it.  Simply shut down the VM, select the VM in the GUI, click
    "Settings", change the RAM setting, and start the VM image again.
    As long as your host OS has enough free RAM, VirtualBox can use it
    for the running VM image.  Thus, you do not need to think too hard
    when choosing the initial RAM size while creating the VM image.
  + I believe it is possible to increase the disk space allocated to
    the VM later, but I have not personally done so, and you will not
    find instructions to do so here.  It is definitely more steps than
    changing the RAM size later.  It also might be possible to
    decrease it later, but only if you can find and run the proper
    utility programs in the guest VM to shrink its files into a subset
    of the available physical disk space.  It is thus more important
    to think of the maximum disk space you expect to use within the
    VM, _or_ copy files out of it to another system to free up disk
    space during the lifetime of that VM.  Fortunately you can pick a
    large size, and choose the option not to preallocate it all when
    the VM is created.  It might be easier to create a new VM and copy
    files from the old one to the new one vs. increasing the disk
    space available to an old one.
+ Click the "Finish" button.  This closes the window you were working
  on, and a new VM image with the name you gave it has now been
  created.  It does not have the OS installed yet.
+ Select that new image and click on the button "Settings".
+ Click "General".
  + Under the "Advanced" tab, change "Shared Clipboard" to
    "Bidirectional".
+ Click "Display".
  + Under the "Screen" tab, change "Video Memory" from 16 MB to 32 MB.
+ If you want to create a shared folder on your host OS that is
  readable and writable from the guest OS, too, click "Shared Folder".
  + Click on the icon that looks like a folder with a "+" symbol on it.
  + Change "Folder Path" to choose the host OS folder you want to share.
  + Check the box for "Auto-mount".
  + If you want the guest OS to only be able to read this folder, but
    not write to it, check the box for "Read-only".
  + Click "OK" button.
+ Back in the main settings window for the VM image, click the OK
  button.


# Common steps for starting any VM image, including a new installer one

+ Select the VM image and click the "Start" button.
+ If the text is uncomfortably small for reading, select the
  VirtualBox menu item View -> Virtual Screen 1 -> Scale to 200%.
  Adjust the scale choice to your reading comfort.


# Creating a VM using VirtualBox and an ISO disk image with an Ubuntu Desktop Linux installer

Follow the steps
[here](README-create-vm-using-iso-installer-for-ubuntu-desktop.md).


# Creating a VM using VirtualBox and an ISO disk image with an Ubuntu Server Linux installer

Follow the steps
[here](README-create-vm-using-iso-installer-for-ubuntu-server.md).
