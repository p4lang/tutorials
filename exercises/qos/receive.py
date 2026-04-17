#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2020 nikkytub
#
# SPDX-License-Identifier: GPL-2.0-only

import sys

from scapy.all import sniff


def handle_pkt(pkt):
    print("got a packet")
    pkt.show2()
    sys.stdout.flush()


def main():
    iface = 'eth0'
    print("sniffing on %s" % iface)
    sys.stdout.flush()
    sniff(iface=iface, prn=lambda x: handle_pkt(x))


if __name__ == '__main__':
    main()
