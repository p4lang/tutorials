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
