/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/* EtherType value for IPv4 packets — defined by the Ethernet standard */
const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

/* Custom types for readability */
typedef bit<9>  egressSpec_t;  /* Output port number (9 bits) */
typedef bit<48> macAddr_t;     /* MAC address (48 bits = 6 bytes) */
typedef bit<32> ip4Addr_t;     /* IPv4 address (32 bits = 4 bytes) */

/* Ethernet header structure — 14 bytes total */
header ethernet_t {
    macAddr_t dstAddr;   /* Destination MAC address */
    macAddr_t srcAddr;   /* Source MAC address */
    bit<16>   etherType; /* Indicates what protocol is inside (IPv4, ARP, etc.) */
}

/* IPv4 header structure — 20 bytes total */
header ipv4_t {
    bit<4>    version;       /* IP version — always 4 for IPv4 */
    bit<4>    ihl;           /* Header length in 32-bit words */
    bit<8>    diffserv;      /* Quality of service field */
    bit<16>   totalLen;      /* Total length of IP packet including payload */
    bit<16>   identification;/* Used for packet fragmentation */
    bit<3>    flags;         /* Fragmentation flags */
    bit<13>   fragOffset;    /* Fragment offset for reassembly */
    bit<8>    ttl;           /* Time To Live — decremented at each hop */
    bit<8>    protocol;      /* Protocol inside IPv4 (TCP=6, UDP=17, etc.) */
    bit<16>   hdrChecksum;   /* Header checksum for error detection */
    ip4Addr_t srcAddr;       /* Source IP address */
    ip4Addr_t dstAddr;       /* Destination IP address */
}

/* Metadata struct — used to pass custom info between pipeline stages */
struct metadata {
    /* empty — not needed for basic forwarding */
}

/* Headers struct — groups all headers used in this program */
struct headers {
    ethernet_t   ethernet; /* Ethernet header */
    ipv4_t       ipv4;     /* IPv4 header */
}

/*************************************************************************
*********************** P A R S E R  *************************************
*************************************************************************/

/* Parser extracts raw packet bits into header structs */
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    /* Entry point — always starts here */
    state start {
        /* Extract Ethernet header from raw packet bits */
        packet.extract(hdr.ethernet);
        /* Check etherType to decide which protocol comes next */
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4; /* If IPv4 → go to parse_ipv4 state */
            default:   accept;     /* Anything else → skip to ingress */
        }
    }

    /* IPv4 parsing state — only reached if etherType == 0x800 */
    state parse_ipv4 {
        /* Extract IPv4 header from raw packet bits */
        packet.extract(hdr.ipv4);
        /* Done parsing → move to ingress processing */
        transition accept;
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

/* Checksum verification — left empty for this exercise */
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

/* Ingress control — decides what to do with each packet */
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* Counts forwarded packets and bytes per output port
	   slot index = port number (slot 1 = port 1, slot 2 = port 2, etc.) */
	counter(1024, CounterType.packets_and_bytes) ipv4_counter;

	/* Counts dropped packets and bytes — all drops go to slot 0
	   useful for monitoring how many packets had no matching rule */
	counter(1024, CounterType.packets_and_bytes) drop_counter;
	
	/* Counts packets blocked by ACL rules per source IP slot
		slot index = arbitrary index assigned by control plane */
	counter(1024, CounterType.packets_and_bytes) acl_drop_counter;
	
	
    /* Action: drop the packet */
    action drop() {
         /* Increment drop counter slot 0 — tracks all dropped packets */
			drop_counter.count(0);
			
		/* Mark packet for dropping — it will be discarded after ingress */
			mark_to_drop(standard_metadata);
    }

	
	/* Action: block packet based on ACL rule
	   called when source IP matches a blocked entry in acl_filter table */
	action acl_drop(bit<32> index) {
		/* Increment ACL drop counter at given index
		   index is provided by control plane in acl_rules.json */
		acl_drop_counter.count(index);
		/* Mark packet for dropping */
		mark_to_drop(standard_metadata);
	}

    /* Action: forward the packet to the next hop
       Parameters are provided by the control plane (s1-runtime.json):
       - dstAddr: MAC address of the next hop
       - port: output port number to send packet out from */
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        /* Set the output port — tells the switch where to send the packet */
        standard_metadata.egress_spec = port;

        /* Update destination MAC to next hop's MAC address */
        hdr.ethernet.dstAddr = dstAddr;

        /* Update source MAC to this switch's MAC address
           (old dstAddr was this switch's MAC — copy it before overwriting) */
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;

        /* Decrement TTL by 1 — standard IP forwarding rule
           prevents packets from looping forever in the network */
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;

        /* Increment the packet counter for this output port */
        ipv4_counter.count((bit<32>)standard_metadata.egress_spec);
    }

	/* ACL table — checks source IP against blocked list
	   runs BEFORE forwarding table to block unwanted traffic early
	   rules are installed by control plane via acl_rules.json */
	table acl_filter {
		key = {
			/* Match on source IP address of incoming packet */
			hdr.ipv4.srcAddr: exact;
		}
		actions = {
			acl_drop;  /* Block this source IP */
			NoAction;  /* Allow this source IP to pass through */
		}
		size = 1024;
		/* Default: allow all packets unless explicitly blocked */
		default_action = NoAction();
	}
	
    /* Forwarding table — matches destination IP and calls the right action
       Uses LPM (Longest Prefix Match) — standard IP routing lookup method
       Rules are installed by the control plane at startup */
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm; /* Match on destination IP address */
        }
        actions = {
            ipv4_forward; /* Forward to next hop */
            drop;         /* Drop the packet */
            NoAction;     /* Do nothing */
        }
        size = 1024;                 /* Maximum number of table entries */
        default_action = NoAction(); /* If no rule matches → do nothing */
    }

		apply {
			/* Only process IPv4 packets — skip non-IPv4 packets like ARP */
			if (hdr.ipv4.isValid()) {

				/* Step 1 — Run ACL check first
				   If source IP is blocked → drop immediately, skip forwarding
				   If source IP is allowed → continue to forwarding */
				switch (acl_filter.apply().action_run) {
					acl_drop: {
						/* Packet was blocked by ACL — stop processing here */
					}
					default: {
						/* Step 2 — ACL passed → now apply forwarding table
						   Look up destination IP and forward to correct port */
						ipv4_lpm.apply();
					}
			}
		}
	}
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

/* Egress control — left empty for this exercise */
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

/* Recompute IPv4 checksum after modifying the header (TTL was decremented) */
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(), /* Only update if IPv4 header exists */
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,       /* TTL was modified — checksum must be updated */
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  ********************************
*************************************************************************/

/* Deparser — reconstructs the packet from modified header structs
   Opposite of the parser — writes structs back into raw packet bits
   Order matters: must match the actual packet structure */
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet); /* Write Ethernet header first */
        packet.emit(hdr.ipv4);     /* Write IPv4 header second */
        /* Payload is automatically appended after the headers */
    }
}

/*************************************************************************
***********************  S W I T C H  ************************************
*************************************************************************/

/* Connect all pipeline stages together in the correct order */
V1Switch(
    MyParser(),          /* Stage 1: Extract headers */
    MyVerifyChecksum(),  /* Stage 2: Verify checksum */
    MyIngress(),         /* Stage 3: Forward or drop decision */
    MyEgress(),          /* Stage 4: Post-processing */
    MyComputeChecksum(), /* Stage 5: Recompute checksum */
    MyDeparser()         /* Stage 6: Reconstruct packet */
) main;