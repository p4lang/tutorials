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
    1>&2 echo "    2026-Jun-01"
    1>&2 echo "    2026-Jul-04"
    1>&2 echo "    2026-Aug-01"
    1>&2 echo "    2026-Sep-01"
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
    2026-Sep-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="8be95de0c126d91a9a21497155cbf0cc9ef4676d"
	export INSTALL_PI_SOURCE_VERSION="577b502da91b7d17e4be5821d49d481dc2e1bb7a"
	export INSTALL_P4C_SOURCE_VERSION="55fe8f2775842125fec9f6261cfa10bf5a7031e6"
	export INSTALL_PTF_SOURCE_VERSION="790a087f79084962e51ec8180f43229a200b73ee"
	;;
    2026-Aug-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="883d4eae360de7b6ad0aaf52ba6d30a2401cd0e0"
	export INSTALL_PI_SOURCE_VERSION="577b502da91b7d17e4be5821d49d481dc2e1bb7a"
	export INSTALL_P4C_SOURCE_VERSION="cdd7205767895d49291bbf0addc2c45f052f5079"
	export INSTALL_PTF_SOURCE_VERSION="680f96b23ee0ba3702691e4b1d2a39122eaa8ecb"
	;;
    2026-Jul-04)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="05ce6940a559ea87da180cf8288bf078735a7148"
	export INSTALL_PI_SOURCE_VERSION="749760bb9ecc820e6cc46a777ea37ed078467318"
	export INSTALL_P4C_SOURCE_VERSION="cae220019f4c3b12ff9ded146cbc9d702bab0640"
	export INSTALL_PTF_SOURCE_VERSION="fe62f401dcc38ec983f9a2df6b2e890983c357fb"
	;;
    2026-Jun-01)
	export INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION="282fce33f94046150781e0cb2e1576a01a2522b9"
	export INSTALL_PI_SOURCE_VERSION="c99ed2ad5d2614be33e788d9c5f32f4f22e9c384"
	export INSTALL_P4C_SOURCE_VERSION="78157dc6c13157df802309313d1005b77cfbe7b1"
	export INSTALL_PTF_SOURCE_VERSION="c15b9e8273976559e6c08e6ca8dc5ff1e2a0a623"
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
