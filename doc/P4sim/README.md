# P4sim: P4-Programmable Packet Processing in ns-3

P4sim ([GitHub](https://github.com/HapCommSys/p4sim)) is a high-performance simulation framework that brings P4-programmable data plane processing into the [ns-3 network simulator](https://www.nsnam.org/). It enables researchers and developers to model, execute, and evaluate P4 programs within realistic end-to-end network simulations, tightly coupling a P4-driven packet processing engine with ns-3's flexible network modeling for fine-grained analysis of programmable networks at scale.

Key features include:

* **Behavioral accuracy**: the packet processing pipeline is based on [bmv2](https://github.com/p4lang/behavioral-model), ensuring the same reference behavior model used by the broader P4 community.
* **ns-3 integration**: network topology, traffic generation, and timing are fully managed by ns-3, making it straightforward to configure experiments or compose P4sim with other ns-3 modules.
* **bmv2 compatibility**: existing P4 programs and flow table entry scripts written for bmv2 can be used directly in P4sim without modification.
* **Accurate timing models**: packet scheduling and queuing faithfully reflect realistic network timing behavior.
* **High-performance simulation**: designed to handle large-scale network scenarios and high traffic rates in ns-3 simulation environments.

Supported P4 architecture specifications:

* V1model
* Portable Switch Architecture (PSA)
* Portable NIC Architecture (PNA) — not yet fully implemented

## Getting Started

### Installation <a name="local-deployment-ns339"></a>

The following steps set up a local environment to run P4sim with `ns-3.39` on **Ubuntu 24.04 LTS**. The setup has been tested on Ubuntu 24.04 LTS Desktop.

> **Note:** The bmv2 and P4 software installation will take **1–2 hours** and consume up to **15 GB** of disk space.

> **Why ns-3.39 or earlier?** Starting from ns-3.40, ns-3 requires C++20. However, bmv2 is currently built with C++17. P4sim therefore supports ns-3.39 and earlier versions. We plan to upgrade once a C++20-compatible bmv2 build becomes available.

#### Step 1: Initialize the Working Directory

```bash
sudo apt update
sudo apt install git vim cmake
mkdir ~/workdir
cd ~/workdir
```

#### Step 2: Install bmv2 and P4 Dependencies

Install all required libraries and tools via the official [p4lang/tutorials](https://github.com/p4lang/tutorials) repository:

```bash
cd ~
git clone https://github.com/p4lang/tutorials
mkdir ~/src && cd ~/src
../tutorials/vm-ubuntu-24.04/install.sh |& tee log.txt
```

Verify the installation:

```bash
simple_switch --version
```

#### Step 3: Clone and Build ns-3.39 with P4sim

```bash
cd ~/workdir
git clone https://github.com/nsnam/ns-3-dev-git.git ns3.39
cd ns3.39
git checkout ns-3.39
```

Add the P4sim module:

```bash
cd contrib
git clone https://github.com/HapCommSys/p4sim.git
cd p4sim && sudo ./set_pkg_config_env.sh
```

Configure and build:

```bash
cd ../..
./ns3 configure --enable-tests --enable-examples
./ns3 build
```

#### Step 4: Set the `P4SIM_DIR` Environment Variable

P4sim resolves P4 artifact paths (JSON pipelines, flow tables, topology files) via the `P4SIM_DIR` environment variable. Add it to your shell profile:

```bash
echo 'export P4SIM_DIR="$HOME/workdir/ns3.39/contrib/p4sim"' >> ~/.bashrc
source ~/.bashrc
```

> **Tip:** If `P4SIM_DIR` is not set, P4sim falls back to a path derived from the executable location, but setting it explicitly is recommended for reliability.

#### Step 5: Run an Example

```bash
./ns3 run p4-v1model-ipv4-forwarding
# ./ns3 run [example name]
```

No manual path editing is required — all examples use portable path helpers. A full list of available example names can be found in [`examples/CMakeLists.txt`](https://github.com/HapCommSys/p4sim/blob/main/examples/CMakeLists.txt).

### P4sim Development Workflow

Using P4sim typically involves the following steps:

1. **Develop the P4 Program**: Implement your packet processing logic in P4 (e.g., defining headers, parsers, match-action tables, and control flow).
2. **Compile the P4 Program**: Use `p4c` to generate the corresponding JSON pipeline description.
3. **Create an ns-3 Simulation Script**: Write a simulation script (e.g., in the `scratch/` directory) and assign P4-enabled switches to the desired nodes.
4. **Configure Control Plane Logic**: Populate match-action tables and implement the required control-plane logic before or during simulation runtime.
5. **Run and Observe**: Execute the simulation and collect performance metrics such as throughput, latency, and packet traces.

## Use Cases

In the [paper](https://dl.acm.org/doi/10.1145/3747204.3747210), P4sim is evaluated using representative networking scenarios, demonstrating its capability to model:

* Basic Tunneling — validating support for custom header encapsulations and decapsulations.
* Load Balancing — distributing traffic across multiple network paths using P4 pipelines.

More use cases can be found [here](https://github.com/HapCommSys/p4sim/blob/main/doc/examples.md), demonstrating that P4sim can serve both research and educational purposes, enabling exploration of programmable data-plane behaviors in realistic network contexts.

## Known Limitations

The packet processing rate `SwitchRate` (in packets per second, pps) must currently be configured manually for each switch. An inappropriate value can cause the switch to enter an idle polling loop, leading to wasted CPU cycles. Automatic rate tuning is planned for a future release.

## Publications & Credits

**Papers:**

- Mingyu Ma, Giang T. Nguyen. **"P4sim: Programming Protocol-independent Packet Processors in ns-3."** 2025. [[ACM DL]](https://dl.acm.org/doi/10.1145/3747204.3747210) [[arXiv]](https://arxiv.org/abs/2503.17554)

**Maintainers & Contributors:**

- **Maintainers**: [Mingyu Ma](mailto:mingyu.ma@tu-dresden.de)
- **Contributors**: Thanks to [GSoC 2025](https://summerofcode.withgoogle.com/) with [Davide](mailto:d.scano89@gmail.com) support and contributor [Vineet](https://github.com/Vineet1101).