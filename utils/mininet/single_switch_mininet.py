#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2013 Barefoot Networks, Inc.
#
# SPDX-License-Identifier: Apache-2.0

import argparse
from subprocess import PIPE, Popen
from time import sleep

from mininet.cli import CLI
from mininet.log import setLogLevel
from mininet.net import Mininet
from mininet.topo import Topo
from p4_mininet import P4Host, P4Switch

parser = argparse.ArgumentParser(description='Mininet demo')
parser.add_argument('--behavioral-exe', help='Path to behavioral executable',
                    type=str, action="store", required=True)
parser.add_argument('--thrift-port', help='Thrift server port for table updates',
                    type=int, action="store", default=9090)
parser.add_argument('--num-hosts', help='Number of hosts to connect to switch',
                    type=int, action="store", default=2)
parser.add_argument('--mode', choices=['l2', 'l3'], type=str, default='l3')
parser.add_argument('--json', help='Path to JSON config file',
                    type=str, action="store", required=True)
parser.add_argument('--log-file', help='Path to write the switch log file',
                    type=str, action="store", required=False)
parser.add_argument('--pcap-dump', help='Dump packets on interfaces to pcap files',
                    type=str, action="store", required=False, default=False)
parser.add_argument('--switch-config', help='simple_switch_CLI script to configure switch',
                    type=str, action="store", required=False, default=False)
parser.add_argument('--cli-message', help='Message to print before starting CLI',
                    type=str, action="store", required=False, default=False)

args = parser.parse_args()


class SingleSwitchTopo(Topo):
    "Single switch connected to n (< 256) hosts."
    def __init__(self, sw_path, json_path, log_file,
                 thrift_port, pcap_dump, n, **opts):
        # Initialize topology and default options
        Topo.__init__(self, **opts)

        switch = self.addSwitch('s1',
                                sw_path = sw_path,
                                json_path = json_path,
                                log_console = True,
                                log_file = log_file,
                                thrift_port = thrift_port,
                                enable_debugger = False,
                                pcap_dump = pcap_dump)

        for h in range(n):
            host = self.addHost('h%d' % (h + 1),
                                ip = "10.0.%d.10/24" % h,
                                mac = '00:04:00:00:00:%02x' %h)
            print("Adding host", str(host))
            self.addLink(host, switch)

def main():
    num_hosts = args.num_hosts
    mode = args.mode

    topo = SingleSwitchTopo(args.behavioral_exe,
                            args.json,
                            args.log_file,
                            args.thrift_port,
                            args.pcap_dump,
                            num_hosts)
    net = Mininet(topo = topo,
                  host = P4Host,
                  switch = P4Switch,
                  controller = None)
    net.start()


    sw_mac = ["00:aa:bb:00:00:%02x" % n for n in range(num_hosts)]

    sw_addr = ["10.0.%d.1" % n for n in range(num_hosts)]

    for n in range(num_hosts):
        h = net.get('h%d' % (n + 1))
        if mode == "l2":
            h.setDefaultRoute("dev %s" % h.defaultIntf().name)
        else:
            h.setARP(sw_addr[n], sw_mac[n])
            h.setDefaultRoute("dev %s via %s" % (h.defaultIntf().name, sw_addr[n]))

    for n in range(num_hosts):
        h = net.get('h%d' % (n + 1))
        h.describe(sw_addr[n], sw_mac[n])

    sleep(1)

    if args.switch_config is not None:
        print()
        print("Reading switch configuration script:", args.switch_config)
        with open(args.switch_config, 'r') as config_file:
            switch_config = config_file.read()

        print("Configuring switch...")
        proc = Popen(["simple_switch_CLI"], stdin=PIPE)
        proc.communicate(input=switch_config)

        print("Configuration complete.")
        print()

    print("Ready !")

    if args.cli_message is not None:
        with open(args.cli_message, 'r') as message_file:
            print(message_file.read())

    CLI( net )
    net.stop()

if __name__ == '__main__':
    setLogLevel( 'info' )
    main()
