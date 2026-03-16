/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
 * Exercise: ACL Firewall with Traffic Monitoring Counters
 *
 * In this exercise you will implement:
 *   1. IPv4 forwarding using LPM (Longest Prefix Match)
 *   2. A stateless ACL table that blocks specific source IP addresses
 *   3. Three indirect counters to monitor traffic at runtime:
 *        - ipv4_counter    : forwarded packets/bytes per output port
 *        - drop_counter    : packets dropped (no matching rule)
 *        - acl_drop_counter: packets blocked by ACL rules
 *
 * Fill in all sections marked with TODO.
 *************************************************************************/

/* EtherType value for IPv4 packets */
const bit<16> TYPE_IPV4 = 0x800;

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

/*************************************************************************
 *                         H E A D E R S
 *************************************************************************/

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

struct metadata { }

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

/*************************************************************************
 *                          P A R S E R
 *************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        // TODO: Extract the Ethernet header from the packet
        // Hint: packet.extract(hdr.ethernet);
        // Then transition based on etherType:
        //   TYPE_IPV4 → parse_ipv4
        //   default   → accept
    }

    state parse_ipv4 {
        // TODO: Extract the IPv4 header from the packet
        // Then transition to accept
    }
}

/*************************************************************************
 *           C H E C K S U M   V E R I F I C A T I O N
 *************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 *               I N G R E S S   P R O C E S S I N G
 *************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    // TODO: Declare three indirect counters, each with 1024 slots,
    //       counting packets_and_bytes:
    //         - ipv4_counter     (slot = output port number)
    //         - drop_counter     (slot = 0 for all drops)
    //         - acl_drop_counter (slot = index provided by control plane)
    // Hint: counter(1024, CounterType.packets_and_bytes) ipv4_counter;

    action drop() {
        // TODO: Increment drop_counter at slot 0
        // Hint: drop_counter.count(0);

        // TODO: Mark the packet for dropping
        // Hint: mark_to_drop(standard_metadata);
    }

    action acl_drop(bit<32> index) {
        // TODO: Increment acl_drop_counter at the given index
        // Hint: acl_drop_counter.count(index);

        // TODO: Mark the packet for dropping
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        // TODO: Set the output port
        // Hint: standard_metadata.egress_spec = port;

        // TODO: Update destination MAC to next hop MAC

        // TODO: Update source MAC (set it to old dstAddr of ethernet header)

        // TODO: Decrement TTL by 1

        // TODO: Increment ipv4_counter using the egress port as slot index
        // Hint: ipv4_counter.count((bit<32>)standard_metadata.egress_spec);
    }

    // ACL table — blocks packets by source IP using exact match
    // Runs BEFORE the forwarding table
    table acl_filter {
        key = {
            // TODO: Match on source IP address using exact match
            // Hint: hdr.ipv4.srcAddr: exact;
        }
        actions = {
            acl_drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    // Forwarding table — routes packets by destination IP using LPM
    table ipv4_lpm {
        key = {
            // TODO: Match on destination IP address using lpm
            // Hint: hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    apply {
        if (hdr.ipv4.isValid()) {
            // TODO: Apply acl_filter first.
            //       If the action was acl_drop → stop (packet is already dropped).
            //       Otherwise → apply ipv4_lpm for forwarding.
            //
            // Hint: use switch(acl_filter.apply().action_run) with:
            //         acl_drop: { /* blocked */ }
            //         default:  { ipv4_lpm.apply(); }
        }
    }
}

/*************************************************************************
 *               E G R E S S   P R O C E S S I N G
 *************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *             C H E C K S U M   C O M P U T A T I O N
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
 *                        D E P A R S E R
 *************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // TODO: Emit the Ethernet header first, then the IPv4 header
        // Hint: packet.emit(hdr.ethernet);
    }
}

/*************************************************************************
 *                         S W I T C H
 *************************************************************************/

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
