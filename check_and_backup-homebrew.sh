#!/usr/bin/env zsh

OLDLIST=/Users/x/tmp/oldlistbrew.txt
NEWLIST=/Users/x/tmp/newlistbrew.txt

brew list > $NEWLIST
brew cask list >> $NEWLIST

if [ -f $OLDLIST ]; then
    if diff $OLDLIST $NEWLIST >/dev/null ; then
	echo "Not change brew packages"
	exit 0
    fi
fi

mv $NEWLIST $OLDLIST

# backup, for 2st's backup 
mv -f /Users/x/Dropbox/Apps/Homebrew/restore-homebrew.sh /Users/x/Dropbox/Apps/Homebrew/restore-homebrew.sh.bak

/Users/x/Dropbox/Apps/Homebrew/backup-homebrew.sh > /Users/x/Dropbox/Apps/Homebrew/restore-homebrew.sh
chmod 755 /Users/x/Dropbox/Apps/Homebrew/restore-homebrew.sh

