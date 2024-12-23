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

if [ -r /usr/share/emacs/site-lisp/p4_16-mode.el ]
then
    echo "Found existing file /usr/share/emacs/site-lisp/p4_16-mode.el   Assuming Emacs P4 files have already been set up before."
else
    # Installing the emacs package causes the postfix package to be
    # installed, which if you do not do it like this, causes
    # interactive questions to be given to the user.  Avoid those
    # interactive questions by installing it as follows.
    echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes postfix

    sudo apt-get install -y emacs
    sudo cp ${THIS_SCRIPT_DIR_ABSOLUTE}/p4_16-mode.el /usr/share/emacs/site-lisp/
    mkdir -p $HOME/.emacs.d/
    echo "(autoload 'p4_16-mode' \"p4_16-mode.el\" \"P4 Syntax.\" t)" > $HOME/.emacs.d/init.el
    echo "(add-to-list 'auto-mode-alist '(\"\\.p4\\'\" . p4_16-mode))" | tee -a $HOME/.emacs.d/init.el
    ln -s /usr/share/emacs/site-lisp/p4_16-mode.el $HOME/.emacs.d/p4_16-mode.el
fi
