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
    1>&2 echo "    2026-Feb-01"
    1>&2 echo "    2026-Jan-01"
    1>&2 echo "    2025-Nov-01"
    1>&2 echo "    2025-Oct-01"
    1>&2 echo "    2025-Sep-01"
    1>&2 echo "    2025-Aug-01"
}

if [ $# -eq 0 ]
then
    VERSION="2026-Mar-01"
    echo "No version specified.  Defaulting to ${VERSION}"
elif [ $# -eq 1 ]
then
    VERSION="$1"
else
    print_usage
    exit 1
fi

case ${VERSION} in
    2026-Mar-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="6c7c93e5484e069c539b5c990bf37c531599894a"
	export INSTALL_PI_SOURCE_VERSION="5689c91a8a7423781267b27d8b166c49a53904ff"
	export INSTALL_P4C_SOURCE_VERSION="d59f5b2e9bb49e211cfca4831077e3d76f0fb70b"
	export INSTALL_PTF_SOURCE_VERSION="05f46c3873feb2213df29743be3d9a9e34d5559b"
	;;
    2026-Feb-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="4cc1333cd51be5675a9bbeeb432d9b647061a817"
	export INSTALL_PI_SOURCE_VERSION="5689c91a8a7423781267b27d8b166c49a53904ff"
	export INSTALL_P4C_SOURCE_VERSION="7d367760701056cfa4fe0321f62914c0e79a6214"
	export INSTALL_PTF_SOURCE_VERSION="05f46c3873feb2213df29743be3d9a9e34d5559b"
	;;
    2026-Jan-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="2bdd0b7b2b2ae89faf2720f2158e9842bc6d2dd2"
	export INSTALL_PI_SOURCE_VERSION="5689c91a8a7423781267b27d8b166c49a53904ff"
	export INSTALL_P4C_SOURCE_VERSION="11d746d94a45694968802675bd9444dfcd029545"
	export INSTALL_PTF_SOURCE_VERSION="05f46c3873feb2213df29743be3d9a9e34d5559b"
	;;
    2025-Nov-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="2bdd0b7b2b2ae89faf2720f2158e9842bc6d2dd2"
	export INSTALL_PI_SOURCE_VERSION="5689c91a8a7423781267b27d8b166c49a53904ff"
	export INSTALL_P4C_SOURCE_VERSION="a97290474ce3d183b1f6bc4ca4959ebbcdb09b3b"
	export INSTALL_PTF_SOURCE_VERSION="05f46c3873feb2213df29743be3d9a9e34d5559b"
	;;
    2025-Oct-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="68f4a978f465fd76e98fcdecb762981843fb7310"
	export INSTALL_PI_SOURCE_VERSION="5689c91a8a7423781267b27d8b166c49a53904ff"
	export INSTALL_P4C_SOURCE_VERSION="2265f80459e06a89ffba26cb51c42cc05b1c023e"
	export INSTALL_PTF_SOURCE_VERSION="05f46c3873feb2213df29743be3d9a9e34d5559b"
	;;
    2025-Sep-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="c8081706b38aa6c7e26e8aa78513ac0ac1c17975"
	export INSTALL_PI_SOURCE_VERSION="5689c91a8a7423781267b27d8b166c49a53904ff"
	export INSTALL_P4C_SOURCE_VERSION="1965b4b523ef5c70e7676145f106ccf9fbba8027"
	export INSTALL_PTF_SOURCE_VERSION="346ff01a7b28f7f478130b1eea11e440f1801307"
	;;
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
