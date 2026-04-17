#!/bin/bash

# SPDX-FileCopyrightText: 2019 Tu Dang
#
# SPDX-License-Identifier: Apache-2.0
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
