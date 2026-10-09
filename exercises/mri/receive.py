#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2018 Nate Foster
#
# SPDX-License-Identifier: GPL-2.0-only
import sys
from typing import Any, ClassVar

from scapy.all import (
    FieldLenField,
    IntField,
    IPOption,
    Packet,
    PacketListField,
    ShortField,
    get_if_list,
    sniff,
)
from scapy.layers.inet import _IPOption_HDR


def get_if():
    iface = None
    for i in get_if_list():
        if "eth0" in i:
            iface = i
            break
    if not iface:
        print("Cannot find eth0 interface")
        sys.exit(1)
    return iface


class SwitchTrace(Packet):
    fields_desc: ClassVar[list[Any]] = [IntField("swid", 0), IntField("qdepth", 0)]

    def extract_padding(self, p):
        return "", p


class IPOption_MRI(IPOption):
    name = "MRI"
    option = 31
    fields_desc: ClassVar[list[Any]] = [
        _IPOption_HDR,
        FieldLenField(
            "length",
            None,
            fmt="B",
            length_of="swtraces",
            adjust=lambda pkt, x: x * 2 + 4,
        ),
        ShortField("count", 0),
        PacketListField(
            "swtraces", [], SwitchTrace, count_from=lambda pkt: pkt.count * 1
        ),
    ]


def handle_pkt(pkt):
    print("got a packet")
    pkt.show2()
    #    hexdump(pkt)
    sys.stdout.flush()


def main():
    iface = "eth0"
    print(f"sniffing on {iface}")
    sys.stdout.flush()
    sniff(filter="udp and port 4321", iface=iface, prn=lambda x: handle_pkt(x))


if __name__ == "__main__":
    main()
