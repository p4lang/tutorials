# SPDX-FileCopyrightText: 2017 Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

import psutil


def check_listening_on_port(port):
    for c in psutil.net_connections(kind='inet'):
        if c.status == 'LISTEN' and c.laddr[1] == port:
            return True
    return False
