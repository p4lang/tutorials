#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2017 Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0
import argparse
import json
import os
import sys

from p4.config.v1 import p4info_pb2

from . import bmv2, helper


def error(msg):
    print(' - ERROR! ' + msg, file=sys.stderr)

def info(msg):
    print(' - ' + msg, file=sys.stdout)


class ConfException(Exception):
    pass

class InvalidFileContentException(ConfException):
    pass


def main():
    parser = argparse.ArgumentParser(description='P4Runtime Simple Controller')

    parser.add_argument('-a', '--p4runtime-server-addr',
                        help='address and port of the switch\'s P4Runtime server (e.g. 192.168.0.1:50051)',
                        type=str, action="store", required=True)
    parser.add_argument('-d', '--device-id',
                        help='Internal device ID to use in P4Runtime messages',
                        type=int, action="store", required=True)
    parser.add_argument('-p', '--proto-dump-file',
                        help='path to file where to dump protobuf messages sent to the switch',
                        type=str, action="store", required=True)
    parser.add_argument("-c", '--runtime-conf-file',
                        help="path to input runtime configuration file (JSON)",
                        type=str, action="store", required=True)

    args = parser.parse_args()

    if not os.path.exists(args.runtime_conf_file):
        parser.error("File %s does not exist!" % args.runtime_conf_file)
    workdir = os.path.dirname(os.path.abspath(args.runtime_conf_file))
    with open(args.runtime_conf_file, 'r') as sw_conf_file:
        program_switch(addr=args.p4runtime_server_addr,
                       device_id=args.device_id,
                       sw_conf_file=sw_conf_file,
                       workdir=workdir,
                       proto_dump_fpath=args.proto_dump_file)


def check_switch_conf(sw_conf, workdir):
    required_keys = ["p4info"]
    files_to_check = ["p4info"]
    target_choices = ["bmv2"]

    if "target" not in sw_conf:
        raise ConfException("missing key 'target'")
    target = sw_conf['target']
    if target not in target_choices:
        raise ConfException("unknown target '%s'" % target)

    if target == 'bmv2':
        required_keys.append("bmv2_json")
        files_to_check.append("bmv2_json")

    for conf_key in required_keys:
        if conf_key not in sw_conf or len(sw_conf[conf_key]) == 0:
            raise ConfException("missing key '%s' or empty value" % conf_key)

    for conf_key in files_to_check:
        real_path = os.path.join(workdir, sw_conf[conf_key])
        if not os.path.exists(real_path):
            raise ConfException("file does not exist %s" % real_path)
        # check for file content (e.g. JSON format for bmv2_json)
        if conf_key == "bmv2_json":
            with open(real_path, 'r') as f:
                try:
                    json.load(f)  # Check if the file can be parsed as JSON
                except json.JSONDecodeError as e:
                    raise InvalidFileContentException(f"Invalid JSON content in {real_path}: {e}")


def program_switch(addr, device_id, sw_conf_file, workdir, proto_dump_fpath, runtime_json):
    sw_conf = json_load_byteified(sw_conf_file)
    try:
        check_switch_conf(sw_conf=sw_conf, workdir=workdir)
    except ConfException as e:
        error("While parsing input runtime configuration: %s" % str(e))
        return

    info('Using P4Info file %s...' % sw_conf['p4info'])
    p4info_fpath = os.path.join(workdir, sw_conf['p4info'])
    p4info_helper = helper.P4InfoHelper(p4info_fpath)

    target = sw_conf['target']

    info("Connecting to P4Runtime server on %s (%s)..." % (addr, target))

    if target == "bmv2":
        sw = bmv2.Bmv2SwitchConnection(address=addr, device_id=device_id,
                                       proto_dump_file=proto_dump_fpath)
    else:
        raise Exception("Don't know how to connect to target %s" % target)

    try:
        sw.MasterArbitrationUpdate()

        if target == "bmv2":
            info("Setting pipeline config (%s)..." % sw_conf['bmv2_json'])
            bmv2_json_fpath = os.path.join(workdir, sw_conf['bmv2_json'])
            sw.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                           bmv2_json_file_path=bmv2_json_fpath)
        else:
            raise Exception("Should not be here")

        if 'table_entries' in sw_conf:
            table_entries = sw_conf['table_entries']
            info("Inserting %d table entries..." % len(table_entries))
            for entry in table_entries:
                info(tableEntryToString(entry))
                validateTableEntry(entry, p4info_helper, runtime_json)
                insertTableEntry(sw, entry, p4info_helper)

        if 'multicast_group_entries' in sw_conf:
            group_entries = sw_conf['multicast_group_entries']
            info("Inserting %d group entries..." % len(group_entries))
            for entry in group_entries:
                info(groupEntryToString(entry))
                insertMulticastGroupEntry(sw, entry, p4info_helper)

        if 'clone_session_entries' in sw_conf:
            clone_entries = sw_conf['clone_session_entries']
            info("Inserting %d clone entries..." % len(clone_entries))
            for entry in clone_entries:
                info(cloneEntryToString(entry))
                insertCloneGroupEntry(sw, entry, p4info_helper)

    finally:
        sw.shutdown()


def validateTableEntry(flow, p4info_helper, runtime_json):
    table_name = flow['table']
    match_fields = flow.get('match')  # None if not found
    priority = flow.get('priority')  # None if not found
    match_types_with_priority = [
        p4info_pb2.MatchField.TERNARY,
        p4info_pb2.MatchField.RANGE,
        p4info_pb2.MatchField.OPTIONAL
    ]
    if match_fields is not None and (priority is None or priority == 0):
        for match_field_name, _ in match_fields.items():
            p4info_match = p4info_helper.get_match_field(
                table_name, match_field_name)
            match_type = p4info_match.match_type
            if match_type in match_types_with_priority:
                raise AssertionError(
                    "non-zero 'priority' field is required for all entries for table {} in {}"
                    .format(table_name, runtime_json)
                )


def insertTableEntry(sw, flow, p4info_helper):
    table_name = flow['table']
    match_fields = flow.get('match') # None if not found
    action_name = flow['action_name']
    default_action = flow.get('default_action') # None if not found
    action_params = flow['action_params']
    priority = flow.get('priority')  # None if not found

    table_entry = p4info_helper.buildTableEntry(
        table_name=table_name,
        match_fields=match_fields,
        default_action=default_action,
        action_name=action_name,
        action_params=action_params,
        priority=priority)

    sw.WriteTableEntry(table_entry)


def json_load_byteified(file_handle):
    return json.load(file_handle)


def _byteify(data, ignore_dicts=False):
    # if this is a unicode string, return its string representation
    if isinstance(data, str):
        return data.encode('utf-8')
    # if this is a list of values, return list of byteified values
    if isinstance(data, list):
        return [_byteify(item, ignore_dicts=True) for item in data]
    # if this is a dictionary, return dictionary of byteified keys and values
    # but only if we haven't already byteified it
    if isinstance(data, dict) and not ignore_dicts:
        return {
            _byteify(key, ignore_dicts=True): _byteify(value, ignore_dicts=True)
            for key, value in data.items()
        }
    # if it's anything else, return it in its original form
    return data


def tableEntryToString(flow):
    if 'match' in flow:
        match_str = ['%s=%s' % (match_name, str(flow['match'][match_name])) for match_name in
                     flow['match']]
        match_str = ', '.join(match_str)
    elif 'default_action' in flow and flow['default_action']:
        match_str = '(default action)'
    else:
        match_str = '(any)'
    params = ['%s=%s' % (param_name, str(flow['action_params'][param_name])) for param_name in
              flow['action_params']]
    params = ', '.join(params)
    return "%s: %s => %s(%s)" % (
        flow['table'], match_str, flow['action_name'], params)


def groupEntryToString(rule):
    group_id = rule["multicast_group_id"]
    replicas = ['%d' % replica["egress_port"] for replica in rule['replicas']]
    ports_str = ', '.join(replicas)
    return 'Group {0} => ({1})'.format(group_id, ports_str)

def cloneEntryToString(rule):
    clone_id = rule["clone_session_id"]
    if "packet_length_bytes" in rule:
        packet_length_bytes = str(rule["packet_length_bytes"])+"B"
    else:
        packet_length_bytes = "NO_TRUNCATION"
    replicas = ['%d' % replica["egress_port"] for replica in rule['replicas']]
    ports_str = ', '.join(replicas)
    return 'Clone Session {0} => ({1}) ({2})'.format(clone_id, ports_str, packet_length_bytes)

def insertMulticastGroupEntry(sw, rule, p4info_helper):
    mc_entry = p4info_helper.buildMulticastGroupEntry(rule["multicast_group_id"], rule['replicas'])
    sw.WritePREEntry(mc_entry)

def insertCloneGroupEntry(sw, rule, p4info_helper):
    clone_entry = p4info_helper.buildCloneSessionEntry(rule['clone_session_id'], rule['replicas'],
                                                       rule.get('packet_length_bytes', 0))
    sw.WritePREEntry(clone_entry)


if __name__ == '__main__':
    main()
