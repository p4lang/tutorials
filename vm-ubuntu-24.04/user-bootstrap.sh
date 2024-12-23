#!/bin/bash

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

# Print script commands and exit on errors.
set -xe

${THIS_SCRIPT_DIR_ABSOLUTE}/setup-emacs.sh
${THIS_SCRIPT_DIR_ABSOLUTE}/setup-vim.sh

# Remove unused directories, if they exist.
for dirname in Documents Music Pictures Public Templates Videos
do
    if [ -d $HOME/$dirname ]
    then
	rmdir $HOME/$dirname
    fi
done

# Update settings via the following corresponding gsettings commands.

# This command has the same effect as doing this in Settings app
# in Ubuntu 24.04:
# Privacy & Security -> Screen Lock -> Blank Screen Delay -> Never
gsettings set org.gnome.desktop.session idle-delay 0

# Privacy & Security -> Screen Lock -> Automatic Screen Lock -> disabled
gsettings set org.gnome.desktop.screensaver lock-enabled false

# Ubuntu Desktop -> Dock -> Icon Size -> 24
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 24

# Update the list of icons pinned in the Dash:
gsettings set org.gnome.shell favorite-apps "['org.gnome.Terminal.desktop', 'firefox_firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Settings.desktop', 'update-manager.desktop', 'yelp.desktop']"

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
