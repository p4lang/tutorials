#! /bin/bash

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

if [ -d $HOME/.vim ]
then
    echo "Found existing directory $HOME/.vim   Assuming Vim P4 files have already been set up before."
else
    sudo apt-get install -y vim
    cd ~
    mkdir -p .vim
    cd .vim
    mkdir -p ftdetect
    mkdir -p syntax
    echo "au BufRead,BufNewFile *.p4      set filetype=p4" >> ftdetect/p4.vim
    echo "set bg=dark" >> ~/.vimrc
    cp ${THIS_SCRIPT_DIR_ABSOLUTE}/p4.vim syntax/p4.vim
fi
