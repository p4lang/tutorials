#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
import argparse
import os
import sys
import asyncio
import traceback
import time
import ipaddress

from collections import Counter
from scapy.all import *

import grpc

# Import P4Runtime lib from parent utils dir
# Probably there's a better way of doing this.
sys.path.append(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 '../../utils/'))
import p4runtime_lib.bmv2
import p4runtime_lib.helper
from p4runtime_lib.switch import ShutdownAllSwitchConnections
import p4runtime_sh.p4runtime as shp4rt

NSEC_PER_SEC = 1000 * 1000 * 1000

global_data = {}

global_data['CPU_PORT'] = 510
global_data['CPU_PORT_CLONE_SESSION_ID'] = 57
global_data['NUM_PORTS'] = 3
global_data['index'] = 0
global_data["10.0.1.1"] = "08:00:00:00:01:11"
global_data["10.0.2.2"] = "08:00:00:00:02:22"
global_data["10.0.3.3"] = "08:00:00:00:03:33"

# The lookup table is defined to simplify reachability and provide connectivity
# among hosts.  In a real-world scenario, however, you should use an algorithm
# to solve this problem more effectively.

lookup_table = {
    "s1": {
        "10.0.1.1": 1,
        "10.0.2.2": 2,
        "10.0.3.3": 3
    },
    "s2": {
        "10.0.2.2": 1,
        "10.0.1.1": 2,
        "10.0.3.3": 3
    },
    "s3": {
        "10.0.3.3": 1,
        "10.0.1.1": 2,
        "10.0.2.2": 3
    }
}

def ipv4ToInt(addr):
    """Take an argument 'addr' containing an IPv4 address written as a
    string in dotted decimal notation, e.g. '10.1.2.3', and convert it
    to an integer."""
    bytes_ = [int(b, 10) for b in addr.split('.')]
    assert len(bytes_) == 4
    # Note: The bytes() call below will throw exception if any
    # elements of bytes_ is outside of the range [0, 255]], so no need
    # to add a separate check for that here.
    return int.from_bytes(bytes(bytes_), byteorder='big')

def decodePacketInMetadata(pktin_info, packet):
    pktin_field_to_val = {}
    for md in packet.metadata:
        md_id_int = md.metadata_id
        md_val_int = int.from_bytes(md.value, byteorder='big')
        assert md_id_int in pktin_info
        md_field_info = pktin_info[md_id_int]
        pktin_field_to_val[md_field_info['name']] = md_val_int
    ret = {'metadata': pktin_field_to_val,
           'payload': packet.payload}
    print("decodePacketInMetadata: ret=%s" % (ret))
    return ret

def serializableEnumDict(p4info_data, name):
    type_info = p4info_data.type_info
    name_to_int = {}
    int_to_name = {}
    for member in type_info.serializable_enums[name].members:
        name = member.name
        int_val = int.from_bytes(member.value, byteorder='big')
        name_to_int[name] = int_val
        int_to_name[int_val] = name
    print("serializableEnumDict: name='%s' name_to_int=%s int_to_name=%s"
                  "" % (name, name_to_int, int_to_name))
    return name_to_int, int_to_name

def decodePacketInMetadata(pktin_info, packet):
    pktin_field_to_val = {}
    for md in packet.metadata:
        md_id_int = md.metadata_id
        md_val_int = int.from_bytes(md.value, byteorder='big')
        assert md_id_int in pktin_info
        md_field_info = pktin_info[md_id_int]
        pktin_field_to_val[md_field_info['name']] = md_val_int
    ret = {'metadata': pktin_field_to_val,
           'payload': packet.payload}
    print("decodePacketInMetadata: ret=%s" % (ret))
    return ret

def getObj(p4info_obj_map, obj_type, name):
    key = (obj_type, name)
    return p4info_obj_map.get(key, None)

def controllerPacketMetadataDictKeyId(p4info_obj_map, name):
    cpm_info = getObj(p4info_obj_map, "controller_packet_metadata", name)
    assert cpm_info != None
    ret = {}
    for md in cpm_info.metadata:
        id = md.id
        ret[md.id] = {'id': md.id, 'name': md.name, 'bitwidth': md.bitwidth}
    return ret

def makeP4infoObjMap(p4info_data):
    p4info_obj_map = {}
    suffix_count = Counter()
    for obj_type in ["tables", "action_profiles", "actions", "counters",
                     "direct_counters", "controller_packet_metadata"]:
        for obj in getattr(p4info_data, obj_type):
            pre = obj.preamble
            suffix = None
            for s in reversed(pre.name.split(".")):
                suffix = s if suffix is None else s + "." + suffix
                key = (obj_type, suffix)
                p4info_obj_map[key] = obj
                suffix_count[key] += 1
    for key, c in list(suffix_count.items()):
        if c > 1:
            del p4info_obj_map[key]
    return p4info_obj_map

def writeCloneSession(sw, clone_session_id, replicas):
    # Size 0 bmv2 does not support truncation for clones, issue behavioral-model #996
    clone_entry = global_data['p4info_helper'].buildCloneSessionEntry(clone_session_id, replicas, 0)
    sw.WritePREEntry(clone_entry)

def addFlowRule( ingress_sw, src_ip_addr, dst_ip_addr, protocol, port, new_dscp, decrement_ttl_bool, dst_eth_addr):
    """
    Install flow rule in flow cache table

    :param ingress_sw: The ingress switch connection.
    :param protocol: The IP protocol to match in the ingress rule.
    :param src_ip_addr: The source IP address to match in the ingress rule.
    :param dst_ip_addr: The destination IP address to match in the ingress rule.
    :param port: The output port to which the packet will be forwarded.
    :param decrement_ttl: The updated TTL value for the IP.
    :param new_dscp: The new DSCP value for the IP.
    :param dst_eth_addr: the destination Ethernet address to write in the rule
    """

    if decrement_ttl_bool:
        x = 1
    else:
        x = 0

    table_entry = global_data['p4info_helper'].buildTableEntry(
        table_name="MyIngress.flow_cache",
        match_fields={
            "hdr.ipv4.protocol": protocol,
            "hdr.ipv4.srcAddr": src_ip_addr,
            "hdr.ipv4.dstAddr": dst_ip_addr
        },
        action_name="MyIngress.cached_action",
        action_params={
            "port":           port,
            "decrement_ttl":  x,
            "new_dscp":       new_dscp,
            "dst_eth_addr":   dst_eth_addr
        },
        # TODO: Add idle timeout
        )
    ingress_sw.WriteTableEntry(table_entry)
    print("Installed ingress rule on %s" % ingress_sw.name)


def deleteFlowRule(notif):
    table_entry = global_data['p4info_helper'].buildTableEntry(
        table_name="MyIngress.flow_cache",
        match_fields={
            "hdr.ipv4.protocol": int.from_bytes(notif["idle"].table_entry[0].match[0].exact.value,byteorder='big'),
            "hdr.ipv4.srcAddr": int(ipaddress.IPv4Address(notif["idle"].table_entry[0].match[2].exact.value)),
            "hdr.ipv4.dstAddr": int(ipaddress.IPv4Address(notif["idle"].table_entry[0].match[1].exact.value))
        },
    )
    notif["sw"].DeleteTableEntry(table_entry)
    print("Deleted ingress rule on %s" % notif["sw"].name)

def packetOutMetadataList(opcode, reserved1, operand0):
    # This function does not use the generated contents of the P4Info
    # file to map PacketOut metadata fields to indices.  If you change
    # the PacketOut metadata format in the P4 program, this code must
    # be manually updated to match.
    return [{"value": opcode, "bitwidth": 8},
            {"value": reserved1, "bitwidth": 8},
            {"value": operand0, "bitwidth": 32}]

def sendPacketOut(sw ,payload, metadatas):
    # TODO: Implement the function logic to send a packet-out message
    sw.PacketOut(payload, metadatas)

def readTableRules(p4info_helper, sw):
    """
    Reads the table entries from all tables on the switch.

    :param p4info_helper: the P4Info helper
    :param sw: the switch connection
    """
    print('\n----- Reading tables rules for %s -----' % sw.name)
    for response in sw.ReadTableEntries():
        for entity in response.entities:
            entry = entity.table_entry
            # TODO For extra credit, you can use the p4info_helper to translate
            #      the IDs in the entry to names
            print(entry)
            print('-----')

def printCounter(p4info_helper, sw, counter_name, index):
    """
    Reads the specified counter at the given index from the switch. In our
    program, the index is derived from the first 6 bits of the IP destination address.
    If the index is 0, it will return all values from the counter.

    :param p4info_helper: the P4Info helper
    :param sw:  the switch connection
    :param counter_name: the name of the counter from the P4 program
    :param index: the counter index (in our case, first 6 bits of the IP)
    """
    try:
        for response in sw.ReadCounters(p4info_helper.get_counters_id(counter_name), index):
            for entity in response.entities:
                counter = entity.counter_entry
                print("%s %s %d: %d packets (%d bytes)" % (
                    sw.name, counter_name, index,
                    counter.data.packet_count, counter.data.byte_count
                ))
    except grpc.RpcError as e:
           print(f"[gRPC Error in printCounter for {sw.name}]")
           printGrpcError(e)

           if e.code() == grpc.StatusCode.UNKNOWN:
            print(f"Unknown gRPC error from {sw.name}. Retrying...")
            time.sleep(2)

    except Exception as e:
           print(f"[Unexpected Error in printCounter for {sw.name}]: {e}")
           traceback.print_exc()
           time.sleep(2)

def processPacket(message):
        payload = message["packet-in"].payload
        packet = message["packet-in"]
        print("Received PacketIn message of length %d bytes from switch %s"
              "" % (len(payload), message["sw"].name))
        if len(payload) > 0:
            i = 0
            pkt = Ether(payload)
            ip_proto = pkt[IP].proto
            ip_sa_str = pkt[IP].src
            src_ip_addr = ipv4ToInt(ip_sa_str)
            ip_da_str = pkt[IP].dst
            dst_ip_addr = ipv4ToInt(ip_da_str)
            pktinfo = decodePacketInMetadata(global_data['cpm_packetin_id2data'], packet)
            debug_packetin = False
            if debug_packetin:
                i += 1
                print("")
                print("pktin %d of %d" % (i, len(payload)))
                print("type(pktin.packet.payload)=%s"
                      "" % (type(payload)))
                print(payload)
                print(pktinfo)
                print("Scapy decode:")
                print(pkt)
                print("IPv4 proto %d (type %s)"
                      "" % (ip_proto, type(ip_proto)))
                print("IPv4 SA %08x (type %s)"
                      "" % (src_ip_addr, type(src_ip_addr)))
                print("IPv4 DA %08x (type %s)"
                      "" % (dst_ip_addr, type(dst_ip_addr)))
            if pktinfo['metadata']['punt_reason'] == global_data['punt_reason_name2int']['FLOW_UNKNOWN']:
                dest_port_int = lookup_table[message["sw"].name][ip_da_str]
                decrement_ttl_bool = True
                new_dscp_int = 5
                global_data['index'] = int(pkt[IP].dst.split('.')[3])
                dst_eth_addr = global_data[ip_da_str]
                metadatas = packetOutMetadataList(
                    global_data['controller_opcode_name2int']['SEND_TO_PORT_IN_OPERAND0'],
                    0, dest_port_int)
                sendPacketOut(message["sw"], payload, metadatas)
                addFlowRule(message["sw"],
                            src_ip_addr,
                            dst_ip_addr,
                            ip_proto,
                            dest_port_int,
                            new_dscp_int,
                            decrement_ttl_bool,
                            dst_eth_addr)

                print("For flow (SA=%s, DA=%s, proto=%d)"
                            " added table entry to send packets"
                            " to port %d with new DSCP %d"
                            "" % (ip_sa_str, ip_da_str, ip_proto,
                                  dest_port_int, new_dscp_int))

async def processNotif(notif_queue):
        while True:
            notif = await notif_queue.get()
            print(notif)
            if notif["type"] == "packet-in":
                processPacket(notif)
                printCounter(global_data ['p4info_helper'], notif["sw"], 'MyIngress.ingressPktOutCounter', global_data ['index'])
                printCounter(global_data ['p4info_helper'], notif["sw"], 'MyEgress.egressPktInCounter', global_data ['index'])
                readTableRules(global_data ['p4info_helper'], notif["sw"])
            elif notif["type"] == "idle-notif":
                deleteFlowRule(notif)

            notif_queue.task_done()

async def packetInHandler(notif_queue,sw):
    # TODO: Implement the function logic to handle a packet-in message
    while True:
        try:

        except grpc.RpcError as e:
            print(f"[gRPC Error in packetInHandler for {sw.name}]")
            printGrpcError(e)

            if e.code() == grpc.StatusCode.UNKNOWN:
                print(f"Unknown gRPC error from {sw.name}. Retrying...")
            await asyncio.sleep(2)

        except Exception as e:
            print(f"[Unexpected Error in packetInHandler for {sw.name}]: {e}")
            traceback.print_exc()
            await asyncio.sleep(2)

async def idleTimeHandler(notif_queue,sw):
    # TODO: Implement the function logic to handle idle timeout notification
    while True:


def printGrpcError(e):
    print("gRPC Error:", e.details(), end=' ')
    status_code = e.code()
    print("(%s)" % status_code.name, end=' ')
    traceback = sys.exc_info()[2]
    print("[%s:%d]" % (traceback.tb_frame.f_code.co_filename, traceback.tb_lineno))

async def main(p4info_file_path, bmv2_file_path):
    # Instantiate a P4Runtime helper from the p4info file
    global_data ['p4info_helper'] = p4runtime_lib.helper.P4InfoHelper(p4info_file_path)
    p4info_helper = global_data ['p4info_helper']

    try:
        # Create a switch connection object for s1,s2,s3;
        # this is backed by a P4Runtime gRPC connection.
        # Also, dump all P4Runtime messages sent to switch to given txt files.
        s1 = p4runtime_lib.bmv2.Bmv2SwitchConnection(
            name='s1',
            address='127.0.0.1:50051',
            device_id=0,
            proto_dump_file='logs/s1-p4runtime-requests.txt')
        s2 = p4runtime_lib.bmv2.Bmv2SwitchConnection(
            name='s2',
            address='127.0.0.1:50052',
            device_id=1,
            proto_dump_file='logs/s2-p4runtime-requests.txt')
        s3 = p4runtime_lib.bmv2.Bmv2SwitchConnection(
            name='s3',
            address='127.0.0.1:50053',
            device_id=2,
            proto_dump_file='logs/s3-p4runtime-requests.txt')

        # Send master arbitration update message to establish this controller as
        # master (required by P4Runtime before performing any other write operation)
        s1.MasterArbitrationUpdate()
        s2.MasterArbitrationUpdate()
        s3.MasterArbitrationUpdate()

        # Install the P4 program on the switches
        s1.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                       bmv2_json_file_path=bmv2_file_path)
        print("Installed P4 Program using SetForwardingPipelineConfig on s1")
        s2.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                       bmv2_json_file_path=bmv2_file_path)
        print("Installed P4 Program using SetForwardingPipelineConfig on s2")
        s3.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                       bmv2_json_file_path=bmv2_file_path)
        print("Installed P4 Program using SetForwardingPipelineConfig on s3")

        global_data['p4info_obj_map'] = makeP4infoObjMap(p4info_helper.p4info)
        global_data['cpm_packetin_id2data'] = \
        controllerPacketMetadataDictKeyId(global_data['p4info_obj_map'],
                                                   "packet_in")

        global_data['punt_reason_name2int'], global_data['punt_reason_int2name'] = \
                serializableEnumDict(p4info_helper.p4info, 'PuntReason_t')
        global_data['controller_opcode_name2int'], global_data['controller_opcode_int2name'] = \
                serializableEnumDict(p4info_helper.p4info, 'ControllerOpcode_t')

        try:
            replicas = [{ "egress_port": global_data['CPU_PORT'], "instance": 1 }]
            writeCloneSession(s1, global_data['CPU_PORT_CLONE_SESSION_ID'], replicas)
            writeCloneSession(s2, global_data['CPU_PORT_CLONE_SESSION_ID'], replicas)
            writeCloneSession(s3, global_data['CPU_PORT_CLONE_SESSION_ID'], replicas)

        except shp4rt.P4RuntimeWriteException as e:
               print("Got exception trying to configure clone session %d."
                        "  Assuming it was initialized already in an earlier"
                        " run of the controller."
                        "" % (global_data['CPU_PORT_CLONE_SESSION_ID']))

        notif_queue = asyncio.Queue()

        pkt_s1 = asyncio.create_task(packetInHandler(notif_queue, s1))
        pkt_s2 = asyncio.create_task(packetInHandler(notif_queue, s2))
        pkt_s3 = asyncio.create_task(packetInHandler(notif_queue, s3))

        idle_notif_s1 = asyncio.create_task(idleTimeHandler(notif_queue, s1))
        idle_notif_s2 = asyncio.create_task(idleTimeHandler(notif_queue, s2))
        idle_notif_s3 = asyncio.create_task(idleTimeHandler(notif_queue, s3))

        proc_notif = asyncio.create_task(processNotif(notif_queue))

        await asyncio.gather(pkt_s1,pkt_s2,pkt_s3,idle_notif_s1, idle_notif_s2, idle_notif_s3, proc_notif)

    except KeyboardInterrupt:
        print(" Shutting down.")
    except grpc.RpcError as e:
        printGrpcError(e)

    ShutdownAllSwitchConnections()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='P4Runtime Controller')
    parser.add_argument('--p4info', help='p4info proto in text format from p4c',
                        type=str, action="store", required=False,
                        default='./build/flowcache.p4.p4info.txtpb')
    parser.add_argument('--bmv2-json', help='BMv2 JSON file from p4c',
                        type=str, action="store", required=False,
                        default='./build/flowcache.json')
    args = parser.parse_args()

    if not os.path.exists(args.p4info):
        parser.print_help()
        print("\np4info file not found: %s\nHave you run 'make'?" % args.p4info)
        parser.exit(1)
    if not os.path.exists(args.bmv2_json):
        parser.print_help()
        print("\nBMv2 JSON file not found: %s\nHave you run 'make'?" % args.bmv2_json)
        parser.exit(1)
    asyncio.run(main(args.p4info, args.bmv2_json))