#!/usr/bin/env sh
# https://www.tekrevue.com/tip/how-to-create-a-4gbs-ram-disk-in-mac-os-x/

# diskutil erasevolume zfs 'RAM Disk' `hdiutil attach -nomount ram://2097152`
PATH=$HOME/bin:/usr/local/bin:$PATH
TMPDIR=$HOME/tmp
TMPFILE=$TMPDIR/ramdisk.info

case "$1" in
    start)
	DEVDISK="$(hdiutil attach -nomount ram://2097151 2>&1)"
	# /dev/disk1
	rm -f $TMPFILE
	echo "$DEVDISK" > $TMPFILE
	sudo zpool create RamDisk $DEVDISK
	sudo chown -R $(whoami) /Volumes/RamDisk
	# cp -rf /Users/x/Documents/RamDisk/x /Volumes/RamDisk/
	rsync -a /Users/x/Documents/RamDisk/ /Volumes/RamDisk
        ;;
    stop)
	rsync -a --delete /Volumes/RamDisk/x/ ~/Documents/RamDisk/x
	sudo zpool destroy RamDisk
	hdiutil detach $(cat "$TMPFILE")
        ;;
    status)
	hdiutil info
	zpool status
        ;;
    restart)
        stop
        start
        ;;
    condrestart)
        if test "x`pidof anacron`" != x; then
            stop
            start
        fi
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart|condrestart|status}"
        exit 1
esac

# sudo zfs create zfs001/p1
# sudo zfs set mountpoint=/Volumes/RamDisk zfs001/p1

