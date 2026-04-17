#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2013 Barefoot Networks, Inc.
#
# SPDX-License-Identifier: Apache-2.0



import argparse
import json
import os
import sys
import tarfile
from collections import OrderedDict

parser = argparse.ArgumentParser(description='p4apprunner')
parser.add_argument('--build-dir', help='Directory to build in.',
                    type=str, action='store', required=False, default='/tmp')
parser.add_argument('--quiet', help='Suppress log messages.',
                    action='store_true', required=False, default=False)
parser.add_argument('--manifest', help='Path to manifest file.',
                    type=str, action='store', required=False, default='./p4app.json')
parser.add_argument('app', help='.p4app package to run.', type=str)
parser.add_argument('target', help=('Target to run. Defaults to the first target '
                                    'in the package.'),
                    nargs='?', type=str)

args = parser.parse_args()

def log(*items):
    if args.quiet != True:
        print(*items)

def log_error(*items):
    print(*items, file=sys.stderr)

def run_command(command):
    log('>', command)
    return os.WEXITSTATUS(os.system(command))

class Manifest:
    def __init__(self, program_file, language, target, target_config):
        self.program_file = program_file
        self.language = language
        self.target = target
        self.target_config = target_config

def read_manifest(manifest_file):
    manifest = json.load(manifest_file, object_pairs_hook=OrderedDict)

    if 'program' not in manifest:
        log_error('No program defined in manifest.')
        sys.exit(1)
    program_file = manifest['program']

    if 'language' not in manifest:
        log_error('No language defined in manifest.')
        sys.exit(1)
    language = manifest['language']

    if 'targets' not in manifest or len(manifest['targets']) < 1:
        log_error('No targets defined in manifest.')
        sys.exit(1)

    if args.target is not None:
        chosen_target = args.target
    elif 'default-target' in manifest:
        chosen_target = manifest['default-target']
    else:
        chosen_target = list(manifest['targets'].keys())[0]

    if chosen_target not in manifest['targets']:
        log_error('Target not found in manifest:', chosen_target)
        sys.exit(1)

    return Manifest(program_file, language, chosen_target, manifest['targets'][chosen_target])


def run_compile_bmv2(manifest):
    if 'run-before-compile' in manifest.target_config:
        commands = manifest.target_config['run-before-compile']
        if not isinstance(commands, list):
            log_error('run-before-compile should be a list:', commands)
            sys.exit(1)
        for command in commands:
            run_command(command)

    compiler_args = []

    if manifest.language == 'p4-14':
        compiler_args.append('--p4v 14')
    elif manifest.language == 'p4-16':
        compiler_args.append('--p4v 16')
    else:
        log_error('Unknown language:', manifest.language)
        sys.exit(1)

    if 'compiler-flags' in manifest.target_config:
        flags = manifest.target_config['compiler-flags']
        if not isinstance(flags, list):
            log_error('compiler-flags should be a list:', flags)
            sys.exit(1)
        compiler_args.extend(flags)

    # Compile the program.
    output_file = manifest.program_file + '.json'
    compiler_args.append('"%s"' % manifest.program_file)
    compiler_args.append('-o "%s"' % output_file)
    rv = run_command('p4c-bm2-ss %s' % ' '.join(compiler_args))

    if 'run-after-compile' in manifest.target_config:
        commands = manifest.target_config['run-after-compile']
        if not isinstance(commands, list):
            log_error('run-after-compile should be a list:', commands)
            sys.exit(1)
        for command in commands:
            run_command(command)

    if rv != 0:
        log_error('Compile failed.')
        sys.exit(1)

    return output_file

def run_mininet(manifest):
    output_file = run_compile_bmv2(manifest)

    # Run the program using the BMV2 Mininet simple switch.
    switch_args = []

    # We'll place the switch's log file in current (build) folder.
    cwd = os.getcwd()
    log_file = os.path.join(cwd, manifest.program_file + '.log')
    print ("*** Log file %s" % log_file)
    switch_args.append('--log-file "%s"' % log_file)

    pcap_dir = os.path.join(cwd)
    print ("*** Pcap folder %s" % pcap_dir)
    switch_args.append('--pcap-dump "%s" '% pcap_dir)

    # Generate a message that will be printed by the Mininet CLI to make
    # interacting with the simple switch a little easier.
    message_file = 'mininet_message.txt'
    with open(message_file, 'w') as message:

        print(file=message)
        print('======================================================================',
              file=message)
        print('Welcome to the BMV2 Mininet CLI!', file=message)
        print('======================================================================',
              file=message)
        print('Your P4 program is installed into the BMV2 software switch', file=message)
        print('and your initial configuration is loaded. You can interact', file=message)
        print('with the network using the mininet CLI below.', file=message)
        print(file=message)
        print('To inspect or change the switch configuration, connect to', file=message)
        print('its CLI from your host operating system using this command:', file=message)
        print('  simple_switch_CLI', file=message)
        print(file=message)
        print('To view the switch log, run this command from your host OS:', file=message)
        print('  tail -f %s' %  log_file, file=message)
        print(file=message)
        print('To view the switch output pcap, check the pcap files in %s:' % pcap_dir, file=message)
        print(' for example run:  sudo tcpdump -xxx -r s1-eth1.pcap', file=message)
        print(file=message)
#        print('To run the switch debugger, run this command from your host OS:', file=message)
#        print('  bm_p4dbg' , file=message)
#        print(file=message)

    switch_args.append('--cli-message "%s"' % message_file)

    if 'num-hosts' in manifest.target_config:
        switch_args.append('--num-hosts %s' % manifest.target_config['num-hosts'])

    if 'switch-config' in manifest.target_config:
        switch_args.append('--switch-config "%s"' % manifest.target_config['switch-config'])

    switch_args.append('--behavioral-exe "%s"' % 'simple_switch')
    switch_args.append('--json "%s"' % output_file)

    program = '"%s/mininet/single_switch_mininet.py"' % sys.path[0]
    return run_command('python3 %s %s' % (program, ' '.join(switch_args)))

def run_multiswitch(manifest):
    output_file = run_compile_bmv2(manifest)

    script_args = []
    cwd = os.getcwd()
    log_dir = os.path.join(cwd, cwd + '/logs')
    print ("*** Log directory %s" % log_dir)
    script_args.append('--log-dir "%s"' % log_dir)
    pcap_dir = os.path.join(cwd)
    print ("*** Pcap directory %s" % cwd)
    script_args.append('--manifest "%s"' % args.manifest)
    script_args.append('--target "%s"' % manifest.target)
    if 'auto-control-plane' in manifest.target_config and manifest.target_config['auto-control-plane']:
        script_args.append('--auto-control-plane' )
    script_args.append('--behavioral-exe "%s"' % 'simple_switch')
    script_args.append('--json "%s"' % output_file)
    #script_args.append('--cli')

    # Generate a message that will be printed by the Mininet CLI to make
    # interacting with the simple switch a little easier.
    message_file = 'mininet_message.txt'
    with open(message_file, 'w') as message:

        print(file=message)
        print('======================================================================',
              file=message)
        print('Welcome to the BMV2 Mininet CLI!', file=message)
        print('======================================================================',
              file=message)
        print('Your P4 program is installed into the BMV2 software switch', file=message)
        print('and your initial configuration is loaded. You can interact', file=message)
        print('with the network using the mininet CLI below.', file=message)
        print(file=message)
        print('To inspect or change the switch configuration, connect to', file=message)
        print('its CLI from your host operating system using this command:', file=message)
        print('  simple_switch_CLI --thrift-port <switch thrift port>', file=message)
        print(file=message)
        print('To view a switch log, run this command from your host OS:', file=message)
        print('  tail -f %s/<switchname>.log' %  log_dir, file=message)
        print(file=message)
        print('To view the switch output pcap, check the pcap files in %s:' % pcap_dir, file=message)
        print(' for example run:  sudo tcpdump -xxx -r s1-eth1.pcap', file=message)
        print(file=message)
#        print('To run the switch debugger, run this command from your host OS:', file=message)
#        print('  bm_p4dbg' , file=message)
#        print(file=message)

    script_args.append('--cli-message "%s"' % message_file)

    program = '"%s/mininet/multi_switch_mininet.py"' % sys.path[0]
    return run_command('python3 %s %s' % (program, ' '.join(script_args)))

def run_stf(manifest):
    output_file = run_compile_bmv2(manifest)

    if not 'test' in manifest.target_config:
        log_error('No STF test file provided.')
        sys.exit(1)
    stf_file = manifest.target_config['test']

    # Run the program using the BMV2 STF interpreter.
    stf_args = []
    stf_args.append('-v')
    stf_args.append(os.path.join(args.build_dir, output_file))
    stf_args.append(os.path.join(args.build_dir, stf_file))

    program = '"%s/stf/bmv2stf.py"' % sys.path[0]
    rv = run_command('python3 %s %s' % (program, ' '.join(stf_args)))
    if rv != 0:
        sys.exit(1)
    return rv

def run_custom(manifest):
    output_file = run_compile_bmv2(manifest)
    python_path = 'PYTHONPATH=$PYTHONPATH:/scripts/mininet/'
    script_args = []
    script_args.append('--behavioral-exe "%s"' % 'simple_switch')
    script_args.append('--json "%s"' % output_file)
    script_args.append('--cli "%s"' % 'simple_switch_CLI')
    if not 'program' in manifest.target_config:
         log_error('No mininet program file provided.')
         sys.exit(1)
    program = manifest.target_config['program']
    rv = run_command('%s python3 %s %s' % (python_path, program, ' '.join(script_args)))

    if rv != 0:
        sys.exit(1)
    return rv

def main():
    log('Entering build directory.')
    os.chdir(args.build_dir)

    # A '.p4app' package is really just a '.tar.gz' archive. Extract it so we
    # can process its contents.
    log('Extracting package.')
    tar = tarfile.open(args.app)
    tar.extractall()
    tar.close()

    log('Reading package manifest.')
    with open(args.manifest, 'r') as manifest_file:
        manifest = read_manifest(manifest_file)

    # Dispatch to the backend implementation for this target.
    backend = manifest.target
    if 'use' in manifest.target_config:
        backend = manifest.target_config['use']

    if backend == 'mininet':
        rc = run_mininet(manifest)
    elif backend == 'multiswitch':
        rc = run_multiswitch(manifest)
    elif backend == 'stf':
        rc = run_stf(manifest)
    elif backend == 'custom':
        rc = run_custom(manifest)
    elif backend == 'compile-bmv2':
        run_compile_bmv2(manifest)
        rc = 0
    else:
        log_error('Target specifies unknown backend:', backend)
        sys.exit(1)

    sys.exit(rc)

if __name__ == '__main__':
    main()
