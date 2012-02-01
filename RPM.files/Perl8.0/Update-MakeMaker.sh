#!/bin/sh

if [ -f ExtUtils-MakeMaker-6.05.tar.gz ] ; then
  tar xzf ExtUtils-MakeMaker-6.05.tar.gz
  if [ -d ExtUtils-MakeMaker-6.05 ] ; then
    cd ExtUtils-MakeMaker-6.05
    perl Makefile.PL
    make
    make install
    echo
    echo Done. Please now run ./install.sh again.
    exit 0
  else
    echo The perl module did not unpack correctly.
    exit 1
  fi
else
  echo Are you in the right directory\?
  echo I could not find the file ExtUtils-MakeMaker-6.05.tar.gz
  exit 1
fi

exit 0

