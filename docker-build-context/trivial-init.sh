#!/bin/sh
#
# trivial-init.sh is meant to be run inside a docker with busybox, and set up the infrastructure to "boot" the PscgBuildOS initramfs (of course, inside docker)
#

# $1 target dir
make_tmpfs_for_first_chroot() (
	targetDir=$1
	mkdir $targetDir
	mount -t tmpfs tmpfs $targetDir
)

# $1 src dir
# $2 target dir
copy_to_first_chroot_dir() (
	[ ! -d $2 ] && { echo failure ; exit 1; }
	cp -a $1/* $2/
	# cp -a $1/.* $2/ # no need for .git stuff et. al
)

# $1 target dir (e.g. initrd-fs, another rootfs etc.)
do_move_mounts() {
	targetDir=$1
	errorMet=false
	DIRS="/mnt/data /mnt/config /mnt/roconfig /mnt/volatile /mnt/ota/state /mnt/ota/extract \
	      /fakestuff "
	#DIRS="$DIRS /root/.config/pulse "
	takecareofsystemd=true
	if [ "$takecareofsystemd" = "true" ] ; then
		DIRS="$DIRS /sys/"
		DIRS="$DIRS /sys/fs/cgroup" # This is needed for systemd to not refuse booting. This will most definitely require tweaks on a Linux host
		#  These are not needed - but left as documentation. docker+systemd are fragile no matter how you look at it, be warned
		DIRS="$DIRS /dev"
		DIRS="$DIRS /dev/mqueue"
		DIRS="$DIRS /dev/shm"
	fi
	MOUNTOPTION="--bind" # Moving is better than binding in real systems. Here, we don't really care, so we make it somewhat "revertable"
	for dir in $DIRS ; do
		mkdir -p $targetDir/$dir
		mount -n $MOUNTOPTION $dir $targetDir/$dir || errorMet=true
	done

	[ "$errorMet" = "false" ] || return 1
}

DEMONSTRATE_SOME_CONCEPTS=false # really, don't change it. see comments in the function itself
#
# This just illustrates some complex costructs and should not be used. The system used to support complete updates without doing A/B using it, but I don't think it is the case.
# I do demonstrate it some times for bind/moves etc., but the essence of the exercise, was pretty much taken from it due to major fixes in docker and systemd.
#
demonstrate_move_or_bind_mounts_ota_additions() {
	if ! do_move_mounts /chroot-target  ; then
		echo -e "\x1b31mError occured during mounts. Might be due to bind mounting inside docker, running a privileged docker and move mounting, or other things\x1b[0m"
	fi

}


main() {
	echo -e "\x1b[32mThe PSCG says: Welcome to casa bonita\x1b[0m"

	# mount -o bind will have sub binded directories not identified by "mountpoint"
	if ! make_tmpfs_for_first_chroot chroot-target ; then 
		echo "Failed to create tmpfsdir"  
		exec /bin/sh
	fi
	copy_to_first_chroot_dir /initrd-fs chroot-target
#	exec /bin/sh	# uncomment to see what is before the chroot. You can also get ther with docker exec!
	export DOCKERENV=1
#	exec chroot chroot-target sh # uncomment to do chroot without running init


	if [ "$DEMONSTRATE_SOME_CONCEPTS" = "true" ] ; then
		demonstrate_bindmounts_ota_additions
		exec chroot chroot-target /init || echo -e "\x1b[31mFailed to chroot\x1b[0m" # won't see the error message because of exec, but it is a conceptual highlighting :)
	fi
	
	echo "MAKING AND MOUNTING ONLY OF FAKE STUFF IN THE CHROOT. REAL SOLUTION (qemu-system-..., real device) DOES NOT NEED ANY FAKE DEVICE, AS IT HAS REAL (OR VIRTIO OR ...) BLOCK DEVICES"
	set -x
	ls /fakestuff
	mkdir -p /chroot-target/fakestuff && mount --move fakestuff/ chroot-target/fakestuff   # TODO mount ro or not? I want it to be ro (the original dir - but in the copying it is not so..."
	set +x

	# We are running the initrd-fs init. Since it parses the (fake) cmdline, you can control the switch_root-ed init (i.e. the target rootfs one) by specifying init=... in the cmdline file
	exec chroot chroot-target /init || echo -e "\x1b[31mFailed to chroot\x1b[0m" # won't see the error message because of exec, but it is a conceptual highlighting :)

	# If you want to debug stuff you could set one of the following lines instead of the previous line
	# exec chroot chroot-target /bin/sh
	# exec chroot initrd-fs /bin/sh
}

main $@
