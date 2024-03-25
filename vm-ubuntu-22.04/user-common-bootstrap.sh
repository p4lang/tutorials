#!/bin/bash

# Print script commands and exit on errors.
set -xe

# --- Mininet --- #
MININET_COMMIT="5b1b376336e1c6330308e64ba41baac6976b6874"  # 2023-May-28
git clone https://github.com/mininet/mininet mininet
cd mininet
git checkout ${MININET_COMMIT}
PATCH_DIR="${HOME}/patches"
patch -p1 < "${PATCH_DIR}/mininet-patch-for-2023-jun.patch"
cd ..
sudo ./mininet/util/install.sh -nw

find /usr/lib /usr/local $HOME/.local | sort > $HOME/usr-local-7-after-mininet-install.txt

# --- Tutorials --- #
git clone https://github.com/p4lang/tutorials
sudo mv tutorials /home/p4
sudo chown -R p4:p4 /home/p4/tutorials

# --- Emacs --- #
sudo cp p4_16-mode.el /usr/share/emacs/site-lisp/
sudo mkdir /home/p4/.emacs.d/
echo "(autoload 'p4_16-mode' \"p4_16-mode.el\" \"P4 Syntax.\" t)" > init.el
echo "(add-to-list 'auto-mode-alist '(\"\\.p4\\'\" . p4_16-mode))" | tee -a init.el
sudo mv init.el /home/p4/.emacs.d/
sudo ln -s /usr/share/emacs/site-lisp/p4_16-mode.el /home/p4/.emacs.d/p4_16-mode.el
sudo chown -R p4:p4 /home/p4/.emacs.d/

# --- Vim --- #
cd ~
mkdir .vim
cd .vim
mkdir ftdetect
mkdir syntax
echo "au BufRead,BufNewFile *.p4      set filetype=p4" >> ftdetect/p4.vim
echo "set bg=dark" >> ~/.vimrc
sudo mv ~/.vimrc /home/p4/.vimrc
cp ~/p4.vim syntax/p4.vim
cd ~
sudo mv .vim /home/p4/.vim
sudo chown -R p4:p4 /home/p4/.vim
sudo chown p4:p4 /home/p4/.vimrc

# --- Adding Desktop icons --- #
DESKTOP=/home/${USER}/Desktop
mkdir -p ${DESKTOP}

cat > ${DESKTOP}/Terminal.desktop << EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Terminal
Name[en_US]=Terminal
Icon=konsole
Exec=/usr/bin/x-terminal-emulator
Comment[en_US]=
EOF

cat > ${DESKTOP}/Wireshark.desktop << EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Wireshark
Name[en_US]=Wireshark
Icon=wireshark
Exec=/usr/bin/wireshark
Comment[en_US]=
EOF

sudo mkdir -p /home/p4/Desktop
sudo mv /home/${USER}/Desktop/* /home/p4/Desktop
sudo chown -R p4:p4 /home/p4/Desktop/

# Do this last!
sudo reboot
