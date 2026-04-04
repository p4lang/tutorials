<!--
SPDX-FileCopyrightText: 2021 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Creating a VM image for distribution to others

If you want to run `p4c` tests, see the next section on how to do so,
_before_ running the commands in this section, since the commands in
this section will delete files that take one to several hours to
create while compiling p4c, needed for running p4c tests.

Below are steps that were performed _after_ the commands in the
README.md file were run on the host OS, before creating the VM images.
Some of these steps could probably be automated with programs, and
changes to the `vagrant` scripts that can do so are welcome.  I
performed these steps manually to create a VM image, simply to avoid
the experimentation and time required to automate them.  I typically
only create new VM images once per month.

+ Log in as user p4 (password p4)
+ Click "Upgrade" in the pop-up window asking if you want to upgrade
  the system, if asked.  This will download the latest Linux kernel
  version released for Ubuntu 20.04, and other updated packages.
+ Reboot the system.
+ This is optional, but if you want to save a little disk space, use
  
  ```
  sudo apt purge <list of packages>
  ```
  
  to remove older version of Linux
  kernel, if the upgrade installed a newer one.
+ Clean the local repository of retrieved package files to free up disk space
  
  ```
  sudo apt clean
  ```


# Notes on test results for the VM

I have run the tests below on every VM image I release, before
releasing it.  You need not run them again, unless you are curious how
to do so.


## p4c testing results

Steps to run the p4c tests:

+ Log in as user vagrant (password vagrant)
+ In a new terminal, execute these commands:

If you are testing on a Release VM image, first get a copy of the p4c
source code using the following command.  This is unnecessary with a
Development VM image, as there is already a `p4c` directory with the
version of source code used to create that image already included in
the home directory of the `vagrant` user account:

```bash
# for Release VM image only 
git clone --recursive https://github.com/p4lang/p4c
```

The following steps are common for both Release and Development VM
images:

```bash
# Compile p4c again from source, since the clean.sh step reduced disk
# space by deleting the p4c/build directory.
git clone https://github.com/jafingerhut/p4-guide
cd p4c
~/p4-guide/bin/build-p4c.sh

# Run the p4c tests
cd build
make -j2 check |& tee make-check-out.txt
```

As of 2024-08-01, the p4c compiler passes all of its included tests,
except for some of the p4testgen tests (if those are enabled).


## Send ping packets in the solution to `basic` exercise of `p4lang/tutorials` repository

With the version of the [tutorials](https://github.com/p4lang/tutorials) repository
that comes pre-installed in the `p4` user account of this VM, the
following tests pass.

First log in as the user `p4` (password `p4`) and open a terminal
window.
```bash
$ cd tutorials/exercises/basic
$ cp solution/basic.p4 basic.p4
$ make run
```

If at the end of many lines of logging output you see a prompt
`mininet>`, you can try entering the command `h1 ping h2` to ping from
virtual host `h1` in the exercise to `h2`, and it should report a
successful ping every second.  It will not stop on its own.  You can
type Control-C to stop it and return to the `mininet>` prompt, and you
can type Control-D to exit from mininet and get back to the original
shell prompt.  To ensure that any processes started by the above steps
are terminated, you can run this command:
```bash
$ make stop
```


# Creating a single file image of the VM

These notes are primarily here as a reminder for people creating VM
images for distribution.  If you downloaded a VM image, these steps
were already performed, and there is no reason you need to perform
them again.

For the particular case of creating the VM named:

+ 'P4 Tutorial Development 2024-08-01'
+ created on August 1, 2024

here were the host OS details, in case it turns out that matters to
the finished VM image for some reason:

+ Windows 10 Enterprise
+ VirtualBox 6.1.30 r148432
+ Vagrant 2.2.18

In the VirtualBox GUI interface:

+ Choose menu item File -> Export Appliance ...
+ Select the VM named 'P4 Tutorial Development 2024-08-01' and click
  Continue button

+ Format
  + I used: Open Virtualization Format 1.0
  + Other available options were:
    + Open Virtualization Format 0.9
    + Open Virtualization Format 2.0
+ Target file
  + I used: /Users/andy/Documents/P4 Tutorials Development 2024-08-01.ova
+ Mac Address Policy
  + I used: Include only NAT network adapter MAC addresses
  + Other available options were:
    + Include all network adapter MAC addresses
    + Strip all network adapter MAC addresses
+ Additionally
  + Write Manifest file: checked
  + Include ISO image files: unchecked

Clicked "Continue" button.

Virtual system settings:

+ Name: P4 Tutorial 2024-08-01
+ Product: I left this blank
+ Product-URL: I left this blank
+ Vendor: P4.org - P4 Language Consortium
+ Vendor-URL: https://p4.org
+ Version: 2024-08-01
+ Description:

```
Open source P4 development tools built from latest source code as of 2024-Aug-01 and packaged into an Ubuntu 20.04 Desktop Linux VM for the AMD64 architecture.
```

+ License

```
Open source code available hosted at https://github.com/p4lang is released under the Apache 2.0 license.  Libraries it depends upon, such as Protobuf, Thrift, gRPC, Ubuntu Linux, etc. are released under their own licenses.
```

Clicked "Export" button.
