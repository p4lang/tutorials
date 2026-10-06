#! /bin/bash

# SPDX-FileCopyrightText: 2024 Andy Fingerhut
# Copyright 2024 Andy Fingerhut
#
# SPDX-License-Identifier: Apache-2.0

# Remember the current directory when the script was started:
INSTALL_DIR="${PWD}"

THIS_SCRIPT_FILE_MAYBE_RELATIVE="$0"
THIS_SCRIPT_DIR_MAYBE_RELATIVE="${THIS_SCRIPT_FILE_MAYBE_RELATIVE%/*}"
THIS_SCRIPT_DIR_ABSOLUTE=`readlink -f "${THIS_SCRIPT_DIR_MAYBE_RELATIVE}"`

print_usage() {
    1>&2 echo "usage: $0 [ latest | <date> ]"
    1>&2 echo ""
    1>&2 echo "Dates supported:"
    1>&2 echo "    2026-Oct-01"
}

if [ $# -eq 0 ]
then
    VERSION="2026-Oct-01"
    echo "No version specified.  Defaulting to ${VERSION}"
elif [ $# -eq 1 ]
then
    VERSION="$1"
else
    print_usage
    exit 1
fi

case ${VERSION} in
    2026-Oct-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="0bf80968bbd533e5bb58f849743001ae8221b715"
	export INSTALL_PI_SOURCE_VERSION="04bf8ac8a0c00cd8a663f1f936fdaadc8b7a658c"
	export INSTALL_P4C_SOURCE_VERSION="3bc092a2119951f86a554adda592a754edfc134e"
	export INSTALL_PTF_SOURCE_VERSION="95a05315668b4e002166186f387fd2a15549f42f"
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


${THIS_SCRIPT_DIR_ABSOLUTE}/install-p4dev-v10.sh

/bin/cp -p "${INSTALL_DIR}/p4setup.bash" "${HOME}/p4setup.bash"
echo "source ~/p4setup.bash" | tee -a ~/.bashrc

${THIS_SCRIPT_DIR_ABSOLUTE}/install-debug-utils.sh
