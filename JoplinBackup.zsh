#!/usr/bin/env zsh

DATE=$(date +%Y%m%d)
FILENAME=$(basename $0 .zsh)
TXZ_FILENAME="$FILENAME-$DATE.txz"
BACKUP_PATH="$HOME/SynologyDrive/JoplinBackup"
TMP_PATH="$HOME/tmp"

cd $HOME
echo "*** Start ***"
echo "*** Make backup file in tmp directory ***"
apack $TMP_PATH/$TXZ_FILENAME Joplin
echo "*** Move tmp file to backup directory ***"
mv -v $TMP_PATH/$TXZ_FILENAME $BACKUP_PATH
echo "*** Delete backup files older than 7 days ***"
fd -H 'txz$' --base-directory $BACKUP_PATH -tf --change-older-than 1weeks -X rm -vf
echo "*** The End ***"
