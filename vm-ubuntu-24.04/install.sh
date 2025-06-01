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
    1>&2 echo "    2025-Jun-01"
    1>&2 echo "    2025-May-01"
    1>&2 echo "    2025-Apr-01"
    1>&2 echo "    2025-Mar-01"
    1>&2 echo "    2025-Feb-01"
    1>&2 echo "    2025-Jan-01"
}

if [ $# -eq 0 ]
then
    VERSION="2025-May-01"
    echo "No version specified.  Defaulting to ${VERSION}"
elif [ $# -eq 1 ]
then
    VERSION="$1"
else
    print_usage
    exit 1
fi

case ${VERSION} in
    2025-Jan-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="7ca39eda3529347e4ba66f1976351b0087294bf8"
	export INSTALL_PI_SOURCE_VERSION="2bb40f7ab800b91b26f3aed174bbbfc739a37ffa"
	export INSTALL_P4C_SOURCE_VERSION="1dc0afae2207f4bb9f5ab45f105ed569cc1ac89b"
	export INSTALL_PTF_SOURCE_VERSION="c554f83685186be4cfa9387eb5d6d700d2bbd7c0"
	;;
    2025-Feb-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="892c42198082d3252f4c6facc7363c02ca1d71d2"
	export INSTALL_PI_SOURCE_VERSION="c3abb96d61f91e4f641aecd7ba2e784870c35290"
	export INSTALL_P4C_SOURCE_VERSION="2776b1948529bc7e8ccfb2f6ea2a9c1ab1f68796"
	export INSTALL_PTF_SOURCE_VERSION="c554f83685186be4cfa9387eb5d6d700d2bbd7c0"
	;;
    2025-Mar-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="d12eefc7bc19fb4da615b1b45c1235899f2e4fb1"
	export INSTALL_PI_SOURCE_VERSION="17802cfd67218a26307c0ea69fe520751ca6ab64"
	export INSTALL_P4C_SOURCE_VERSION="3ffac66ee232f2ab9d1860751dde94725d3b1af8"
	export INSTALL_PTF_SOURCE_VERSION="77a5ba448f3db54b45a03a6235b7cec8c8c7d093"
	;;
    2025-Apr-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="d12eefc7bc19fb4da615b1b45c1235899f2e4fb1"
	export INSTALL_PI_SOURCE_VERSION="17802cfd67218a26307c0ea69fe520751ca6ab64"
	export INSTALL_P4C_SOURCE_VERSION="1d456721080836ecf9afc7daaf17147332173620"
	export INSTALL_PTF_SOURCE_VERSION="e29ef7ec0bd34d4ceef88016383e53238ab5383c"
	;;
    2025-May-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="c0ff3aba77a78ed08dfcb8634f0875fa172e18ab"
	export INSTALL_PI_SOURCE_VERSION="17802cfd67218a26307c0ea69fe520751ca6ab64"
	export INSTALL_P4C_SOURCE_VERSION="305ca61bfd1c3f13206dd4733ca3b8c56145a19f"
	export INSTALL_PTF_SOURCE_VERSION="e29ef7ec0bd34d4ceef88016383e53238ab5383c"
	;;
    2025-Jun-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="c0ff3aba77a78ed08dfcb8634f0875fa172e18ab"
	export INSTALL_PI_SOURCE_VERSION="d28b31e4fa05b51f93b9810f5a3ef4a57fbfb8a8"
	export INSTALL_P4C_SOURCE_VERSION="45bbb002e86e5dafcbbb61499d122bb9982698c6"
	export INSTALL_PTF_SOURCE_VERSION="e29ef7ec0bd34d4ceef88016383e53238ab5383c"
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
