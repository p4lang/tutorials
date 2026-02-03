# P4Sim: NS-3-Based P4 Simulation Environment

### Index

- [Local Deployment (ns-3.39)](#local-deployment-ns339)
- Virtual Machine as Virtual Env
  - [ns-3 Version 3.x – 3.35](#setup-ns335)
  -  [ns-3 Version 3.36 – 3.39](#setup-ns339)
- [Appendix](#appendix)

## Installation & Usage Guide

It is recommended to use a **virtual machine** with Vagrant to simplify the installation and ensure compatibility. 

## <a name="local-deployment-ns339"></a> Local Deployment (ns-3.39)

This guide walks you through setting up a local environment to run the P4Sim integrated with `ns-3.39` on Ubuntu 24.04. The full setup includes installing the behavioral model (`bmv2`), setting up SSH for remote access, and building the ns-3 project with P4Sim support. This is tested with `Ubuntu 24.04 LTS Desktop`. 

> Note: The bmv2 and P4 software installation step will take **~3 hours** and consume up to **15GB** of disk space.

---

## 1. Initialize the Working Directory

Create a workspace and install basic development tools.

```bash
sudo apt update
mkdir ~/workdir
cd ~/workdir
sudo apt install git vim cmake
```

---

##  2. Install P4 Behavioral Model (bmv2) and Dependencies

> This installs all necessary libraries and tools for P4 development (via the official `p4lang/tutorials` repo).

```bash
cd ~
git clone https://github.com/p4lang/tutorials
mkdir ~/src
cd ~/src
../tutorials/vm-ubuntu-24.04/install.sh |& tee log.txt
```

After installation, verify that `simple_switch` is available:

```bash
simple_switch
```

---

## 3. Clone and Build ns-3.39 with P4Simulator

### Step 3.1: Clone ns-3.39

```bash
cd ~/workdir
git clone https://github.com/nsnam/ns-3-dev-git.git ns3.39
cd ns3.39
git checkout ns-3.39
```

### Step 3.2: Add P4Sim Module

```bash
cd contrib
git clone https://github.com/HapCommSys/p4sim.git
cd p4sim
sudo ./set_pkg_config_env.sh
```

### Step 3.3: Configure and Build

```bash
cd ../..
./ns3 configure --enable-tests --enable-examples
./ns3 build
```

---
## 4. Configure P4 Files in Your Simulation

You may need to **manually update file paths** for P4 artifacts in your simulation code.

Example path updates:

```cpp
// p4 is the username 
std::string p4JsonPath = "/home/p4/workdir/ns3.39/contrib/p4sim/test/test_simple/test_simple.json";
std::string flowTablePath = "/home/p4/workdir/ns3.39/contrib/p4sim/test/test_simple/flowtable_0.txt";
std::string topoInput = "/home/p4/workdir/ns3.39/contrib/p4sim/test/test_simple/topo.txt";
```

Make sure these paths match your actual working directory and files.

---
##  5. Run an Example
Before running the example you need to **copy and paste** that particular example inside `ns3's scratch` folder then you can run a built-in example using:

```bash
./ns3 run scratch/"exampleA"  # You should be in the ns-3 directory before running this command.This will run exampleA (name).
```
---

## Done!

You now have a working ns-3.39 simulator with P4 integration ready for your experiments.

---

## Feedback or Issues?

If you encounter problems or have suggestions, feel free to open an issue or contact the maintainer.

**Contact:** mingyu.ma@tu-dresden.de



# Virtual Machine as virtual env ##

`p4sim` integrates an NS-3-based P4 simulation environment with virtual machine configuration files sourced via sparse checkout from the [P4Lang Tutorials repository](https://github.com/p4lang/tutorials/tree/master).  

The `vm` directory contains Vagrant configurations and bootstrap scripts for Ubuntu-based virtual machines (Ubuntu 24.04 recommended). These pre-configured environments streamline the setup process, ensuring compatibility and reducing installation issues.  

Tested with:  
- P4Lang Tutorials Commit: `7273da1c2ac2fd05cea0a9dd0504184b8c955eae`  
- Date: `2025-01-25`

Notes:  
- Ensure you have `Vagrant` and `VirtualBox` installed before running `vagrant up dev`.
- The setup script (`set_pkg_config_env.sh`) configures the required environment variables for P4Sim.
- `Ubuntu 24.04` is the recommended OS for the virtual machine.

---

## <a name="setup-ns335"></a>  Setup Instructions for ns-3 version 3.x - 3.35 (Build with `waf`)

This has been tested with ns-3 repo Tag `ns-3.35`.

### 1. Build the Virtual Machine  
```bash
# with vm-ubuntu-24.04/Vagrantfile or vm-ubuntu-20.04/Vagrantfile
vagrant up dev

sudo apt update
sudo apt install git vim

cd ~
git clone https://github.com/p4lang/tutorials
mkdir ~/src
cd ~/src
../tutorials/vm-ubuntu-24.04/install.sh |& tee log.txt
```

Please also **check the webpage**: [Introduction build venv of vm-ubuntu-24.04](https://github.com/p4lang/tutorials/tree/7273da1c2ac2fd05cea0a9dd0504184b8c955eae/vm-ubuntu-24.04#introduction), current version you need to install the tools by yourself: [install](https://github.com/p4lang/tutorials/tree/7273da1c2ac2fd05cea0a9dd0504184b8c955eae/vm-ubuntu-24.04#installing-open-source-p4-development-tools-on-the-vm)

This will create a virtual machine with name "P4 Tutorial Development" with the date. Please **test with `simple_switch` command**, to test if the `bmv2` is correct installed. Later we use the libs.

### 2. Clone the NS-3 Repository  
```bash
cd
mkdir workdir
cd workdir
git clone https://github.com/nsnam/ns-3-dev-git.git ns3.35
cd ns3.35
git checkout ns-3.35 
```

### 3. Clone & Integrate `p4sim` into NS-3  
```bash
cd /home/p4/workdir/ns3.35/contrib/
git clone https://github.com/HapCommSys/p4sim.git
```

### 4. Set Up the Environment (for external libs)
```bash
cd /home/p4/workdir/ns3.35/contrib/p4sim/ # p4sim root directory
sudo ./set_pkg_config_env.sh
```

### 5. Patch for the ns-3 code
```bash
cd ../../ # in ns-3 root directory
git apply ./contrib/p4sim/doc/changes.patch 
```

### 6. Configure & Build NS-3  
```bash
# in ns-3 root directory
./ns3 configure --enable-examples --enable-tests
./ns3 build
```

### 7. Run a Simulation Example  
```bash
./ns3 run "exampleA" # This will run exampleA (name).

# In the p4sim example, you may need to adjust the path of p4 and other files.
# For example:
# std::string p4JsonPath =
#       "/home/p4/workdir/ns3.35/contrib/p4sim/test/test_simple/test_simple.json";
#   std::string flowTablePath =
#       "/home/p4/workdir/ns3.35/contrib/p4sim/test/test_simple/flowtable_0.txt";
#   std::string topoInput = "/home/p4/workdir/ns3.35/contrib/p4sim/test/test_simple/topo.txt";
```

---

##  <a name='setup-ns339'></a> Setup Instructions for ns-3 version 3.36 - 3.39 (Build with `Cmake`)

This has been tested with ns-3 repo Tag `ns-3.39`. Because the virtual machine will build BMv2 and libs with **C++17**, and ns-3 p4simulator using the external inlucde file and libs, therefore the ns-3 also need to build with **C++17**.
The include file is: `/usr/local/include/bm`, the libs is `/usr/local/lib/libbmall.so`.


### 1. Build the Virtual Machine  
```bash
# with vm-ubuntu-24.04/Vagrantfile or vm-ubuntu-20.04/Vagrantfile
vagrant up dev

sudo apt update
sudo apt install git vim

cd ~
git clone https://github.com/p4lang/tutorials
mkdir ~/src
cd ~/src
../tutorials/vm-ubuntu-24.04/install.sh |& tee log.txt

```

Please also **check the webpage**: [Introduction build venv of vm-ubuntu-24.04](https://github.com/p4lang/tutorials/tree/7273da1c2ac2fd05cea0a9dd0504184b8c955eae/vm-ubuntu-24.04#introduction), current version you need to install the tools by yourself: [install](https://github.com/p4lang/tutorials/tree/7273da1c2ac2fd05cea0a9dd0504184b8c955eae/vm-ubuntu-24.04#installing-open-source-p4-development-tools-on-the-vm)

This will create a virtual machine with name "P4 Tutorial Development" with the date. Please **test with `simple_switch` command**, to test if the `bmv2` is correct installed. Later we use the libs.

### 2. install Cmake
```bash
sudo apt update
sudo apt install cmake

```

### 3. Clone the NS-3 Repository  
```bash
cd
mkdir workdir
cd workdir
git clone https://github.com/nsnam/ns-3-dev-git.git ns3.39
cd ns3.39
git checkout ns-3.39
```

### 4. Clone & Integrate `p4sim` into NS-3  
```bash
cd /home/p4/workdir/ns3.39/contrib/
git clone https://github.com/HapCommSys/p4sim.git
```

### 5. Set Up the Environment (for external libs)
```bash
cd /home/p4/workdir/ns3.39/contrib/p4sim/ # p4sim root directory
sudo ./set_pkg_config_env.sh
```

### 6. Configure & Build NS-3  
```bash
# in ns-3 root directory
./ns3 configure --enable-tests --enable-examples
./ns3 build
```

### 7. Run a Simulation Example  
```bash
./ns3 run "exampleA" # This will run exampleA (name).

# In the p4sim example, you may need to adjust the path of p4 and other files.
# For example:
# std::string p4JsonPath =
#       "/home/p4/workdir/ns3.35/contrib/p4sim/test/test_simple/test_simple.json";
#   std::string flowTablePath =
#       "/home/p4/workdir/ns3.35/contrib/p4sim/test/test_simple/flowtable_0.txt";
#   std::string topoInput = "/home/p4/workdir/ns3.35/contrib/p4sim/test/test_simple/topo.txt";
```

---

# Install on a local machine

Not been tested yet.

# References

[1] [add_specific_folder_with_submodule_to_a_repository](https://www.reddit.com/r/git/comments/sme7k4/add_specific_folder_with_submodule_to_a_repository/)

[2] [P4Lang Tutorials repository](https://github.com/p4lang/tutorials/tree/master)

#  <a name='appendix'></a> Appendix 

After `Install P4 Behavioral Model (bmv2) and Dependencies`, you should have that:

```bash
# For the libs
(p4dev-python-venv) mm@bb24:~$ ls /usr/local/lib/ | grep bm
libbmall.a
libbmall.la
libbmall.so
libbmall.so.0
libbmall.so.0.0.0
libbm_grpc_dataplane.a
libbm_grpc_dataplane.la
libbm_grpc_dataplane.so
libbm_grpc_dataplane.so.0
libbm_grpc_dataplane.so.0.0.0
libbmp4apps.a
libbmp4apps.la
libbmp4apps.so
libbmp4apps.so.0
libbmp4apps.so.0.0.0
libbmpi.a
libbmpi.la
libbmpi.so
libbmpi.so.0
libbmpi.so.0.0.0

# For the include files
(p4dev-python-venv) mm@bb24:~$ ls /usr/local/include/bm
bm_apps     PI                      PsaSwitch.h                 SimplePreLAG.h             SimpleSwitch.h         standard_types.h
bm_grpc     pna_nic_constants.h     psa_switch_types.h          simple_pre_lag_types.h     simple_switch_types.h  thrift
bm_runtime  PnaNic.h                simple_pre_constants.h      simple_pre_types.h         spdlog
bm_sim      pna_nic_types.h         SimplePre.h                 simple_switch              standard_constants.h
config.h    psa_switch_constants.h  simple_pre_lag_constants.h  simple_switch_constants.h  Standard.h

```

After running `sudo ./set_pkg_config_env.sh`, you should have that: (In between, we only use bm.)

```bash
# set_pkg_config_env.sh, the p4simulator module requires the first (bm)
pkg-config --list-all | grep xxx
    bm                             BMv2 - Behavioral Model
    simple_switch                  simple switch - Behavioral Model Target Simple Switch
    boost_system                   Boost System - Boost System

# SPD log from BMv2 should be blocked, ns-3 has it's own logging system.
```