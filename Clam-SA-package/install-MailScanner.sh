#!/bin/sh

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
for ac_option
do
  ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`

  case $ac_option in
  --perl=*)
    perl=$ac_optarg ;;

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

_ACEOF

fi

test -n "$ac_init_help" && exit 0

# Set variables for later use
PERL=$perl
NODEPS=$nodeps

###################
# Main program

# Are we on an RPM system? If so, use rpm commands to do everything
echo
if [ -x /bin/rpmbuild ]; then
  RPMBUILD=/bin/rpmbuild
elif [ -x /usr/bin/rpmbuild ]; then
  RPMBUILD=/usr/bin/rpmbuild
elif [ -x /usr/local/bin/rpmbuild ]; then
  RPMBUILD=/usr/local/bin/rpmbuild
elif [ -x /bin/rpm ]; then
  RPMBUILD=/bin/rpm
elif [ -x /usr/bin/rpm ]; then
  RPMBUILD=/usr/bin/rpm
elif [ -x /usr/local/bin/rpm ]; then
  RPMBUILD=/usr/local/bin/rpm
else
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

# This must be done here, not relying on them to run another command.
# Check they have an up to date copy of ExtUtils::MakeMaker or else they
# will start generating duff Makefiles.
#echo
#if ./CheckModuleVersion ExtUtils::MakeMaker 6.05; then
#  echo Good, your version of ExtUtils::MakeMaker is up to date
#else
#  echo Your copy of the Perl module ExtUtils::MakeMaker is out of date.
#  echo I will install a newer version for you.
#  sleep 2
#  tar xzf ExtUtils-MakeMaker-6.05.tar.gz
#  if [ -d ExtUtils-MakeMaker-6.05 ] ; then
#    cd ExtUtils-MakeMaker-6.05
#    perl Makefile.PL
#    make
#    make install
#
#
#fi

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

echo
echo Rebuilding all the Perl modules for your version of Perl
echo
sleep 2

while read MODNAME MODFILE VERS BUILD TEST ARC PATCHSFX
do
  # If the module version is already installed, go onto the next one
  # (unless it is MIME-tools which is always rebuilt.
  if $PERL ./CheckModuleVersion ${MODNAME} ${VERS} ; then
    echo Oh good, module ${MODNAME} version ${VERS} is already installed.
    echo
    sleep 2
  else
    perlinstmod
  fi
done << EOF
ExtUtils::MakeMaker ExtUtils-MakeMaker 6.05 1	yes	noarch
Net::CIDR	Net-CIDR	0.09	3	yes	noarch
IsABundle	IO-stringy	2.108	1	yes	noarch
MIME::Base64	MIME-Base64	2.12	1	yes	i386
IsABundle	TimeDate	1.1301	3	yes	noarch
IsABundle	MailTools	1.50	1	yes	noarch
File::Spec	File-Spec	0.82	1	yes	noarch
File::Temp	File-Temp	0.12	1	yes	noarch
HTML::Tagset	HTML-Tagset	3.03	1	yes	noarch
HTML::Parser	HTML-Parser	3.26	2	yes	i386
IsABundle	MIME-tools	5.411	pl4.3	yes	noarch -patched
Convert::TNEF	Convert-TNEF	0.17	1	yes	noarch
Compress::Zlib	Compress-Zlib	1.33	2	yes	i386
Archive::Zip	Archive-Zip	1.13	1	yes	noarch
Convert::BinHex	Convert-BinHex	1.119	2	no	noarch
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
  echo Please remember to kill all the old mailscanner version 3
  echo processes before you start the new version.
  echo
fi
mailscannerinstall

