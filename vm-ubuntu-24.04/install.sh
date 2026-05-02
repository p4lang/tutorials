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

# Remember the current directory when the script was started:
INSTALL_DIR="${PWD}"

THIS_SCRIPT_FILE_MAYBE_RELATIVE="$0"
THIS_SCRIPT_DIR_MAYBE_RELATIVE="${THIS_SCRIPT_FILE_MAYBE_RELATIVE%/*}"
THIS_SCRIPT_DIR_ABSOLUTE=`readlink -f "${THIS_SCRIPT_DIR_MAYBE_RELATIVE}"`

print_usage() {
    1>&2 echo "usage: $0 [ latest | <date> ]"
    1>&2 echo ""
    1>&2 echo "Dates supported:"
    1>&2 echo "    2026-May-01"
}

if [ $# -eq 0 ]
then
    VERSION="2026-Apr-01"
    echo "No version specified.  Defaulting to ${VERSION}"
elif [ $# -eq 1 ]
then
    VERSION="$1"
else
    print_usage
    exit 1
fi

case ${VERSION} in
    2026-May-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="08bba268ecf3c92e53778b9605696c1e2c46d9e8"
	export INSTALL_PI_SOURCE_VERSION="51805c0108cb49e85e4812dd05bb6693b1f48f85"
	export INSTALL_P4C_SOURCE_VERSION="fe95abfa3318512732776a1ad0aa83b4f2192216"
	export INSTALL_PTF_SOURCE_VERSION="c67ca73692fb1ec23e0b11c7f5b03f1633da09a2"
	;;
    latest)
	echo "Using the latest version of all p4lang repository source code."
	;;
    *)
	print_usage
	exit 1
	;;
esac

${THIS_SCRIPT_DIR_ABSOLUTE}/user-bootstrap.sh


${THIS_SCRIPT_DIR_ABSOLUTE}/install-p4dev-v8.sh

/bin/cp -p "${INSTALL_DIR}/p4setup.bash" "${HOME}/p4setup.bash"
echo "source ~/p4setup.bash" | tee -a ~/.bashrc

${THIS_SCRIPT_DIR_ABSOLUTE}/install-debug-utils.sh
