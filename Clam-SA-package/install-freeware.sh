#!/bin/sh

echo
echo This script will install the extra software packages required to
echo build and install MailScanner and its dependencies.
echo
sleep 2

echo Installing freeware for `uname -p` architecture
cd freeware.`uname -p`

for F in *gz
do
  PKG=`echo $F | sed -e 's/\.gz$//'`
  gunzip $F
  echo
  echo Please say yes to any installation questions
  echo
  sleep 2
  echo Installing $PKG
  pkgadd -d ./$PKG
  echo
  echo Installed $PKG
  echo
  gzip $PKG
  sleep 2
done

# Now set up the link for BerkeleyDB to work for SpamAssassin
rm -f /usr/local/BerkeleyDB
ln -s BerkeleyDB.3.3 /usr/local/BerkeleyDB

