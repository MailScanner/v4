#!/bin/sh

EXIMVERSION=4.41
export EXIMVERSION

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

DISTTYPE=tar
echo You appear to be running on Solaris, I will use the ready-built
echo binaries for you where necessary.
ARCHITECT=solaris
# Need to add elements to path to find make as it is non-standard,
# and SUN C compiler if installed.
PATH=/usr/local/bin:/usr/ccs/bin:/opt/SUNWspro/bin:${PATH}
export PATH


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


echo
echo This script will install a basic Exim setup.
echo
sleep 2

. ./install.tar-fns.sh

echo Do not worry about errors from the next 2 commands.
groupadd exim
useradd -m -c 'Exim  User' -d /export/home/exim -g exim exim
echo Start worrying about errors again.

unpackarchive $TMPBUILDDIR ${PERL_DIR}/exim-${EXIMVERSION}.tar.gz
    (
      olddir=`pwd`
      cd ${TMPBUILDDIR}/exim-${EXIMVERSION}
      echo
      echo About to build the Exim email transport
      echo
      cp ${olddir}/Exim.Local.Makefile Local/Makefile
      sleep 1
      make
      sleep 5
      make install
    )



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

