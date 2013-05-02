#!/usr/bin/sh

DATETIME=$(date +%Y%m%d_%H%M%S)
# echo $DATETIME
# exit 0
# echo "XXXX"
mkdir -p bak
mv -v setup.exe bak/setup_$DATETIME
wget http://www.cygwin.com/setup.exe
chmod 755 setup.exe
# q : Quiet mode, M : Package Manager
./setup.exe -qM
