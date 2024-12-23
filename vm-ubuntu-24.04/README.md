# Creating a Virtual Machine (VM)

You can use a program called Vagrant to create the VM if your system
has an Intel or AMD 64-bit processor.  This is not supported if you
have a system with an ARM CPU, e.g. Apple Silicon Macs.

The section below for creating a VM without Vagrant works on all of
those systems.

Building a VM using Vagrant, and the instructions for creating a VM,
are specific to [VirtualBox](https://virtualbox.org), which you must
install first in order to use it.


## Creating the VM using Vagrant

Below are the steps to create a brand new VM using Vagrant.

+ Install
  [Vagrant](https://developer.hashicorp.com/vagrant/docs/installation)
  on your system if it is not already installed.
+ In a terminal window, change to this `vm-ubuntu-24.04` directory
  inside the `tutorials` directory.
+ Run the command below in the terminal.

```bash
vagrant up
```

Skip the next section, and proceed to the section titled "Installing
open source P4 development tools on the VM".


## Creating the VM using VirtualBox, without Vagrant

TODO

```bash
sudo apt-get install git
```


# Installing open source P4 development tools on the VM

Log in as user p4 (password p4).  Create a terminal window.

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
