#!/bin/bash

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

# Print script commands and exit on errors.
set -xe

# Modify sudoers configuration file so that this user can run any
# command via sudo without having to enter a password.
echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/99_${USER}
sudo chmod 440 /etc/sudoers.d/99_${USER}

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

${THIS_SCRIPT_DIR_ABSOLUTE}/config-gnome-settings.sh
