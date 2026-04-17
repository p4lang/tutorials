#! /bin/bash

# SPDX-FileCopyrightText: 2025 Andy Fingerhut
#
# SPDX-License-Identifier: Apache-2.0

######################################################################
# Copyright 2024 Andy Fingerhut
#
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
######################################################################

# Customize some GNOME desktop settings that I prefer.

# This command will show the GNOME version number installed/running on
# the system:
#     gnome-shell --version
# The output on all versions I checked was of the form:
# GNOME Shell <dotted decimal version string>

# This command can be used to see what names that the version of GNOME
# installed on a system uses for the applications that have been
# pinned in the Dash:
#     gsettings get org.gnome.shell favorite-apps

which gnome-shell > /dev/null
exit_status=$?
if [ ${exit_status} -ne 0 ]
then
    1>&2 echo "No command 'gnome-shell' found in command path."
    1>&2 echo "Does this system have GNOME installed?  Aborting."
    exit 1
fi

which gsettings > /dev/null
exit_status=$?
if [ ${exit_status} -ne 0 ]
then
    1>&2 echo "No command 'gsettings' found in command path."
    1>&2 echo "Does this system have GNOME installed?  Aborting."
    exit 1
fi

GNOME_VERSION_STR=`gnome-shell --version | awk '{print $3;}'`

TERMINAL_NAME="org.gnome.Terminal.desktop"
NAUTILUS_NAME="org.gnome.Nautilus.desktop"
UPDATE_MANAGER_NAME="update-manager.desktop"
HELP_NAME="yelp.desktop"

supported_version=0
case ${GNOME_VERSION_STR} in
    3.36.9)
	# I have seen GNOME version 3.36.9 installed on systems running:
	# Ubuntu 20.04
	supported_version=1
	FIREFOX_NAME="firefox.desktop"
	SETTINGS_NAME="gnome-control-center.desktop"
	;;
    42.9)
	# I have seen GNOME version 42.9 installed on systems running:
	# Ubuntu 22.04
	supported_version=1
	FIREFOX_NAME="firefox_firefox.desktop"
	SETTINGS_NAME="gnome-control-center.desktop"
	;;
    46.0|47.0)
	# I have seen GNOME version 46.0 installed on systems running:
	# Ubuntu 24.04
	# I have seen GNOME version 47.0 installed on systems running:
	# Ubuntu 24.10
	supported_version=1
	FIREFOX_NAME="firefox_firefox.desktop"
	SETTINGS_NAME="org.gnome.Settings.desktop"
	;;
esac

if [ ${supported_version} -eq 1 ]
then
    echo "Found supported GNOME version ${GNOME_VERSION_STR} installed."
else
    1>&2 echo "Found GNOME version ${GNOME_VERSION_STR} installed, but"
    1>&2 echo "this script does not support that version of GNOME."
    1>&2 echo "Consider updating the script so it does."
    exit 1
fi

set -x
# Update GNOME settings via the following corresponding gsettings
# commands.

# This command has the same effect as doing this in Settings app
# in Ubuntu 24.04:
# Privacy & Security -> Screen Lock -> Blank Screen Delay -> Never
gsettings set org.gnome.desktop.session idle-delay 0

# Privacy & Security -> Screen Lock -> Automatic Screen Lock -> disabled
gsettings set org.gnome.desktop.screensaver lock-enabled false

# Ubuntu Desktop -> Dock -> Icon Size -> 24
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 24

# Update the list of icons pinned in the Dash:
gsettings set org.gnome.shell favorite-apps "['${TERMINAL_NAME}', '${FIREFOX_NAME}', '${NAUTILUS_NAME}', '${SETTINGS_NAME}', '${UPDATE_MANAGER_NAME}', '${HELP_NAME}']"

# System -> Users -> user account "p4" -> Automatic Login -> enabled
# Changing this does not change the output of the command:
# gsettings list-recursively
# It must modify something on the system elsewhere.
# I learned that it causes a line like the following in file
# /etc/gdm3/custom.conf to have the value after the = change from False to True:
#AutomaticLoginEnable=False
# This line is in a section labeled [daemon].
# It also causes this line to be created, or its value modified,
# to the user account name:
#AutomaticLogin=p4

# TODO: The best way to change this from a Bash script would be to
# find a well-tested utility program that modifies or adds settings to
# files with that format, which is like a Windows INI format file.
