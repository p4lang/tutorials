<!--
SPDX-FileCopyrightText: 2024 Contributors to the P4 Project

SPDX-License-Identifier: Apache-2.0
-->

# Creating a VM using VirtualBox and an ISO disk image with an Ubuntu Desktop Linux 24.04 installer

In the initial boot menu, the default choice "Try or Install Ubuntu"
should be highlighted.  Press return to continue.

Choose your language.  Click Next button.

In "Accessibility", I usually do not change any of the defaults.  You
might want to.  Click Next button when ready to continue.

Select your keyboard layout.  Click Next button.

In "Internet connection" screen, you will likely see the default
choice as "Use wired connection", and there is a greyed-out
unselectable choice "No Wi-Fi devices connected".  This is the case
even if the host system has no wired network connection, only Wi-Fi.
The reason you see these choices is that as far as the VM is
concerned, it detects only a virtual wired Ethernet adapter, created
by VirtualBox, and does not see the host system's physical Wi-Fi
device.  This is normal.  Click the Next button to proceed.

In "Try or Install Ubuntu", select "Install Ubuntu".  Click the Next
button.

In "Type of installation", select "Interactive Installation".  At
least, that is what these instructions are written for.  If you want
to try an Automated installation, feel free to do so, but don't expect
the steps to be documented here.  Click the Next button.

In "Applications" window, select "Default selection", and click Next.

In "Optimise your computer" window, I leave the boxes unchecked, and
click Next.

In "Disk setup" window, select "Erase disk and install Ubuntu", and
click Next.

In "Create your account" window, enter your full name, desired system
name, user name, and password.  I prefer to uncheck the box next to
"Require my password to log in", as my host system is intended to keep
the computer secure with requiring a password to log in, with screen
lock after a timeout if you desire.  Repeating that for the guest OS
is just annoying to me.  Click Next button to continue.

In "Select your timezone" window, click on the map your approximate
location, or edit the contents of the text boxes labeled "Location" or
"Timezone".  Click Next to continue.

In "Ready to install" window, click "Install" button.

Installation can take several minutes.  Be patient.  Eventually you
should see a window titled "Installation complete".  Click the
"Restart now" button.

If in a boot screen you see the message "Please remove this
installation medium, then press ENTER:", just press return to
continue.

Proceed to the section titled [Installing open source P4 development
tools on the
VM](README.md#installing-open-source-p4-development-tools-on-the-vm).
