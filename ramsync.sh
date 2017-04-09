#!/usr/bin/env sh
rsync -av --delete /Volumes/RamDisk/ ~/Works/RamDisk/4B82348C-ABF2-444C-9173-88AEB51B7EAC-1.iRamDiskBackup
sync
echo "\n\n============================================================================\n"
df -h /dev/disk1
