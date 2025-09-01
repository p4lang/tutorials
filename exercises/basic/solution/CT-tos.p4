/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    tos;
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

// header tcp_t {
//     bit<16> srcPort;
//     bit<16> dstPort;
//     bit<32> seqNo;
//     bit<32> ackNo;
//     bit<4>  dataOffset;
//     bit<3>  res;
//     bit<3>  ecn;
//     bit<6>  ctrl;
//     bit<16> window;
//     bit<16> checksum;
//     bit<16> urgentPtr;
// }

struct metadata {
    bit<32> rank;
    // bit<32> queue_index;
    // bit<32> tree_node_lower;
    // bit<32> tree_node_upper;
    // bit<32> left_child_lower;
    // bit<32> left_child_upper;
    // bit<32> right_child_lower;
    // bit<32> right_child_upper;
    bit<32> l1_t;
    bit<32> l2_t;
    bit<32> l3_t;
    bit<32> t;
    bit<32> cm;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

register<bit<32>>(7) cml_registers; // 7 entries for cml
register<bit<32>>(7) cmr_registers; // 7 entries for cmr

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action congruity_metric(bit<32> left_bound, bit<32> right_bound) {
        meta.cm = (left_bound >> 1) + (left_bound >> 3) + (right_bound >> 2) + (right_bound >> 3);
    }

    action threshold(bit<32> left_bound, bit<32> right_bound) {
        meta.t = (left_bound >> 2) + (left_bound >> 3) + (right_bound >> 1) + (right_bound >> 3);
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
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
            meta.rank = (bit<32>)hdr.ipv4.tos << 4;
            log_msg("Rank of the packet is: {}", {meta.rank});

            bit<32> cml_val;
            bit<32> cmr_val;

            cml_registers.read(cml_val, 0);
            cmr_registers.read(cmr_val, 0);
            threshold(cml_val, cmr_val);
            if (meta.rank > meta.t) {
                cml_registers.read(cml_val, 2);
                cmr_registers.read(cmr_val, 2);
                threshold(cml_val, cmr_val);
                if (meta.rank > meta.t) {
                    cml_registers.read(cml_val, 6);
                    cmr_registers.read(cmr_val, 6);
                    threshold(cml_val, cmr_val);
                    if (meta.rank > meta.t) {
                        cmr_registers.write(6, meta.rank);
                        standard_metadata.priority = 0;
                    } else {
                        cml_registers.write(6, meta.rank);
                        standard_metadata.priority = 1;
                    }
                    cml_registers.read(cml_val, 6);
                    cmr_registers.read(cmr_val, 6);
                    congruity_metric(cml_val, cmr_val);
                    cmr_registers.write(2, meta.cm);
                } else {
                    cml_registers.read(cml_val, 5);
                    cmr_registers.read(cmr_val, 5);
                    threshold(cml_val, cmr_val);
                    if (meta.rank > meta.t) {
                        cmr_registers.write(5, meta.rank);
                        standard_metadata.priority = 2;
                    } else {
                        cml_registers.write(5, meta.rank);
                        standard_metadata.priority = 3;
                    }
                    cml_registers.read(cml_val, 5);
                    cmr_registers.read(cmr_val, 5);
                    congruity_metric(cml_val, cmr_val);
                    cml_registers.write(2, meta.cm);
                }
                cml_registers.read(cml_val, 2);
                cmr_registers.read(cmr_val, 2);
                congruity_metric(cml_val, cmr_val);
                cml_registers.write(0, meta.cm);
            } else {
                cml_registers.read(cml_val, 1);
                cmr_registers.read(cmr_val, 1);
                threshold(cml_val, cmr_val);
                if (meta.rank > meta.t) {
                    cml_registers.read(cml_val, 4);
                    cmr_registers.read(cmr_val, 4);
                    threshold(cml_val, cmr_val);
                    if (meta.rank > meta.t) {
                        cmr_registers.write(4, meta.rank);
                        standard_metadata.priority = 4;
                    } else {
                        cml_registers.write(4, meta.rank);
                        standard_metadata.priority = 5;
                    }
                    cml_registers.read(cml_val, 4);
                    cmr_registers.read(cmr_val, 4);
                    congruity_metric(cml_val, cmr_val);
                    cmr_registers.write(1, meta.cm);
                } else {
                    cml_registers.read(cml_val, 3);
                    cmr_registers.read(cmr_val, 3);
                    threshold(cml_val, cmr_val);
                    if (meta.rank > meta.t) {
                        cmr_registers.write(3, meta.rank);
                        standard_metadata.priority = 6;
                    } else {
                        cml_registers.write(3, meta.rank);
                        standard_metadata.priority = 7;
                    }
                    cml_registers.read(cml_val, 3);
                    cmr_registers.read(cmr_val, 3);
                    congruity_metric(cml_val, cmr_val);
                    cml_registers.write(1, meta.cm);
                }
                cml_registers.read(cml_val, 1);
                cmr_registers.read(cmr_val, 1);
                congruity_metric(cml_val, cmr_val);
                cml_registers.write(0, meta.cm);
            }

            ipv4_lpm.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply { }
}

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.tos,
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
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        // packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;