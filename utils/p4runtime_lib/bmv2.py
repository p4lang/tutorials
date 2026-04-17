# SPDX-FileCopyrightText: 2017 Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0
from p4.tmp import p4config_pb2

from .switch import SwitchConnection


def buildDeviceConfig(bmv2_json_file_path=None):
    "Builds the device config for BMv2"
    device_config = p4config_pb2.P4DeviceConfig()
    device_config.reassign = True
    with open(bmv2_json_file_path) as f:
        device_config.device_data = f.read().encode('utf-8')
    return device_config


class Bmv2SwitchConnection(SwitchConnection):
    def buildDeviceConfig(self, **kwargs):
        return buildDeviceConfig(**kwargs)
