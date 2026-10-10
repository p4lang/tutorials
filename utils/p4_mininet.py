# SPDX-FileCopyrightText: 2013 Barefoot Networks, Inc.
#
# SPDX-License-Identifier: Apache-2.0

import os
import tempfile
from sys import exit
from time import sleep

from mininet.log import debug, error, info
from mininet.moduledeps import pathCheck
from mininet.node import Host, Switch
from netstat import check_listening_on_port

SWITCH_START_TIMEOUT = 10  # seconds


class P4Host(Host):
    def config(self, **params):
        r = super(Host, self).config(**params)

        self.defaultIntf().rename("eth0")

        for off in ["rx", "tx", "sg"]:
            cmd = f"/sbin/ethtool --offload eth0 {off} off"
            self.cmd(cmd)

        # disable IPv6
        self.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        self.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
        self.cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")

        return r

    def describe(self):
        print("**********")
        print(self.name)
        print(
            f"default interface: {self.defaultIntf().name}\t{self.defaultIntf().IP()}\t{self.defaultIntf().MAC()}"
        )
        print("**********")


class P4Switch(Switch):
    """P4 virtual switch"""

    device_id = 0

    def __init__(
        self,
        name,
        sw_path=None,
        json_path=None,
        thrift_port=None,
        pcap_dump=False,
        log_console=False,
        log_file=None,
        verbose=False,
        device_id=None,
        enable_debugger=False,
        **kwargs,
    ):
        Switch.__init__(self, name, **kwargs)
        assert sw_path
        assert json_path
        # make sure that the provided sw_path is valid
        pathCheck(sw_path)
        # make sure that the provided JSON file exists
        if not os.path.isfile(json_path):
            error("Invalid JSON file.\n")
            exit(1)
        self.sw_path = sw_path
        self.json_path = json_path
        self.verbose = verbose
        logfile = f"/tmp/p4s.{self.name}.log"
        self.output = open(logfile, "w")   # noqa: SIM115
        self.thrift_port = thrift_port
        if check_listening_on_port(self.thrift_port):
            error(f"{self.name} cannot bind port {self.grpc_port} because it is bound by another process\n")
            exit(1)
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

    @classmethod
    def setup(cls):
        pass

    def check_switch_started(self, pid):
        """While the process is running (pid exists), we check if the
        Thrift server has been started. If the Thrift server is ready,
        we assume that the switch was started successfully. This is
        only reliable if the Thrift server is started at the end of
        the init process"""
        while True:
            if not os.path.exists(os.path.join("/proc", str(pid))):
                return False
            if check_listening_on_port(self.thrift_port):
                return True
            sleep(0.5)

    def start(self, controllers):
        "Start up a new P4 switch"
        info(f"Starting P4 switch {self.name}.\n")
        args = [self.sw_path]
        for port, intf in list(self.intfs.items()):
            if not intf.IP():
                args.extend(["-i", str(port) + "@" + intf.name])
        if self.pcap_dump:
            args.append(f"--pcap {self.pcap_dump}")
        if self.thrift_port:
            args.extend(["--thrift-port", str(self.thrift_port)])
        if self.nanomsg:
            args.extend(["--nanolog", self.nanomsg])
        args.extend(["--device-id", str(self.device_id)])
        P4Switch.device_id += 1
        args.append(self.json_path)
        if self.enable_debugger:
            args.append("--debugger")
        if self.log_console:
            args.append("--log-console")
        info(" ".join(args) + "\n")

        pid = None
        with tempfile.NamedTemporaryFile() as f:
            # self.cmd(' '.join(args) + ' > /dev/null 2>&1 &')
            self.cmd(
                " ".join(args) + " >" + self.log_file + " 2>&1 & echo $! >> " + f.name
            )
            pid = int(f.read())
        debug(f"P4 switch {self.name} PID is {pid}.\n")
        if not self.check_switch_started(pid):
            error(f"P4 switch {self.name} did not start correctly.\n")
            exit(1)
        info(f"P4 switch {self.name} has been started.\n")

    def stop(self):
        "Terminate P4 switch."
        self.output.flush()
        self.cmd("kill %" + self.sw_path)
        self.cmd("wait")
        self.deleteIntfs()

    def attach(self, intf):
        "Connect a data port"
        assert 0

    def detach(self, intf):
        "Disconnect a data port"
        assert 0
