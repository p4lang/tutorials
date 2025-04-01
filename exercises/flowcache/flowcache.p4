/*
Copyright 2024 Andy Fingerhut (andy.fingerhut@gmail.com)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include <core.p4>
#define V1MODEL_VERSION 20200408
#include <v1model.p4>


typedef bit<48>  EthernetAddress;
typedef bit<32>  IPv4Address;
typedef bit<16>  etype_t;
typedef bit<8>   ipproto_t;

const etype_t ETYPE_IPV4      = 0x0800; /* IPv4 */

// https://en.wikipedia.org/wiki/Ethernet_frame
header ethernet_h {
    EthernetAddress dst_addr;
    EthernetAddress src_addr;
    etype_t ether_type;
}

// RFC 791
// https://en.wikipedia.org/wiki/IPv4
// https://tools.ietf.org/html/rfc791
header ipv4_h {
    bit<4>  version;            // always 4 for IPv4
    bit<4>  ihl;                // Internet header length
    bit<8>  diffserv;           // 6 bits of DSCP followed by 2-bit ECN
    bit<16> total_len;          // in bytes, including IPv4 header
    bit<16> identification;
    bit<3>  flags;              // rsvd:1, DF (don't fragment):1,
                                // MF (more fragments):1
    bit<13> frag_offset;
    bit<8>  ttl;                // time to live
    ipproto_t protocol;
    bit<16> hdr_checksum;
    IPv4Address src_addr;
    IPv4Address dst_addr;
}

#define CPU_PORT 510

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
// software switch to receive and send such messages:
//
//     --cpu-port 510

typedef bit<16> PortIdToController_t;

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
    ControllerOpcode_t   opcode;
    bit<8>  reserved1;
    bit<32> operand0;
}

@controller_header("packet_in")
header packet_in_header_h {
    PortIdToController_t input_port;
    PuntReason_t         punt_reason;
    ControllerOpcode_t   opcode;
}

bool MulticastMACAddress (in bit<48> macAddr) {
    if (macAddr[40:40] == 1) {
        return true;
    } else {
        return false;
    }
}

// There is nothing magic about the multicast group id value of 42 to
// BMv2.  I simply picked a constant value somewhat arbitrarily.  Many
// other values would also work, as long as the controller configures
// this multicast group id so that packets using it are replicated to
// all regular output ports.
typedef bit<16> McastGrpId_t;
const McastGrpId_t FLOOD_MCAST_GROUP = 42;

// There is nothing magic about the clone session id value of 57 to
// BMv2.  I simply picked a constant value somewhat arbitrarily.  Many
// other values would also work, as long as the controller configures
// the clone session id to send a copy of the packet to the CPU_PORT.
const int CPU_PORT_CLONE_SESSION_ID = 57;

const int FL_PACKET_IN = 1;

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

parser parserImpl(packet_in packet,
                  out headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t stdmeta)
{
    state start {
        transition check_for_cpu_port;
    }
    state check_for_cpu_port {
        transition select (stdmeta.ingress_port) {
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
        transition select (hdr.ethernet.ether_type) {
            ETYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

control ingressImpl(inout headers_t hdr,
                    inout metadata_t meta,
                    inout standard_metadata_t stdmeta)
{
    action send_to_controller_with_details(
        PuntReason_t       punt_reason,
        ControllerOpcode_t opcode)
    {
        stdmeta.egress_spec = CPU_PORT;
        meta.ingress_port = stdmeta.ingress_port;
        meta.punt_reason = punt_reason;
        meta.opcode = opcode;
    }
    action send_copy_to_controller(
        PuntReason_t       punt_reason,
        ControllerOpcode_t opcode)
    {
        clone_preserving_field_list(CloneType.I2E, CPU_PORT_CLONE_SESSION_ID, FL_PACKET_IN);
        meta.ingress_port = stdmeta.ingress_port;
        meta.punt_reason = punt_reason;
        meta.opcode = opcode;
    }
    action drop_packet() {
        mark_to_drop(stdmeta);
    }
    action cached_action (
        PortId_t port,
        bit<1> decrement_ttl,
        bit<6> new_dscp)
    {
        stdmeta.egress_spec = port;
        hdr.ipv4.ttl = (decrement_ttl == 1) ? (hdr.ipv4.ttl |-| 1) : hdr.ipv4.ttl;
        hdr.ipv4.diffserv[7:2] = new_dscp;
    }
    action flow_unknown () {
        send_copy_to_controller(PuntReason_t.FLOW_UNKNOWN,
            ControllerOpcode_t.NO_OP);
        drop_packet();
        // TODO: Update per-ingress-port packet counter for number of
        // packets received with unknown SMAC.
    }
    table flow_cache {
        key = {
            hdr.ipv4.protocol : exact;
            hdr.ipv4.src_addr : exact;
            hdr.ipv4.dst_addr : exact;
        }
        actions = {
            cached_action;
            drop_packet;
            flow_unknown;
        }
        support_timeout = true;
        default_action = flow_unknown();
        size = 65536;
    }

    table dbgPacketOutHdr {
        key = {
            hdr.packet_out.opcode : exact;
            // TODO  find another field
            //hdr.packet_out.reserved1 : exact;
        }
        actions = { NoAction; }
        const default_action = NoAction;
    }

    apply {
        if (hdr.packet_out.isValid()) {
            // Process packet from controller
            dbgPacketOutHdr.apply();
            switch (hdr.packet_out.opcode) {
                ControllerOpcode_t.SEND_TO_PORT_IN_OPERAND0: {
                    stdmeta.egress_spec = (PortId_t) hdr.packet_out.operand0;
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
            // TODO: Update per-input-port packet count for packets
            // dropped because they are not IPv4.
        }
    }
}

control egressImpl(inout headers_t hdr,
                   inout metadata_t meta,
                   inout standard_metadata_t stdmeta)
{
    table debug_egress_stdmeta {
        key = {
            stdmeta.ingress_port : exact;
            stdmeta.egress_spec : exact;
            stdmeta.egress_port : exact;
            stdmeta.instance_type : exact;
            stdmeta.packet_length : exact;
            //stdmeta.enq_timestamp : exact;
            //stdmeta.enq_qdepth : exact;
            //stdmeta.deq_timedelta : exact;
            //stdmeta.deq_qdepth : exact;
            //stdmeta.ingress_global_timestamp : exact;
            //stdmeta.egress_global_timestamp : exact;
            //stdmeta.mcast_grp : exact;
            //stdmeta.egress_rid : exact;
            //stdmeta.checksum_error : exact;
            //stdmeta.parser_error : exact;
            //stdmeta.priority : exact;
        }
        actions = { NoAction; }
        const default_action = NoAction();
        size = 0;
    }
    action drop_packet() {
        mark_to_drop(stdmeta);
    }
    action prepend_packet_in_hdr (
        PuntReason_t punt_reason,
        PortId_t ingress_port)
    {
        hdr.packet_in.setValid();
        hdr.packet_in.input_port = (PortIdToController_t) ingress_port;
        hdr.packet_in.punt_reason = punt_reason;
        hdr.packet_in.opcode = ControllerOpcode_t.NO_OP;
    }
    apply {
        debug_egress_stdmeta.apply();
        if (stdmeta.egress_port == CPU_PORT) {
            prepend_packet_in_hdr(meta.punt_reason, meta.ingress_port);
        } else {
            // Allow the packet to go out without further processing.
        }
    }
}

control deparserImpl(packet_out packet,
                     in headers_t hdr)
{
    apply {
        packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

control verifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
        verify_checksum(hdr.ipv4.isValid() && hdr.ipv4.ihl == 5,
            { hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr },
            hdr.ipv4.hdr_checksum, HashAlgorithm.csum16);
    }
}

control updateChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
        update_checksum(hdr.ipv4.isValid() && hdr.ipv4.ihl == 5,
            { hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr },
            hdr.ipv4.hdr_checksum, HashAlgorithm.csum16);
    }
}

V1Switch(parserImpl(),
         verifyChecksum(),
         ingressImpl(),
         egressImpl(),
         updateChecksum(),
         deparserImpl()) main;
