#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2017 Andy Fingerhut

# This script was originally copied from the location below, then
# modified:
#
# https://github.com/p4lang/behavioral-model/blob/master/tools/veth_setup.sh

for idx in 0 1 2 3 4 5 6 7 8; do
    intf0="veth$(($idx*2))"
    intf1="veth$(($idx*2+1))"
    if ! ip link show $intf0 &> /dev/null; then
        ip link add name $intf0 type veth peer name $intf1
        ip link set dev $intf0 up
        ip link set dev $intf1 up

        # Set the MTU of these interfaces to be larger than default of
        # 1500 bytes, so that P4 behavioral-model testing can be done
        # on jumbo frames.
        ip link set $intf0 mtu 9500
        ip link set $intf1 mtu 9500
	############################################################
	# ifconfig is deprecated, and no longer installed by default
	# in Ubuntu Linux minimal installs starting with Ubuntu 18.04
	# LTS.
	#ifconfig $intf0 mtu 9500 up
	#ifconfig $intf1 mtu 9500 up
	############################################################

        # Disable IPv6 on the interfaces, so that the Linux kernel
        # will not automatically send IPv6 MDNS, Router Solicitation,
        # and Multicast Listener Report packets on the interface,
        # which can make P4 program debugging more confusing.
        #
        # Testing indicates that we can still send IPv6 packets across
        # such interfaces, both from scapy to simple_switch, and from
        # simple_switch out to scapy sniffing.
        #
        # https://superuser.com/questions/356286/how-can-i-switch-off-ipv6-nd-ra-transmissions-in-linux
        sysctl -q net.ipv6.conf.${intf0}.disable_ipv6=1
        sysctl -q net.ipv6.conf.${intf1}.disable_ipv6=1
    fi
done
