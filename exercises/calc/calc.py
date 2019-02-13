#!/usr/bin/env python

import argparse
import sys
import socket
import random
import struct
import re

from scapy.all import sendp, send, srp1
from scapy.all import Packet, hexdump
from scapy.all import Ether, StrFixedLenField, XByteField, IntField
from scapy.all import bind_layers
import readline

class P4calc(Packet):
    name = "P4calc"
    fields_desc = [ StrFixedLenField("P", "P", length=1),
                    StrFixedLenField("Four", "4", length=1),
                    XByteField("version", 0x01),
                    StrFixedLenField("op", "+", length=1),
                    IntField("operand_a", 0),
                    IntField("operand_b", 0),
                    IntField("result", 0xDEADBABE)]

bind_layers(Ether, P4calc, type=0x1234)

class NumParseError(Exception):
    pass

class OpParseError(Exception):
    pass

class Token:
    def __init__(self,type,value = None):
        self.type = type
        self.value = value

def num_parser(s, i, ts):
    pattern = "^\s*([0-9]+)\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError('Expected number literal.')


def op_parser(s, i, ts):
    pattern = "^\s*([-+&|^])\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError("Expected binary operator '-', '+', '&', '|', or '^'.")


def make_seq(p1, p2):
    def parse(s, i, ts):
        i,ts2 = p1(s,i,ts)
        return p2(s,i,ts2)
    return parse


def main():

    p = make_seq(num_parser, make_seq(op_parser,num_parser))
    s = ''
    iface = 'h1-eth0'

    while True:
        s = str(raw_input('> '))
        if s == "quit":
            break
        print s
        try:
            i,ts = p(s,0,[])
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / P4calc(op=ts[1].value,
                                              operand_a=int(ts[0].value),
                                              operand_b=int(ts[2].value))
            pkt = pkt/' '

#            pkt.show()
            resp = srp1(pkt, iface=iface, timeout=1, verbose=False)
            if resp:
                p4calc=resp[P4calc]
                if p4calc:
                    print p4calc.result
                else:
                    print "cannot find P4calc header in the packet"
            else:
                print "Didn't receive response"
        except Exception as error:
            print error


if __name__ == '__main__':
    main()
