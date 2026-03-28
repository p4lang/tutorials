
# SPDX-FileCopyrightText: 2018 Contributors to the P4 Project
#
# SPDX-License-Identifier: Apache-2.0

from mininet.topo import Topo


class AppTopo(Topo):

    def __init__(self, links, latencies={}, manifest=None, target=None,
                 log_dir="/tmp", bws={}, **opts):
        Topo.__init__(self, **opts)

        nodes = sum(list(map(list, list(zip(*links)))), [])
        host_names = sorted(list(set([n for n in nodes if n[0] == 'h'])))
        sw_names = sorted(list(set([n for n in nodes if n[0] == 's'])))
        sw_ports = dict([(sw, []) for sw in sw_names])

        self._host_links = {}
        self._sw_links = dict([(sw, {}) for sw in sw_names])

        for sw_name in sw_names:
            self.addSwitch(sw_name, log_file="%s/%s.log" %(log_dir, sw_name))

        for host_name in host_names:
            host_num = int(host_name[1:])

            self.addHost(host_name)

            self._host_links[host_name] = {}
            host_links = [l for l in links if l[0]==host_name or l[1]==host_name]

            sw_idx = 0
            for link in host_links:
                sw = link[0] if link[0] != host_name else link[1]
                sw_num = int(sw[1:])
                assert sw[0]=='s', "Hosts should be connected to switches, not " + str(sw)
                host_ip = "10.0.%d.%d" % (sw_num, host_num)
                host_mac = '00:00:00:00:%02x:%02x' % (sw_num, host_num)
                delay_key = ''.join([host_name, sw])
                delay = latencies[delay_key] if delay_key in latencies else '0ms'
                bw = bws[delay_key] if delay_key in bws else None
                sw_ports[sw].append(host_name)
                self._host_links[host_name][sw] = dict(
                        idx=sw_idx,
                        host_mac = host_mac,
                        host_ip = host_ip,
                        sw = sw,
                        sw_mac = "00:00:00:00:%02x:%02x" % (sw_num, host_num),
                        sw_ip = "10.0.%d.%d" % (sw_num, 254),
                        sw_port = sw_ports[sw].index(host_name)+1
                        )
                self.addLink(host_name, sw, delay=delay, bw=bw,
                        addr1=host_mac, addr2=self._host_links[host_name][sw]['sw_mac'])
                sw_idx += 1

        for link in links: # only check switch-switch links
            sw1, sw2 = link
            if sw1[0] != 's' or sw2[0] != 's': continue

            delay_key = ''.join(sorted([sw1, sw2]))
            delay = latencies[delay_key] if delay_key in latencies else '0ms'
            bw = bws[delay_key] if delay_key in bws else None

            self.addLink(sw1, sw2, delay=delay, bw=bw)#,  max_queue_size=10)
            sw_ports[sw1].append(sw2)
            sw_ports[sw2].append(sw1)

            sw1_num, sw2_num = int(sw1[1:]), int(sw2[1:])
            sw1_port = dict(mac="00:00:00:%02x:%02x:00" % (sw1_num, sw2_num), port=sw_ports[sw1].index(sw2)+1)
            sw2_port = dict(mac="00:00:00:%02x:%02x:00" % (sw2_num, sw1_num), port=sw_ports[sw2].index(sw1)+1)

            self._sw_links[sw1][sw2] = [sw1_port, sw2_port]
            self._sw_links[sw2][sw1] = [sw2_port, sw1_port]

