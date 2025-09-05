#!/bin/bash

PRIVILEGED=--privileged # Bad for your host, but saves enormous time explaining every possible docker issue
#NETWORK="--network=host"
: ${DOCKER_FLAGS=" $PRIVILEGED $NETWORK -it --rm"} # e.g. "-d" to detach (should be the default behavior you use!",  e.g "-it"  to see the systemd messages on boot (but then don't detach) etc.
: ${DOCKERWIPBINDMOUNTBASE="$HOME/pscgdockos-materials/docker-mounts/"}
: ${DOCKERIMAGENAME="pscg-dockos-rd"}
: ${DOCKERNAME="pscg-dockos-rd"}
: ${hostname="dockos-rd-1337"}
: ${forward_pulseaudio="false"} # set this to true if you understand the meaning of it, and have properly set up pulseaudio at your host
: ${initrdfs_host_path="$HOME/pscgdockos-materials/runtime-materials/pscgdockos/initramfs-unpacked"}
: ${initrdfs_target_path="/initrd-fs"}
: ${init_host_path="trivial-init.sh"} 	# note: we assume this is (the default value) in the docker context folder, which will be cd-ed into prior to invoking the docker
: ${init_target_path="/trivial-init.sh"}
: ${fakestuff_dir="$HOME/pscgdockos-materials/runtime-materials/dockosrd/fakestuff"}	# Host. Maybe target logic will change, so we don't bother to fix it here too

#
# during ramdisk phase, use ota partitions only from the loopback device
# this is useful if you want to emulate real operation - but may be less convenient if you want to work with the 
# "userspace only docker" without any loopback devices et. al but rather only bind mounts
#
use_ota_partitions_from_loopback_emmc() {
	cd "$(dirname ${BASH_SOURCE[0]})/../docker-build-context"

	: ${EXTRA_ENV=""} # may come handy if you want e.g. to share XDG_RUNTIME_DIR (for graphics or audio forwarding to the host), etc. there is a good example for that in the pscg-dockos-richosonly project

	init_host_path="$(readlink -f $init_host_path)" # this fixes up an easier default parameter setting - docker MUST have full path names for host bind mounts, so just giving a relative path won't do!

	# in fact, we don't need any of the bindmounts in this case. maybe only for very initial configuration
	# and/or maybe if we want to avoid the flasher as loopback device, and work on some of the directories directly.
	# it does have its defficiencies
	docker run  $DOCKER_FLAGS  \
		--name $DOCKERNAME  \
		--hostname=$hostname \
		$EXTRA_ENV \
		-v $init_host_path:$init_target_path \
		-v $initrdfs_host_path:$initrdfs_target_path \
		-v $fakestuff_dir/fake-files:/fakestuff/ \
		$DOCKERIMAGENAME $init_target_path
}

#
# This function should not be used unless it is for some demonstrations. It was very useful before implementing the loopback devices, but then I just implemented everything on QEMU as well, and the code has been stable for years.
# This is presented for the sake of history and some demonstrations - that are also not so relevant in 2025, unless using older distros - as both systemd and docker fixed a lot of their interoperability issues in recent versions.
# Instructor note: if used, use with docker_use_bindmount_ota_partitions=true
#
# What it does, is during ramdisk phase, use ota partitions from the docker bind mounts
# 
use_ota_partitions_from_docker_bind_mounts() {
	cd "$(readlink -f $(dirname ${BASH_SOURCE[0]})/../docker-build-context)"
	
	: ${EXTRA_ENV=""} # may come handy if you want e.g. to share XDG_RUNTIME_DIR (for graphics or audio forwarding to the host), etc. there is a good example for that in the pscg-dockos-richosonly project

	init_host_path="$(readlink -f $init_host_path)" # this fixes up an easier default parameter setting - docker MUST have full path names for host bind mounts, so just giving a relative path won't do!

	docker run  $DOCKER_FLAGS  \
		--name $DOCKERNAME  \
		--hostname=$hostname \
		$EXTRA_ENV \
		-v $init_host_path:$init_target_path \
		-v $initrdfs_host_path:$initrdfs_target_path \
		-v $DOCKERWIPBINDMOUNTBASE/data:/mnt/data \
		-v $DOCKERWIPBINDMOUNTBASE/otastate:/mnt/ota/state \
		-v $DOCKERWIPBINDMOUNTBASE/otaextract:/mnt/ota/extract \
		-v $fakestuff_dir/fake-files:/fakestuff/ \
		$DOCKERIMAGENAME $init_target_path
}


error() { echo -e "\x1b[31m$@\x1b[0m" ; } 
fatalError() { echo -e "\x1b[31m$@\x1b[0m" ; exit 1; } 

check_stuff() {
	[ -x "$init_host_path" ] || fatalError "init_host_path=$init_host_path does not exist or is not executable"
	[ -d "$initrdfs_host_path" ] || fatalError "initrdfs_host_path=$initrdfs_host_path does not exist"
	if [ -d "$fakestuff_dir" ] ; then
		set -o pipefail
		echo -n "Running with fake cmdline:"
		cat $fakestuff_dir/fake-files/cmdline || fatalError "Failed to run cmdline"
	else
		error "fakestuff_dir=$fakestuff_dir does not exist"
	fi
}

main() {
	cd "$(dirname ${BASH_SOURCE[0]})/../docker-build-context"
	check_stuff
	#use_ota_partitions_from_docker_bind_mounts  # see comments - don't use it - unless you want to demonstrate some things
	use_ota_partitions_from_loopback_emmc
	
	echo "Dockos exited [rc=$?] applying excess cleanup of fakestorage devices (actually done by the dockos on the next run, but let's do it here too)"
	losetup | grep fakestorage | cut -f1 -d " " | xargs sudo losetup -d
}

main $@

