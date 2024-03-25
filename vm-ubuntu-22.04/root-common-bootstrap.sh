#!/bin/bash

# Print commands and exit on errors
set -xe

useradd -m -d /home/p4 -s /bin/bash p4
echo "p4:p4" | chpasswd
echo "p4 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99_p4
chmod 440 /etc/sudoers.d/99_p4
usermod -aG vboxsf p4

# Install p4 logo as wallpaper
mv /home/vagrant/p4-logo.png /usr/share/lubuntu/wallpapers/lubuntu-default-wallpaper.png

# 2021-Mar-06 this command failed with an error that the file did not exist.
#sed -i s@#background=@background=/usr/share/lubuntu/wallpapers/1604-lubuntu-default-wallpaper.png@ /etc/lightdm/lightdm-gtk-greeter.conf
# The following command will hopefully cause the P4 logo to be normal
# size and centered on the initial desktop image, rather than scaled
# and stretched and cropped horribly.
#sed -i s@wallpaper_mode=crop@wallpaper_mode=center@ /etc/xdg/pcmanfm/lubuntu/desktop-items-0.conf

# If that does not have the desired effect, another possibility is
# executing that command to edit the same string in file
# /etc/xdg/pcmanfm/lubuntu/pcmanfm.conf

# TBD: Ubuntu 20.04 does not have the light-locker package, so it
# fails if you try to remove it.  Probably enabling auto-login
# requires a different modification than is done below with the cat <<
# EOF command.

# Disable screensaver
#apt-get -y remove light-locker

# Automatically log into the P4 user
#cat << EOF | tee -a /etc/lightdm/lightdm.conf.d/10-lightdm.conf
#[SeatDefaults]
#autologin-user=p4
#autologin-user-timeout=0
#user-session=Lubuntu
#EOF
