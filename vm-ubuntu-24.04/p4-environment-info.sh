#! /bin/bash

# SPDX-FileCopyrightText: 2024 Andy Fingerhut
#
# SPDX-License-Identifier: Apache-2.0

# Copyright 2024 Andy Fingerhut

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

get_package_info() {
    local pkg="$1"
    local exit_status
    echo ""
    echo "$ which $pkg"
    which $pkg
    exit_status=$?
    if [ $exit_status != 0 ]
    then
	echo "[ No such program found in your PATH -- it might still be elsewhere on the system ]"
    else
        get_version=1
	get_version_opts="--version"
	case $pkg in
	simple_switch_CLI) get_version=0 ;;
	esac
	if [ $get_version == 1 ]
	then
	    echo "$ $pkg $get_version_opts"
	    $pkg $get_version_opts
	fi

	get_more_info=0
	case $pkg in
            pip) echo "$ pip list"
		 pip list ;;
            pip3) echo "$ pip3 list"
		  pip3 list ;;
	esac
    fi
}

echo "p4-environment-info version 1"
echo ""

echo "$ uname -a"
uname -a

echo ""
source /etc/os-release
echo "ID=${ID}"
echo "VERSION_ID=${VERSION_ID}"

get_package_info gcc
get_package_info g++
get_package_info make
get_package_info cmake
get_package_info m4
get_package_info autoconf
get_package_info automake
get_package_info as
get_package_info bison
get_package_info flex
get_package_info llvm-config
get_package_info python
get_package_info pip
get_package_info python3
get_package_info pip3
get_package_info libtool
get_package_info pkg-config
get_package_info mn
get_package_info protoc
get_package_info thrift
get_package_info simple_switch
get_package_info simple_switch_grpc
get_package_info simple_switch_CLI
get_package_info p4c

echo ""
echo "$ find /usr | grep p4runtime | sort | xargs ls -ld"
find /usr | grep p4runtime | sort | xargs ls -ld

echo ""
echo "$ find /usr/local/lib | grep grpc | sort | xargs ls -ld"
find /usr/local/lib | grep grpc | sort | xargs ls -ld
