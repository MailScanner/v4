#!/bin/sh
#
#   MailScanner - SMTP E-Mail Virus Scanner
#   Copyright (C) 2002  Julian Field
#
#   $Id: install.rpm-fns.sh 3044 2005-05-20 15:41:56Z jkf $
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#   The author, Julian Field, can be contacted by email at
#      Jules@JulianField.net
#   or by paper mail at
#      Julian Field
#      Dept of Electronics & Computer Science
#      University of Southampton
#      Southampton
#      SO17 1BJ
#      United Kingdom
#

#
# Many thanks to David Lee for writing most of this installer!
#

# The Perl SRPMs are all stored in here, relative to the distribution root
TMPBUILDDIR=/tmp
PERL_DIR=perl-rpm

# Make a temp dir we use for a few things
TMPINSTALL=${TMPBUILDDIR}/MStmpinstall.$$
mkdir $TMPINSTALL
chmod go-rwx $TMPINSTALL

# Check that /usr/src/redhat exists
echo
if [ -d /usr/src/redhat ]; then
  echo Good, you have /usr/src/redhat in place.
  RPMROOT=/usr/src/redhat
elif [ -d /usr/src/RPM ]; then
  echo Okay, you have /usr/src/RPM.
  RPMROOT=/usr/src/RPM
elif [ -d /usr/src/packages ]; then
  echo Okay, you have /usr/src/packages.
  RPMROOT=/usr/src/packages
else
  echo Your /usr/src/redhat, /usr/src/RPM or /usr/src/packages
  echo tree is missing.
  echo If you have access to an RPM called rpm-build or rpmbuild
  echo then install it first and come back and try again.
  echo
  exit 1
fi

# Ensure that the RPM macro
# %_unpackaged_files_terminate_build 1
# is set. Otherwise package building will fail.
echo
if grep -qs '%_unpackaged_files_terminate_build[ 	][ 	]*0' ~/.rpmmacros
then
  echo Good, unpackaged files will not break the build process.
else
  echo Writing a .rpmmacros file in your home directory to stop
  echo unpackaged files breaking the build process.
  echo You can delete it once MailScanner is installed if you want to.
  echo '%_unpackaged_files_terminate_build 0' >> ~/.rpmmacros
  echo
  sleep 10
fi

# Check they have the development tools installed on SuSE
if [ -f /etc/SuSE-release -o -f /etc/redhat-release ]; then
  echo
  echo I think you are running on RedHat Linux or SuSE Linux.
  GCC=gcc
  if [ -f /etc/redhat-release ] && fgrep -q ' 6.' /etc/redhat-release ; then
      # RedHat used egcs in RedHat 6 and not gcc
      GCC=egcs
  fi
  if rpm -q binutils glibc-devel $GCC make >/dev/null 2>&1 ; then
    echo Good, you appear to have the basic development tools installed.
    sleep 5
  else
    echo You must have the following RPM packages installed before
    echo you try and do anything else:
    echo '       binutils glibc-devel' $GCC 'make'
    echo You are missing at least 1 of these.
    echo Please install them all
    echo '(Read the manuals if you do not know how to do this).'
    echo Then come back and run this install.sh script again.
    echo
    exit 1
  fi
fi

# Need GNU tar and make
TARPATH="/usr/local/bin /usr/local/sbin /usr/freeware/bin /usr/bin /usr/sbin /bin"
CCPATH="/opt/SUNWspro/bin /usr/local/bin /usr/local/sbin /usr/freeware/bin /usr/bin /usr/sbin /bin"
MAKEPATH="/usr/local/bin /usr/freeware/bin /usr/ccs/bin /usr/bin /bin"
GUNZIPPATH="/usr/local/bin /usr/freeware/bin /usr/bin /bin"

TAR=`findprog tar $TARPATH`
MAKE=`findprog make $MAKEPATH`
GUNZIP=`findprog gunzip $GUNZIPPATH`
CC=`findprog cc $CCPATH`
GCC=`findprog gcc $TARPATH`
RPMBUILD=`findprog rpmbuild $TARPATH`

# Now we have tar, check it is GNU tar as we need the "z" option
TARCHECK=`$TAR --version 2>/dev/null | grep GNU`
if [ "x$TARCHECK"  = "x" ]; then
  echo Bother, could not find GNU tar.
  TARISGNU=no
  if [ "x$GUNZIP" = "x" ]; then
    echo Could not find gunzip either. You will have to decompress the
    echo .tar.gz files yourself, to leave a collection of .tar files.
    sleep 2
  else
    echo No problem, will decompress them with gunzip.
    sleep 2
  fi
else
  echo Good, I have found GNU tar in $TAR.
  TARISGNU=yes
fi

# The function to unpack an archive into a directory.
unpackarchive () {
  DIR=$1
  SOURCE=$2

  if [ "x$TARISGNU" = "xyes" ]; then
    ( cd $DIR && $TAR xzBpf - ) < $SOURCE
  else
    # Not GNU tar, so try to gunzip ourselves
    if [ "x$GUNZIP" = "x" ]; then
      SOURCE2=`echo $SOURCE | sed -e 's/\.gz$//'`
      if [ -f "$SOURCE2" ]; then
        ( cd $DIR && $TAR xBpf - ) < $SOURCE2
      else
        echo Could not find ${SOURCE2}.
        echo As I could not find GNU tar or gunzip, you need to
        echo uncompress each of the .gz files yourself.
        echo Sorry about that.
        exit 1
      fi
    else
      $GUNZIP -c $SOURCE | ( cd $DIR && $TAR xBpf - )
    fi
  fi
}

################################################################
# The function to install a perl module.
# Uses as quasi-arguments:
#       PERL_DIR: directory of perl modules
#       MODFILE: filename
#       VERS: version
#       BUILD: build number
#	TEST: yes or no
#       ARC: architecture
perlinstmod () {
  FILEPREFIX=perl-${MODFILE}-${VERS}-${BUILD}
  echo Attempting to build and install ${FILEPREFIX}
  if [ -f ${PERL_DIR}/${FILEPREFIX}.src.rpm ]; then
    ( cd $PERL_DIR ;
      echo y | $RPMBUILD --rebuild ${FILEPREFIX}.src.rpm
    )
    sleep 10
    echo
    echo
    echo
  else
    echo Missing file ${PERL_DIR}/${FILEPREFIX}.src.rpm. Are you in the right directory\?
    sleep 10
    echo
  fi
  if [ -f ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm ]; then
    echo
    echo Do not worry too much about errors from the next command.
    echo It is quite likely that some of the Perl modules are
    echo already installed on your system.
    echo
    echo Ignore errors from the perl-Digest and perl-Digest-MD5 packages.
    echo Test-Harness is probably okay to ignore too.
    echo
    sleep 10
    rpm -Uvh ${NODEPS} ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm
    sleep 10
    echo
    echo
    echo
  else
    echo Missing file ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm.
    echo Maybe it did not build correctly\?
    echo '*'
    echo '* This Could Be A Problem. Press Ctrl-S Now!!'
    echo '*'
    sleep 10
    echo
  fi
}

#
# Install the TNEF decoder
# Ready-built if we are on Solaris or an RPM system
#
tnefinstall () {
  rpm -Uvh tnef*i386.rpm
}

#
# Intall MailScanner itself
#
mailscannerinstall () {
  rpm -Uvh ${NODEPS} mailscanner*noarch.rpm

  rpmnew=`ls /usr/lib/MailScanner/*rpmnew 2>/dev/null | wc -w`
  if [ $rpmnew -ne 0 ]; then
    echo
    echo 'There are new *.rpmnew files in /usr/lib/MailScanner.'
    echo 'You should rename each of these over the top of the old'
    echo 'version of each file, but remember to copy any changes'
    echo 'you have made to the old versions.'
    echo
  fi
  rpmnew=`ls /etc/MailScanner/reports/*/languages.conf.rpmnew 2>/dev/null | wc -w`
  if [ $rpmnew -ne 0 ]; then
    echo
    echo 'There are new versions of the'
    echo '/etc/MailScanner/reports/.../langauges.conf files.'
    echo 'You should rename each of these over the top of the old'
    echo 'version of each file, but remember to copy any changes'
    echo 'you have made to the old versions.'
    echo
  fi
}

