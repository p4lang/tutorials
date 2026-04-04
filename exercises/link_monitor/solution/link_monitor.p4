// SPDX-FileCopyrightText: 2019 Contributors to the P4 Project
//
// SPDX-License-Identifier: Apache-2.0

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4  = 0x800;
const bit<16> TYPE_PROBE = 0x812;

#define MAX_HOPS 10
#define MAX_PORTS 8

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

typedef bit<48> time_t;

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

// Top-level probe header, indicates how many hops this probe
// packet has traversed so far.
header probe_t {
    bit<8> hop_cnt;
}

// The data added to the probe by each switch at each hop.
header probe_data_t {
    bit<1>    bos;
    bit<7>    swid;
    bit<8>    port;
    bit<32>   byte_cnt;
    time_t    last_time;
    time_t    cur_time;
}

// Indicates the egress port the switch should send this probe
// packet out of. There is one of these headers for each hop.
header probe_fwd_t {
    bit<8>   egress_spec;
}

struct parser_metadata_t {
    bit<8>  remaining;
}

struct metadata {
    bit<8> egress_spec;
    parser_metadata_t parser_metadata;
}

struct headers {
    ethernet_t              ethernet;
    ipv4_t                  ipv4;
    probe_t                 probe;
    probe_data_t[MAX_HOPS]  probe_data;
    probe_fwd_t[MAX_HOPS]   probe_fwd;
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
            TYPE_PROBE: parse_probe;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

    state parse_probe {
        packet.extract(hdr.probe);
        meta.parser_metadata.remaining = hdr.probe.hop_cnt + 1;
        transition select(hdr.probe.hop_cnt) {
            0: parse_probe_fwd;
            default: parse_probe_data;
        }
    }

    state parse_probe_data {
        packet.extract(hdr.probe_data.next);
        transition select(hdr.probe_data.last.bos) {
            1: parse_probe_fwd;
            default: parse_probe_data;
        }
    }

    state parse_probe_fwd {
        packet.extract(hdr.probe_fwd.next);
        meta.parser_metadata.remaining = meta.parser_metadata.remaining - 1;
        // extract the forwarding data
        meta.egress_spec = hdr.probe_fwd.last.egress_spec;
        transition select(meta.parser_metadata.remaining) {
            0: accept;
            default: parse_probe_fwd;
        }
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

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
        default_action = drop();
    }

    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
        else if (hdr.probe.isValid()) {
            standard_metadata.egress_spec = (bit<9>)meta.egress_spec;
            hdr.probe.hop_cnt = hdr.probe.hop_cnt + 1;
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   ********************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    // count the number of bytes seen since the last probe
    register<bit<32>>(MAX_PORTS) byte_cnt_reg;
    // remember the time of the last probe
    register<time_t>(MAX_PORTS) last_time_reg;

    action set_swid(bit<7> swid) {
        hdr.probe_data[0].swid = swid;
    }

    table swid {
        actions = {
            set_swid;
            NoAction;
        }
        default_action = NoAction();
    }

    apply {
        bit<32> byte_cnt;
        bit<32> new_byte_cnt;
        time_t last_time;
        time_t cur_time = standard_metadata.egress_global_timestamp;
        // increment byte cnt for this packet's port
        byte_cnt_reg.read(byte_cnt, (bit<32>)standard_metadata.egress_port);
        byte_cnt = byte_cnt + standard_metadata.packet_length;
        // reset the byte count when a probe packet passes through
        new_byte_cnt = (hdr.probe.isValid()) ? 0 : byte_cnt;
        byte_cnt_reg.write((bit<32>)standard_metadata.egress_port, new_byte_cnt);

        if (hdr.probe.isValid()) {
            // fill out probe fields
            hdr.probe_data.push_front(1);
            hdr.probe_data[0].setValid();
            if (hdr.probe.hop_cnt == 1) {
                hdr.probe_data[0].bos = 1;
            }
            else {
                hdr.probe_data[0].bos = 0;
            }
            // set switch ID field
            swid.apply();
            hdr.probe_data[0].port = (bit<8>)standard_metadata.egress_port;
            hdr.probe_data[0].byte_cnt = byte_cnt;
            // read / update the last_time_reg
            last_time_reg.read(last_time, (bit<32>)standard_metadata.egress_port);
            last_time_reg.write((bit<32>)standard_metadata.egress_port, cur_time);
            hdr.probe_data[0].last_time = last_time;
            hdr.probe_data[0].cur_time = cur_time;
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
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
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.probe);
        packet.emit(hdr.probe_data);
        packet.emit(hdr.probe_fwd);
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
