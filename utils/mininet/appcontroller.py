
# SPDX-FileCopyrightText: 2018 Contributors to the P4 Project
#
# SPDX-License-Identifier: Apache-2.0

import subprocess

from shortest_path import ShortestPath


class AppController:

    def __init__(self, manifest=None, target=None, topo=None, net=None, links=None):
        self.manifest = manifest
        self.target = target
        self.conf = manifest['targets'][target]
        self.topo = topo
        self.net = net
        self.links = links

    def read_entries(self, filename):
        entries = []
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if line == '': continue
                entries.append(line)
        return entries

    def add_entries(self, thrift_port=9090, sw=None, entries=None):
        assert entries
        if sw: thrift_port = sw.thrift_port

        print('\n'.join(entries))
        p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)], stdin=subprocess.PIPE)
        p.communicate(input='\n'.join(entries))

    def read_register(self, register, idx, thrift_port=9090, sw=None):
        if sw: thrift_port = sw.thrift_port
        p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = p.communicate(input="register_read %s %d" % (register, idx))
        reg_val = [l for l in stdout.split('\n') if ' %s[%d]' % (register, idx) in l][0].split('= ', 1)[1]
        return int(reg_val)

    def start(self):
        shortestpath = ShortestPath(self.links)
        entries = {}
        for sw in self.topo.switches():
            entries[sw] = []
            if 'switches' in self.conf and sw in self.conf['switches'] and 'entries' in self.conf['switches'][sw]:
                extra_entries = self.conf['switches'][sw]['entries']
                if type(extra_entries) == list: # array of entries
                    entries[sw] += extra_entries
                else: # path to file that contains entries
                    entries[sw] += self.read_entries(extra_entries)
            #entries[sw] += [
            #    'table_set_default send_frame _drop',
            #    'table_set_default forward _drop',
            #    'table_set_default ipv4_lpm _drop']

        for host_name in self.topo._host_links:
            h = self.net.get(host_name)
            for link in list(self.topo._host_links[host_name].values()):
                sw = link['sw']
                #entries[sw].append('table_add send_frame rewrite_mac %d => %s' % (link['sw_port'], link['sw_mac']))
                #entries[sw].append('table_add forward set_dmac %s => %s' % (link['host_ip'], link['host_mac']))
                #entries[sw].append('table_add ipv4_lpm set_nhop %s/32 => %s %d' % (link['host_ip'], link['host_ip'], link['sw_port']))
                iface = h.intfNames()[link['idx']]
                # use mininet to set ip and mac to let it know the change
                h.setIP(link['host_ip'], 24)
                h.setMAC(link['host_mac'])
                #h.cmd('ifconfig %s %s hw ether %s' % (iface, link['host_ip'], link['host_mac']))
                h.cmd('arp -i %s -s %s %s' % (iface, link['sw_ip'], link['sw_mac']))
                h.cmd('ethtool --offload %s rx off tx off' % iface)
                h.cmd('ip route add %s dev %s' % (link['sw_ip'], iface))
            h.setDefaultRoute("via %s" % link['sw_ip'])

        for h in self.net.hosts:
            h_link = list(self.topo._host_links[h.name].values())[0]
            for sw in self.net.switches:
                path = shortestpath.get(sw.name, h.name, exclude=lambda n: n[0]=='h')
                if not path: continue
                if not path[1][0] == 's': continue # next hop is a switch
                sw_link = self.topo._sw_links[sw.name][path[1]]
                #entries[sw.name].append('table_add send_frame rewrite_mac %d => %s' % (sw_link[0]['port'], sw_link[0]['mac']))
                #entries[sw.name].append('table_add forward set_dmac %s => %s' % (h_link['host_ip'], sw_link[1]['mac']))
                #entries[sw.name].append('table_add ipv4_lpm set_nhop %s/32 => %s %d' % (h_link['host_ip'], h_link['host_ip'], sw_link[0]['port']))

            for h2 in self.net.hosts:
                if h == h2: continue
                path = shortestpath.get(h.name, h2.name, exclude=lambda n: n[0]=='h')
                if not path: continue
                h_link = self.topo._host_links[h.name][path[1]]
                h2_link = list(self.topo._host_links[h2.name].values())[0]
                h.cmd('ip route add %s via %s' % (h2_link['host_ip'], h_link['sw_ip']))


        print("**********")
        print("Configuring entries in p4 tables")
        for sw_name in entries:
            print()
            print("Configuring switch... %s" % sw_name)
            sw = self.net.get(sw_name)
            if entries[sw_name]:
                self.add_entries(sw=sw, entries=entries[sw_name])
        print("Configuration complete.")
        print("**********")

    def stop(self):
        pass
