#!/usr/bin/env python3

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

import logging

import ptf
import ptf.testutils as tu
from ptf.base_tests import BaseTest
import p4runtime_sh.shell as sh
import p4runtime_shell_utils as shu


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
        grpc_addr = tu.test_param_get("grpcaddr")
        if grpc_addr is None:
            grpc_addr = 'localhost:9559'
        p4info_txt_fname = tu.test_param_get("p4info")
        p4prog_binary_fname = tu.test_param_get("config")
        sh.setup(device_id=0,
                 grpc_addr=grpc_addr,
                 election_id=(0, 1),
                 config=sh.FwdPipeConfig(p4info_txt_fname, p4prog_binary_fname),
                 verbose=False)

    def tearDown(self):
        logging.debug("BasicFwdTest.tearDown()")
        sh.teardown()


######################################################################
# Helper function to add entries to ipv4_lpm table
######################################################################

def add_ipv4_lpm_entry(ipv4_addr_str, prefix_len, dst_mac_str, port):
    te = sh.TableEntry('MyIngress.ipv4_lpm')(action='MyIngress.ipv4_forward')
    te.match['hdr.ipv4.dstAddr'] = '%s/%d' % (ipv4_addr_str, prefix_len)
    te.action['dstAddr'] = dst_mac_str
    te.action['port'] = '%d' % port
    te.insert()


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
        add_ipv4_lpm_entry(ip_dst, 32, out_dmac, eg_port)

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
            add_ipv4_lpm_entry(e['ip_dst'], e['prefix_len'],
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
