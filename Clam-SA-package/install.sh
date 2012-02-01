#!/bin/sh

echo
echo This is the master script for installing the whole of MailScanner for NTL.
echo

echo Please sit and watch this on the first system to ensure everything works.
echo It will print a row of = signs and wait for 10 seconds between each script.

for F in freeware MailScanner Clam-SA Exim
do
  echo ====================================================================
  echo About to run ./install-${F}.sh
  echo
  ./install-${F}.sh
  echo ====================================================================
  sleep 10
  echo
done

