# SPDX-FileCopyrightText: 2017 Barefoot Networks, Inc.
# SPDX-FileCopyrightText: 2017 Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

import os
import sys
import tempfile
from time import sleep

from mininet.log import debug, error, info
from mininet.moduledeps import pathCheck
from mininet.node import Switch
from netstat import check_listening_on_port
from p4_mininet import SWITCH_START_TIMEOUT, P4Switch


class P4RuntimeSwitch(P4Switch):
    "BMv2 switch with gRPC support"

    next_grpc_port = 50051
    next_thrift_port = 9090

    def __init__(
        self,
        name,
        sw_path=None,
        json_path=None,
        grpc_port=None,
        thrift_port=None,
        pcap_dump=False,
        log_console=False,
        verbose=False,
        device_id=None,
        enable_debugger=False,
        log_file=None,
        **kwargs,
    ):
        Switch.__init__(self, name, **kwargs)
        assert sw_path
        self.sw_path = sw_path
        # make sure that the provided sw_path is valid
        pathCheck(sw_path)

        if json_path is not None:
            # make sure that the provided JSON file exists
            if not os.path.isfile(json_path):
                error(f"Invalid JSON file: {json_path}\n")
                sys.exit(1)
            self.json_path = json_path
        else:
            self.json_path = None

        if grpc_port is not None:
            self.grpc_port = grpc_port
        else:
            self.grpc_port = P4RuntimeSwitch.next_grpc_port
            P4RuntimeSwitch.next_grpc_port += 1

        if thrift_port is not None:
            self.thrift_port = thrift_port
        else:
            self.thrift_port = P4RuntimeSwitch.next_thrift_port
            P4RuntimeSwitch.next_thrift_port += 1

        if check_listening_on_port(self.grpc_port):
            error(
                f"{self.name} cannot bind port {self.grpc_port} because it is bound"
                " by another process\n"
            )
            sys.exit(1)

        self.verbose = verbose
        logfile = f"/tmp/p4s.{self.name}.log"
        self.output = open(logfile, "w")   # noqa: SIM115
        self.pcap_dump = pcap_dump
        self.enable_debugger = enable_debugger
        self.log_console = log_console
        if log_file is not None:
            self.log_file = log_file
        else:
            self.log_file = f"/tmp/p4s.{self.name}.log"
        if device_id is not None:
            self.device_id = device_id
            P4Switch.device_id = max(P4Switch.device_id, device_id)
        else:
            self.device_id = P4Switch.device_id
            P4Switch.device_id += 1
        self.nanomsg = f"ipc:///tmp/bm-{self.device_id}-log.ipc"

        self.cpu_port = None
        if "cpu_port" in kwargs:
            self.cpu_port = kwargs["cpu_port"]

        self.priority_queues = None
        if "priority_queues" in kwargs:
            self.priority_queues = kwargs["priority_queues"]

    def check_switch_started(self, pid):
        for _ in range(SWITCH_START_TIMEOUT * 2):
            if not os.path.exists(os.path.join("/proc", str(pid))):
                return False
            if check_listening_on_port(self.grpc_port):
                return True
            sleep(0.5)

    def start(self, controllers):
        info(f"Starting P4 switch {self.name}.\n")
        args = [self.sw_path]
        for port, intf in list(self.intfs.items()):
            if not intf.IP():
                args.extend(["-i", str(port) + "@" + intf.name])
        if self.pcap_dump:
            args.append(f"--pcap {self.pcap_dump}")
        if self.nanomsg:
            args.extend(["--nanolog", self.nanomsg])
        args.extend(["--device-id", str(self.device_id)])
        P4Switch.device_id += 1
        if self.json_path:
            args.append(self.json_path)
        else:
            args.append("--no-p4")
        if self.enable_debugger:
            args.append("--debugger")
        if self.log_console:
            args.append("--log-console")
        if self.thrift_port:
            args.append("--thrift-port " + str(self.thrift_port))
        if self.grpc_port:
            args.append("-- --grpc-server-addr 0.0.0.0:" + str(self.grpc_port))
        if self.cpu_port:
            args.append("--cpu-port " + str(self.cpu_port))
        if self.priority_queues:
            args.append("--priority-queues " + str(self.priority_queues))
        cmd = " ".join(args)
        info(cmd + "\n")
        print(cmd + "\n")

        pid = None
        with tempfile.NamedTemporaryFile() as f:
            self.cmd(cmd + " >" + self.log_file + " 2>&1 & echo $! >> " + f.name)
            pid = int(f.read())
        debug(f"P4 switch {self.name} PID is {pid}.\n")
        if not self.check_switch_started(pid):
            error(f"P4 switch {self.name} did not start correctly.\n")
            sys.exit(1)
        info(f"P4 switch {self.name} has been started.\n")
