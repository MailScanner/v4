#!/bin/sh

CLAMAVVERSION=0.84
export CLAMAVVERSION
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
yessa=yes
for ac_option
do
  ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`

  case $ac_option in
  --perl=*)
    perl=$ac_optarg ;;

  --nodeps)
    nodeps=$ac_option ;;

  --noclam)
    noclam=$ac_option ;;

  --nosa)
    #nosa=$ac_option ;;
    yessa= ;;

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
  --noclam                do not install ClamAV
  --nosa                  do not install SpamAssassin

_ACEOF

fi

test -n "$ac_init_help" && exit 0

# Set variables for later use
PERL=$perl
NODEPS=$nodeps
NOCLAM=$noclam
YESSA=$yessa

###################
# Main program

DISTTYPE=rpm
ARCHITECT=linux

# You need the db library installed
echo
echo You must have installed the RPM containing the \"db\" library
echo before you try to run this script. You should find this on
echo your Linux distribution CDs or DVD.
echo If you do not have this installed, this script WILL fail.
echo Press Ctrl-C now to stop this script.
echo
sleep 10

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
    echo I strongly advise you remove all traces of perl from
    echo within /usr/local and then run this script again.
    echo
    echo If you do not want to do that, and really want to continue,
    echo then you will need to run this script as
    echo "        $0 --perl=/path/to/perl"
    echo substituting \'/path/to\' appropriately. 
    echo
    exit 1
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
    sleep 2

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
sleep 2

echo
echo If this fails due to dependency checks, and you wish to ignore
echo these problems, you can run
echo "    $0 --nodeps"
sleep 2

if [ "x$NOCLAM" = "x" ]; then
  echo
  echo Installing ClamAV
  echo
  sleep 2
  echo To skip this completely, you can run
  echo "    $0 --noclam"
  sleep 5
  #crle -u -l /usr/local/lib
  echo Do not worry about warnings or errors from the next 2 commands
  groupadd clamav
  useradd -m -c 'ClamAV User' -d /home/clamav -g clamav clamav
  sleep 2
  echo You can start worrying about errors again now
  sleep 2
  echo
  echo Warning: I am about to uninstall the old Dag Wieers\' RPM packages
  echo Warning: of ClamAV and install Oliver Falk\'s RPMs instead.
  echo
  sleep 2
  echo Uninstalling...
  rpm -e --nodeps clamav-devel clamav-db clamav
  sleep 2
  echo
  echo Installing...
  rpm -Uvh ${PERL_DIR}/clamav*${CLAMAVVERSION}*i386.rpm
  sleep 2
  if [ -f /etc/MailScanner/virus.scanners.conf ]; then
    echo Updating your virus.scanners.conf file to point to the ClamAV I just installed.
    perl -pi.bak -e 's:^(clamav.*)/usr/local.*$:$1/usr:' /etc/MailScanner/virus.scanners.conf
  fi
else
  echo
  echo Skipping ClamAV installation.
  echo I assume you have already installed it yourself.
  echo I will still install the Mail::ClamAV Perl module for you.
  echo
  sleep 10
fi


echo
echo Rebuilding all the Perl modules for your version of Perl
echo
sleep 2

while read MODNAME MODFILE VERS BUILD TEST ARC PATCHSFX
do
  if [ "x$MODNAME" = "xMail::SpamAssassin" -a "x$YESSA" = "x" ]; then
    :
  else
    # If the module version is already installed, go onto the next one
    # (unless it is MIME-tools which is always rebuilt.
    if $PERL ./CheckModuleVersion ${MODNAME} ${VERS} ; then
      echo Oh good, module ${MODNAME} version ${VERS} is already installed.
      echo
      sleep 2
    else
      perlinstmod
    fi
  fi
done << EOF
Digest		Digest		1.08	1	yes	noarch
Text::Balanced	Text-Balanced	1.95	1	yes	noarch
Digest::MD5	Digest-MD5	2.33	1	yes	noarch
Parse::RecDescent Parse-RecDescent 1.94	1	yes	noarch
Inline		Inline		0.44	1	yes	noarch
Test::Harness	Test-Harness	2.42	1	yes	noarch
Test::Simple	Test-Simple	0.47	1	yes	noarch
Mail::ClamAV	Mail-ClamAV	0.13	1	yes	noarch
DB_File		DB_File		1.810	1	yes	noarch
Digest::SHA1	Digest-SHA1	2.10	1	yes	noarch
Net::CIDR::Lite	Net-CIDR-Lite	0.15	1	yes	noarch
Test::Manifest	Test-Manifest	0.95	1	yes	noarch
Business::ISBN	Business-ISBN	1.74	1	yes	noarch
Sys::Hostname::Long	Sys-Hostname-Long	1.2	1	yes	noarch
Digest::HMAC	Digest-HMAC	1.01	1	yes	noarch
Net::DNS	Net-DNS		0.48	1	no	noarch
URI		URI		1.35	1	yes	noarch
Mail::SPF::Query	Mail-SPF-Query	1.997	1	no	noarch
Mail::SpamAssassin Mail-SpamAssassin 3.0.3 1	yes	noarch
EOF

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
  sleep 2
fi


