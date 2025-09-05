# pscg-dockos-rd - a super fast docker running initramfs and then the entire removable-media/persistent storage PscgBuildOS flow
## About
This allows for testing a significant part of the ramdisk work, without requiring a real hardware.
This also allows for testing some parts of a full image without modifying it. 

It allows for testing everything an emulator would test on PscgBuildOS - using the host kernel (or the hypervisor kernel in MacOS and Windows).

Videos:
- [PscgBuildOS: blazing fast full system control from the initramfs and on with pscg-dockos-rd](https://www.youtube.com/watch?v=e28RXdeAgGQ&list=PLBaH8x4hthVysdRTOlg2_8hL6CWCnN5l-&index=131)

## Design and layering

The idea is as follows:
- Create an empty docker (i.e. FROM scratch)
- Add to it a very minimal initrd which can be our initrd - and then chroot to a full image (this is the first implementation)
- Run an entire installer and mount a fake loopback image for it, as well as for a fake backing storage device - and then run all the filesystem stuff on it, as if it were a real device.

This is all user space only, and does not replace an emulator.

## Building the docker image

### Order of build
1. scratch
2. **Dockerfile.initrd** - sets up initial filesystem to have scripts executed on and take care of the logic.

### Building
Note: may use --no-cache, --squash and the rest of the fields if they make you feel better
```
docker build -t pscg-dockos-rd -f docker-build-context/Dockerfile.initrd docker-build-context  --no-cache
```

This is done as part of the `./helpers/prepare-run.sh` script. You can rebuild the docker by running `./helpers/prepare-run.sh --rebuild-docker`. 
Anyhow, the script itself
documents itself very well, and you should read it thoroughly.

## Running the product

### Setup recommendations before running

The procedure is well documented inside the different files.
On the very first time:
```
./helpers/first-setup.sh
```

Before running, or if you want to change the ramdisk (E.g. to another architectures, or if you built it):
```
./helpers/prepare-run.sh
```

Should you want to rebuild for another architecture, for example, you would want to edit the paths in the script (or provide them via environment variables), and
re-run the script, including rebuilding the docker image:
`./helpers/prepare-run.sh --rebuild-docker`

### Running
To run: with the overlaid setup (That allows you to do some ramdisk modifications on the fly, on your host)
```
initrdfs_host_path=/tmp/dockos-rd-overlays/merged/  ./helpers/run-dockos-rd-with-loopback-images.sh
```

You can also add `forward_pulseaudio=true` to the line above (e.g. at the beginning of it).

After running, you would likely want to do some cleanups. The script above tries to do some for the loopback devices.
You would also want to follow the instructions at the output of `./helpers-prepare-run.sh` as per cleaning up the overlayfs mounts


### About the loopback devices and cmdline file (read: about fakestuff)
- fakestuff  
	- fake storage devices 
	  You would want to keep the following for emmc/removable media emulation:
	  ```
	  fakestuff/fake-files/fakestorage0
	  fakestuff/fake-files/fakestorage1  # only if you want to say that the removable media is in
	  ```
	- fake command line  
	  You would want to specify your "kernel command line" in 
	  ```
	  fakestuff/fake-files/cmdline
	  ```
		- Some notes:
		  - Note that if we set `docker_use_bindmount_ota_partitions=true`, then the mount points from the hosts are used. There are several modes, that will not be documented at this point.  
		  - Note that if you want the removable media to be writable (e.g. for logs, or partition backup to removable media) you would want to also provide `mountfatrw` to the command line arguments.

You can also add `forward_pulseaudio=true` to the line above (e.g. at the beginning of it).

```
fakestuff
├── fake-files
│   ├── cmdline
│   ├── fakestorage0
│   └── fakestorage1
```

There are additional options described in some of the sub-folders, for example the option to also extern audio to external pulseaudio server.

#### Notes about audio
It's been tested some years ago, and is mostly demonstrated in the [Linux on MacBooks - in and out of MacOS](https://www.youtube.com/watch?v=j5ajUgxmqKU&list=PLBaH8x4hthVysdRTOlg2_8hL6CWCnN5l-&index=31) video, with *pulseaudio*. Since most distros moved to *pipewire*, and since this project is mostly published as a nice addendum, it has not been really taken care of or tested lately. As the emulator versions support more hardware, these kind of things would most likely get more focus on the emulators, or on real devices.

In particular, the emulator uses tinyalsa, which does not require plugins. Building full alsa just to provide plugins is unnecessary, and if the richos is rich enough (heh), you can forward pulseaudio (as it was used before) or pipewire (actually, you can just pw-cat and share the UDS (Unix Domain Socket) from the richos and that's it. Working on it for the initramfs itself is pointless.
Audio has not been tested in Linux at this point (as really, most of the work would be with emualtors or real devices).

## What we expect you to keep out of source control
- docker-mounts - will include mount points, e.g. for the config, OTA etc., in case you chose to use that (i.e. if not using the fake loopback devices mode)
- initrd-fs - this may get another entry of source control of its own. Essentially you just need to start from a copy of an initramfs.
	- Alternatively, could unpack the cpio (and prior to that remove the header, if it is in a U-boot format)
- fake-files - these are the installer and fake hard drive/emmc storage, command line file, and possibly other things.

Both are generally true if we use the mount approach. They are somewhat true otherwise.

## More usage tips and hacks
To get into your docker, you need to exec the busybox shell and then chroot, or alternatively, if you know the ip, and you are running a system that has sshd set up, you can ssh into it as if it were a real device. Under nominal cases you should be able to use:
```
docker exec -it pscg-dockos-rd chroot /chroot-target sshpass -p <defaultpassword>  ssh -o StrictHostKeyChecking=no root@localhost
```

Alternatively, you can just exec `sh` in the chroot:
```
docker exec -it pscg-dockos-rd chroot /chroot-target sh
```

# More notes:
This is definitely not a complete README. Most people will probably prefer to use a full emulator (on which we will also speed up things quite significantly)
