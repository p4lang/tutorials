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

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}


struct metadata {
    bit<32> current_queue_bound;
    bit<32> rank;
    // bit<32> flow_id;    // Added to store flow ID
    // bit<32> flow_size;  // Added to store flow size
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
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
        transition select(hdr.ipv4.protocol) {
            0x06: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
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
    
    /*Queue with index 0 is the bottom one, with lowest priority*/
    register<bit<32>>(8) queue_bound;
    bit<48> in_flow_id = 0;
    bit<32> in_flow_size = 0;

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
        default_action = NoAction();
    }
    
    apply {

        if (hdr.ipv4.isValid()) {

            meta.rank = (bit<32>)hdr.ipv4.tos;

            queue_bound.read(meta.current_queue_bound, 0);
            if ((meta.current_queue_bound <= meta.rank)) {
                standard_metadata.priority = (bit<3>)0;
                queue_bound.write(0, meta.rank);
            } else {
                queue_bound.read(meta.current_queue_bound, 1);
                if ((meta.current_queue_bound <= meta.rank)) {
                    standard_metadata.priority = (bit<3>)1;
                    queue_bound.write(1, meta.rank);
                } else {
                    queue_bound.read(meta.current_queue_bound, 2);
                    if ((meta.current_queue_bound <= meta.rank)) {
                        standard_metadata.priority = (bit<3>)2;
                        queue_bound.write(2, meta.rank);
                    } else {
                        queue_bound.read(meta.current_queue_bound, 3);
                        if ((meta.current_queue_bound <= meta.rank)) {
                            standard_metadata.priority = (bit<3>)3;
                            queue_bound.write(3, meta.rank);
                        } else {
                            queue_bound.read(meta.current_queue_bound, 4);
                            if ((meta.current_queue_bound <= meta.rank)) {
                                standard_metadata.priority = (bit<3>)4;
                                queue_bound.write(4, meta.rank);
                            } else {
                                queue_bound.read(meta.current_queue_bound, 5);
                                if ((meta.current_queue_bound <= meta.rank)) {
                                    standard_metadata.priority = (bit<3>)5;
                                    queue_bound.write(5, meta.rank);
                                } else {
                                    queue_bound.read(meta.current_queue_bound, 6);
                                    if ((meta.current_queue_bound <= meta.rank)) {
                                        standard_metadata.priority = (bit<3>)6;
                                        queue_bound.write(6, meta.rank);
                                    } else {
                                        standard_metadata.priority = (bit<3>)7;
                                        queue_bound.read(meta.current_queue_bound, 7);

                                        /*Blocking reaction*/
                                        if(meta.current_queue_bound > meta.rank) {
                                            bit<32> cost = meta.current_queue_bound - meta.rank;

                                            /*Decrease the bound of all the following queues a factor equal to the cost of the blocking*/
                                            queue_bound.read(meta.current_queue_bound, 0);			    
                                            queue_bound.write(0, (bit<32>)(meta.current_queue_bound-cost));
                                            queue_bound.read(meta.current_queue_bound, 1);			    
                                            queue_bound.write(1, (bit<32>)(meta.current_queue_bound-cost));
                                            queue_bound.read(meta.current_queue_bound, 2);			    
                                            queue_bound.write(2, (bit<32>)(meta.current_queue_bound-cost));
                                            queue_bound.read(meta.current_queue_bound, 3);			    
                                            queue_bound.write(3, (bit<32>)(meta.current_queue_bound-cost));
                                            queue_bound.read(meta.current_queue_bound, 4);			    
                                            queue_bound.write(4, (bit<32>)(meta.current_queue_bound-cost));
                                            queue_bound.read(meta.current_queue_bound, 5);			    
                                            queue_bound.write(5, (bit<32>)(meta.current_queue_bound-cost));
                                            queue_bound.read(meta.current_queue_bound, 6);			    
                                            queue_bound.write(6, (bit<32>)(meta.current_queue_bound-cost));			    
                                            queue_bound.write(7, meta.rank);
                                        } else {
                                            queue_bound.write(7, meta.rank);
                                        }
                                    }
                                }
			                }
                        }
                    }
                }
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
    apply {
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
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
        packet.emit(hdr.tcp);
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