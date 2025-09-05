#!/bin/bash
set -euo pipefail

# all variables set here are examples. it is up to you to use your own
: ${INSTALLER_IMAGE=$HOME/PscgBuildOS/out/artifacts/images/pscg_alpineos-x86_64-installer.img}
: ${SOURCE_RAMDISK_DIR=$HOME/PscgBuildOS/out/target/product/pscg_alpineos/build-x86_64/ramdisk/initramfs}
: ${FAKE_FILES_DIR=$HOME/pscgdockos-materials/runtime-materials/dockosrd/fakestuff/fake-files/}
: ${FAKE_FILES_DIR=$HOME/pscgdockos-materials/runtime-materials/dockosrd/fakestuff/fake-files/}
: ${LOWER_DIR_UNPACKED_RAMDISK=$HOME/pscgdockos-materials/runtime-materials/pscgdockos/initramfs-unpacked}
: ${DOCKER_BUILD_CONTEXT=$(readlink -f $(dirname ${BASH_SOURCE[0]})/../docker-build-context)}
: ${DOCKER_BUILD_CONTEXT_INITRD_FS_DIR=$DOCKER_BUILD_CONTEXT/initrd-fs}
: ${REBUILD_DOCKER=false}
: ${DOCKER_IMAGE_NAME=pscg-dockos-rd}


LOCAL_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))
echo $LOCAL_DIR
cd $LOCAL_DIR/..

if [ ! -d $SOURCE_RAMDISK_DIR -a ! -L $SOURCE_RAMDISK_DIR ] ; then
	echo -e "\e[31m$SOURCE_RAMDISK_DIR does not exist. Please provide a ramdisk source dir (either extract an initramfs, or use your respective build materials dir before it was packed)\e[0m"
	exit 1
fi

if [ ! -e $INSTALLER_IMAGE ] ; then
	echo -e "\e[31m$INSTALLER_IMAGE does not exist. Please provide a valid installer image file\e[0m"
	exit 1
fi

arg1=${1:-""} # keep set -u happy
if [ "$arg1" = "--rebuild-docker" -o $(docker images "$DOCKER_IMAGE_NAME" | wc -l) -lt 2 ] ;  then
	REBUILD_DOCKER=true
fi

if [ "$REBUILD_DOCKER" = "true" ] ; then
	echo "[+] Recreating the docker-context initrd-fs at $DOCKER_BUILD_CONTEXT_INITRD_FS_DIR"
	if [ -d "$DOCKER_BUILD_CONTEXT_INITRD_FS_DIR" -o -L "$DOCKER_BUILD_CONTEXT_INITRD_FS_DIR" ] ; then
		echo "removing previous directory $DOCKER_BUILD_CONTEXT_INITRD_FS_DIR and recreating from $SOURCE_RAMDISK_DIR"
		rm -rf $DOCKER_BUILD_CONTEXT_INITRD_FS_DIR
	fi

	# Soft links cannot be added. Hard links cannot be done for folders.
	# We COULD bind mount -  but I wanted to demonstrate that the docker is scratch + busybox executables
	# We can copy only the respective files with cp -al - but since everything so small, there is no harm in copying. We could copy the entire folder - but let's copy only
	# what we care about
	mkdir $DOCKER_BUILD_CONTEXT_INITRD_FS_DIR
	for d in usr/ bin/ sbin/ ; do
		echo $d
		cp -a $SOURCE_RAMDISK_DIR/$d $DOCKER_BUILD_CONTEXT_INITRD_FS_DIR/$d
	done

	docker build -t pscg-dockos-rd -f docker-build-context/Dockerfile.initrd docker-build-context  --no-cache
fi

echo "[+] Populating installer image"
# This must either be a copy, or a hardlink (in the same filesystem in host), as the target of course cannot resolve a symlink to paths it does not know

[ -f $FAKE_FILES_DIR/fakestorage1 ] && unlink $FAKE_FILES_DIR/fakestorage1
ln $INSTALLER_IMAGE $FAKE_FILES_DIR/fakestorage1

echo "[+] Setting up ramdisk as a lowerdir for overlayfs ($SOURCE_RAMDISK_DIR --> $LOWER_DIR_UNPACKED_RAMDISK)"
rm -rf  $LOWER_DIR_UNPACKED_RAMDISK && mkdir -p $(dirname $LOWER_DIR_UNPACKED_RAMDISK)
ln -s $SOURCE_RAMDISK_DIR $LOWER_DIR_UNPACKED_RAMDISK

echo "[+] Creating the overlay dir at /tmp/dockos-rd-overlays/merged"
./helpers/quickly-create-overlay-initramfs-folder.sh 

echo -e "[+] DONE. You may run with\ninitrdfs_host_path=/tmp/dockos-rd-overlays/merged/  ./helpers/run-dockos-rd-with-loopback-images.sh"
