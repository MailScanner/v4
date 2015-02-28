#!/bin/sh

MOD="File::Spec	File-Spec	0.82	3	noarch	no	no
ExtUtils::MakeMaker ExtUtils-MakeMaker 6.50 2	noarch	no	no
Pod::Escapes	Pod-Escapes	1.04	2	noarch	no	no
Pod::Simple	Pod-Simple	3.05	2	noarch	no	no
Test::Simple	Test-Simple	0.86	2	noarch	no	no
Math::BigInt	Math-BigInt	1.89	2	noarch	no	no
Math::BigRat	Math-BigRat	0.22	1	noarch	no	no
bignum		bignum		0.23	1	noarch	no	no
MIME::Base64	MIME-Base64	3.07	3	arch	no	no
IsABundle	TimeDate	1.16	4	noarch	no	no
Pod::Simple	Pod-Simple	3.05	2	noarch	no	no
Pod::Escapes	Pod-Escapes	1.04	2	noarch	no	no
Pod::Simple	Pod-Simple	3.05	2	noarch	no	no
Test::Harness	Test-Harness	2.64	3	noarch	no	no
Test::Simple	Test-Simple	0.86	2	noarch	no	no
Test::Pod	Test-Pod	1.26	2	noarch	no	no
IO		IO		1.2301	5	arch	no	no
IsABundle	IO-stringy	2.110	2	noarch	no	no
IsABundle	MailTools	2.04	2	noarch	no	no
File::Temp	File-Temp	0.20	4	noarch	no	no
HTML::Tagset	HTML-Tagset	3.03	2	noarch	no	no
HTML::Parser	HTML-Parser	3.64	1	arch	no	no
Convert::BinHex	Convert-BinHex	1.119	3	noarch	no	no
IsABundle	MIME-tools	5.427	2	noarch	no	no
Convert::TNEF	Convert-TNEF	0.17	2	noarch	no	no
Compress::Zlib	Compress-Zlib	1.41	2	arch	no	no
Compress::Raw::Zlib	Compress-Raw-Zlib	2.027	1	noarch	no	no
Archive::Zip	Archive-Zip	1.30	1	noarch	no	no
Scalar::Util	Scalar-List-Utils 1.19	3	noarch	no	no
Storable	Storable	2.16	3	noarch	no	no
DBI		DBI		1.607	2	arch	no	no
DBD::SQLite	DBD-SQLite	1.25	2	arch	no	no
Getopt::Long	Getopt-Long	2.38	2	noarch	no	no
Time::HiRes	Time-HiRes	1.9707	3	noarch	no	no
Filesys::Df     Filesys-Df 	0.90	3	arch	no	no
Net::CIDR	Net-CIDR	0.13	1	noarch	no	no
Net::IP		Net-IP		1.25	2	noarch	no	no
Sys::Hostname::Long Sys-Hostname-Long 1.4 2	noarch	no	no
Sys::Syslog	Sys-Syslog	0.27	1	noarch	no	no
Digest::MD5	Digest-MD5	2.36	3	noarch	no	no
Digest::SHA1	Digest-SHA1	2.11	3	arch	no	no
Digest::HMAC	Digest-HMAC	1.01	1	noarch	no	no
Net::DNS	Net-DNS		0.65	2	arch	no	no
OLE::Storage_Lite OLE-Storage_Lite 0.16	2	noarch	no	no
Sys::SigAction	Sys-SigAction	0.11	1	noarch	no	no"

# Wait for n seconds unless they ran me with "fast" on the command-line
timewait () {
  DELAY=$1
  if [ "x$FAST" = "x" ]; then
    sleep $DELAY
  fi
}

(

echo
echo I am logging everything into \"install.log\".
timewait 3

echo
if [ -x /bin/rpmbuild ]; then
  RPMBUILD=/bin/rpmbuild
elif [ -x /usr/bin/rpmbuild ]; then
  RPMBUILD=/usr/bin/rpmbuild
elif [ -x /bin/rpm ]; then
  RPMBUILD=/bin/rpm
elif [ -x /usr/bin/rpm ]; then
  RPMBUILD=/usr/bin/rpm
else
  echo I cannot find any rpm or rpmbuild command on your path.
  echo Please check you are definitely using an RPM-based system.
  echo If you are, then please install the RPMs called rpm and
  echo rpm-build, then try running this script again.
  echo
  exit 1
fi

echo
if [ -x /bin/patch -o -x /usr/bin/patch ]; then
  echo Good. You have the patch command.
else
  echo You need to install the patch command from your Linux distribution.
  echo Once you have done that, please try running this script again.
  exit 1
fi

# Check that /usr/src/redhat exists
echo
if [ -d ~/rpmbuild ]; then
  echo Aha, a new Fedora system building in your home directory.
  RPMROOT=~/rpmbuild
elif [ -d /usr/src/redhat ]; then
  echo Good, you have /usr/src/redhat in place.
  RPMROOT=/usr/src/redhat
elif [ -d /usr/src/RPM ]; then
  echo Okay, you have /usr/src/RPM.
  RPMROOT=/usr/src/RPM
elif [ -d /usr/src/rpm ]; then
  echo Okay, you have /usr/src/rpm.
  RPMROOT=/usr/src/rpm
elif [ -d /usr/src/packages ]; then
  echo Okay, you have /usr/src/packages.
  RPMROOT=/usr/src/packages
elif rpmbuild --showrc | grep ': _topdir' | grep -q 'HOME.*rpmbuild'; then
  echo Okay, a recent system building into '~/rpmbuild'.
  RPMROOT=~/rpmbuild
else
  echo Your /usr/src/redhat, /usr/src/RPM or /usr/src/packages
  echo tree is missing.
  echo If you have access to an RPM called rpm-build or rpmbuild
  echo then install it first and come back and try again.
  echo
  exit 1
fi

# Fix up 2 problems with Mandriva
ONFIVE='no'
ONFEDORATEN='no'
INTURN='no'
if [ -f /etc/redhat-release  ];
then
  if egrep -qi 'mandrake|mandriva' /etc/redhat-release
  then
    echo I think you are running on Mandrake or Mandriva.
    echo There are 2 problems I need to correct.
    # Mandriva only
    DONT_CLEAN_PERL=1
    export DONT_CLEAN_PERL
    if [ -f /usr/lib/rpm/brp-compress ]; then
      perl -pi.bak -e 's/^COMPRESS=(.*)-n/COMPRESS=$1/' /usr/lib/rpm/brp-compress
      timewait 1
      echo Done.
    else
      echo Failed to find /usr/lib/rpm/brp-compress.
      echo Have you installed the rpm-build package\?
      echo You need to do that first or I cannot do anything.
      exit 1
    fi
    timewait 5
  fi
  # Don't force install of anything on RedHat 5 or CentOS 5 or above
  if grep -q 'release  *[56]' /etc/redhat-release
  then
    echo You are running release 5 of RedHat, or a clone.
    #echo So I will only force the installation of a very few Perl modules.
    timewait 2
    ONFIVE='yes'
  fi
  if grep -iq 'Fedora' /etc/redhat-release
  then
    if grep -q '1[0-9]' /etc/redhat-release
    then
      echo You are running a Fedora 10 or above system.
      #echo So I will only force the installation of a very few Perl modules.
      timewait 2
      ONFIVE='yes'
      ONFEDORATEN='yes'
    else
      echo You are running Fedora 9 or below system.
      #echo But you are running Fedora, so I am going to force the installation
      #echo of the Perl modules that normally require it.
      timewait 2
      ONFIVE='no'
    fi
  fi
fi
export ONFIVE

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
  timewait 10
fi
if grep -qs '%__perl_requires[ 	][ 	]*%{!?nil}' ~/.rpmmacros
then
  echo Good, far-too-clever Perl requirements will be ignored.
else
  echo Adding to the .rpmmacros file in your home directory to stop
  echo RPM trying to be too clever finding Perl requirements.
  echo You can delete it once MailScanner is installed if you want to.
  echo '%__perl_requires %{!?nil}' >> ~/.rpmmacros
  echo
  timewait 10
fi
if grep -qs '%__arch_install_post[ 	][ 	]*%{nil}' ~/.rpmmacros
then
  echo Good, Fedora 8 options will be ignored.
else
  echo Adding to the .rpmmacros file in your home directory to stop
  echo RPM trying to break on Fedora 8.
  echo You can delete it once MailScanner is installed if you want to.
  echo '%__arch_install_post %{nil}' >> ~/.rpmmacros
  echo
  timewait 10
fi
timewait 5

# Process the command-line options
# This is blatantly plagiarised from the typical "./configure" produced by
# "autoconf".  If we need to get more complicated, then we should probably
# migrate towards using "autoconf" itself.  (Hence not optimising this part, to
# preserve resemblance and encourage compability with "autoconf" conventions.)

as_me=`(basename "$0") 2>/dev/null`

ac_init_help=
ignoreperl=
nodeps=
fast=
nomodules=
reinstall=
inturn=
for ac_option
do
  ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`

  case $ac_option in
  ignore-perl)
    ignoreperl=$ac_option ;;

  nodeps)
    nodeps=$ac_option ;;

  reinstall)
    reinstall=$ac_option ;;

  --reinstall)
    reinstall=$ac_option ;;

  fast)
    fast=$ac_option ;;

  --fast)
    fast=$ac_option ;;

  --nomodules)
    nomodules=$ac_option ;;

  nomodules)
    nomodules=$ac_option ;;

  --inturn)
    inturn=$ac_option ;;

  inturn)
    inturn=$ac_option ;;

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

  -h, --help  display this help and exit
  nodeps      ignore dependencies when installing MailScanner
  ignore-perl ignore perl versions check
  fast        do not wait for long during installation
  reinstall   force uninstallation of all Perl modules before install
  inturn      force uninstall of each Perl module immediately before installing
  nomodules   do not install required Perl modules

_ACEOF

fi

test -n "$ac_init_help" && exit 0

# Set variables for later use
IGNORE_PERL=$ignoreperl
NODEPS=$nodeps
FAST=$fast
NOMODULES=$nomodules
REINSTALL=$reinstall
INTURN=$inturn

# Check they don't have 2 Perl installations, this will cause all sorts
# of grief later.
echo
if [ \! "x$IGNORE_PERL" = "xignore-perl" ] ; then
  if [ -x /usr/bin/perl -a -f /usr/local/bin/perl -a -x /usr/local/bin/perl ] ;
  then
    echo You appear to have 2 versions of Perl installed,
    echo the normal one in /usr/bin and one in /usr/local.
    echo This often happens if you have used CPAN to install modules.
    PERL1=`ls -l /usr/bin/perl | awk '{ print $NF }'`
    PERL2=`ls -l /usr/local/bin/perl | awk '{ print $NF }'`
    if [ "x$PERL1" = "x$PERL2" ]; then
      echo Fortunately they both point to the same place, so you are fine.
      sleep 2
    else
      echo I strongly advise you remove all traces of perl from
      echo within /usr/local and then run this script again.
      echo
      echo If you do not want to do that, and really want to continue,
      echo then you will need to run this script as
      echo '        ./install.sh ignore-perl'
      echo
      exit 1
    fi
  else
    echo Good, you appear to only have 1 copy of Perl installed.
  fi
fi
PERL="/usr/bin/perl"

# Check to see if they want to ignore dependencies in the final
# MailScanner RPM install.
if [ \! "x$NODEPS" = "x" ]
then
  NODEPS='--nodeps'
else
  NODEPS=
fi

# Check that they aren't on a RaQ3 with a broken copy of Perl 5.005003.
if [ -d /usr/lib/perl5/5.00503/i386-linux/CORE ]; then
  echo
  echo I think you are running Perl 5.00503.
  echo Ensuring that you have all the header files that are needed
  echo to build HTML-Parser which is used by both MailScanner and
  echo SpamAssassin.

  touch /usr/lib/perl5/5.00503/i386-linux/CORE/opnames.h
  touch /usr/lib/perl5/5.00503/i386-linux/CORE/perlapi.h
  touch /usr/lib/perl5/5.00503/i386-linux/CORE/utf8.h
  touch /usr/lib/perl5/5.00503/i386-linux/CORE/warnings.h
fi

# Check that they aren't missing pod2text but have pod2man.
if [ -x /usr/bin/pod2man -a \! -x /usr/bin/pod2text ] ; then
  echo
  echo You appear to have pod2man but not pod2text.
  echo Creating pod2text for you.
  ln -s pod2man /usr/bin/pod2text
fi

# Check they have the development tools installed on SuSE
if [ -f /etc/SuSE-release -o -f /etc/redhat-release ]; then
  echo
  echo I think you are running on RedHat Linux, Mandriva Linux or SuSE Linux.
  GCC=gcc
  #if [ -f /etc/redhat-release ] && fgrep -q ' 6.' /etc/redhat-release ; then
  #    # RedHat used egcs in RedHat 6 and not gcc
  #    GCC=egcs
  #fi
  if rpm -q binutils glibc-devel $GCC make >/dev/null 2>&1 ; then
    echo Good, you appear to have the basic development tools installed.
    timewait 5
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

echo
echo This script will pause for a few seconds after each major step,
echo so do not worry if it appears to stop for a while.
echo If you want it to stop so you can scroll back through the output
echo then press Ctrl-S to stop the output and Ctrl-Q to start it again.
echo
timewait 10

echo
echo If this fails due to dependency checks, and you wish to ignore
echo these problems, you can run
echo '    ./install.sh nodeps'
timewait 5

echo
echo Setting Perl5 search path
echo
#PERL5LIB=`perl -V | grep site_perl | grep -v config_args | tr -d ' ' | tr '\n' ':'`
#export PERL5LIB
LOCALPERL5LIB=`./getPERLLIB`
export LOCALPERL5LIB

# Work out the architecture we are building for
BUILDARCH=`rpm -q --queryformat='%{ARCH}' perl`
# Fedora Core 3 reports both i386 and x86_64, so use x86_64
if [ $BUILDARCH = 'i386x86_64' -o $BUILDARCH = 'x86_64i386' -o $BUILDARCH = 'x86_64x86_64' ]; then
  BUILDARCH='x86_64'
fi
export BUILDARCH
echo I think your system will build architecture-dependent modules for $BUILDARCH

OLDMSVERSION=`rpm -q --queryformat='%{VERSION}' mailscanner`
OLDMSLEN=`echo $OLDMSVERSION | wc -m`
#echo VERSION = $OLDMSVERSION LENGTH = $OLDMSLEN
# If they are doing a fresh install then start from scratch
if echo "$OLDMSVERSION" | grep -q 'not installed'; then
  # Don't remove old modules on Fedora 10 systems or nothing will build!
  if [ "x$ONFEDORATEN" \!= "xyes" ]; then
    WASOLD=yes
  fi
fi
# If they are upgrading from an old version of MailScanner before 4.76.11
# then insist that we delete all the old RPM packages and install new ones.
if [ -n "$OLDMSVERSION" -a "$OLDMSLEN" -le 15 ]; then
  VONE=`echo $OLDMSVERSION | cut -d. -f1`
  VTWO=`echo $OLDMSVERSION | cut -d. -f2`
  VTHREE=`echo $OLDMSVERSION | cut -d. -f3`
  #echo 1 = $VONE, 2 = $VTWO, 3 = $VTHREE
  if [ "$VONE" -lt 4 ]; then
    WASOLD=yes
  elif [ "$VONE" -eq 4 ]; then
    if [ "$VTWO" -lt 76 ]; then
      WASOLD=yes
    elif [ "$VTWO" -eq 76 ]; then
      if [ "$VTHREE" -lt 11 ]; then
        WASOLD=yes
      fi
    fi
  fi
fi

if [ "x$ONFEDORATEN" = "xyes" ]; then
  # Fedora 10 systems get inturn when they are old
  if [ "x$WASOLD" = "xyes" ]; then
    REINSTALL=yes
    INTURN=inturn
  else
    REINSTALL=
    INTURN=
  fi
else
  # Non-Fedora 10 systems get reinstall when they are old
  if [ "x$WASOLD" = "xyes" ]; then
    REINSTALL=yes
  else
    REINSTALL=
  fi
fi

if [ "x$REINSTALL" = "xyes" ]; then
  if [ "x$INTURN" = "xinturn" ]; then
    echo
    echo Removing each old module I built just before installing the
    echo new version.
    echo
    timewait 5
  else
    echo
    echo Deleting all the old versions of the Perl modules I built,
    echo I will re-install them in a minute.
    echo
    timewait 5

    while read MODNAME MODFILE VERS BUILD ARC FORCE FORCE5
    do
      #if rpm -q --quiet perl-${MODFILE}; then
      if ( rpm -q --queryformat="%{PACKAGER}" perl-${MODFILE} | fgrep -qi mailscanner ); then
        # We built it.
        echo -n Removing perl-${MODFILE}
        rpm -e --nodeps --allmatches perl-${MODFILE} >/dev/null 2>&1
        echo
      fi
    done <<EOF1
$MOD
EOF1
    echo Perl modules I built have been removed...
    sleep 5
  fi
fi
  #echo
  #echo If you want to upgrade your version of Perl, then now is a good time
  #echo to press Ctrl-Z, upgrade everything, and then continue this script
  #echo by running the \"fg\" command.

if [ "x$NOMODULES" = "x" ]; then
  echo
  echo Rebuilding all the Perl RPMs for your version of Perl
  echo
  timewait 5

  while read MODNAME MODFILE VERS BUILD ARC FORCE FORCE5
  do
    # Reset the architecture to what it really is
    if [ "x$ARC" = "xarch" ]; then
      ARC=$BUILDARCH
    fi

    # If the module version is already installed, go onto the next one
    # (unless it is MIME-tools which is always rebuilt.
    if [ "x$MODNAME" = "xArchive::Zip" -o "x$MODNAME" = "xTest::Simple" -o "x$MODNAME" = "xTest::Harness" ]; then
      OLDPERL5LIB="$PERL5LIB"
      PERL5LIB=
      export PERL5LIB
    else
      PERL5LIB="$LOCALPERL5LIB"
      export PERL5LIB
    fi

    # If we're reinstalling on Fedora 10 then just delete each
    # module in turn before installing new one.
    # Also do it if they gave us --inturn.
    if [ "x$INTURN" = "xinturn" ]; then
      #if [ "x$MODFILE" = "xExtUtils-MakeMaker" ]; then
      #  echo Cannot rebuild $MODFILE without $MODFILE being there
      #else
        #if rpm -q --quiet perl-${MODFILE}; then
        if ( rpm -q --queryformat="%{PACKAGER}" perl-${MODFILE} | fgrep -qi mailscanner ); then
          # We built it.
          echo -n Removing perl-${MODFILE}
          rpm -e --nodeps --allmatches perl-${MODFILE} >/dev/null 2>&1
          echo
        fi
      #fi
    fi

    BUILDTHIS=yes
    # If this Perl version is installed, don't rebuild it
    if ./CheckModuleVersion ${MODNAME} ${VERS} 2>/dev/null ; then
      # But there is a list of exceptions
      if [ "x$MODFILE" \!= "xExtUtils-MakeMaker" ]; then
        BUILDTHIS=no
      fi
    fi
    # If this RPM is installed, don't rebuild it
    if rpm -q perl-${MODFILE}-${VERS}-${BUILD} >/dev/null 2>&1 ; then
      BUILDTHIS=no
    fi

    # Do we want to rebuild it?
    if [ "x$BUILDTHIS" = "xno" ]; then
      echo Oh good, module ${MODFILE} version ${VERS} is already installed.
      echo
      timewait 5
    else
      FILEPREFIX=perl-${MODFILE}-${VERS}-${BUILD}
      ## Need to install my customised version of MIME-Base64
      #if [ "x${MODFILE}" = "xMIME-Base64" ]; then
      #  FILEPREFIX=MailScanner-${FILEPREFIX}
      #fi
      echo Attempting to build and install ${FILEPREFIX}
      if [ -f ${FILEPREFIX}.src.rpm ]; then
        if [ "x${MODFILE}" = "xCompress-Zlib" -o "x${MODFILE}" = "xTest-Harness" -o "x${MODFILE}" = "xTest-Simple" ]; then
          echo Detected Compress-Zlib, building appropriately...
          PERL5LIB= $RPMBUILD --rebuild ${FILEPREFIX}.src.rpm
        elif [ "x${MODFILE}" = "xNet-DNS" ]; then
          # Net-DNS asks a question about live tests, don't want them.
          yes n | $RPMBUILD --rebuild ${FILEPREFIX}.src.rpm
        else
          $RPMBUILD --rebuild ${FILEPREFIX}.src.rpm
        fi
        timewait 10
        echo
        echo
        echo
      else
        echo Missing file ${FILEPREFIX}.src.rpm. Are you in the right directory\?
        timewait 10
        echo
      fi
      if [ -f ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm ]; then
        echo
        echo Do not worry too much about errors from the next command.
        echo It is quite likely that some of the Perl modules are
        echo already installed on your system.
        echo
        echo The important ones are HTML-Parser and MIME-tools.
        echo
        timewait 10

        if [ -f /etc/SuSE-release -a "x${MODFILE}" = "xMIME-tools" ];
        then
          echo As you are running SuSE, I have to force installation of
          echo the MIME-tools package to ensure you have all the security
          echo patches applied.
          rpm -Uvh --force ${NODEPS} ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm
        elif [ "x${FORCE}${ONFIVE}" = "xyesno" -o "x${FORCE5}${ONFIVE}" = "xyesyes" ]; then
          echo I have to force installation of ${MODFILE}. Sorry.
          rpm -Uvh --force ${NODEPS} ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm
        else
          rpm -Uvh ${NODEPS} ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm
        fi
        timewait 10
        echo
        echo
        echo
      else
        echo Missing file ${RPMROOT}/RPMS/${ARC}/${FILEPREFIX}.${ARC}.rpm.
        echo Maybe it did not build correctly\?
        timewait 10
        echo
      fi
      PERL5LIB="$OLDPERL5LIB"
      export PERL5LIB
    fi
  done <<EOF2
$MOD
EOF2
else
  echo
  echo Skipping installing required Perl modules, at your request.
  echo
  timewait 5
fi

# Undo the temporary change to /usr/lib/rpm/perl.req
if [ -f /usr/lib/rpm/perl.req.MSoriginal ];
then
  mv -f /usr/lib/rpm/perl.req.MSoriginal /usr/lib/rpm/perl.req
fi

echo
echo Installing tnef decoder
echo

TNEFARCH=`rpm -q --queryformat='%{ARCH}' tnef`
# Fedora Core 3 reports both i386 and x86_64, so use x86_64
if [ "$TNEFARCH" = 'i386x86_64' -o "$TNEFARCH" = 'x86_64i386' ]; then
  TNEFARCH='x86_64'
fi
export TNEFARCH

if [ "$BUILDARCH" = 'x86_64' -a "$TNEFARCH" = 'i386' ]; then
  # Have a i386 tnef installed, but should be x86_64,
  # so remove the old tnef before we install the new run to stop
  # upgrade errors.
  echo Removing old i386 tnef to replace it with x86_64 one.
  rpm -e --nodeps tnef
fi

# Crazy Fedora 11 produces i586 !
if [ "$BUILDARCH" = 'i586' -o "$BUILDARCH" = 'i686' ]; then
  BUILDARCH=i386
fi

rpm -Uvh tnef*.${BUILDARCH}.rpm

echo
echo Now to install MailScanner itself.
echo
echo NOTE: If you get lots of errors here, run the install.sh script
echo NOTE: again with the command \"./install.sh nodeps\"
echo
timewait 10

if [ -d /usr/local/MailScanner ] ; then
  echo
  echo
  echo Please remember to kill all the old mailscanner version 3
  echo processes before you start the new version.
  echo
fi

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

sleep 5
echo '----------------------------------------------------------'
echo 'Please buy the MailScanner book from www.mailscanner.info!'
echo 'It is a very useful administration guide and introduction'
echo 'to MailScanner. All the proceeds go directly to making'
echo 'MailScanner a better supported package than it is today.'
echo

) 2>&1 | tee install.log

