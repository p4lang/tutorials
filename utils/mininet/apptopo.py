# SPDX-FileCopyrightText: 2018 Nate Foster
#
# SPDX-License-Identifier: Apache-2.0
import functools
import operator

from mininet.topo import Topo


class AppTopo(Topo):
    def __init__(
        self,
        links,
        latencies=None,
        manifest=None,
        target=None,
        log_dir="/tmp",
        bws=None,
        **opts,
    ):
        if bws is None:
            bws = {}
        if latencies is None:
            latencies = {}
        Topo.__init__(self, **opts)

        nodes = functools.reduce(operator.iadd, list(map(list, list(zip(*links)))), [])
        host_names = sorted({n for n in nodes if n[0] == "h"})
        sw_names = sorted({n for n in nodes if n[0] == "s"})
        sw_ports = {sw: [] for sw in sw_names}

        self._host_links = {}
        self._sw_links = {sw: {} for sw in sw_names}

        for sw_name in sw_names:
            self.addSwitch(sw_name, log_file=f"{log_dir}/{sw_name}.log")

        for host_name in host_names:
            host_num = int(host_name[1:])

            self.addHost(host_name)

            self._host_links[host_name] = {}
            host_links = [x for x in links if x[0] == host_name or x[1] == host_name]

            for sw_idx, link in enumerate(host_links):
                sw = link[0] if link[0] != host_name else link[1]
                sw_num = int(sw[1:])
                assert sw[0] == "s", (
                    "Hosts should be connected to switches, not " + str(sw)
                )
                host_ip = f"10.0.{sw_num}.{host_num}"
                host_mac = f"00:00:00:00:{sw_num:02x}:{host_num:02x}"
                delay_key = f"{host_name}{sw}"
                delay = latencies.get(delay_key, "0ms")
                bw = bws.get(delay_key, None)
                sw_ports[sw].append(host_name)
                self._host_links[host_name][sw] = {
                    "idx": sw_idx,
                    "host_mac": host_mac,
                    "host_ip": host_ip,
                    "sw": sw,
                    "sw_mac": f"00:00:00:00:{sw_num:02x}:{host_num:02x}",
                    "sw_ip": f"10.0.{sw_num}.254",
                    "sw_port": sw_ports[sw].index(host_name) + 1,
                }
                self.addLink(
                    host_name,
                    sw,
                    delay=delay,
                    bw=bw,
                    addr1=host_mac,
                    addr2=self._host_links[host_name][sw]["sw_mac"],
                )

        for link in links:  # only check switch-switch links
            sw1, sw2 = link
            if sw1[0] != "s" or sw2[0] != "s":
                continue

            delay_key = "".join(sorted([sw1, sw2]))
            delay = latencies.get(delay_key, "0ms")
            bw = bws.get(delay_key, None)

            self.addLink(sw1, sw2, delay=delay, bw=bw)  # ,  max_queue_size=10)
            sw_ports[sw1].append(sw2)
            sw_ports[sw2].append(sw1)

            sw1_num, sw2_num = int(sw1[1:]), int(sw2[1:])
            sw1_port = {
                "mac": f"00:00:00:{sw1_num:02x}:{sw2_num:02x}:00",
                "port": sw_ports[sw1].index(sw2) + 1,
            }
            sw2_port = {
                "mac": f"00:00:00:{sw2_num:02x}:{sw1_num:02x}:00",
                "port": sw_ports[sw2].index(sw1) + 1,
            }

            self._sw_links[sw1][sw2] = [sw1_port, sw2_port]
            self._sw_links[sw2][sw1] = [sw2_port, sw1_port]
