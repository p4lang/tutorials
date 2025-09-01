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
# Instead of using the protocol buffer class, we'll use a simple class that provides the same interface
class SimpleP4DeviceConfig(object):
    def __init__(self):
        self.reassign = False
        self.device_data = b''
    
    def SerializeToString(self):
        """
        Emulates the Protocol Buffer's SerializeToString method.
        Just returns the device_data as binary string.
        """
        return self.device_data

from .switch import SwitchConnection


def buildDeviceConfig(bmv2_json_file_path=None):
    "Builds the device config for BMv2"
    device_config = SimpleP4DeviceConfig()
    device_config.reassign = True
    with open(bmv2_json_file_path) as f:
        device_config.device_data = f.read().encode('utf-8')
    return device_config


class Bmv2SwitchConnection(SwitchConnection):
    def buildDeviceConfig(self, **kwargs):
        return buildDeviceConfig(**kwargs)
