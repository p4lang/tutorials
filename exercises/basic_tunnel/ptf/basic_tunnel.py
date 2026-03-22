#!/usr/bin/env python3

# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Andrew Nguyen
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import logging
import os
import sys

import ptf
import ptf.testutils as tu
from ptf.base_tests import BaseTest
from scapy.all import IP, TCP, Ether, Packet, ShortField, bind_layers

TYPE_MYTUNNEL = 0x1212
TYPE_IPV4 = 0x0800


class MyTunnel(Packet):
    name = "MyTunnel"
    fields_desc = [ShortField("proto_id", TYPE_IPV4), ShortField("dst_id", 0)]


bind_layers(Ether, MyTunnel, type=TYPE_MYTUNNEL)
bind_layers(MyTunnel, IP, proto_id=TYPE_IPV4)

# Import p4runtime_lib from the tutorials repo utils directory
sys.path.append(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../utils/")
)
import p4runtime_lib.bmv2
import p4runtime_lib.helper
from p4runtime_lib.switch import ShutdownAllSwitchConnections


logger = logging.getLogger(None)
handler = logging.StreamHandler()
handler.setLevel(logging.INFO)
handler.setFormatter(
    logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
)
logger.addHandler(handler)


class BasicTunnelTest(BaseTest):
    def setUp(self):
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()

        grpc_addr = tu.test_param_get("grpcaddr") or "localhost:9559"
        p4info_txt_fname = tu.test_param_get("p4info")
        p4prog_binary_fname = tu.test_param_get("config")

        self.p4info_helper = p4runtime_lib.helper.P4InfoHelper(p4info_txt_fname)
        self.sw = p4runtime_lib.bmv2.Bmv2SwitchConnection(
            name="s1",
            address=grpc_addr,
            device_id=0,
            proto_dump_file="logs/s1-p4runtime-requests.txt",
        )
        self.sw.MasterArbitrationUpdate()
        self.sw.SetForwardingPipelineConfig(
            p4info=self.p4info_helper.p4info, bmv2_json_file_path=p4prog_binary_fname
        )

    def tearDown(self):
        ShutdownAllSwitchConnections()

    def add_ipv4_lpm_entry(self, ipv4_addr_str, prefix_len, dst_mac_str, port):
        table_entry = self.p4info_helper.buildTableEntry(
            table_name="MyIngress.ipv4_lpm",
            match_fields={"hdr.ipv4.dstAddr": (ipv4_addr_str, prefix_len)},
            action_name="MyIngress.ipv4_forward",
            action_params={"dstAddr": dst_mac_str, "port": port},
        )
        self.sw.WriteTableEntry(table_entry)

    def add_tunnel_entry(self, dst_id, port):
        table_entry = self.p4info_helper.buildTableEntry(
            table_name="MyIngress.myTunnel_exact",
            match_fields={"hdr.myTunnel.dst_id": dst_id},
            action_name="MyIngress.myTunnel_forward",
            action_params={"port": port},
        )
        self.sw.WriteTableEntry(table_entry)


class Ipv4DropOnMissTest(BasicTunnelTest):
    def runTest(self):
        pkt = tu.simple_tcp_packet(
            eth_src="ee:cd:00:7e:70:00",
            eth_dst="ee:30:ca:9d:1e:00",
            ip_dst="10.0.1.1",
            ip_ttl=64,
        )
        tu.send_packet(self, 1, pkt)
        tu.verify_no_other_packets(self)


class Ipv4ForwardTest(BasicTunnelTest):
    def runTest(self):
        in_dmac = "ee:30:ca:9d:1e:00"
        in_smac = "ee:cd:00:7e:70:00"
        ip_dst = "10.0.2.2"
        eg_port = 2
        out_dmac = "08:00:00:00:02:22"

        self.add_ipv4_lpm_entry(ip_dst, 32, out_dmac, eg_port)

        pkt = tu.simple_tcp_packet(
            eth_src=in_smac, eth_dst=in_dmac, ip_dst=ip_dst, ip_ttl=64
        )
        exp_pkt = tu.simple_tcp_packet(
            eth_src=in_dmac, eth_dst=out_dmac, ip_dst=ip_dst, ip_ttl=63
        )
        tu.send_packet(self, 1, pkt)
        tu.verify_packets(self, exp_pkt, [eg_port])


class TunnelForwardTest(BasicTunnelTest):
    def runTest(self):
        in_pkt = (
            Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff", type=TYPE_MYTUNNEL)
            / MyTunnel(proto_id=TYPE_IPV4, dst_id=2)
            / IP(src="10.0.1.1", dst="10.0.3.3", ttl=64)
            / TCP(sport=12345, dport=1234)
            / "tunnel-forward"
        )
        self.add_tunnel_entry(dst_id=2, port=3)
        tu.send_packet(self, 0, in_pkt)
        tu.verify_packets(self, in_pkt, [3])


class TunnelDropOnMissTest(BasicTunnelTest):
    def runTest(self):
        in_pkt = (
            Ether(src="00:11:22:33:44:66", dst="ff:ff:ff:ff:ff:ff", type=TYPE_MYTUNNEL)
            / MyTunnel(proto_id=TYPE_IPV4, dst_id=77)
            / IP(src="10.0.1.1", dst="10.0.3.3", ttl=64)
            / TCP(sport=12345, dport=1234)
            / "tunnel-drop"
        )
        tu.send_packet(self, 0, in_pkt)
        tu.verify_no_other_packets(self)
