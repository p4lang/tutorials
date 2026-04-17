#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2013 Barefoot Networks, Inc.
#
# SPDX-License-Identifier: Apache-2.0

import argparse
import importlib
import json
import os
import re
import sys
from time import sleep

import appcontroller
import apptopo
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.log import setLogLevel
from mininet.net import Mininet
from p4_mininet import P4Host, P4Switch

parser = argparse.ArgumentParser(description='Mininet demo')
parser.add_argument('--behavioral-exe', help='Path to behavioral executable',
                    type=str, action="store", required=True)
parser.add_argument('--thrift-port', help='Thrift server port for table updates',
                    type=int, action="store", default=9090)
parser.add_argument('--bmv2-log', help='verbose messages in log file', action="store_true")
parser.add_argument('--cli', help="start the mininet cli", action="store_true")
parser.add_argument('--auto-control-plane', help='enable automatic control plane population', action="store_true")
parser.add_argument('--json', help='Path to JSON config file',
                    type=str, action="store", required=True)
parser.add_argument('--pcap-dump', help='Dump packets on interfaces to pcap files',
                    action="store_true")
parser.add_argument('--manifest', '-m', help='Path to manifest file',
                    type=str, action="store", required=True)
parser.add_argument('--target', '-t', help='Target in manifest file to run',
                    type=str, action="store", required=True)
parser.add_argument('--log-dir', '-l', help='Location to save output to',
                    type=str, action="store", required=True)
parser.add_argument('--cli-message', help='Message to print before starting CLI',
                    type=str, action="store", required=False, default=False)


args = parser.parse_args()


next_thrift_port = args.thrift_port

def run_command(command):
    return os.WEXITSTATUS(os.system(command))

def configureP4Switch(**switch_args):
    class ConfiguredP4Switch(P4Switch):
        def __init__(self, *opts, **kwargs):
            global next_thrift_port
            kwargs.update(switch_args)
            kwargs['thrift_port'] = next_thrift_port
            next_thrift_port += 1
            P4Switch.__init__(self, *opts, **kwargs)
    return ConfiguredP4Switch


def main():

    with open(args.manifest, 'r') as f:
        manifest = json.load(f)

    conf = manifest['targets'][args.target]
    params = conf['parameters'] if 'parameters' in conf else {}

    os.environ.update(dict([(k_v[0], str(k_v[1])) for k_v in iter(params.items())]))

    def formatParams(s):
        for param in params:
            s = re.sub('\$'+param+'(\W|$)', str(params[param]) + r'\1', s)
            s = s.replace('${'+param+'}', str(params[param]))
        return s

    AppTopo = apptopo.AppTopo
    AppController = appcontroller.AppController

    if 'topo_module' in conf:
        sys.path.insert(0, os.path.dirname(args.manifest))
        topo_module = importlib.import_module(conf['topo_module'])
        AppTopo = topo_module.CustomAppTopo

    if 'controller_module' in conf:
        sys.path.insert(0, os.path.dirname(args.manifest))
        controller_module = importlib.import_module(conf['controller_module'])
        AppController = controller_module.CustomAppController

    if not os.path.isdir(args.log_dir):
        if os.path.exists(args.log_dir): raise Exception('Log dir exists and is not a dir')
        os.mkdir(args.log_dir)
    os.environ['P4APP_LOGDIR'] = args.log_dir


    links = [l[:2] for l in conf['links']]
    latencies = dict([(''.join(sorted(l[:2])), l[2]) for l in conf['links'] if len(l)>=3])
    bws = dict([(''.join(sorted(l[:2])), l[3]) for l in conf['links'] if len(l)>=4])

    for host_name in sorted(conf['hosts'].keys()):
        host = conf['hosts'][host_name]
        if 'latency' not in host: continue
        for a, b in links:
            if a != host_name and b != host_name: continue
            other = a if a != host_name else b
            latencies[host_name+other] = host['latency']

    for l in latencies:
        if isinstance(latencies[l], str):
            latencies[l] = formatParams(latencies[l])
        else:
            latencies[l] = str(latencies[l]) + "ms"

    bmv2_log = args.bmv2_log or ('bmv2_log' in conf and conf['bmv2_log'])
    pcap_dump = args.pcap_dump or ('pcap_dump' in conf and conf['pcap_dump'])

    topo = AppTopo(links, latencies, manifest=manifest, target=args.target,
                  log_dir=args.log_dir, bws=bws)
    switchClass = configureP4Switch(
            sw_path=args.behavioral_exe,
            json_path=args.json,
            log_console=bmv2_log,
            pcap_dump=pcap_dump)
    net = Mininet(topo = topo,
                  link = TCLink,
                  host = P4Host,
                  switch = switchClass,
                  controller = None)
    net.start()

    sleep(1)

    controller = None
    if args.auto_control_plane or 'controller_module' in conf:
        controller = AppController(manifest=manifest, target=args.target,
                                     topo=topo, net=net, links=links)
        controller.start()


    for h in net.hosts:
        h.describe()

    if args.cli_message is not None:
        with open(args.cli_message, 'r') as message_file:
            print(message_file.read())

    if args.cli or ('cli' in conf and conf['cli']):
        CLI(net)

    stdout_files = dict()
    return_codes = []
    host_procs = []


    def formatCmd(cmd):
        for h in net.hosts:
            cmd = cmd.replace(h.name, h.defaultIntf().updateIP())
        return cmd

    def _wait_for_exit(p, host):
        print(p.communicate())
        if p.returncode is None:
            p.wait()
            print(p.communicate())
        return_codes.append(p.returncode)
        if host_name in stdout_files:
            stdout_files[host_name].flush()
            stdout_files[host_name].close()

    print('\n'.join(["%s: %s"%(k_v1[0],k_v1[1]) for k_v1 in iter(params.items())]) + '\n')

    for host_name in sorted(conf['hosts'].keys()):
        host = conf['hosts'][host_name]
        if 'cmd' not in host: continue

        h = net.get(host_name)
        stdout_filename = os.path.join(args.log_dir, h.name + '.stdout')
        stdout_files[h.name] = open(stdout_filename, 'w')
        cmd = formatCmd(host['cmd'])
        print(h.name, cmd)
        p = h.popen(cmd, stdout=stdout_files[h.name], shell=True, preexec_fn=os.setpgrp)
        if 'startup_sleep' in host: sleep(host['startup_sleep'])

        if 'wait' in host and host['wait']:
            _wait_for_exit(p, host_name)
        else:
            host_procs.append((p, host_name))

    for p, host_name in host_procs:
        if 'wait' in conf['hosts'][host_name] and conf['hosts'][host_name]['wait']:
            _wait_for_exit(p, host_name)


    for p, host_name in host_procs:
        if 'wait' in conf['hosts'][host_name] and conf['hosts'][host_name]['wait']:
            continue
        if p.returncode is None:
            run_command('pkill -INT -P %d' % p.pid)
            sleep(0.2)
            rc = run_command('pkill -0 -P %d' % p.pid) # check if it's still running
            if rc == 0: # the process group is still running, send TERM
                sleep(1) # give it a little more time to exit gracefully
                run_command('pkill -TERM -P %d' % p.pid)
        _wait_for_exit(p, host_name)

    if 'after' in conf and 'cmd' in conf['after']:
        cmds = conf['after']['cmd'] if type(conf['after']['cmd']) == list else [conf['after']['cmd']]
        for cmd in cmds:
            os.system(cmd)

    if controller: controller.stop()

    net.stop()

#    if bmv2_log:
#        os.system('bash -c "cp /tmp/p4s.s*.log \'%s\'"' % args.log_dir)
#    if pcap_dump:
#        os.system('bash -c "cp *.pcap \'%s\'"' % args.log_dir)

    bad_codes = [rc for rc in return_codes if rc != 0]
    if len(bad_codes): sys.exit(1)

if __name__ == '__main__':
    setLogLevel( 'info' )
    main()
