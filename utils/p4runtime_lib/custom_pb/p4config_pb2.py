# -*- coding: utf-8 -*-
# Custom implementation to provide missing P4DeviceConfig class

from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from google.protobuf import reflection as _reflection
from google.protobuf import symbol_database as _symbol_database

_sym_db = _symbol_database.Default()

class P4DeviceConfig(_message.Message):
    """Custom implementation of P4DeviceConfig message"""
    
    DESCRIPTOR = _descriptor.Descriptor(
        name='P4DeviceConfig',
        full_name='p4.tmp.P4DeviceConfig',
        filename=None,
        containing_type=None,
        fields=[],
        extensions=[],
        nested_types=[],
        enum_types=[],
        options=None,
        is_extendable=False,
        syntax='proto3',
        extension_ranges=[],
        oneofs=[],
        serialized_start=31,
        serialized_end=48,
    )
    
    def __init__(self, **kwargs):
        super(P4DeviceConfig, self).__init__(**kwargs)
        self.reassign = False
        self.device_data = b''