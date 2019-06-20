#!/bin/bash

# Print commands and exit on errors
set -xe

#Src
BMV2_COMMIT="884e01b531c6fd078cc2438a40258ecae011a65b"  # Apr 24, 2019
PI_COMMIT="19de33e83bae7b737a3f8a1c9507c6e84173d96f"    # Apr 24, 2019
P4C_COMMIT="61409c890c58d14ec7d6790f263eb44f393e542a"   # Apr 24, 2019
PROTOBUF_COMMIT="v3.2.0"
GRPC_COMMIT="v1.3.2"

#Get the number of cores to speed up the compilation process
NUM_CORES=`grep -c ^processor /proc/cpuinfo`
KERNEL=$(uname -r)


#Get the current pwd
CURR_PWD="$(pwd)"


function update {
	apt-get update
}

function dep {  

	apt-get install -y --no-install-recommends --fix-missing\
  	autoconf \
  	automake \
  	bison \
  	build-essential \
  	ca-certificates \
  	cmake \
  	cpp \
  	curl \
  	flex \
  	git \
  	libboost-dev \
  	libboost-filesystem-dev \
  	libboost-iostreams1.58-dev \
  	libboost-program-options-dev \
  	libboost-system-dev \
  	libboost-test-dev \
  	libboost-thread-dev \
  	libc6-dev \
  	libevent-dev \
  	libffi-dev \
  	libfl-dev \
  	libgc-dev \
  	libgc1c2 \
  	libgflags-dev \
  	libgmp-dev \
  	libgmp10 \
  	libgmpxx4ldbl \
  	libjudy-dev \
  	libpcap-dev \
  	libreadline6 \
  	libreadline6-dev \
  	libssl-dev \
  	libtool \
  	linux-headers-$KERNEL\
  	make \
  	mktemp \
  	pkg-config \
  	python \
  	python-dev \
  	python-ipaddr \
  	python-pip \
  	python-psutil \
  	python-scapy \
  	python-setuptools \
  	tcpdump \
  	unzip \
  	vim \
  	wget \
  	xcscope-el \
  	xterm
}

function dep_native {
	DEBIAN_FRONTEND=noninteractive sudo add-apt-repository -y ppa:webupd8team/sublime-text-3
	DEBIAN_FRONTEND=noninteractive sudo add-apt-repository -y ppa:webupd8team/atom
	update
	DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

	apt-get install -y --no-install-recommends --fix-missing\
  		atom \
		emacs24 \
		lubuntu-desktop \
		sublime-text-installer \

}

function user_native {
	useradd -m -d /home/p4 -s /bin/bash p4
	echo "p4:p4" | chpasswd
	echo "p4 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99_p4
	chmod 440 /etc/sudoers.d/99_p4
	if [ $(getent group vboxsf) ]; then
		usermod -aG vboxsf p4
	
	fi
}

function wallpaper_native {
	cd /usr/share/lubuntu/wallpapers/
	cp $CURR_PWD/p4-logo.png .
	rm lubuntu-default-wallpaper.png
	ln -s p4-logo.png lubuntu-default-wallpaper.png
	rm $CURR_PWD/p4-logo.png
	cd $CURR_PWD
	sed -i s@#background=@background=/usr/share/lubuntu/wallpapers/1604-lubuntu-default-wallpaper.png@ /etc/lightdm/lightdm-gtk-greeter.conf

}

function screensaver_native {

	# Disable screensaver
	apt-get -y remove light-locker
}

function login_native {
	# Automatically log into the P4 user
	cat << EOF | tee -a /etc/lightdm/lightdm.conf.d/10-lightdm.conf
	[SeatDefaults]
	autologin-user=p4
	autologin-user-timeout=0
	user-session=Lubuntu
EOF
}

function tuto_native {
	git clone https://github.com/p4lang/tutorials
	sudo mv tutorials /home/p4
	sudo chown -R p4:p4 /home/p4/tutorials

}

function emacs_native {
# --- Emacs --- #
	sudo cp p4_16-mode.el /usr/share/emacs/site-lisp/
	sudo mkdir /home/p4/.emacs.d/
	echo "(autoload 'p4_16-mode' \"p4_16-mode.el\" \"P4 Syntax.\" t)" > init.el
	echo "(add-to-list 'auto-mode-alist '(\"\\.p4\\'\" . p4_16-mode))" | tee -a init.el
	sudo mv init.el /home/p4/.emacs.d/
	sudo ln -s /usr/share/emacs/site-lisp/p4_16-mode.el /home/p4/.emacs.d/p4_16-mode.el
	sudo chown -R p4:p4 /home/p4/.emacs.d/


}

function vim_native {
	cd $CURR_PWD  
	mkdir .vim
	cd .vim
	mkdir ftdetect
	mkdir syntax
	echo "au BufRead,BufNewFile *.p4      set filetype=p4" >> ftdetect/p4.vim
	echo "set bg=dark" >> ~/.vimrc
	sudo mv ~/.vimrc /home/p4/.vimrc
	cp $CURR_PWD/p4.vim syntax/p4.vim
	cd $CURR_PWD
	sudo mv .vim /home/p4/.vim
	sudo chown -R p4:p4 /home/p4/.vim
	sudo chown p4:p4 /home/p4/.vimrc
}

function desktop_icons_native {

	# --- Adding Desktop icons --- #
	DESKTOP=/home/${USER}/Desktop
	mkdir -p ${DESKTOP}

	cat > ${DESKTOP}/Terminal << EOF
	[Desktop Entry]
	Encoding=UTF-8
	Type=Application
	Name=Terminal
	Name[en_US]=Terminal
	Icon=konsole
	Exec=/usr/bin/x-terminal-emulator
	Comment[en_US]=
EOF

	cat > ${DESKTOP}/Wireshark << EOF
	[Desktop Entry]
	Encoding=UTF-8
	Type=Application
	Name=Wireshark
	Name[en_US]=Wireshark
	Icon=wireshark
	Exec=/usr/bin/wireshark
	Comment[en_US]=
EOF

	cat > ${DESKTOP}/Sublime\ Text << EOF
	[Desktop Entry]
	Encoding=UTF-8
	Type=Application
	Name=Sublime Text
	Name[en_US]=Sublime Text
	Icon=sublime-text
	Exec=/opt/sublime_text/sublime_text
	Comment[en_US]=
EOF

	sudo mkdir -p /home/p4/Desktop
	sudo mv /home/${USER}/Desktop/* /home/p4/Desktop
	sudo chown -R p4:p4 /home/p4/Desktop/


}

function Mininet {
	# --- Mininet --- #
	git clone git://github.com/mininet/mininet mininet
	sudo ./mininet/util/install.sh -nwv
}

function Protobuf {
	# --- Protobuf --- #
	git clone https://github.com/google/protobuf.git
	cd protobuf
	git checkout ${PROTOBUF_COMMIT}
	export CFLAGS="-Os"
	export CXXFLAGS="-Os"
	export LDFLAGS="-Wl,-s"
	./autogen.sh || ./autogen.sh
	./configure --prefix=/usr
	make -j${NUM_CORES}
	sudo make install
	sudo ldconfig
	unset CFLAGS CXXFLAGS LDFLAGS
	# Force install python module
	cd python
	sudo python setup.py install
	cd ../..
}

function gRPC {
	# --- gRPC --- #
	git clone https://github.com/grpc/grpc.git
	cd grpc
	git checkout ${GRPC_COMMIT}
	git submodule update --init --recursive
	export LDFLAGS="-Wl,-s"
	make -j${NUM_CORES}
	sudo make install
	sudo ldconfig
	unset LDFLAGS
	cd ..
	# Install gRPC Python Package
	sudo pip install grpcio
}

function BMv2_dep {
	# --- BMv2 deps (needed by PI) --- #
	git clone https://github.com/p4lang/behavioral-model.git
	cd behavioral-model
	git checkout ${BMV2_COMMIT}
	# From bmv2's install_deps.sh, we can skip apt-get install.
	# Nanomsg is required by p4runtime, p4runtime is needed by BMv2...
	tmpdir=`mktemp -d -p .`
	cd ${tmpdir}
	bash ../travis/install-thrift.sh
	bash ../travis/install-nanomsg.sh
	sudo ldconfig
	bash ../travis/install-nnpy.sh
	cd ..
	sudo rm -rf $tmpdir
	cd ..
}

function PI {
	# --- PI/P4Runtime --- #
	git clone https://github.com/p4lang/PI.git
	cd PI
	git checkout ${PI_COMMIT}
	git submodule update --init --recursive
	./autogen.sh || ./autogen.sh
	./configure --with-proto
	make -j${NUM_CORES}
	sudo make install
	sudo ldconfig
	cd ..
}

function BMv2 {
	# --- Bmv2 --- #
	cd behavioral-model
	./autogen.sh || ./autogen.sh
	./configure --enable-debugger --with-pi
	make -j${NUM_CORES}
	sudo make install
	sudo ldconfig
	# Simple_switch_grpc target
	cd targets/simple_switch_grpc
	./autogen.sh
	./configure --with-thrift
	make -j${NUM_CORES}
	sudo make install
	sudo ldconfig
	cd ../../..
}

function p4c {
	# --- P4C --- #
	git clone https://github.com/p4lang/p4c
	cd p4c
	git checkout ${P4C_COMMIT}
	git submodule update --init --recursive
	mkdir -p build
	cd build
	cmake ..
	make -j${NUM_CORES}
	sudo make install
	sudo ldconfig
	cd ../..
}

function tuto_dep {
	# --- Tutorials --- #
	sudo pip install crcmod
}

function vim {
	# --- Vim --- #
	
	cd ~  
	mkdir .vim
	cd .vim
	mkdir ftdetect
	mkdir syntax
	echo "au BufRead,BufNewFile *.p4      set filetype=p4" >> ftdetect/p4.vim
	echo "set bg=dark" >> ~/.vimrc
	cp $CURR_PWD/p4.vim ./syntax/
}
 
function usage {
	
	
	set +x
	clear
    	printf '\n\n\nUsage: %s [-hqn]\n\n' $(basename $0) >&2

    	printf 'This installation script aims to provide the user \n' >&2
    	printf 'with all the dependencies to carry out the P4 tutorial.\n' >&2
    	printf 'It should work on Ubuntu 16.04 and Vagrant installation method.\n\n' >&2


    	printf 'options:\n' >&2
    	printf -- ' -h: print this (H)elp message\n' >&2
    	printf -- ' -q: Use the (Q)uick installation method\n' >&2
	printf -- ' -n: (Default) Use the (N)ative installation method\n\n' >&2

	set -x
    	exit 2

}

function quick_method {
	update
	dep
	Mininet
	Protobuf
	gRPC
	BMv2_dep
	PI	
	BMv2
	p4c
	tuto_dep
	vim
}

function native_method {
	update
	dep_native
	dep
	user_native
	wallpaper_native
	screensaver_native
	login_native
	Mininet
	Protobuf
	gRPC
	BMv2_dep
	PI	
	BMv2
	p4c
	tuto_dep
	tuto_native
	vim_native
	emacs_native
	desktop_icons_native
}


if [ $# -eq 0 ]
then
    native_method
else
    while getopts 'hqn?' OPTION
    do
      case $OPTION in

      h)	usage;;
      q)	quick_method;;
      n)	native_method;;
      ?)	usage;;

      esac
    done
    shift $(($OPTIND - 1))
fi



# Do this last!
cd $CURR_PWD
rm -f ltmain.sh

sudo reboot