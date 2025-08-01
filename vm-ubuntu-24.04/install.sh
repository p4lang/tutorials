#! /bin/bash
# SPDX-License-Identifier:  Apache-2.0

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
    1>&2 echo "    2025-Aug-01"
}

if [ $# -eq 0 ]
then
    VERSION="2025-Aug-01"
    echo "No version specified.  Defaulting to ${VERSION}"
elif [ $# -eq 1 ]
then
    VERSION="$1"
else
    print_usage
    exit 1
fi

case ${VERSION} in
    2025-Aug-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="4f84a09f217665f84471e8cef74c0b46b873bbe5"
	export INSTALL_PI_SOURCE_VERSION="d28b31e4fa05b51f93b9810f5a3ef4a57fbfb8a8"
	export INSTALL_P4C_SOURCE_VERSION="4d926d0723c42175c960dd72c762b92de70e5b58"
	export INSTALL_PTF_SOURCE_VERSION="6af750831ffe14512c5195383f2b39691744503e"
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
