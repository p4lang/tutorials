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

For installation and environment setup, see the [Installation & Usage](https://github.com/HapCommSys/p4sim/blob/main/doc/vm-env.md) guide.

Using P4sim typically involves the following steps:

1. **Develop the P4 Program**: Implement your packet processing logic in P4 (e.g., defining headers, parsers, match-action tables, and control flow).
2. **Compile the P4 Program**: Use a P4 compiler (such as `p4c`) to generate the corresponding JSON pipeline description.
3. **Create an ns-3 Simulation Script**: Write an ns-3 simulation script (e.g., in the `scratch/` directory) and specify which nodes should operate as P4-enabled switches.
4. **Configure Tables and Control Plane Logic**: Populate match-action tables and implement the required control-plane logic before or during simulation runtime.
5. **Run the Simulation**: Execute the ns-3 simulation, including traffic generation, forwarding, and observation of performance metrics.

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
