#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2018 Contributors to the P4 Project
#
# SPDX-License-Identifier: GPL-2.0-only
# Reason-GPL: import-scapy

import re

from scapy.all import (
    Ether,
    IntField,
    Packet,
    StrFixedLenField,
    XByteField,
    bind_layers,
    srp1
)

# Define custom packet class for P4calc
class P4calc(Packet):
    name = "P4calc"
    # Define fields for the P4calc packet
    fields_desc = [ StrFixedLenField("P", "P", length=1),
                    StrFixedLenField("Four", "4", length=1),
                    XByteField("version", 0x01),
                    StrFixedLenField("op", "+", length=1),
                    IntField("operand_a", 0),
                    IntField("operand_b", 0),
                    IntField("result", 0xDEADBABE)]

# Bind custom packet class to Ethernet type 0x1234
bind_layers(Ether, P4calc, type=0x1234)

# Custom exception for number parsing error
class NumParseError(Exception):
    pass

# Custom exception for operator parsing error
class OpParseError(Exception):
    pass

# Token class for representing parsed tokens
class Token:
    def __init__(self, type, value=None):
        self.type = type
        self.value = value

# Parser function for parsing number literals
def num_parser(s, i, ts):
    pattern = "^\s*([0-9]+)\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError('Expected number literal.')

# Parser function for parsing binary operators
def op_parser(s, i, ts):
    pattern = "^\s*([-+&|^])\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('op', match.group(1)))
        return i + match.end(), ts
    raise OpParseError("Expected binary operator '-', '+', '&', '|', or '^'.")

# Function to create a sequence of parsers
def make_seq(p1, p2):
    def parse(s, i, ts):
        i,ts2 = p1(s,i,ts)
        return p2(s,i,ts2)
    return parse


def main():

    p = make_seq(num_parser, make_seq(op_parser,num_parser))  # Create parser for number and operator sequence
    s = ''
    iface = 'eth0'

    while True:
        s = input('> ')
        if s == "quit":
            break
        print(s)
        try:
            i,ts = p(s,0,[])
            # Construct packet using parsed tokens
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / P4calc(op=ts[1].value,
                                              operand_a=int(ts[0].value),
                                              operand_b=int(ts[2].value))
            pkt = pkt/' '

            resp = srp1(pkt, iface=iface, timeout=1, verbose=False)  # Send packet and receive response
            if resp:
                p4calc=resp[P4calc]
                if p4calc:
                    print(p4calc.result)  # Print the result from the response packet
                else:
                    print("cannot find P4calc header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            print(error)  # Print any exceptions that occur during parsing or packet handling


if __name__ == '__main__':
    main()
