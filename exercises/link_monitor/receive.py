#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2019 Contributors to the P4 Project
#
# SPDX-License-Identifier: GPL-2.0-only
# Reason-GPL: import-scapy via probe_hdrs

from probe_hdrs import *


def expand(x):
    yield x
    while x.payload:
        x = x.payload
        yield x

def handle_pkt(pkt):
    if ProbeData in pkt:
        data_layers = [l for l in expand(pkt) if l.name=='ProbeData']
        print("")
        for sw in data_layers:
            utilization = 0 if sw.cur_time == sw.last_time else 8.0*sw.byte_cnt/(sw.cur_time - sw.last_time)
            print("Switch {} - Port {}: {} Mbps".format(sw.swid, sw.port, utilization))

def main():
    iface = 'eth0'
    print("sniffing on {}".format(iface))
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
