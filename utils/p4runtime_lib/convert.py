# SPDX-License-Identifier: Apache-2.0
# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import math
import re
import socket

'''
This package contains several helper functions for encoding to and decoding from byte strings:
- integers
- IPv4 address strings
- Ethernet address strings
'''

mac_pattern = re.compile(r'^([\da-fA-F]{2}:){5}([\da-fA-F]{2})$')
def matchesMac(mac_addr_string):
    return mac_pattern.match(mac_addr_string) is not None

def encodeMac(mac_addr_string):
    return bytes.fromhex(mac_addr_string.replace(':', ''))

def decodeMac(encoded_mac_addr):
    return ':'.join(s.hex() for s in encoded_mac_addr)

ip_pattern = re.compile(r'^(\d{1,3}\.){3}(\d{1,3})$')
def matchesIPv4(ip_addr_string):
    return ip_pattern.match(ip_addr_string) is not None

def encodeIPv4(ip_addr_string):
    return socket.inet_aton(ip_addr_string)

def decodeIPv4(encoded_ip_addr):
    return socket.inet_ntoa(encoded_ip_addr)

def matchesIPv6(ip_addr_string):
    try:
        socket.inet_pton(socket.AF_INET6, ip_addr_string)
        return True
    except socket.error:
        return False

def encodeIPv6(ip_addr_string):
    return socket.inet_pton(socket.AF_INET6, ip_addr_string)

def decodeIPv6(encoded_ip_addr):
    return socket.inet_ntop(socket.AF_INET6, encoded_ip_addr) 

def bitwidthToBytes(bitwidth):
    return int(math.ceil(bitwidth / 8.0))

def encodeNum(number, bitwidth):
    byte_len = bitwidthToBytes(bitwidth)
    # If number is negative, calculate the positive number that its
    # 2's complement encoding would look like in 'bitwidth' bits.
    orig_number = number
    if number < 0:
        if number < -(2 ** (bitwidth-1)):
            raise Exception("Negative number, %d, has 2's complement representation that does not fit in %d bits" % (number, bitwidth))
        number = (2 ** bitwidth) + number
    num_str = '%x' % number
    if orig_number < 0:
        print("CONVERT_NEGATIVE_NUMBER debug: orig_number=%s number=%s bitwidth=%d num_str='%s'"
              "" % (orig_number, number, bitwidth, num_str))
    if number >= 2 ** bitwidth:
        raise Exception("Number, %d, does not fit in %d bits" % (number, bitwidth))
    return bytes.fromhex('0' * (byte_len * 2 - len(num_str)) + num_str)

def decodeNum(encoded_number):
    return int(encoded_number.hex(), 16)

def encode(x, bitwidth):
    'Tries to infer the type of `x` and encode it'
    byte_len = bitwidthToBytes(bitwidth)
    if (type(x) == list or type(x) == tuple) and len(x) == 1:
        x = x[0]
    encoded_bytes = None
    if type(x) == str:
        if matchesMac(x):
            encoded_bytes = encodeMac(x)
        elif matchesIPv4(x):
            encoded_bytes = encodeIPv4(x)
        elif matchesIPv6(x):
            encoded_bytes = encodeIPv6(x)
        else:
            # Assume that the string is already encoded
            encoded_bytes = x
    elif type(x) == int:
        encoded_bytes = encodeNum(x, bitwidth)
    else:
        raise Exception("Encoding objects of %r is not supported" % type(x))
    assert(len(encoded_bytes) == byte_len)
    return encoded_bytes


def decode(enc_val):
    decode_functions = [decodeIPv4, decodeMac, decodeNum]
    for func in decode_functions:
        try:
            return func(enc_val)
        except:
            pass
    raise Exception("Encoded value format not compatible")

if __name__ == '__main__':
    # TODO These tests should be moved out of main eventually

    # Test encoding and decoding for MAC address
    mac = "aa:bb:cc:dd:ee:ff"
    enc_mac = encodeMac(mac)
    assert(enc_mac == '\xaa\xbb\xcc\xdd\xee\xff')
    dec_mac = decodeMac(enc_mac)
    assert(mac == dec_mac)

    # Test encoding and decoding for IPv4 address
    ip0 = "10.0.0.1"
    enc_ipv4 = encodeIPv4(ip0)
    assert(enc_ipv4 == '\x0a\x00\x00\x01')
    dec_ipv4 = decodeIPv4(enc_ipv4)
    assert(ip0 == dec_ipv4)

    # Test encoding and decoding for IPv6 address
    ip1 = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    enc_ipv6 = encodeIPv6(ip1)
    assert(enc_ipv6 == '\x01\r\xb8\x85\xa3\x00\x00\x00\x00\x8a.\x03ps4')
    dec_ipv6 = decodeIPv6(enc_ipv6)
    assert(ip1 == dec_ipv6)

    # Test encoding and decoding for a number
    num = 1337
    byte_len = 5
    enc_num = encodeNum(num, byte_len * 8)
    assert(enc_num == '\x00\x00\x00\x05\x39')
    dec_num = decodeNum(enc_num)
    assert(num == dec_num)

    assert(matchesIPv4('10.0.0.1'))
    assert(not matchesIPv4('10.0.0.1.5'))
    assert(not matchesIPv4('1000.0.0.1'))
    assert(not matchesIPv4('10001'))

    assert(matchesIPv6('2001:0db8:85a3:0000:0000:8a2e:0370:7334'))
    assert(not matchesIPv6('241.54.113.65'))
    assert(not matchesIPv6('::1::2'))
    assert(not matchesIPv6('192.168.1.1'))

    # Test generic encoding function
    assert(encode(mac, 6 * 8) == enc_mac)
    assert(encode(ip0, 4 * 8) == enc_ipv4)
    assert(encode(ip1, 16 * 8) == enc_ipv6)
    assert(encode(num, 5 * 8) == enc_num)
    assert(encode((num,), 5 * 8) == enc_num)
    assert(encode([num], 5 * 8) == enc_num)

    num = 256
    byte_len = 2
    try:
        enc_num = encodeNum(num, 8)
        raise Exception("expected exception")
    except Exception as e:
        print(e)
