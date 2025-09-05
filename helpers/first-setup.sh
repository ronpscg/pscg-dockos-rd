#!/bin/bash
#
# This script sets up an initial infrastructure for you to run a loopback based emmc storage device, with docker
#
set -euo pipefail
if [ $(id -u) = 0 ] ; then
	if [ -n "$SUDO_HOME" ] ; then
		homedir=$SUDO_HOME
	else
		homedir=$HOME
	fi
else
	homedir=$HOME
	echo "Please run as superuser"
	#exit 1
fi
: ${fakestuff_dir="$homedir/pscgdockos-materials/runtime-materials/dockosrd/fakestuff"}
: ${fakestuff_storage_size_mib=15028}
FAKE_STORAGE0=fakestorage0
FAKE_STORAGE1=fakestorage1

# mountfatrw is not necessary, and can be used for logging and andparts backup purposes as a preparation for bootloader work
# If you don't want to use removable media (which actually can also test A/B updates without requiring internet) remove after the first installation the word "waitforremovablemedia"
# Do not add comments to the file as they will be parsed by the initramfs
fake_cmdline="thePSCG=rules docker_use_bindmount_ota_partitions=false forward_pulseaudio=true overlayfs pscgrd.hw.bsp=docker installer_a_only=false abtestimageoverlaystrategy=usesystemoverlay waitforremovablemedia" 

if [ ! -L $fakestuff_dir/fake-files -a ! -d $fakestuff_dir/fake-files ] ; then
	echo "[+] Creating $fakestuff_dir/fake-files dir for the first time"
	mkdir -p $fakestuff_dir/fake-files || { echo "Failed" ; exit 1; }
fi

if [ ! -f of=$fakestuff_dir/fake-files/$FAKE_STORAGE0 ] ; then	
	echo "[+] Creating $fakestuff_dir/fake-files/$FAKE_STORAGE0 for the first time"
	dd if=/dev/zero of=$fakestuff_dir/fake-files/$FAKE_STORAGE0 conv=sparse bs=$((1024*1024)) count=$fakestuff_storage_size_mib
fi

set -x
echo $fake_cmdline > $fakestuff_dir/fake-files/cmdline
set +x

echo -e "\x1b[32mDone, \x1b[33mbut don't forget to set up an installer file at $fakestuff_dir/fake-files/$FAKE_STORAGE1\x1b[0m"
