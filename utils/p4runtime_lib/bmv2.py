# SPDX-FileCopyrightText: 2017 Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

from .switch import SwitchConnection


def buildDeviceConfig(bmv2_json_file_path=None):
    "Builds the device config for BMv2"
    with open(bmv2_json_file_path) as f:
        device_config = f.read().encode('utf-8')
    return device_config


class Bmv2SwitchConnection(SwitchConnection):
    def buildDeviceConfig(self, **kwargs):
        return buildDeviceConfig(**kwargs)
