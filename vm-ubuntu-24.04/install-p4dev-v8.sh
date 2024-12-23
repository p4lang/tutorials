#! /bin/bash

# Copyright 2022-present Intel Corporation

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


# This script differs from install-p4dev-v6.sh as follows:

# * Installs all Python3 packages into a virtual environment created
#   via `python3 -m venv <venv-name>`, instead of in system-wide
#   directories like /usr/local/lib   See [Note 1] below.
# * Install more recent Thrift (0.16)
# * Support Ubuntu 24.04 (this is the first version of this install
#   script that does so).
# * Installs Protobuf and gRPC from pre-built packages and Python
#   packages, at least for OS versions where this has been tested to
#   work.  I could not find a single version of these packages that
#   would compile and work on all supported OS versions.  This script
#   will in general install different versions of these packages on
#   different OS versions, but they are regularly tested to ensure
#   that they work for the purposes of the open source P4 development
#   tools.

# [Note 1]
# One motivation for this change is that Ubuntu 23.04 and Ubuntu 24.04
# now by default give an error when you try to use 'sudo pip3 install
# ...' to install a Python package in a system-wide directory.  Thus
# it seems likely that something in this script needs to change to
# support Ubuntu 23.04 and probably later versions of Ubuntu.  Another
# reason is that it avoids some of the hacky code I have in
# install-p4dev-v6.sh to move installed Python packages from the
# site-packages directory to the dist-packages directory.

# Remember the current directory when the script was started:
INSTALL_DIR="${PWD}"

THIS_SCRIPT_FILE_MAYBE_RELATIVE="$0"
THIS_SCRIPT_DIR_MAYBE_RELATIVE="${THIS_SCRIPT_FILE_MAYBE_RELATIVE%/*}"
THIS_SCRIPT_DIR_ABSOLUTE=`readlink -f "${THIS_SCRIPT_DIR_MAYBE_RELATIVE}"`

linux_version_warning() {
    1>&2 echo "Found ID ${ID} and VERSION_ID ${VERSION_ID} in /etc/os-release"
    1>&2 echo "This script only supports these:"
    1>&2 echo "    ID ubuntu, VERSION_ID in 20.04 22.04 24.04"
    #1>&2 echo "    ID fedora, VERSION_ID in 36 37 38"
    1>&2 echo ""
    1>&2 echo "Proceed installing manually at your own risk of"
    1>&2 echo "significant time spent figuring out how to make it all"
    1>&2 echo "work, or consider getting VirtualBox and creating a"
    1>&2 echo "virtual machine with one of the tested versions."
}

check_for_python2_installed() {
    for p in python python2
    do
	which $p > /dev/null
	e1=$?
        if [ $e1 -eq 0 ]
	then
	    tmp_out=`$p -c 'import sys; print(sys.version_info)' | grep 'major=2'`
	    e2=$?
	    if [ $e2 -eq 0 ]
	    then
		#echo "Found Python2 installed with cmd name: $p"
		python2_cmd_name=$p
		return
	    fi
	fi
    done
    python2_cmd_name=""
}

python_version_warning() {
    1>&2 echo "The following version of Python2 was found installed on"
    1>&2 echo "this system:"
    1>&2 echo ""
    1>&2 echo "Python2 command name: $python2_cmd_name"
    1>&2 echo "sys.version_info value from that command:"
    1>&2 echo ""
    "$python2_cmd_name" -c 'import sys; print(sys.version_info)'
    1>&2 echo ""
    1>&2 echo "This script has been tested on systems where Python2"
    1>&2 echo "was installed, and while it produces no errors while"
    1>&2 echo "the script is running, the resulting system ends up"
    1>&2 echo "with a mix of some Python2 packages installed, and some"
    1>&2 echo "Python3 packages installed, that cause failures when"
    1>&2 echo "attempting to run many P4 open source development tools"
    1>&2 echo "in common use cases."
    1>&2 echo ""
    1>&2 echo "It is recommended that you only use this install script"
    1>&2 echo "on systems with no Python2 installed at all, since"
    1>&2 echo "Python2 is no longer supported as of 2020-Jan-01, and"
    1>&2 echo "the P4 open source development tools do work well with"
    1>&2 echo "Python3, and I doubt any changes will be made in P4"
    1>&2 echo "development tools to improve their working with Python2"
    1>&2 echo "any longer."
    1>&2 echo ""
    1>&2 echo "    https://python.org/doc/sunset-python-2"
    1>&2 echo ""
    1>&2 echo "You are welcome to disable this check in your copy of"
    1>&2 echo "this install script, and force installation anyway, but"
    1>&2 echo "expect the resulting installation not to work, unless"
    1>&2 echo "you figure out yourself how to make it work."
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
DEBUG_INSTALL=2

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

PYTHON_VENV="${INSTALL_DIR}/p4dev-python-venv"

debug_dump_many_install_files() {
    local OUT_FNAME="$1"
    local DIRNAME="${INSTALL_DIR}/`basename $1 .txt`"
    if [ ${DEBUG_INSTALL} -ge 2 ]
    then
	find /usr/lib /usr/local $HOME/.local "${PYTHON_VENV}" | sort > "${OUT_FNAME}"
    fi
    if [ ${DEBUG_INSTALL} -ge 3 ]
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
	20.04)
	    supported_distribution=1
	    INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=0
	    # Versions installed by Ubuntu apt
	    PROTOBUF_PKG_VERSION="3.6.1.3"
	    GRPC_PKG_VERSION="1.16.1"
	    # Versions to install for Ubuntu 20.04 are newer than
	    # those above, because PI and behavioral-model require
	    # later versions.
	    GRPC_SOURCE_VERSION="1.30.2"
	    PROTOBUF_VERSION_FOR_PIP="3.12.4"
	    ;;
	22.04)
	    supported_distribution=1
	    INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=1
	    # Versions installed by Ubuntu apt
	    PROTOBUF_PKG_VERSION="3.12.4"
	    GRPC_PKG_VERSION="1.30.2"
	    # Closest versions available via "pip3 install" to the above
	    PROTOBUF_VERSION_FOR_PIP="3.12.4"
	    ;;
	24.04)
	    supported_distribution=1
	    INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS=1
	    # Versions installed by Ubuntu apt
	    PROTOBUF_PKG_VERSION="3.21.12"
	    GRPC_PKG_VERSION="1.51.1"
	    # Closest versions available via "pip3 install" to the above
	    PROTOBUF_VERSION_FOR_PIP="4.21.12"
	    ;;
    esac
elif [ "${ID}" = "fedora" ]
then
    # I have not tested this script with fedora yet.
    case "${VERSION_ID}" in
	38)
	    supported_distribution=0
	    ;;
	39)
	    supported_distribution=0
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

check_for_python2_installed
if [ ! -z "$python2_cmd_name" ]
then
    python_version_warning
    exit 1
else
    1>&2 echo "Found no Python2 installed.  Continuing with installation."
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
echo "    Ubuntu 20.04"
echo "    Ubuntu 22.04"
echo "    Ubuntu 24.04"
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
echo "  which, as of 2023-Sep-22, also installs these things:"
echo "  + thrift version 0.16.0"
echo "  + nanomsg version 1.0.0"
echo "  + nnpy latest version available via 'pip install'"
echo "+ p4c: github.com/p4lang/p4c latest version"
echo "+ ptf: github.com/p4lang/ptf latest version"
echo "+ tutorials: github.com/p4lang/tutorials latest version"
echo "+ Mininet: github.com/mininet/mininet latest version as of 2024-Sep-18"
echo "+ Python packages: protobuf ${PROTOBUF_VERSION_FOR_PIP}, grpcio - a recent version auto-selected by pip3"
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
python2 -V || echo "No such command in PATH: python2"
python3 -V || echo "No such command in PATH: python3"
pip -V  || echo "No such command in PATH: pip"
pip2 -V || echo "No such command in PATH: pip2"
pip3 -V || echo "No such command in PATH: pip3"

# On new systems if you have never checked repos you should do that first

# Install a few packages (vim is not strictly necessary -- installed for
# my own convenience):
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes update
    sudo apt-get --yes install git vim
elif [ "${ID}" = "fedora" ]
then
    sudo dnf -y update
    sudo dnf -y install git vim
fi

# Run a child process in the background that will keep sudo
# credentials fresh.  The hope is that after a user enters their
# password once, they will not need to do so again for the entire
# duration of running this install script.

# However, since it runs in the background, do _not_ start it until
# after the first command in this script that uses 'sudo', so the
# foreground 'sudo' command will cause the password prompt to be
# waited for, if it is needed.
"${THIS_SCRIPT_DIR_ABSOLUTE}/keep-sudo-credentials-fresh.sh" &
CHILD_PROCESS_PID=$!

set +x
clean_up() {
    echo "Killing child process"
    kill ${CHILD_PROCESS_PID}
    # Invalidate the user's cached credentials
    sudo --reset-timestamp
    exit
}
set -x

# Kill the child process
trap clean_up SIGHUP SIGINT SIGTERM

# Install pkg-config here, as it is required for p4lang/PI
# installation to succeed.

# It appears that some part of the build process for Thrift 0.16.0
# requires that pip3 has been installed first.  Without this, there is
# an error during building Thrift 0.16.0 where a Python 3 program
# cannot import from the setuptools package.
TIME_AUTOTOOLS_START=$(date +%s)
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes install \
	 autoconf automake libtool curl make g++ unzip \
	 pkg-config python3-pip python3-venv
elif [ "${ID}" = "fedora" ]
then
    sudo dnf -y install \
	 autoconf automake libtool curl make g++ unzip \
	 pkg-config python3-pip
fi

if [ \( "${ID}" = "ubuntu" -a "${VERSION_ID}" = "20.04" \) -o \( "${ID}" = "fedora" -a "${VERSION_ID}" = "35" \) ]
then
    if [ -d automake-1.16.5 ]
    then
	echo "Found directory ${INSTALL_DIR}/automake-1.16.5.  Assuming desired version of automake-1.16.5 is already installed."
    else
	# Install more recent versions of autoconf and automake than those
	# that are installed by the Ubuntu 20.04 packages.  That helps
	# cause Python packages to be installed in the venv while building
	# grpc and behavioral-model below.
	wget https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz
	tar xkzf automake-1.16.5.tar.gz
	cd automake-1.16.5
	./configure
	make
	sudo make install
	cd ..
    fi

    if [ -d autoconf-2.71 ]
    then
	echo "Found directory ${INSTALL_DIR}/autoconf-2.71.  Assuming desired version of autoconf-2.71 is already installed."
    else
	wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz
	tar xkzf autoconf-2.71.tar.gz
	cd autoconf-2.71
	./configure
	make
	sudo make install
	cd ..
    fi

    if [ "${ID}" = "ubuntu" ]
    then
	sudo apt-get purge -y autoconf automake
	sudo apt-get install --yes libtool-bin
    elif [ "${ID}" = "fedora" ]
    then
	sudo dnf remove -y autoconf automake
	sudo dnf install -y libtool
    fi
    # I learned about the fix-up commands below in an answer here:
    # https://superuser.com/questions/565988/autoconf-libtool-and-an-undefined-ac-prog-libtool
    for file in /usr/share/aclocal/*.m4
    do
	b=`basename $file .m4`
	sudo ln -s /usr/share/aclocal/$b.m4 /usr/local/share/aclocal/$b.m4 || echo "Creating symbolic link /usr/local/share/aclocal/$b.m4 failed, probably because the file already exists"
    done
fi
TIME_AUTOTOOLS_END=$(date +%s)
echo "autotools              : $(($TIME_AUTOTOOLS_END-$TIME_AUTOTOOLS_START)) sec"
DISK_USED_AFTER_AUTOTOOLS=`get_used_disk_space_in_mbytes`

# Create a new Python virtual environment using venv.  Later we will
# attempt to ensure that all new Python packages installed are
# installed into this virtual environment, not into system-wide
# directories like /usr/local/bin
python3 -m venv "${PYTHON_VENV}"
source "${PYTHON_VENV}/bin/activate"

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
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-1-before-protobuf.txt

set +x
echo "------------------------------------------------------------"
echo "Installing grpc, needed for installing p4lang/PI"
echo "start install grpc:"
set -x
date

if [ ${INSTALL_GRPC_PROTOBUF_FROM_PREBUILT_PKGS} -eq 1 ]
then
    TIME_GRPC_CLONE_START=$(date +%s)
    TIME_GRPC_CLONE_END=$(date +%s)
    TIME_GRPC_INSTALL_START=$(date +%s)
    sudo apt-get --yes install libprotobuf-dev protobuf-compiler protobuf-compiler-grpc libgrpc-dev libgrpc++-dev
    if [ "${PROTOBUF_VERSION_FOR_PIP}" != "" ]
    then
	pip3 install protobuf==${PROTOBUF_VERSION_FOR_PIP}
    fi
    TIME_GRPC_INSTALL_END=$(date +%s)
    pip3 list
else
    # Do not bother installing protobuf package from source code, as
    # whatever parts of protobuf we need is installed as a result of
    # installing grpc from source code, and/or installing the Python
    # protobuf package using pip.
    if [ "${PROTOBUF_VERSION_FOR_PIP}" != "" ]
    then
	pip3 install protobuf==${PROTOBUF_VERSION_FOR_PIP}
    fi

    cd "${INSTALL_DIR}"
    debug_dump_many_install_files ${INSTALL_DIR}/usr-local-2-after-protobuf.txt

    if [ "${ID}" = "ubuntu" ]
    then
	sudo apt-get --yes install cmake
    elif [ "${ID}" = "fedora" ]
    then
	sudo dnf -y install cmake
    fi

    # From BUILDING.md of grpc source repository
    if [ "${ID}" = "ubuntu" ]
    then
	sudo apt-get --yes install build-essential autoconf libtool pkg-config
	# TODO: This package is not mentioned in grpc BUILDING.md
	# instructions, but when I tried on Ubuntu 20.04 without it, the
	# building of grpc failed with not being able to find an OpenSSL
	# library.
	sudo apt-get --yes install libssl-dev
    elif [ "${ID}" = "fedora" ]
    then
	# I am not sure that the 'Development Tools' group on Fedora is
	# identical to installing the build-essential package on Ubuntu,
	# but there is at least significant overlap between what they
	# install.
	sudo dnf group install -y 'Development Tools'
	# python3-devel is needed on Fedora systems for the `pip3 install
	# .` step below
	sudo dnf -y install autoconf libtool pkg-config python3-devel
	# TODO: Should I install openssl-devel here on Fedora?  There is
	# no package named libssl-dev or libssl-devel.  It seems like it
	# might be unnecessary, as without doing so the build of grpc
	# below went through with no errors.
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
	get_from_nearest https://github.com/grpc/grpc.git grpc.tar.gz
	cd grpc
	git checkout v${GRPC_SOURCE_VERSION}
	# These commands are recommended in grpc's BUILDING.md file for Unix:
	git submodule update --init --recursive
	TIME_GRPC_CLONE_END=$(date +%s)
	TIME_GRPC_INSTALL_START=$(date +%s)
	mkdir -p cmake/build
	cd cmake/build
	# I learned about the cmake option -DgRPC_SSL_PROVIDER=package
	# from the pages linked below, after experiencing link-time errors
	# when trying to build behavioral-model with gRPC v1.54.2 and
	# getting errors that it could not find symbols like OPENSSL_free,
	# and many others.
	# https://github.com/grpc/grpc/issues/30524
	cmake ../.. -DgRPC_SSL_PROVIDER=package
	make
	sudo make install
	cd ../..
	sudo ldconfig
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
    sudo apt-get --yes install libreadline-dev valgrind libtool-bin libboost-dev libboost-system-dev libboost-thread-dev
elif [ "${ID}" = "fedora" ]
then
    # Any other libraries output from 'dnf search libtool' that need
    # to be installed?
    sudo dnf -y install readline-devel valgrind libtool boost-devel boost-system boost-thread
fi

DISK_USED_BEFORE_PI_CLEANUP=`get_used_disk_space_in_mbytes`
if [ -d PI ]
then
    echo "Found directory ${INSTALL_DIR}/PI.  Assuming desired version of PI is already installed."
else
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
    ./autogen.sh
    # Cause 'sudo make install' to install Python packages for PI in a
    # Python virtual environment, if one is in use.
    configure_python_prefix="--with-python_prefix=${PYTHON_VENV}"
    if [ "${ID}" = "ubuntu" ]
    then
	./configure --with-proto --without-internal-rpc --without-cli --without-bmv2 ${configure_python_prefix}
    elif [ "${ID}" = "fedora" ]
    then
	PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure --with-proto --without-internal-rpc --without-cli --without-bmv2 ${configure_python_prefix}
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
    sudo make install

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
    patch -p1 < "${PATCH_DIR}/behavioral-model-support-fedora.patch"
    patch -p1 < "${PATCH_DIR}/behavioral-model-support-venv.patch"
    # This command installs Thrift, which I want to include in my build of
    # simple_switch_grpc
    ./install_deps.sh
    # simple_switch_grpc README.md says to configure and build the bmv2
    # code first, using these commands:
    ./autogen.sh
    # Remove 'CXXFLAGS ...' part to disable debug
    if [ "${ID}" = "ubuntu" ]
    then
	./configure --with-pi --with-thrift ${configure_python_prefix} 'CXXFLAGS=-O0 -g'
    elif [ "${ID}" = "fedora" ]
    then
	PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure --with-pi --with-thrift ${configure_python_prefix} 'CXXFLAGS=-O0 -g'
    fi
    make
    sudo make install-strip
    sudo ldconfig
    # 'sudo make install-strip' installs several files in ${PYTHON_VENV}
    # with root owner.  Change them to be owned by the regular user id.
    change_owner_and_group_of_venv_lib_python3_files ${PYTHON_VENV}
    DISK_USED_BEFORE_BMV2_CLEANUP=`get_used_disk_space_in_mbytes`
    if [ ${CLEAN_UP_AS_WE_GO} -eq 1 ]
    then
	echo "Disk space used just before cleaning up behavioral-model:"
	df -BM .
	cd "${INSTALL_DIR}"
	cd behavioral-model
	make clean
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
elif [ "${ID}" = "fedora" ]
then
    sudo dnf -y install g++ git automake libtool gc-devel \
         bison flex libfl-devel gmp-devel \
         boost-devel boost-iostreams boost-graph \
         llvm llvm-devel pkgconf python3-pip tcpdump clang
fi
# Starting in 2019-Nov, Python3 version of Scapy is needed for `cd
# p4c/build ; make check` to succeed.
# ply package is needed for ebpf and ubpf backend tests to pass
# TODO: It appears that some changes were made from scapy 2.5.0 to
# 2.6.0 that require changes in P4 open source tools in order to use
# version 2.6.0.  Until those changes are made, install scapy 2.5.0.
pip3 install scapy==2.5.0 ply
pip3 list

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
    sudo make install/strip
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
patch -p1 < "${PATCH_DIR}/mininet-patch-for-2024-sep-enable-venv.patch"
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
PYTHON=python3 ./mininet/util/install.sh -nw
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

git clone https://github.com/p4lang/ptf
cd ptf
if [ "x${INSTALL_PTF_SOURCE_VERSION}" != "x" ]; then
    git checkout ${INSTALL_PTF_SOURCE_VERSION}
fi
git log -n 1
pip install .
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
elif [ "${ID}" = "fedora" ]
then
    sudo dnf -y install gflags-devel net-tools
fi
pip3 install psutil crcmod

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
pip3 install wheel
if [ "${ID}" == "ubuntu" -a "${VERSION_ID}" == "24.04" ]
then
    # Version 1.51.3 fails to install on Ubuntu 24.04 as of
    # 2024-May-20.
    pip3 install grpcio==1.59.3
else
    pip3 install grpcio==1.51.3
fi

git clone https://github.com/p4lang/p4runtime-shell
cd p4runtime-shell
if [ "x${INSTALL_P4RUNTIME_SHELL_SOURCE_VERSION}" != "x" ]; then
    git checkout ${INSTALL_P4RUNTIME_SHELL_SOURCE_VERSION}
fi
git log -n 1
PATCH_DIR="${THIS_SCRIPT_DIR_ABSOLUTE}/patches"
patch -p1 < "${PATCH_DIR}/p4runtime-shell-2023-changes.patch"
pip3 install .

pip3 list

set +x
echo "end install miscellaneous packages:"
set -x
date

cd "${INSTALL_DIR}"
set +x
echo "------------------------------------------------------------"
echo "Installing p4lang/tutorials"
echo "start install tutorials:"
set -x
date

git clone https://github.com/p4lang/tutorials
cd tutorials
git log -n 1

set +x
echo "end install tutorials:"
set -x
date


cd "${INSTALL_DIR}"
debug_dump_many_install_files ${INSTALL_DIR}/usr-local-9-after-miscellaneous-install.txt

pip list  || echo "Some error occurred attempting to run command: pip"
pip3 list

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
echo "autotools              : $(($TIME_AUTOTOOLS_END-$TIME_AUTOTOOLS_START)) sec"
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
echo  "DISK_USED_AFTER_AUTOTOOLS      ${DISK_USED_AFTER_AUTOTOOLS}"
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

DISK_USED_MAX=`max_of_list ${DISK_USED_START} ${DISK_USED_AFTER_AUTOTOOLS} ${DISK_USED_BEFORE_GRPC_CLEANUP} ${DISK_USED_AFTER_GRPC} ${DISK_USED_BEFORE_PI_CLEANUP} ${DISK_USED_AFTER_PI} ${DISK_USED_BEFORE_BMV2_CLEANUP} ${DISK_USED_AFTER_BMV2} ${DISK_USED_BEFORE_P4C_CLEANUP} ${DISK_USED_AFTER_P4C} ${DISK_USED_AFTER_MININET} ${DISK_USED_END}`
echo  "DISK_USED_MAX                  ${DISK_USED_MAX}"
echo  "DISK_USED_MAX - DISK_USED_START : $((${DISK_USED_MAX}-${DISK_USED_START})) MBytes"
set -x

cd "${INSTALL_DIR}"
DETS="install-details"
mkdir -p "${DETS}"
mv usr-local-*.txt pip3-list-2b-before-grpc-pip3.txt "${DETS}"

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
echo "export PATH=\"${P4GUIDE_BIN}:${INSTALL_DIR}/behavioral-model/tools:/usr/local/bin:\$PATH\"" >> p4setup.bash
echo "export P4_EXTRA_SUDO_OPTS=\"PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python\"" >> p4setup.bash

cp /dev/null p4setup.csh
echo "source ${INSTALL_DIR}/p4dev-python-venv/bin/activate.csh" >> p4setup.csh
echo "set path = ( ${P4GUIDE_BIN} ${INSTALL_DIR}/behavioral-model/tools /usr/local/bin \$path )" >> p4setup.csh
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

clean_up
