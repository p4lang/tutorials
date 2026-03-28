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

### High-Performance Simulation with P4sim

**Some of the examples have results and plots for analysis in [link](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result), include the `parameters`, `pcaps` for running, please have a look with more detail.**

| Name | Description | ns-3 script | p4 script |
|-----|-------------|--------------|------|
| [p4-basic-example](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-basic-example) | [basic](https://github.com/p4lang/tutorials/tree/master/exercises/basic) example | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-basic-example.cc) | basic pipeline verification [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/p4_basic) |
| [p4-basic-tunnel](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-basic-tunnel) | [basic tunnel](https://github.com/p4lang/tutorials/tree/master/exercises/basic_tunnel) example | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-basic-tunnel.cc) | encapsulation / decapsulation test [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/basic_tunnel) |
| [p4-fat-tree](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-fat-tree) | fat tree topo testing | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/topo-fattree.cc) | multi-switch forwarding validation [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/fat-tree) |
| [p4-firewall](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-firewall) | [firewall](https://github.com/p4lang/tutorials/tree/master/exercises/firewall) example | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-firewall.cc) | ACL rule verification [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/firewall) |
| [p4-psa-ipv4-forwarding](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-psa-ipv4-forwarding) | ipv4 forwarding in psa arch | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-psa-ipv4-forwarding.cc) | PSA pipeline example [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/simple_psa) |
| [p4-spine-leaf-topo](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-spine-leaf-topo) | Spine leaf topo testing | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-spine-leaf-topo.cc) | datacenter fabric test [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/load_balance) |
| [p4-v1model-ipv4-forwarding](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/examples_test_result/p4-v1model-ipv4-forwarding) | ipv4 forwarding in v1model arch | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-v1model-ipv4-forwarding.cc) | v1model pipeline example [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/ipv4_forward) |
| [queuing_test](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/queuing_test) | queuing test with qos priority mapping | [ns-3](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-queue-test.cc) | QoS / priority queue experiment [p4src](https://github.com/HapCommSys/p4sim/tree/main/examples/p4src/qos) |

Following we give two simple examples: `IPv4 Forwarding Benchmark` and `Queue and Packet Scheduling Test` show how run the examples.

#### IPv4 Forwarding Benchmark

The following example runs a simple two-host, one-switch topology with IPv4 forwarding at 100 Mbps. The link rate (`--linkRate`), application data rate (`--appDataRate`), and other parameters can be tuned as needed:

```bash
# V1model architecture (recommended)
./ns3 run p4-v1model-ipv4-forwarding -- \
  --pktSize=1000 --appDataRate=100Mbps --linkRate=1000Mbps \
  --switchRate=100000 --linkDelay=0.01ms --simDuration=20 --pcap=false

# PSA (Portable Switch Architecture)
./ns3 run p4-psa-ipv4-forwarding -- \
  --pktSize=1000 --appDataRate=100Mbps --linkRate=1000Mbps \
  --switchRate=100000 --linkDelay=0.01ms --simDuration=20 --pcap=false

# PNA (Portable NIC Architecture) — not yet fully implemented
./ns3 run p4-pna-ipv4-forwarding -- \
  --pktSize=1000 --appDataRate=100Mbps --linkRate=1000Mbps \
  --switchRate=100000 --linkDelay=0.01ms --simDuration=20 --pcap=false
```

#### Queue and Packet Scheduling Test

To evaluate queuing and packet scheduling behavior on the P4 switch, use the [`p4-queue-test.cc`](https://github.com/HapCommSys/p4sim/blob/main/examples/p4-queue-test.cc) example. It accepts three independent traffic flows with configurable data rates:

```bash
./ns3 run p4-queue-test -- \
  --pktSize=1000 \
  --appDataRate1=3Mbps --appDataRate2=4Mbps --appDataRate3=5Mbps \
  --switchRate=1500 --linkRate=1000Mbps --queueSize=1000 --pcap=true
```

Mote details, results, plots please check [Queue Status Monitor](https://github.com/HapCommSys/p4sim-artifact-icns3/tree/main/queuing_test)

> **Note:** Per-port queue parameters cannot currently be set via command-line arguments. Instead, configure them at runtime using the P4 controller command interface:
>
> ```
> set_queue_depth <depth_in_packets> <port_number>
> set_queue_rate  <rate_in_pps>      <port_number>
> ```
>
> Flow priorities are assigned through match-action table entries that map UDP port numbers to priority levels:
>
> ```
> table_add udp_priority set_priority 2000              => 0x1
> table_add udp_priority set_priority <udp_port_number> => <priority>
> ```
>
> The bottleneck processing rate is controlled by `--switchRate` (in packets per second). In this example it is set to `1500`.

After the simulation completes, inspect the generated PCAP files to observe how packets from the three flows are scheduled and reordered according to their assigned priorities.

## Known Limitations

The packet processing rate `SwitchRate` (in packets per second, pps) must currently be configured manually for each switch. An inappropriate value can cause the switch to enter an idle polling loop, leading to wasted CPU cycles. Automatic rate tuning is planned for a future release.

## Publications & Credits

**Papers:**

- Mingyu Ma, Giang T. Nguyen. **"P4sim: Programming Protocol-independent Packet Processors in ns-3."** 2025. [[ACM DL]](https://dl.acm.org/doi/10.1145/3747204.3747210) [[arXiv]](https://arxiv.org/abs/2503.17554)

**Maintainers & Contributors:**

- **Maintainers**: [Mingyu Ma](mailto:mingyu.ma@tu-dresden.de)
- **Contributors**: Thanks to [GSoC 2025](https://summerofcode.withgoogle.com/) with [Davide](mailto:d.scano89@gmail.com) support and contributor [Vineet](https://github.com/Vineet1101).
