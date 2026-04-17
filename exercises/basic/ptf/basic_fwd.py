#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2026 Andrew Nguyen
#
# SPDX-License-Identifier: Apache-2.0

import logging
import os
import sys

import ptf
import ptf.testutils as tu
from ptf.base_tests import BaseTest

# Import p4runtime_lib from the tutorials repo utils directory
sys.path.append(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 '../../../utils/'))
import p4runtime_lib.bmv2
import p4runtime_lib.helper
from p4runtime_lib.switch import ShutdownAllSwitchConnections


# Configure logging
logger = logging.getLogger(None)
ch = logging.StreamHandler()
ch.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)


class BasicFwdTest(BaseTest):
    def setUp(self):
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()

        logging.debug("BasicFwdTest.setUp()")

        # Get test parameters
        grpc_addr = tu.test_param_get("grpcaddr")
        if grpc_addr is None:
            grpc_addr = 'localhost:9559'
        p4info_txt_fname = tu.test_param_get("p4info")
        p4prog_binary_fname = tu.test_param_get("config")

        # Create P4Info helper for building table entries
        self.p4info_helper = p4runtime_lib.helper.P4InfoHelper(p4info_txt_fname)

        # Connect to the switch via gRPC
        self.sw = p4runtime_lib.bmv2.Bmv2SwitchConnection(
            name='s1',
            address=grpc_addr,
            device_id=0,
            proto_dump_file='logs/s1-p4runtime-requests.txt')

        # Establish as master controller
        self.sw.MasterArbitrationUpdate()

        # Load the P4 program onto the switch
        self.sw.SetForwardingPipelineConfig(
            p4info=self.p4info_helper.p4info,
            bmv2_json_file_path=p4prog_binary_fname)

    def tearDown(self):
        logging.debug("BasicFwdTest.tearDown()")
        ShutdownAllSwitchConnections()


######################################################################
# Helper function to add entries to ipv4_lpm table
######################################################################

    def add_ipv4_lpm_entry(self, ipv4_addr_str, prefix_len, dst_mac_str, port):
        table_entry = self.p4info_helper.buildTableEntry(
            table_name='MyIngress.ipv4_lpm',
            match_fields={
                'hdr.ipv4.dstAddr': (ipv4_addr_str, prefix_len)
            },
            action_name='MyIngress.ipv4_forward',
            action_params={
                'dstAddr': dst_mac_str,
                'port': port
            })
        self.sw.WriteTableEntry(table_entry)


class DropTest(BasicFwdTest):
    """Test that packets are dropped when no table entries are installed."""
    def runTest(self):
        in_dmac = 'ee:30:ca:9d:1e:00'
        in_smac = 'ee:cd:00:7e:70:00'
        ip_dst = '10.0.1.1'
        ig_port = 1

        pkt = tu.simple_tcp_packet(eth_src=in_smac, eth_dst=in_dmac,
                                   ip_dst=ip_dst, ip_ttl=64)
        tu.send_packet(self, ig_port, pkt)
        tu.verify_no_other_packets(self)


class FwdTest(BasicFwdTest):
    """Test that a packet is forwarded correctly with one table entry."""
    def runTest(self):
        in_dmac = 'ee:30:ca:9d:1e:00'
        in_smac = 'ee:cd:00:7e:70:00'
        ip_dst = '10.0.1.1'
        ig_port = 1

        eg_port = 2
        out_dmac = '08:00:00:00:02:22'

        # Add a forwarding entry
        self.add_ipv4_lpm_entry(ip_dst, 32, out_dmac, eg_port)

        # Send packet
        pkt = tu.simple_tcp_packet(eth_src=in_smac, eth_dst=in_dmac,
                                   ip_dst=ip_dst, ip_ttl=64)

        # Expected: srcAddr = old dstAddr, dstAddr = new MAC, TTL decremented
        exp_pkt = tu.simple_tcp_packet(eth_src=in_dmac, eth_dst=out_dmac,
                                       ip_dst=ip_dst, ip_ttl=63)
        tu.send_packet(self, ig_port, pkt)
        tu.verify_packets(self, exp_pkt, [eg_port])


class MultiEntryTest(BasicFwdTest):
    """Test multiple LPM entries route to different ports correctly."""
    def runTest(self):
        in_dmac = 'ee:30:ca:9d:1e:00'
        in_smac = 'ee:cd:00:7e:70:00'
        ig_port = 0

        entries = []
        entries.append({'ip_dst': '10.0.1.1',
                        'prefix_len': 32,
                        'pkt_dst': '10.0.1.1',
                        'eg_port': 1,
                        'out_dmac': '08:00:00:00:01:11'})
        entries.append({'ip_dst': '10.0.2.0',
                        'prefix_len': 24,
                        'pkt_dst': '10.0.2.99',
                        'eg_port': 2,
                        'out_dmac': '08:00:00:00:02:22'})
        entries.append({'ip_dst': '10.0.3.0',
                        'prefix_len': 24,
                        'pkt_dst': '10.0.3.1',
                        'eg_port': 3,
                        'out_dmac': '08:00:00:00:03:33'})

        # Add all entries
        for e in entries:
            self.add_ipv4_lpm_entry(e['ip_dst'], e['prefix_len'],
                                    e['out_dmac'], e['eg_port'])

        # Test each entry
        ttl_in = 64
        for e in entries:
            pkt = tu.simple_tcp_packet(eth_src=in_smac, eth_dst=in_dmac,
                                       ip_dst=e['pkt_dst'], ip_ttl=ttl_in)
            exp_pkt = tu.simple_tcp_packet(eth_src=in_dmac, eth_dst=e['out_dmac'],
                                           ip_dst=e['pkt_dst'],
                                           ip_ttl=ttl_in - 1)
            tu.send_packet(self, ig_port, pkt)
            tu.verify_packets(self, exp_pkt, [e['eg_port']])
            ttl_in -= 10


class LpmTiebreakerTest(BasicFwdTest):
    """Test that longest-prefix match wins for overlapping routes."""
    def runTest(self):
        in_dmac = 'ee:30:ca:9d:1e:00'
        in_smac = 'ee:cd:00:7e:70:00'
        ig_port = 0

        less_specific_out_dmac = '08:00:00:00:11:11'
        less_specific_eg_port = 1
        more_specific_out_dmac = '08:00:00:00:22:22'
        more_specific_eg_port = 2

        # Two overlapping routes: /16 and /24. Packet should match /24.
        self.add_ipv4_lpm_entry('10.0.0.0', 16,
                                less_specific_out_dmac, less_specific_eg_port)
        self.add_ipv4_lpm_entry('10.0.1.0', 24,
                                more_specific_out_dmac, more_specific_eg_port)

        pkt = tu.simple_tcp_packet(eth_src=in_smac, eth_dst=in_dmac,
                                   ip_dst='10.0.1.99', ip_ttl=64)
        exp_pkt = tu.simple_tcp_packet(eth_src=in_dmac, eth_dst=more_specific_out_dmac,
                                       ip_dst='10.0.1.99', ip_ttl=63)

        tu.send_packet(self, ig_port, pkt)
        tu.verify_packets(self, exp_pkt, [more_specific_eg_port])


class TtlBoundaryTest(BasicFwdTest):
    """Test forwarding behavior when input IPv4 TTL is at boundary value 1."""
    def runTest(self):
        in_dmac = 'ee:30:ca:9d:1e:00'
        in_smac = 'ee:cd:00:7e:70:00'
        ip_dst = '10.0.9.9'
        ig_port = 1

        eg_port = 3
        out_dmac = '08:00:00:00:09:99'

        self.add_ipv4_lpm_entry(ip_dst, 32, out_dmac, eg_port)

        pkt = tu.simple_tcp_packet(eth_src=in_smac, eth_dst=in_dmac,
                                   ip_dst=ip_dst, ip_ttl=1)
        exp_pkt = tu.simple_tcp_packet(eth_src=in_dmac, eth_dst=out_dmac,
                                       ip_dst=ip_dst, ip_ttl=0)

        tu.send_packet(self, ig_port, pkt)
        tu.verify_packets(self, exp_pkt, [eg_port])


class NonIpv4DropTest(BasicFwdTest):
    """Test non-IPv4 traffic bypasses IPv4 LPM forwarding logic."""
    def runTest(self):
        ig_port = 1
        pkt = tu.simple_arp_packet(
            eth_dst='ff:ff:ff:ff:ff:ff',
            eth_src='00:de:ad:be:ef:01',
            arp_op=1,
            ip_snd='10.0.1.10',
            ip_tgt='10.0.1.1',
            hw_snd='00:de:ad:be:ef:01',
            hw_tgt='00:00:00:00:00:00')

        tu.send_packet(self, ig_port, pkt)
        tu.verify_packets(self, pkt, [0])
