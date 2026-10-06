#! /bin/bash

# SPDX-FileCopyrightText: 2024 Andy Fingerhut
# Copyright 2024 Andy Fingerhut
#
# SPDX-License-Identifier: Apache-2.0

# This script differs from install-p4dev-v9.sh as follows:

# * Add support for Ubuntu 26.04
# * Remove support for Ubuntu 20.04
# * Use uv for creating Python venv and installing Python packages
# * Remove old checks for Python2 files
# * Remove vestiges of support for Fedora Linux

# Remember the current directory when the script was started:
INSTALL_DIR="${PWD}"

THIS_SCRIPT_FILE_MAYBE_RELATIVE="$0"
THIS_SCRIPT_DIR_MAYBE_RELATIVE="${THIS_SCRIPT_FILE_MAYBE_RELATIVE%/*}"
export THIS_SCRIPT_DIR_ABSOLUTE=`readlink -f "${THIS_SCRIPT_DIR_MAYBE_RELATIVE}"`

linux_version_warning() {
    1>&2 echo "Found ID ${ID} and VERSION_ID ${VERSION_ID} in /etc/os-release"
    1>&2 echo "This script only supports these:"
    1>&2 echo "    ID ubuntu, VERSION_ID in 22.04 24.04 26.04"
    1>&2 echo ""
    1>&2 echo "Proceed installing manually at your own risk of"
    1>&2 echo "significant time spent figuring out how to make it all"
    1>&2 echo "work, or consider getting VirtualBox and creating a"
    1>&2 echo "virtual machine with one of the tested versions."
}

get_used_disk_space_in_mbytes() {
    echo $(df --output=used --block-size=1M . | tail -n 1)
}

max_of_list() {
    local lst=$*
    local max=""
    for x in $lst
    do
        if [ -z ${max} ]
        then
            max=${x}
        else
            if [ ${x} -gt ${max} ]
            then
                max=${x}
            fi
        fi
    done
    echo ${max}
}

# Change this to a lower value if you do not like all this extra debug
# output.  It is occasionally useful to debug why Python package
# install files, or other files installed system-wide, are not going
# to the places where one might hope.
export DEBUG_INSTALL_P4DEV=2

# By default, save storage space by cleaning up various builds as we
# go.  This is not always what you want when things are failing, so it
# may be useful to disable this when making experimental changes to
# the script.  At least when things are working, most people won't
# want the extra build files.
CLEAN_UP_AS_WE_GO=1

# As an exception to the above, I very commonly want to keep around
# the contents of the p4c/build directory, even though it is large,
# because it is needed for running p4c tests.  If you change this to
# 0, then the p4c/build directory will also be cleaned up (if
# CLEAN_UP_AS_WE_GO=1).
KEEP_P4C_BUILD_FOR_TESTING=1

USE_DISTRIBUTION_SSL_PACKAGE=1

PYTHON_VENV="${INSTALL_DIR}/p4dev-python-venv"

PYTHON_DEBUG_DUMP_DIR="${INSTALL_DIR}/install-p4dev-dumpdir"
mkdir -p ${PYTHON_DEBUG_DUMP_DIR}

dump_python_lib_info() {
    local output_dir=$1
    if [ ${DEBUG_INSTALL_P4DEV} -lt 2 ]
    then
        return
    fi
    set +e
    mkdir -p ${output_dir}
    outf=${output_dir}/dirs.txt
    cp /dev/null ${outf}
    echo "VIRTUAL_ENV=${VIRTUAL_ENV}" >> ${outf}
    # This variable enables `uv sync` and other commands to use the
    # venv.
    echo "UV_PROJECT_ENVIRONMENT=${UV_PROJECT_ENVIRONMENT}" >> ${outf}
    echo "All directories named site-packages or dist-packages:" >> ${outf}
    find / -name site-packages -o -name dist-packages 2>/dev/null | sort >> ${outf}
    echo "" >> ${outf}
    echo "ls -la on each such directory:" >> ${outf}
    for d in $(find / -name site-packages -o -name dist-packages 2>/dev/null | sort)
    do
        echo $d >> ${outf}
        ls -la $d >> ${outf}
    done
    #echo "" >> ${outf}
    #echo "ls -laR on each such directory:" >> ${outf}
    for d in $(find / -name site-packages -o -name dist-packages 2>/dev/null | sort)
    do
        outf="${output_dir}/ls-laR-of-$(echo "$d" | tr '/' '-')"
        cp /dev/null ${outf}
        #echo $d >> ${outf}
        ls -laR $d >> ${outf}
    done
    set -e
}

debug_dump_many_install_files() {
    local OUT_FNAME="$1"
    local DIRNAME="${INSTALL_DIR}/`basename $1 .txt`"
    if [ ${DEBUG_INSTALL_P4DEV} -ge 2 ]
    then
        find /usr/lib /usr/local $HOME/.local "${PYTHON_VENV}" 2>/dev/null | sort > "${OUT_FNAME}"
    fi
    if [ ${DEBUG_INSTALL_P4DEV} -ge 3 ]
    then
        /bin/cp -pr ${PYTHON_VENV}/lib/python*/site-packages ${DIRNAME}
    fi
}

# max_parallel_jobs calculates a number of parallel jobs N to run for
# a command like `make -j<N>`

# Often this does not actually help finish the command earlier if N is
# larger than the number of CPU cores on the system, so calculate a
# value of N no more than that number.

# Also, if N is so large that the processes started in parallel exceed
# the available memory on the system, it can cause the system to copy
# memory to and from swap space, which dramatically reduces
# performance.  Alternately, it can cause the kernel to kill
# processes, to reduce system memory usage, which causes the overall
# job to fail.  Thus we would like to calculate a value of N that is
# no more than:

# (currently free mem / expected mem used per parallel job)

# The caller must provide a value for "expected mem used per parallel
# job", because this code has no way to estimate that.

max_parallel_jobs() {
    local expected_mem_per_job_MBytes=$1
    local memtotal_KBytes=`head -n 1 /proc/meminfo | awk '{print $2;}'`
    local memtotal_MBytes=`expr ${memtotal_KBytes} / 1024`
    local max_jobs_for_mem=`expr ${memtotal_MBytes} / ${expected_mem_per_job_MBytes}`
    local max_jobs_for_processors=`grep -c '^processor' /proc/cpuinfo`
    1>&2 echo "Available memory (MBytes): ${memtotal_MBytes}"
    1>&2 echo "Expected memory used per job (MBytes): ${expected_mem_per_job_MBytes}"
    1>&2 echo "Max number of parallel jobs for available mem: ${max_jobs_for_mem}"
    1>&2 echo "Max number of parallel jobs for processors: ${max_jobs_for_processors}"
    if [ ${max_jobs_for_processors} -lt ${max_jobs_for_mem} ]
    then
        echo ${max_jobs_for_processors}
    elif [ ${max_jobs_for_mem} -ge 1 ]
    then
        echo ${max_jobs_for_mem}
    else
        echo 1
    fi
}

abort_script=0

if [ ! -r /etc/os-release ]
then
    1>&2 echo "No file /etc/os-release.  Cannot determine what OS this is."
    linux_version_warning
    exit 1
fi
source /etc/os-release
PROCESSOR=`uname --machine`

supported_distribution=0
tried_but_got_build_errors=0
if [ "${ID}" = "ubuntu" ]
then
    case "${VERSION_ID}" in
        22.04)
            supported_distribution=1
            INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=1
            # Versions installed by Ubuntu apt
            PROTOBUF_PKG_VERSION="3.12.4"
            GRPC_PKG_VERSION="1.30.2"
            # Closest versions available via "pip3 install" to the above
            PROTOBUF_PYTHON_PKG_VERSION="3.12.4"
	    GRPCIO_PYTHON_PKG_VERSION="1.51.3"
            ;;
        24.04)
            supported_distribution=1
            INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=1
            # Versions installed by Ubuntu apt
            PROTOBUF_PKG_VERSION="3.21.12"
            GRPC_PKG_VERSION="1.51.1"
            # Closest versions available via "pip3 install" to the above
            PROTOBUF_PYTHON_PKG_VERSION="4.21.12"
	    # grpcio version 1.51.3 fails to install on Ubuntu 24.04
	    # as of 2024-May-20.
	    GRPCIO_PYTHON_PKG_VERSION="1.59.3"
            ;;
        26.04)
            #############################################################
            # Use Ubuntu apt to install grpc and protobuf
            #############################################################
            supported_distribution=1
            INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=1
            # Versions installed by Ubuntu apt
            PROTOBUF_PKG_VERSION="3.21.12"
            GRPC_PKG_VERSION="1.51.1"
            # Closest versions available via "pip3 install" to the above
            PROTOBUF_PYTHON_PKG_VERSION="4.21.12"
	    # TODO: Try changing grpcio to version 1.51.1 to see if it
	    # works.  'uv pip install grpcio==<version>' fails to
	    # install on Ubuntu 26.04 for versions 1.51.3 and 1.59.3
	    # as of 2026-Oct-03.  This version installs, and enables
	    # tests to pass.
	    GRPCIO_PYTHON_PKG_VERSION="1.75.1"

            #############################################################
            # Build grpc and protobuf from source
            #############################################################
            #supported_distribution=1
            #INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=0
            ## Version of grpc source to install by building it
            #GRPC_SOURCE_VERSION="1.75.1"
            ## Version of Python package protobuf to install
            ## corresponding to grpc source version above
            #PROTOBUF_PYTHON_PKG_VERSION="6.31.0"
            ;;
    esac
fi

if [ ${INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS} -eq 1 ]
then
    GRPC_VERSION=${GRPC_PKG_VERSION}
else
    GRPC_VERSION=${GRPC_SOURCE_VERSION}
fi

if [ ${supported_distribution} -eq 1 ]
then
    echo "Found supported ID ${ID} and VERSION_ID ${VERSION_ID} in /etc/os-release"
else
    linux_version_warning
    if [ ${tried_but_got_build_errors} -eq 1 ]
    then
        1>&2 echo ""
        1>&2 echo "This OS has been tried at least once before, but"
        1>&2 echo "there were errors during a compilation or build"
        1>&2 echo "step that have not yet been fixed.  If you have"
        1>&2 echo "experience in fixing such matters, your help is"
        1>&2 echo "appreciated."
    fi
    exit 1
fi

# Minimum required system memory is 2 GBytes, minus a few MBytes
# because from experiments I have run on several different Ubuntu
# Linux VMs, when you configure them with 2 Gbytes of RAM, the first
# line of /proc/meminfo shows a little less than that available, I
# believe because some memory occupied by the kernel is not shown.

min_mem_MBytes=`expr 2 \* \( 1024 - 64 \)`
memtotal_KBytes=`head -n 1 /proc/meminfo | awk '{print $2;}'`
memtotal_MBytes=`expr ${memtotal_KBytes} / 1024`

if [ "${memtotal_MBytes}" -lt "${min_mem_MBytes}" ]
then
    memtotal_comment="too low"
    abort_script=1
else
    memtotal_comment="enough"
fi

echo "Minimum recommended memory to run this script: ${min_mem_MBytes} MBytes"
echo "Memory on this system from /proc/meminfo:      ${memtotal_MBytes} MBytes -> $memtotal_comment"

min_free_disk_MBytes=`expr 8 \* 1024`
free_disk_MBytes=`df --output=avail --block-size=1M . | tail -n 1`

if [ "${free_disk_MBytes}" -lt "${min_free_disk_MBytes}" ]
then
    free_disk_comment="too low"
    abort_script=1
else
    free_disk_comment="enough"
fi

echo "Minimum free disk space to run this script:    ${min_free_disk_MBytes} MBytes"
echo "Free disk space on this system from df output: ${free_disk_MBytes} MBytes -> $free_disk_comment"

if [ "${abort_script}" == 1 ]
then
    echo ""
    echo "Aborting script because system has too little RAM or free disk space"
    exit 1
fi

PATCH_DIR1="${THIS_SCRIPT_DIR_ABSOLUTE}/patches"

for dir in "${PATCH_DIR1}"
do
    if [ -d "${dir}" ]
    then
        echo "Found directory containing patches: ${dir}"
    else
        echo "NO directory containing patches: ${dir}"
        abort_script=1
    fi
done

if [ "${abort_script}" == 1 ]
then
    echo ""
    echo "Aborting script because an expected directory does not exist (see above)."
    echo ""
    echo "This script is not designed to work if you only copy the"
    echo "script file to a system.  You should run it in the context"
    echo "of a cloned copy of the repository: https://github/jafingerhut/p4-guide"
    exit 1
fi

echo "Passed all sanity checks"

DISK_USED_START=`get_used_disk_space_in_mbytes`

set -e
set -x

set +x
echo "This script builds and installs the P4_16 (and also P4_14)"
echo "compiler, and the behavioral-model software packet forwarding"
echo "program, that can behave as just about any legal P4 program."
echo ""
echo "It is regularly tested on freshly installed versions of these systems:"
echo "    Ubuntu 22.04"
echo "    Ubuntu 24.04"
echo "    Ubuntu 26.04"
echo "with all Ubuntu software updates as of the date of testing.  See"
echo "this directory for log files recording the last date this script"
echo "was tested on its supported operating systems:"
echo ""
echo "    https://github.com/jafingerhut/p4-guide/tree/master/bin/output"
echo ""
echo "The files installed by this script consume about 8 GB of disk space."
echo ""
echo "On a 2019 MacBook Pro with a decent speed Internet connection"
echo "and an SSD drive, running Ubuntu Linux in a VirtualBox VM, it"
echo "took about 2 hours."
echo ""
echo "Versions of software that will be installed by this script:"
echo ""
echo "+ gRPC: github.com/google/grpc.git v${GRPC_VERSION}"
echo "+ PI: github.com/p4lang/PI latest version"
echo "+ behavioral-model: github.com/p4lang/behavioral-model latest version"
echo "  which, as of 2026-Oct-03, also installs these things:"
echo "  + thrift version 0.22.0"
echo "  + nanomsg version 1.0.0"
echo "  + nnpy latest version available via 'pip install'"
echo "+ p4c: github.com/p4lang/p4c latest version"
echo "+ ptf: github.com/p4lang/ptf latest version"
echo "+ Mininet: github.com/mininet/mininet latest version as of 2024-Sep-18"
echo "+ Python packages: protobuf ${PROTOBUF_PYTHON_PKG_VERSION}, grpcio ${GRPCIO_PYTHON_PKG_VERSION}"
echo "+ Python packages: scapy (2.5.0), psutil, crcmod"
echo ""
echo "Note that anything installed as 'the latest version' can change"
echo "its precise contents from one run of this script to another."
echo "That is an intentional property of this script -- to get the"
echo "latest version of that software.  If you want particular"
echo "versions that are not the latest, you can modify this script by"
echo "adding 'git checkout <tag>' and/or 'git checkout <commit-sha>'"
echo "command at the appropriate places."
echo ""
set -x


set +x
REPO_CACHE_DIR="${INSTALL_DIR}/repository-cache"
get_from_nearest() {
    local git_url="$1"
    local repo_cache_name="$2"

    if [ -e "${REPO_CACHE_DIR}/${repo_cache_name}" ]
    then
        echo "Creating contents of ${git_url} from local cached copy ${REPO_CACHE_DIR}/${repo_cache_name}"
        tar xkzf "${REPO_CACHE_DIR}/${repo_cache_name}"
    else
        echo "git clone ${git_url}"
        git clone "${git_url}"
    fi
}

change_owner_and_group_of_venv_lib_python3_files() {
    local venv
    local user_name
    local group_name

    venv="$1"
    user_name=`id --user --name`
    group_name=`id --group --name`
    sudo chown -R ${user_name}:${group_name} ${venv}/lib/python*/site-packages
}


echo "------------------------------------------------------------"
echo "Time and disk space used before installation begins:"
set -x
date
df -h .
df -BM .
TIME_START=$(date +%s)

# Check to see which versions of Python-related programs this system
# already has installed, before the script starts installing things.
python -V  || echo "No such command in PATH: python"
python3 -V || echo "No such command in PATH: python3"
pip -V  || echo "No such command in PATH: pip"
pip2 -V || echo "No such command in PATH: pip2"
pip3 -V || echo "No such command in PATH: pip3"

dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/000-init"

# On new systems if you have never checked repos you should do that first

# Install a few packages (vim is not strictly necessary -- installed for
# my own convenience):
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes update
    sudo apt-get --yes install git vim
fi

# It appears that some part of the build process for Thrift 0.16.0
# requires that pip3 has been installed first.  Without this, there is
# an error during building Thrift 0.16.0 where a Python 3 program
# cannot import from the setuptools package.
if [ "${ID}" = "ubuntu" ]
then
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/003-just-before-python3-pip-install"
    sudo apt-get --yes install \
         autoconf automake libtool curl make g++ unzip \
         pkg-config python3-pip python3-venv
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/005-after-python-apt-installs"
fi

if ! command -v uv &> /dev/null; then
    # Install uv
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
fi
which uv
uv pip list

if [ ! -d "${PYTHON_VENV}" ]
then
    # Create a new Python virtual environment using venv.  Later we
    # will attempt to ensure that all new Python packages installed
    # are installed into this virtual environment, not into
    # system-wide directories like /usr/local/bin
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/008-just-before-venv-creation"
    uv venv "${PYTHON_VENV}"
fi
source "${PYTHON_VENV}/bin/activate"
# Set this variable to enable `uv sync` and other commands to use the
# venv.
export UV_PROJECT_ENVIRONMENT="${VIRTUAL_ENV}"
echo "VIRTUAL_ENV=${VIRTUAL_ENV}"
echo "UV_PROJECT_ENVIRONMENT=${UV_PROJECT_ENVIRONMENT}"

pip -V  || echo "No such command in PATH: pip"
pip2 -V || echo "No such command in PATH: pip2"
pip3 -V || echo "No such command in PATH: pip3"
# At multiple points I do a 'pip list' command.  This is not required
# for a successful installation -- I do it mainly because I am curious
# to see in the log output files from running this script what
# packages and versions were installed at those times during script
# execution.
pip list  || echo "Some error occurred attempting to run command: pip"
pip3 list || echo "Some error occurred attempting to run command: pip3"

cd "${INSTALL_DIR}"

set +x
echo "------------------------------------------------------------"
echo "Installing grpc, needed for installing p4lang/PI"
echo "start install grpc:"
set -x
date

# We might not need cmake for installing Protobuf and gRPC, but we
# will definitely use it later below, even if not immediately.
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes install cmake
fi

if [ ${INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS} -eq 1 ]
then
    debug_dump_many_install_files ${INSTALL_DIR}/usr-local-1-before-protobuf.txt
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/010-before-installing-grpc"
    TIME_GRPC_CLONE_START=$(date +%s)
    TIME_GRPC_CLONE_END=$(date +%s)
    TIME_GRPC_INSTALL_START=$(date +%s)
    sudo apt-get --yes install libprotobuf-dev protobuf-compiler protobuf-compiler-grpc libgrpc-dev libgrpc++-dev
    if [ "${PROTOBUF_PYTHON_PKG_VERSION}" != "" ]
    then
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/013-just-before-installing-protobuf-via-pip"
        uv pip install protobuf==${PROTOBUF_PYTHON_PKG_VERSION}
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/015-after-installing-protobuf-via-pip"
    fi
    TIME_GRPC_INSTALL_END=$(date +%s)
    uv pip list
else
    if [ ! -d grpc ]
    then
        debug_dump_many_install_files ${INSTALL_DIR}/usr-local-1-before-protobuf.txt
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/010-before-installing-grpc"
    fi
    # Do not bother installing protobuf package from source code, as
    # whatever parts of protobuf we need is installed as a result of
    # installing grpc from source code, and/or installing the Python
    # protobuf package using pip.
    if [ "${PROTOBUF_PYTHON_PKG_VERSION}" != "" ]
    then
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/013-just-before-installing-protobuf-via-pip"
        uv pip install protobuf==${PROTOBUF_PYTHON_PKG_VERSION}
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/015-after-installing-protobuf-via-pip"
    fi

    cd "${INSTALL_DIR}"
    debug_dump_many_install_files ${INSTALL_DIR}/usr-local-2-after-protobuf.txt

    # From BUILDING.md of grpc source repository
    if [ "${ID}" = "ubuntu" ]
    then
        sudo apt-get --yes install build-essential autoconf libtool pkg-config
        if [ ${USE_DISTRIBUTION_SSL_PACKAGE} -eq 1 ]
        then
            # TODO: This package is not mentioned in grpc BUILDING.md
            # instructions, but when I tried on Ubuntu 20.04 without it, the
            # building of grpc failed with not being able to find an OpenSSL
            # library.
            sudo apt-get --yes install libssl-dev
        fi
    fi

    TIME_GRPC_CLONE_START=$(date +%s)
    TIME_GRPC_CLONE_END=$(date +%s)
    TIME_GRPC_INSTALL_START=$(date +%s)
    DISK_USED_BEFORE_GRPC_CLEANUP=`get_used_disk_space_in_mbytes`
    if [ -d grpc ]
    then
        echo "Found directory ${INSTALL_DIR}/grpc.  Assuming desired version of grpc is already installed."
    else
        TIME_GRPC_CLONE_START=$(date +%s)
        if [ -r ${REPO_CACHE_DIR}/grpc-with-submodules-v${GRPC_SOURCE_VERSION}.tar.gz ]
        then
            get_from_nearest https://github.com/grpc/grpc.git grpc-with-submodules-v${GRPC_SOURCE_VERSION}.tar.gz
            cd grpc
        else
            get_from_nearest https://github.com/grpc/grpc.git grpc.tar.gz
            cd grpc
            git checkout v${GRPC_SOURCE_VERSION}
            # These commands are recommended in grpc's BUILDING.md file for Unix:
            git submodule update --init --recursive
        fi
        TIME_GRPC_CLONE_END=$(date +%s)
        TIME_GRPC_INSTALL_START=$(date +%s)
        mkdir -p cmake/build
        cd cmake/build
        GRPC_CMAKE_OPTS="-DgRPC_INSTALL=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_STANDARD=17"
        if [ ${USE_DISTRIBUTION_SSL_PACKAGE} -eq 1 ]
        then
           # I learned about the cmake option
           # -DgRPC_SSL_PROVIDER=package from the pages linked below,
           # after experiencing link-time errors when trying to build
           # behavioral-model with gRPC v1.54.2 and getting errors
           # that it could not find symbols like OPENSSL_free, and
           # many others.
           # https://github.com/grpc/grpc/issues/30524
           GRPC_CMAKE_OPTS="${GRPC_CMAKE_OPTS} -DgRPC_SSL_PROVIDER=package"
        fi
        cmake ${GRPC_CMAKE_OPTS} ../..
        make
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/013-just-before-grpc-sudo-make-install"
        sudo make install
        cd ../..
        sudo ldconfig
        dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/020-after-installing-grpc-from-source"
        # Without the following command, later the command 'pkg-config
        # --cflags grpc' fails, at least on Ubuntu 23.10 after building
        # grpc v1.54.2
        RE2_PKGCONFIG_FILE=""
        if [ -e third_party/re2/re2.pc ]
        then
            RE2_PKGCONFIG_FILE="third_party/re2/re2.pc"
        elif [ -e third_party/bloaty/third_party/re2/re2.pc ]
        then
            RE2_PKGCONFIG_FILE="third_party/bloaty/third_party/re2/re2.pc"
        fi
        if [ "${RE2_PKGCONFIG_FILE}" != "" ]
        then
            sudo /usr/bin/install -c -m 644 ${RE2_PKGCONFIG_FILE} /usr/local/lib/pkgconfig
        fi
        DISK_USED_BEFORE_GRPC_CLEANUP=`get_used_disk_space_in_mbytes`
        if [ ${CLEAN_UP_AS_WE_GO} -eq 1 ]
        then
            echo "Disk space used just before cleaning up grpc:"
            df -BM .
            cd "${INSTALL_DIR}"
            /bin/rm -fr grpc
            # Make an empty directory with the name grpc, so that if a
            # later step fails, and someone re-runs this script, it will
            # not build grpc again.
            mkdir grpc
        fi
        TIME_GRPC_INSTALL_END=$(date +%s)
        echo "grpc clone             : $(($TIME_GRPC_CLONE_END-$TIME_GRPC_CLONE_START)) sec"
        echo "grpc install           : $(($TIME_GRPC_INSTALL_END-$TIME_GRPC_INSTALL_START)) sec"
    fi
fi
DISK_USED_AFTER_GRPC=`get_used_disk_space_in_mbytes`

set +x
echo "end install grpc:"
set -x
date

# Check how many hidden symbols are in libprotobuf.a.  When building
# behavioral-model succeeds later, there are only 2 unique hidden
# symbols.  When I see many more unique hidden symbols, building
# behavioral-model later typically fails with an error while trying to
# link with libprotobuf.a
objdump -t /usr/local/lib/libprotobuf.a | grep hidden | sort | uniq -c | wc -l
objdump -t /usr/local/lib/libprotobuf.a | grep hidden | sort | uniq -c | sort -nr | head -n 20

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-3-after-grpc.txt

set +x
echo "------------------------------------------------------------"
echo "Installing p4lang/PI, needed for installing p4lang/behavioral-model simple_switch_grpc"
echo "start install PI:"
set -x
date

TIME_PI_CLONE_START=$(date +%s)
TIME_PI_CLONE_END=$(date +%s)
TIME_PI_INSTALL_START=$(date +%s)
# Deps needed to build PI:
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes install libreadline-dev valgrind libtool-bin libboost-dev libboost-thread-dev
    if [ "${VERSION_ID}" != "26.04" ]
    then
        # libboost-system-dev package does not exist on Ubuntu 26.04
        # (it did on Ubuntu 22.04 and 24.04).
        sudo apt-get --yes install libboost-system-dev
    fi
fi

DISK_USED_BEFORE_PI_CLEANUP=`get_used_disk_space_in_mbytes`
if [ -d PI ]
then
    echo "Found directory ${INSTALL_DIR}/PI.  Assuming desired version of PI is already installed."
else
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/025-before-PI"
    TIME_PI_CLONE_START=$(date +%s)
    git clone https://github.com/p4lang/PI
    cd PI
    if [ "x${INSTALL_PI_SOURCE_VERSION}" != "x" ]; then
        git checkout ${INSTALL_PI_SOURCE_VERSION}
    fi
    git submodule update --init --recursive
    TIME_PI_CLONE_END=$(date +%s)
    git log -n 1
    TIME_PI_INSTALL_START=$(date +%s)
    if [ "${ID}" == "ubuntu" -a "${VERSION_ID}" == "26.04" ]
    then
        # libboost-system-dev package does not exist on Ubuntu 26.04
        # (it did on Ubuntu 22.04 and 24.04).
        PATCH_DIR="${THIS_SCRIPT_DIR_ABSOLUTE}/patches"
        patch -p1 < "${PATCH_DIR}/PI-dont-require-boost-system.patch"
    fi
    ./autogen.sh
    # Cause 'sudo make install' to install Python packages for PI in a
    # Python virtual environment, if one is in use.
    configure_python_prefix="--with-python_prefix=${PYTHON_VENV}"
    if [ "${ID}" = "ubuntu" ]
    then
        ./configure --with-proto --without-internal-rpc --without-cli --without-bmv2 ${configure_python_prefix}
    fi
    # Check what version of protoc is installed before the 'make'
    # command below uses protoc on P4Runtime protobuf definition
    # files.
    which protoc
    type -a protoc
    protoc --version
    set +e
    /usr/local/bin/protoc --version
    set -e
    make
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/027-PI-just-before-sudo-make-install"
    sudo make install
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/029-PI-just-after-sudo-make-install"

    DISK_USED_BEFORE_PI_CLEANUP=`get_used_disk_space_in_mbytes`
    if [ ${CLEAN_UP_AS_WE_GO} -eq 1 ]
    then
        echo "Disk space used just before cleaning up PI:"
        df -BM .
        # Save about 0.25G of storage by cleaning up PI build
        make clean
    fi
    # 'sudo make install' installs several files in ${PYTHON_VENV} with
    # root owner.  Change them to be owned by the regular user id.
    change_owner_and_group_of_venv_lib_python3_files ${PYTHON_VENV}
fi
TIME_PI_INSTALL_END=$(date +%s)
echo "p4lang/PI clone        : $(($TIME_PI_CLONE_END-$TIME_PI_CLONE_START)) sec"
echo "p4lang/PI install      : $(($TIME_PI_INSTALL_END-$TIME_PI_INSTALL_START)) sec"
DISK_USED_AFTER_PI=`get_used_disk_space_in_mbytes`

set +x
echo "end install PI:"
set -x
date

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-4-after-PI.txt

set +x
echo "------------------------------------------------------------"
echo "Installing p4lang/behavioral-model"
echo "start install behavioral-model:"
set -x
date

TIME_BEHAVIORAL_MODEL_CLONE_START=$(date +%s)
TIME_BEHAVIORAL_MODEL_CLONE_END=$(date +%s)
TIME_BEHAVIORAL_MODEL_INSTALL_START=$(date +%s)
# Following instructions in the file
# targets/simple_switch_grpc/README.md in the p4lang/behavioral-model
# repository with git commit 66cefc5e901eafcebb0e1a8f681a05795463215a.
# That README.md file was last updated 2018-Apr-03.

# It says to first follow the instructions here:
# https://github.com/p4lang/PI#dependencies to install required
# dependencies for the `--with-proto` configure flag.  This script
# does _not_ use the option `--with-sysrepo` configure flag, which is
# needed for experimental gNMI support.  That should all have been
# done by this time, by the script above.

DISK_USED_BEFORE_BMV2_CLEANUP=`get_used_disk_space_in_mbytes`
if [ -d behavioral-model ]
then
    echo "Found directory ${INSTALL_DIR}/behavioral-model.  Assuming desired version of behavioral-model is already installed."
else
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/030-before-behavioral-model"
    TIME_BEHAVIORAL_MODEL_CLONE_START=$(date +%s)
    get_from_nearest https://github.com/p4lang/behavioral-model.git behavioral-model.tar.gz
    cd behavioral-model
    # Get latest updates that are not in the repo cache version
    git pull
    if [ "x${INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION}" != "x" ]; then
        git checkout ${INSTALL_BEHAVIORAL_MODEL_SOURCE_VERSION}
    fi
    TIME_BEHAVIORAL_MODEL_CLONE_END=$(date +%s)
    git log -n 1
    TIME_BEHAVIORAL_MODEL_INSTALL_START=$(date +%s)
    PATCH_DIR="${THIS_SCRIPT_DIR_ABSOLUTE}/patches"
    patch -p1 < "${PATCH_DIR}/behavioral-model-adjust-ubuntu-packges.patch"
    patch -p1 < "${PATCH_DIR}/behavioral-model-support-venv-2026-sep.patch"
    if [ "${ID}" == "ubuntu" -a "${VERSION_ID}" == "26.04" ]
    then
        # I have confirmed that as of the latest version of this
        # script on 2026-Oct-02, if you attempt to run it with the
        # only change being to remove the following patch command, the
        # linking of simple_switch_grpc fails on Ubuntu 26.04.  I
        # think it builds fine on Ubuntu 22.04 and 24.04 without these
        # changes.  I do not know why there is a difference on 26.04.
        patch -p1 < "${PATCH_DIR}/behavioral-model-extra-libs-for-build.patch"
    fi
    # This command installs Thrift, which I want to include in my build of
    # simple_switch_grpc
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/031-behavioral-model-just-before-install_deps"
    ./install_deps.sh
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/035-behavioral-model-just-after-install_deps"
    mkdir build
    cd build
    cmake -DWITH_PI=on -DWITH_THRIFT=on -DENABLE_MODULES=on ..
    make
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/038-behavioral-model-just-before-sudo-make-install-strip"
    sudo make install/strip
    sudo ldconfig
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/040-after-behavioral-model-install"
    # 'sudo make install/strip' installs several files in ${PYTHON_VENV}
    # with root owner.  Change them to be owned by the regular user id.
    change_owner_and_group_of_venv_lib_python3_files ${PYTHON_VENV}
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/045-after-behavioral-model-change_owner"
    DISK_USED_BEFORE_BMV2_CLEANUP=`get_used_disk_space_in_mbytes`
    if [ ${CLEAN_UP_AS_WE_GO} -eq 1 ]
    then
        echo "Disk space used just before cleaning up behavioral-model:"
        df -BM .
        cd "${INSTALL_DIR}"
        cd behavioral-model
        /bin/rm -fr build
    fi
fi
TIME_BEHAVIORAL_MODEL_INSTALL_END=$(date +%s)
echo "p4lang/behavioral-model clone  : $(($TIME_BEHAVIORAL_MODEL_CLONE_END-$TIME_BEHAVIORAL_MODEL_CLONE_START)) sec"
echo "p4lang/behavioral-model install: $(($TIME_BEHAVIORAL_MODEL_INSTALL_END-$TIME_BEHAVIORAL_MODEL_INSTALL_START)) sec"
DISK_USED_AFTER_BMV2=`get_used_disk_space_in_mbytes`

set +x
echo "end install behavioral-model:"
set -x
date

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-5-after-behavioral-model.txt

if [ ! -d p4c ]
then
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/050-before-p4c"
fi

set +x
echo "------------------------------------------------------------"
echo "Installing p4lang/p4c"
echo "start install p4c:"
set -x
date

TIME_P4C_CLONE_START=$(date +%s)
TIME_P4C_CLONE_END=$(date +%s)
TIME_P4C_INSTALL_START=$(date +%s)
# Installing clang is not needed for building p4c, but it does enable
# ebpf tests run by `make check` in the p4c/build directory to pass.
if [ "${ID}" = "ubuntu" ]
then
    # Install Ubuntu dependencies needed by p4c, from its README.md.
    # It may not match the latest p4c README.md suggested list of
    # packages as of today, but it is tested every month.
    sudo apt-get --yes install g++ git automake libtool libgc-dev \
         bison flex libfl-dev libgmp-dev \
         libboost-dev libboost-iostreams-dev libboost-graph-dev \
         llvm pkg-config python3-pip tcpdump libelf-dev clang
fi
# Starting in 2019-Nov, Python3 version of Scapy is needed for `cd
# p4c/build ; make check` to succeed.
# ply package is needed for ebpf and ubpf backend tests to pass
# TODO: It appears that some changes were made from scapy 2.5.0 to
# 2.6.0 that require changes in P4 open source tools in order to use
# version 2.6.0.  Until those changes are made, install scapy 2.5.0.
uv pip install scapy==2.5.0 ply
uv pip list

if [ ! -d p4c ]
then
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/055-before-p4c-after-install-scapy"
fi

DISK_USED_BEFORE_P4C_CLEANUP=`get_used_disk_space_in_mbytes`
if [ -d p4c ]
then
    echo "Found directory ${INSTALL_DIR}/p4c.  Assuming desired version of p4c is already installed."
else
    TIME_P4C_CLONE_START=$(date +%s)
    # Clone p4c and its submodules:
    get_from_nearest https://github.com/p4lang/p4c.git p4c.tar.gz
    cd p4c
    # Get latest updates that are not in the repo cache version
    git pull
    if [ "x${INSTALL_P4C_SOURCE_VERSION}" != "x" ]; then
        git checkout ${INSTALL_P4C_SOURCE_VERSION}
    fi
    git log -n 1
    git submodule update --init --recursive
    TIME_P4C_CLONE_END=$(date +%s)
    TIME_P4C_INSTALL_START=$(date +%s)
    P4C_CMAKE_OPTS="-DENABLE_TEST_TOOLS=ON"
    mkdir build
    cd build
    # Configure for a release build and build p4testgen
    cmake .. -DCMAKE_BUILD_TYPE=Release ${P4C_CMAKE_OPTS}
    MAX_PARALLEL_JOBS=`max_parallel_jobs 2048`
    make -j${MAX_PARALLEL_JOBS}
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/058-p4c-just-before-sudo-make-install-strip"
    sudo make install/strip
    dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/060-p4c-just-after-sudo-make-install-strip"
    sudo ldconfig
    DISK_USED_BEFORE_P4C_CLEANUP=`get_used_disk_space_in_mbytes`
    if [ ${CLEAN_UP_AS_WE_GO} -eq 1 -a ${KEEP_P4C_BUILD_FOR_TESTING} -eq 0 ]
    then
        echo "Disk space used just before cleaning up p4c:"
        df -BM .
        cd "${INSTALL_DIR}"
        cd p4c
        /bin/rm -fr build
    fi
fi
TIME_P4C_INSTALL_END=$(date +%s)
echo "p4lang/p4c clone       : $(($TIME_P4C_CLONE_END-$TIME_P4C_CLONE_START)) sec"
echo "p4lang/p4c install     : $(($TIME_P4C_INSTALL_END-$TIME_P4C_INSTALL_START)) sec"
DISK_USED_AFTER_P4C=`get_used_disk_space_in_mbytes`

set +x
echo "end install p4c:"
set -x
date

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-6-after-p4c.txt

set +x
echo "------------------------------------------------------------"

echo "Installing Mininet - not necessary to run P4 programs, but useful if"
echo "you want to run tutorials from https://github.com/p4lang/tutorials"
echo "repository."
echo "start install mininet:"
set -x
date

TIME_MININET_START=$(date +%s)
# Pin to a particular version, so that I know the patch below will
# continue to apply.  Will likely want to update this to newer
# versions once or twice a year.
MININET_COMMIT="6eb8973c0bfd13c25c244a3871130c5e36b5fbd7"  # 2024-Sep-18
git clone https://github.com/mininet/mininet mininet
cd mininet
git checkout ${MININET_COMMIT}
PATCH_DIR="${THIS_SCRIPT_DIR_ABSOLUTE}/patches"
patch -p1 < "${PATCH_DIR}/mininet-patch-for-2026-sep-enable-uv-venv.patch"
cd ..
RESTORE_SUDOERS_FILE=0
if [ -e /etc/sudoers.d/sudoers-dotfiles ]
then
    # Starting with Ubuntu 24.04, by default it includes a sudo
    # configuration file that disallows passing environment variables
    # such as DEBIAN_FRONTEND on a sudo command line for apt-get
    # commands.  On such systems, temporarily rename this
    # configuration file while installing Mininet, since Mininet's
    # install script uses this feature of sudo.
    sudo mv /etc/sudoers.d/sudoers-dotfiles /etc/sudoers.d/sudoers-dotfiles.orig
    RESTORE_SUDOERS_FILE=1
fi
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/065-mininet-just-before-install"
PYTHON=python3 ./mininet/util/install.sh -nw
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/070-mininet-just-after-install"
if [ ${RESTORE_SUDOERS_FILE} -eq 1 ]
then
    sudo mv /etc/sudoers.d/sudoers-dotfiles.orig /etc/sudoers.d/sudoers-dotfiles
fi
TIME_MININET_END=$(date +%s)
echo "mininet                : $(($TIME_MININET_END-$TIME_MININET_START)) sec"
DISK_USED_AFTER_MININET=`get_used_disk_space_in_mbytes`

set +x
echo "end install mininet:"
set -x
date

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-7-after-mininet-install.txt

set +x
echo "------------------------------------------------------------"

echo "Installing PTF"
echo "start install ptf:"
set -x
date

TIME_PTF_START=$(date +%s)
# Attempting this command was causing errors on Ubuntu 22.04 systems.
# The ptf README says it is optional, so leave it out for now,
# until/unless someone discovers a way to install it correctly on
# Ubuntu 22.04.
#sudo pip3 install pypcap

dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/075-before-ptf"
git clone https://github.com/p4lang/ptf
cd ptf
if [ "x${INSTALL_PTF_SOURCE_VERSION}" != "x" ]; then
    git checkout ${INSTALL_PTF_SOURCE_VERSION}
fi
git log -n 1
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/078-ptf-just-before-pip-install"
uv pip install .
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/080-ptf-just-after-pip-install"
TIME_PTF_END=$(date +%s)
echo "p4lang/ptf             : $(($TIME_PTF_END-$TIME_PTF_START)) sec"

set +x
echo "end install ptf:"
set -x
date

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-8-after-ptf-install.txt

set +x
echo "------------------------------------------------------------"
echo "Installing a few miscellaneous packages"
echo "start install miscellaneous packages:"
set -x
date

# Things needed for `cd tutorials/exercises/basic ; make run` to work:
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes install libgflags-dev net-tools
fi
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/084-before-pip-install-psutil-crcmod"
uv pip install psutil crcmod
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/085-after-pip-install-psutil-crcmod"

# Install p4runtime-shell from source repo, with a slightly modified
# setup.cfg file so that it allows us to keep the version of the
# protobuf package already installed earlier above, without changing
# it, and so that it does _not_ install the p4runtime Python package,
# which would replace the current Python files in
# ${PYTHON_VENV}/lib/python*/site-packages/p4 with ones generated
# using an older version of protobuf.

# First install a known working version of the grpcio package, because
# otherwise installing p4runtime-shell packages will likely pick some
# very recent version of grpcio that may cause trouble.
uv pip install wheel
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/090-after-pip-install-wheel"
uv pip install grpcio=="${GRPCIO_PYTHON_PKG_VERSION}"
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/095-after-pip-install-grpcio"

git clone https://github.com/p4lang/p4runtime-shell
cd p4runtime-shell
if [ "x${INSTALL_P4RUNTIME_SHELL_SOURCE_VERSION}" != "x" ]; then
    git checkout ${INSTALL_P4RUNTIME_SHELL_SOURCE_VERSION}
fi
git log -n 1
PATCH_DIR="${THIS_SCRIPT_DIR_ABSOLUTE}/patches"
patch -p1 < "${PATCH_DIR}/p4runtime-shell-2023-changes.patch"
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/099-p4runtime-shell-just-before-pip-install"
uv pip install .
dump_python_lib_info "${PYTHON_DEBUG_DUMP_DIR}/100-p4runtime-shell-just-after-pip-install"

uv pip list

set +x
echo "end install miscellaneous packages:"
set -x
date

cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-9-after-miscellaneous-install.txt

pip list  || echo "Some error occurred attempting to run command: pip"
uv pip list

set +e

set +x
echo "------------------------------------------------------------"
echo "Time and disk space used when installation was complete:"
set -x
date
df -h .
df -BM .
TIME_END=$(date +%s)
set +x
echo ""
echo "Elapsed time for various install steps:"
echo "grpc clone             : $(($TIME_GRPC_CLONE_END-$TIME_GRPC_CLONE_START)) sec"
echo "grpc install           : $(($TIME_GRPC_INSTALL_END-$TIME_GRPC_INSTALL_START)) sec"
echo "p4lang/PI clone        : $(($TIME_PI_CLONE_END-$TIME_PI_CLONE_START)) sec"
echo "p4lang/PI install      : $(($TIME_PI_INSTALL_END-$TIME_PI_INSTALL_START)) sec"
echo "p4lang/behavioral-model clone  : $(($TIME_BEHAVIORAL_MODEL_CLONE_END-$TIME_BEHAVIORAL_MODEL_CLONE_START)) sec"
echo "p4lang/behavioral-model install: $(($TIME_BEHAVIORAL_MODEL_INSTALL_END-$TIME_BEHAVIORAL_MODEL_INSTALL_START)) sec"
echo "p4lang/p4c clone       : $(($TIME_P4C_CLONE_END-$TIME_P4C_CLONE_START)) sec"
echo "p4lang/p4c install     : $(($TIME_P4C_INSTALL_END-$TIME_P4C_INSTALL_START)) sec"
echo "mininet                : $(($TIME_MININET_END-$TIME_MININET_START)) sec"
echo "p4lang/ptf             : $(($TIME_PTF_END-$TIME_PTF_START)) sec"
echo "Total time             : $(($TIME_END-$TIME_START)) sec"
set -x

DISK_USED_END=`get_used_disk_space_in_mbytes`

set +x
echo "All disk space utilizations below are in MBytes:"
echo ""
echo  "DISK_USED_START                ${DISK_USED_START}"
echo  "DISK_USED_BEFORE_GRPC_CLEANUP  ${DISK_USED_BEFORE_GRPC_CLEANUP}"
echo  "DISK_USED_AFTER_GRPC           ${DISK_USED_AFTER_GRPC}"
echo  "DISK_USED_BEFORE_PI_CLEANUP    ${DISK_USED_BEFORE_PI_CLEANUP}"
echo  "DISK_USED_AFTER_PI             ${DISK_USED_AFTER_PI}"
echo  "DISK_USED_BEFORE_BMV2_CLEANUP  ${DISK_USED_BEFORE_BMV2_CLEANUP}"
echo  "DISK_USED_AFTER_BMV2           ${DISK_USED_AFTER_BMV2}"
echo  "DISK_USED_BEFORE_P4C_CLEANUP   ${DISK_USED_BEFORE_P4C_CLEANUP}"
echo  "DISK_USED_AFTER_P4C            ${DISK_USED_AFTER_P4C}"
echo  "DISK_USED_AFTER_MININET        ${DISK_USED_AFTER_MININET}"
echo  "DISK_USED_END                  ${DISK_USED_END}"

DISK_USED_MAX=`max_of_list ${DISK_USED_START} ${DISK_USED_BEFORE_GRPC_CLEANUP} ${DISK_USED_AFTER_GRPC} ${DISK_USED_BEFORE_PI_CLEANUP} ${DISK_USED_AFTER_PI} ${DISK_USED_BEFORE_BMV2_CLEANUP} ${DISK_USED_AFTER_BMV2} ${DISK_USED_BEFORE_P4C_CLEANUP} ${DISK_USED_AFTER_P4C} ${DISK_USED_AFTER_MININET} ${DISK_USED_END}`
echo  "DISK_USED_MAX                  ${DISK_USED_MAX}"
echo  "DISK_USED_MAX - DISK_USED_START : $((${DISK_USED_MAX}-${DISK_USED_START})) MBytes"
set -x

cd "${INSTALL_DIR}"
DETS="install-details"
mkdir -p "${DETS}"
mv usr-local-*.txt "${DETS}"

P4GUIDE_BIN="${THIS_SCRIPT_DIR_ABSOLUTE}"

set +x
echo "----------------------------------------------------------------------"
echo "Output of script p4-environment-info.sh"
echo "----------------------------------------------------------------------"
"${THIS_SCRIPT_DIR_ABSOLUTE}/p4-environment-info.sh"
echo "----------------------------------------------------------------------"

echo "----------------------------------------------------------------------"
echo "CONSIDER READING WHAT IS BELOW"
echo "----------------------------------------------------------------------"
echo ""

cd "${INSTALL_DIR}"
cp /dev/null p4setup.bash
echo "source ${INSTALL_DIR}/p4dev-python-venv/bin/activate" >> p4setup.bash
echo "export UV_PROJECT_ENVIRONMENT=\${VIRTUAL_ENV}" >> p4setup.bash
echo "export PATH=\"${HOME}/.local/bin:${P4GUIDE_BIN}:${INSTALL_DIR}/behavioral-model/tools:/usr/local/bin:\$PATH\"" >> p4setup.bash
echo "export P4_EXTRA_SUDO_OPTS=\"PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python\"" >> p4setup.bash

cp /dev/null p4setup.csh
echo "source ${INSTALL_DIR}/p4dev-python-venv/bin/activate.csh" >> p4setup.csh
echo "setenv UV_PROJECT_ENVIRONMENT \${VIRTUAL_ENV}" >> p4setup.csh
echo "set path = ( ${HOME}/.local/bin ${P4GUIDE_BIN} ${INSTALL_DIR}/behavioral-model/tools /usr/local/bin \$path )" >> p4setup.csh
echo "setenv P4_EXTRA_SUDO_OPTS \"PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python\"" >> p4setup.csh

echo "If you use a Bash-like command shell, you may wish to add a line like"
echo "the following to your .bashrc or other shell rc file:"
echo ""
echo "    source \$HOME/p4setup.bash"
echo ""
echo "If you use the tcsh or csh shells, use p4setup.csh instead."

echo "----------------------------------------------------------------------"
echo "CONSIDER READING WHAT IS ABOVE"
echo "----------------------------------------------------------------------"
set -x
