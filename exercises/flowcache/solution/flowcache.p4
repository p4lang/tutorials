// SPDX-License-Identifier: Apache-2.0
/* -*- P4_16 -*- */

#include <core.p4>
#include <v1model.p4>


typedef bit<9>  egressSpec_t;
typedef bit<9>  PortId_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

const bit<16> TYPE_IPV4 = 0x800;


typedef bit<16> PortIdToController_t;

// There is nothing magic about the clone session id value of 57 to
// BMv2.  I simply picked a constant value somewhat arbitrarily. Many
// other values would also work, as long as the controller configures
// the clone session id to send a copy of the packet to the CPU_PORT.
const int CPU_PORT_CLONE_SESSION_ID = 57;

const int FL_PACKET_IN = 1;

const bit<32> NUMBER_OF_HOSTS = 4;

#define CPU_PORT 510

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ethernet_h {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_h {
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

// Note on the names of the controller_header header types:

// packet_out and packet_in are named here from the perspective of the
// controller, and that is how these messages are named in the
// P4Runtime API specification as well.

// Thus packet_out is a packet sent out of the controller to the
// switch, which becomes a packet received by the switch on port
// CPU_PORT.

// A packet sent by the switch to port CPU_PORT becomes a PacketIn
// message to the controller.

// When running with simple_switch_grpc, you must provide the
// following command line option to enable the ability for the
// software switch to receive and send such messages: --cpu-port 510

enum bit<8> ControllerOpcode_t {
    NO_OP                    = 0,
    SEND_TO_PORT_IN_OPERAND0 = 1
}

enum bit<8> PuntReason_t {
    FLOW_UNKNOWN        = 1,
    UNRECOGNIZED_OPCODE = 2
}

@controller_header("packet_out")
header packet_out_header_h {
    /* TODO: Add packet-out fields */
    ControllerOpcode_t   opcode;
    bit<8>  reserved1;
    bit<32> operand0;
}

@controller_header("packet_in")
header packet_in_header_h {
    /* TODO: Add packet-in fields */
    PortIdToController_t input_port;
    PuntReason_t         punt_reason;
    ControllerOpcode_t   opcode;
}

struct metadata_t {
    @field_list(FL_PACKET_IN)
    PortId_t             ingress_port;
    @field_list(FL_PACKET_IN)
    PuntReason_t         punt_reason;
    @field_list(FL_PACKET_IN)
    ControllerOpcode_t   opcode;
}

struct headers_t {
    packet_in_header_h  packet_in;
    packet_out_header_h packet_out;
    ethernet_h ethernet;
    ipv4_h     ipv4;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                  out headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t standard_metadata)
{
    state start {
        transition check_for_cpu_port;
    }
    state check_for_cpu_port {
        transition select (standard_metadata.ingress_port) {
            CPU_PORT: parse_controller_packet_out_header;
            default: parse_ethernet;
        }
    }
    state parse_controller_packet_out_header {
        packet.extract(hdr.packet_out);
        transition accept;
    }
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select (hdr.ethernet.etherType) {
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
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/
control MyVerifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
        verify_checksum(hdr.ipv4.isValid() && hdr.ipv4.ihl == 5,
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
            hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
    }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t standard_metadata){

    counter(NUMBER_OF_HOSTS, CounterType.packets_and_bytes) ingressPktOutCounter;

    action send_to_controller_with_details(
        PuntReason_t       punt_reason,
        ControllerOpcode_t opcode)
    {
        standard_metadata.egress_spec = CPU_PORT;
        meta.ingress_port = standard_metadata.ingress_port;
        meta.punt_reason = punt_reason;
        meta.opcode = opcode;
    }
    action send_copy_to_controller(
        PuntReason_t       punt_reason,
        ControllerOpcode_t opcode)
    {
        clone_preserving_field_list(CloneType.I2E, CPU_PORT_CLONE_SESSION_ID, FL_PACKET_IN);
        meta.ingress_port = standard_metadata.ingress_port;
        meta.punt_reason = punt_reason;
        meta.opcode = opcode;
    }
    action drop_packet() {
        mark_to_drop(standard_metadata);
    }
    action cached_action (
        PortId_t port,
        bit<1> decrement_ttl,
        bit<6> new_dscp,
        macAddr_t dst_eth_addr)
    {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = (decrement_ttl == 1) ? (hdr.ipv4.ttl |-| 1) : hdr.ipv4.ttl;
        hdr.ipv4.diffserv[7:2] = new_dscp;
        hdr.ethernet.dstAddr = dst_eth_addr;
    }
    action flow_unknown () {
        send_copy_to_controller(PuntReason_t.FLOW_UNKNOWN,
            ControllerOpcode_t.NO_OP);
        drop_packet();
    }
    table flow_cache {
        key = {
            hdr.ipv4.protocol : exact;
            hdr.ipv4.srcAddr : exact;
            hdr.ipv4.dstAddr : exact;
        }
        actions = {
            cached_action;
            drop_packet;
            flow_unknown;
        }
        /* TODO: Add support timeout */
        support_timeout = true;
        default_action = flow_unknown();
        size = 65536;
    }

    apply {
        if (hdr.packet_out.isValid()) {
            // Process packet from controller
            ingressPktOutCounter.count((bit<32>)hdr.ipv4.dstAddr[5:0]);
            switch (hdr.packet_out.opcode) {
                ControllerOpcode_t.SEND_TO_PORT_IN_OPERAND0: {
                    standard_metadata.egress_spec = (PortId_t) hdr.packet_out.operand0;
                    hdr.packet_out.setInvalid();
                }
                default: {
                    send_to_controller_with_details(
                        PuntReason_t.UNRECOGNIZED_OPCODE,
                        hdr.packet_out.opcode);
                    hdr.packet_out.setInvalid();
                }
            }
        } else if (hdr.ipv4.isValid()) {
            flow_cache.apply();
        } else {
            // This is a toy demo.  It drops all packets that are not
            // IPv4, nor PacketOut packets from the controller.
            drop_packet();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers_t hdr,
                 inout metadata_t meta,
                 inout standard_metadata_t standard_metadata){

    counter(NUMBER_OF_HOSTS, CounterType.packets_and_bytes) egressPktInCounter;

    action prepend_packet_in_hdr (
        PuntReason_t punt_reason,
        PortId_t ingress_port)
    {
        hdr.packet_in.setValid();
        hdr.packet_in.input_port = (PortIdToController_t) ingress_port;
        hdr.packet_in.punt_reason = punt_reason;
        hdr.packet_in.opcode = ControllerOpcode_t.NO_OP;
        egressPktInCounter.count((bit<32>)hdr.ipv4.dstAddr[5:0]);
    }
    apply {
        if (standard_metadata.egress_port == CPU_PORT) {
            prepend_packet_in_hdr(meta.punt_reason, meta.ingress_port);
        } else {
            // Allow the packet to go out without further processing.
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers_t hdr, inout metadata_t meta) {
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

control MyDeparser(packet_out packet, in headers_t hdr) {
    apply {
        packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
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
