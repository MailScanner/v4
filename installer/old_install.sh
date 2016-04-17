#!/bin/bash

# Let the "tail" commands work on fussy new posix systems
_POSIX2_VERSION=199209
export _POSIX2_VERSION

#
# Locate a program given a list of directories to look in.
# Need to break out of loop as soon as we find it.
#
findprog () {
  _prog=$1
  shift
  for _path in $*
  do
    if [ -f ${_path}/${_prog} ]; then
      echo ${_path}/${_prog}
      break
    fi
    shift
  done
  echo
}

###################
# Parse arguments: "./install.sh --help" for more details.
# This is blatantly plagiarised from the typical "./configure" produced by
# "autoconf".  If we need to get more complicated, then we should probably
# migrate towards using "autoconf" itself.  (Hence not optimising this part, to
# preserve resemblance and encourage compability with "autoconf" conventions.)

as_me=`(basename "$0") 2>/dev/null`

ac_init_help=
perl=
nodeps=
fast=
nomodules=
for ac_option
do
  ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`

  case $ac_option in
  --perl=*)
    perl=$ac_optarg ;;

  fast)
    fast=$ac_option ;;

  --fast)
    fast=$ac_option ;;

  --nomodules)
    nomodules=$ac_option ;;

  --nodeps)
    nodeps=$ac_option ;;

  --help | -h)
    ac_init_help=long ;;

  -*) { echo "$as_me: error: unrecognized option: $ac_option
Try \`$0 --help' for more information." >&2
   { (exit 1); exit 1; }; }
    ;;

  *) { echo "$as_me: error: unrecognized argument: $ac_option
Try \`$0 --help' for more information." >&2
   { (exit 1); exit 1; }; }
    ;;

  esac
done

if test "$ac_init_help" = "long"; then
    cat <<_ACEOF
Usage: $0 [OPTION]... [VAR=VALUE]...

  -h, --help              display this help and exit
  --perl=PERL             location of perl binary to use
  --nodeps                ignore dependencies when installing MailScanner
  --fast                  Do not wait for a long time while installing
  --nomodules             Skip installing required Perl modules

_ACEOF

fi

test -n "$ac_init_help" && exit 0

# Set variables for later use
PERL=$perl
NODEPS=$nodeps
FAST=$fast
NOMODULES=$nomodules

###################
# Main program

(

echo
echo I am logging everything into \"install.log\".
sleep 3


echo
echo You appear to be running on a system that does not use the
echo RPM packaging system.
echo If you think you can use RPM, then press Ctrl-C right now,
echo 'make sure the "rpm" and "rpmbuild" programs can be found'
echo and run this script again.
echo I will install MailScanner under /opt, from where you can
echo move it if you want.
sleep 2
DISTTYPE=tar
if [ x`uname -s` = "xSunOS" ]; then
  echo You appear to be running on Solaris, I will use the ready-built
  echo binaries for you where necessary.
  ARCHITECT=solaris
  # Need to add elements to path to find make as it is non-standard,
  # and SUN C compiler if installed.
  PATH=/usr/local/bin:/usr/ccs/bin:/opt/SUNWspro/bin:${PATH}
  export PATH
else
  echo I will need to build the tnef program for you too.
  ARCHITECT=unknown
fi

# If we have set RPMBUILD then we are on an rpm system
if [ "x$RPMBUILD" = "x" ]; then
  :
else
  DISTTYPE=rpm
fi

# Have they not explicitly specified a perl installation?
if [ "x$PERL" = "x" ] ; then
  # Check they don't have 2 Perl installations, this will cause all sorts
  # of grief later.
  echo
  if [ -x /usr/bin/perl -a -f /usr/local/bin/perl -a -x /usr/local/bin/perl ] ;
  then
    echo You appear to have 2 versions of Perl installed,
    echo the normal one in /usr/bin and one in /usr/local.
    echo This often happens if you have used CPAN to install modules.
    PERL1=`ls -l /usr/bin/perl | awk '{ print $NF }'`
    PERL2=`ls -l /usr/local/bin/perl | awk '{ print $NF }'`
    if [ "x$PERL1" = "x$PERL2" ]; then
      echo Fortunately they both point to the same place, so you are fine.
      PERL="/usr/bin/perl"
      sleep 2
    else
      echo I strongly advise you remove all traces of perl from
      echo within /usr/local and then run this script again.
      echo
      echo If you do not want to do that, and really want to continue,
      echo then you will need to run this script as
      echo "        $0 --perl=/path/to/perl"
      echo substituting \'/path/to\' appropriately. 
      echo
      exit 1
    fi
  else
    PERLPATH="/usr/bin /usr/local/bin"
    PERL=`findprog perl $PERLPATH`
    echo Good, you appear to only have 1 copy of Perl installed: $PERL
  fi

fi
if [ \! -x $PERL ] ; then
  echo No executable perl $PERL . Exiting.
  exit 1
fi

#
# Read the installation-specific stuff and do any extra checks
#
. ./install.${DISTTYPE}-fns.sh

###################
# Problems with perl 5.00503, typically on RaQ3 and Solaris 8:
# often lacks "opnames.h" and similar.
# Temporarily patch up.  Remove later.

perlfudgelist="opnames.h perlapi.h utf8.h warnings.h"
perlcoredir=""
for perldir in \
  /usr/lib/perl5/5.00503/i386-linux /usr/perl5/5.00503/sun4-solaris
do
  if [ -d ${perldir}/CORE ]; then
    echo
    echo I think you are running Perl 5.00503.
    echo Ensuring that you have all the header files in ${perldir}/CORE
    echo that are needed to build HTML-Parser which is used by
    echo both MailScanner and SpamAssassin.
  
    perlcoredir=${perldir}/CORE
    for perlfudgefile in $perlfudgelist
    do
      if [ \! -f ${perlcoredir}/${perlfudgefile} ] ; then
        echo installing perl fudge file ${perlcoredir}/${perlfudgefile}
        touch ${perlcoredir}/${perlfudgefile}.MS
        ln ${perlcoredir}/${perlfudgefile}.MS ${perlcoredir}/${perlfudgefile}
      fi
    done
    timewait 2

    break
  fi
done


# JKF This needs to be a lot cleverer to correctly check
# JKF /usr/perl5/bin and /usr/lib/perl5/*/bin and /usr/lib/perl5/bin as well.
# JKF Also check /usr/local/bin.
# Check that they aren't missing pod2text but have pod2man.
if [ -x /usr/bin/pod2man -a \! -x /usr/bin/pod2text ] ; then
  echo
  echo You appear to have pod2man but not pod2text.
  echo Creating pod2text for you.
  ln -s pod2man /usr/bin/pod2text
fi

echo
echo This script will pause for a few seconds after each major step,
echo so do not worry if it appears to stop for a while.
echo If you want it to stop so you can scroll back through the output
echo then press Ctrl-S to stop the output and Ctrl-Q to start it again.
echo
timewait 2

echo
echo If this fails due to dependency checks, and you wish to ignore
echo these problems, you can run
echo "    $0 --nodeps"
timewait 2

echo
echo Setting Perl5 search path
echo
#PERL5LIB=`$PERL -V | grep site_perl | grep -v config_args | tr -d ' ' | tr '\n' ':'`
#export PERL5LIB
PERL5LIB=`./getPERLLIB`
export PERL5LIB

if [ "x$NOMODULES" = "x" ]; then
  echo
  echo Rebuilding all the Perl modules for your version of Perl
  echo
  timewait 2

  while read MODNAME MODFILE VERS BUILD TEST ARC PATCHSFX
  do
    # If the module version is already installed, go onto the next one
    # (unless it is MIME-tools which is always rebuilt.
    if [ ${MODNAME} = "Test::Simple" -o ${MODNAME} = "Test::Harness" ]; then
      if PERL5LIB= $PERL ./CheckModuleVersion ${MODNAME} ${VERS} 2>/dev/null ; then
        echo Oh good, module ${MODNAME} version ${VERS} is already installed.
        echo
        timewait 2
      else
        perlinstmod
      fi
    else
      if $PERL ./CheckModuleVersion ${MODNAME} ${VERS} 2>/dev/null && [ "x$MODNAME" \!= "xMIME::Base64" ]; then # && [ "x$MODNAME" \!= "xDBI" ] && [ "x$MODNAME" \!= "xTest::Simple" ] && [ "x$MODNAME" \!= "xMath::BigInt" ] && [ "x$MODNAME" \!= "xMath::BigRat" ]; then
        echo Oh good, module ${MODNAME} version ${VERS} is already installed.
        echo
        timewait 2
      else
        perlinstmod
      fi
    fi
  done << EOF
File::Spec	File-Spec	0.82	1	yes	noarch
ExtUtils::MakeMaker ExtUtils-MakeMaker 6.50 2	yes	noarch
IsABundle	IO-stringy	2.110	1	yes	noarch
MIME::Base64	MIME-Base64	3.07	5	yes	i386
IsABundle	TimeDate	1.16	3	yes	noarch
Pod::Escapes    Pod-Escapes     1.04    1	yes	noarch
Pod::Simple     Pod-Simple      3.05    1       yes	noarch
Test::Harness	Test-Harness	2.64	1	yes	noarch
Test::Simple	Test-Simple	0.86	1	no	noarch
Test::Pod       Test-Pod        1.26    1       yes	noarch
IsABundle	MailTools	2.04	1	yes	noarch
IO		IO		1.2301	1	yes	noarch
File::Temp	File-Temp	0.20	1	yes	noarch
HTML::Tagset	HTML-Tagset	3.03	1	yes	noarch
HTML::Parser	HTML-Parser	3.64	1	yes	i386
IsABundle	MIME-tools	5.427	1	yes	noarch
Convert::TNEF	Convert-TNEF	0.17	1	yes	noarch
Compress::Zlib	Compress-Zlib	1.41	1	yes	i386
Compress::Raw::Zlib	Compress-Raw-Zlib	2.027	1	yes	noarch
Archive::Zip	Archive-Zip	1.30	1	yes	noarch
Convert::BinHex	Convert-BinHex	1.119	2	no	noarch
Scalar::Util	Scalar-List-Utils 1.19	1	yes	noarch
Storable	Storable	2.16	1	yes	noarch
DBI		DBI		1.607	1	yes	noarch
DBD::SQLite	DBD-SQLite	1.25	1	yes	noarch
Getopt::Long	Getopt-Long	2.38	1	yes	noarch
Time::HiRes	Time-HiRes	1.9707	1	yes	noarch
Filesys::Df	Filesys-Df	0.90	1	yes	noarch
Math::BigInt	Math-BigInt	1.89	2	yes	noarch
Math::BigRat	Math-BigRat	0.22	1	yes	noarch
bignum		bignum		0.23	1	yes	noarch
Net::CIDR	Net-CIDR	0.13	1	yes	noarch
Net::IP		Net-IP		1.25	1	yes	noarch
Sys::Hostname::Long Sys-Hostname-Long 1.4 1	yes	noarch
Sys::Syslog	Sys-Syslog	0.27	1	yes	noarch
Digest::MD5	Digest-MD5	2.36	1	yes	noarch
Digest::SHA1	Digest-SHA1	2.11	1	yes	noarch
Digest::HMAC	Digest-HMAC	1.01	1	yes	noarch
Net::DNS	Net-DNS		0.65	1	yes	noarch
OLE::Storage_Lite OLE-Storage_Lite 0.16	1	yes	noarch
Sys::SigAction	Sys-SigAction	0.11	1	yes	noarch
EOF

else
  echo
  echo Skipping installing required Perl modules, at your request
  echo
  timewait 5
fi

###################
# Did we fudge perl 5.00503?  If so, tidy up.
if [ "x${perlcoredir}" != "x" ] ; then
  echo
  for perlfudgefile in $perlfudgelist
  do
    echo removing perl fudge files for ${perlcoredir}/${perlfudgefile}
    if [ -f ${perlcoredir}/${perlfudgefile}.MS ] ; then
      rm -f ${perlcoredir}/${perlfudgefile}.MS ${perlcoredir}/${perlfudgefile}
    fi
  done
  echo
  timewait 2
fi

afterperlmodules

echo
echo Installing tnef decoder
echo
tnefinstall

echo
echo Now to install MailScanner itself.
echo

if [ -d /usr/local/MailScanner ] ; then
  echo
  echo
  echo Please remember to kill all the old mailscanner version
  echo processes before you start the new version.
  echo
fi
mailscannerinstall
timewait 5

echo
echo Linking into SpamAssassin if you have it installed.
echo

SADIR=`$PERL -MMail::SpamAssassin -e 'print Mail::SpamAssassin->new->first_existing_path(@Mail::SpamAssassin::site_rules_path)' 2>/dev/null`

if [ "x$SADIR" = "x" ]; then
  echo No SpamAssassin installation found.
else
  if [ -d /etc/MailScanner ]; then
    if [ -e ${SADIR}/mailscanner.cf ]; then
      echo Leaving mailscanner.cf link or file alone.
    else
      ln -s -f /etc/MailScanner/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    fi
    echo Good, the link was created to /etc/MailScanner
  elif [ -d /usr/local/MailScanner/etc ]; then
    if [ -e ${SADIR}/mailscanner.cf ]; then
      echo Leaving mailscanner.cf link or file alone.
    else
      ln -s -f /usr/local/MailScanner/etc/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    fi
    echo Good, the link was created to /usr/local/MailScanner/etc
  elif [ -d /etc/MailScanner ]; then
    if [ -e ${SADIR}/mailscanner.cf ]; then
      echo Leaving mailscanner.cf link or file alone.
    else
      ln -s -f /etc/MailScanner/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    fi
    echo Good, the link was created to /etc/MailScanner
  elif [ -d /usr/local/etc/MailScanner ]; then
    if [ -e ${SADIR}/mailscanner.cf ]; then
      echo Leaving mailscanner.cf link or file alone.
    else
      ln -s -f /usr/local/etc/MailScanner/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    fi
    echo Good, the link was created to /usr/local/etc/MailScanner
  else
    echo
    echo 'WARNING: Could not find MailScanner installation directory.'
    echo  WARNING: You must create a link in ${SADIR} called mailscanner.cf
    echo  WARNING: which points to the spam.assassin.prefs.conf file in the
    echo  WARNING: MailScanner etc directory.
    echo
    sleep 10
  fi
fi
timewait 5

echo
echo 'I strongly recommend you create a few root cron jobs:'
echo
echo '37      5 * * * /usr/sbin/update_phishing_sites'
echo '07      * * * * /usr/sbin/update_bad_phishing_sites'
#echo '37      4 * * * /usr/sbin/clean.SA.cache'
echo '58     23 * * * /usr/sbin/clean.quarantine'
echo '42      * * * * /usr/sbin/update_virus_scanners'
echo '3,23,43 * * * * /usr/sbin/check_mailscanner'
echo

timewait 10

echo
echo 'If you want help setting up MailScanner, please read the Wiki'
echo 'at wiki.mailscanner.info and download the MailScanner book at'
echo 'www.mailscanner.info'
echo

) 2>&1 | tee install.log

