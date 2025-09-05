#!/bin/bash
#
# the objective here is to take a busybox installation or a previous unpacked initramfs installation (better if there are no radically conflicting changes)
# and overlay the source of the initramfs from PscgBuildOS, on top of it. This way, a change in the source will propagate to the target, without modifying it.
#
#

homedir=$HOME
: ${lowerdir=$homedir/pscgdockos-materials/runtime-materials/pscgdockos/initramfs-unpacked}
: ${upperdir=$homedir/dev/otaworkshop/PscgBuildOS/layers/common/recipes/ramdisk/files}
: ${workdir=$homedir/dev/otaworkshop/tmp-workdir-dockos} # must be in the same filesystem as upper - which is why we delete it when we done (out of the script though)
: ${merged=/tmp/dockos-rd-overlays/merged}

mkdir -p $merged $workdir

echo -e "Using the following source and targets:
	\e[34mlowerdir\e[0m=$lowerdir
	\e[34mupperdir\e[0m=$upperdir
	\e[34mworkdir\e[0m=$workdir
	\e[34mmerged\e[0m=$merged"

set -x
sudo mount -t overlay overlayfs -o lowerdir=$lowerdir,upperdir=$upperdir,workdir=$workdir $merged
set +x
if [ ! $? = 0 ] ; then
	echo "Failed to mount. exitting"
	exit 
else 
	echo -e "Mounted. When done, don't forget to\n\e[33msudo umount $merged && sudo rm -r $merged $workdir\e[0m"
fi
