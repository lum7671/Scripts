#!/usr/bin/env zsh

# debug
# sudo sshfs -p 3022 -o debug,sshfs_debug,loglevel=debug,allow_other,default_permissions ness@172.30.1.58:/home/ness/tmp /Volumes/rp
#
sudo sshfs -p 3022 -o allow_other,default_permissions ness@172.30.1.58:/home/ness/tmp /Volumes/rp
