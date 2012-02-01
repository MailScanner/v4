#!/bin/sh

CLAMAVVERSION=0.96.5
export CLAMAVVERSION
LDSOCONF=/etc/ld.so.conf

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
# Now see if they are running on Solaris
ARCHITECT=other
if uname -a | fgrep "SunOS" >/dev/null ; then
  ARCHITECT=solaris
fi
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
. ./functions.sh

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
echo Thinking about installing ClamAV
echo
sleep 2

echo 'There are 2 recommended ways of installing ClamAV, depending on'
echo 'various factors.'
echo 'If you want to use MailScanners support for Clamd (virus-scanning'
echo 'daemon) then I recommend you cancel this script now (press Ctrl-C)'
echo 'and install the RPMs for clamav, clamav-db and clamd from'
echo '     http://packages.sw.be/clamav/'
echo 'Then re-run this script and tell me that clamscan is installed in'
echo '/usr/bin. This will set up your virus.scanners.conf file for you.'
echo
echo 'Otherwise you probably want me to install ClamAV now. So answer y.'
echo
echo -n 'Do you want me to install ClamAV for you [y or n, default is y] ? '
read CLAMYN
if [ "x$CLAMYN" = "x" ]; then
  CLAMYN="y"
fi

# This is used to set their virus.scanners.conf file later
CLAMPATH='/usr/local'
CLAMPRINT='/usr/local'

if [ "$CLAMYN" = "n" ]; then
  # Don't install ClamAV, have to ask them where their ClamAV is installed.
  # As we're not installing, they are probably using an RPM which probably
  # puts everything under /usr.
  CLAMPATH='/usr'

  # Ask the user for the install path of ClamAV
  echo 'I need to know where ClamAV is installed.'
  echo -n 'Where is clamscan? [default is '$CLAMPATH'/bin] '
  read CLAMIN
  if [ "x$CLAMIN" = "x" ]; then
    CLAMIN=$CLAMPATH
  fi
  #echo Before chopping, CLAMIN is $CLAMIN
  CLAMIN=`echo $CLAMIN | sed -e 's/^[ 	]*//'`
  #echo Without spaces, CLAMIN is $CLAMIN
  CLAMIN=`echo $CLAMIN | sed -e 's/\/clamscan *$//'`
  #echo Without clamscan, CLAMIN is $CLAMIN
  CLAMIN=`echo $CLAMIN | sed -e 's/\/bin *$//'`
  #echo Without bin, CLAMIN is $CLAMIN
  CLAMPRINT=$CLAMIN
  CLAMIN=`echo $CLAMIN | sed -e 's/\//\\\\\//g'`
  #echo With escapes, CLAMIN is $CLAMIN

  CLAMPATH=$CLAMIN

else

  # We are installing ClamAV for them, so know it will be into /usr/local

  # But it could be in lib or lib64
  CLAMLIB=lib
  if ( arch | fgrep -q 64 ) then
    CLAMLIB=lib64
  fi

  sleep 2
  echo Do not worry about warnings or errors from the next 3 commands
  mkdir -p $CLAMPRINT/$CLAMLIB
  groupadd clamav
  useradd -m -c 'ClamAV User' -d /home/clamav -g clamav clamav
  sleep 2
  echo You can start worrying about errors again now
  sleep 2
  unpackarchive $TMPBUILDDIR ${PERL_DIR}/clamav-${CLAMAVVERSION}.tar.gz
    (
      cd ${TMPBUILDDIR}/clamav-${CLAMAVVERSION}
      echo
      echo About to build the ClamAV virus scanner
      ./configure --disable-zlib-vcheck
      sleep 5
      make
      sleep 5
      make install
      echo
      echo 'Enabling ClamAV auto-updates'
      if [ $CLAMPRINT = "/usr" ]; then
        CLAMETC=/etc
      else
        CLAMETC=$CLAMPRINT/etc
      fi
      for F in clamd.conf freshclam.conf
      do
        G="${CLAMETC}/$F"
        export G
        if [ -f "$G" ]; then
          perl -pi.bak -e 's/Example/#Example/i;s/^\s*PhishingRestrictedScan/#PhishingRestrictedScan/i;' $G
        fi
      done
    )
fi

# Guess where virus.scanners.conf is, and set the path to clam in there.
FOUNDIT=no
for VSWHERE in /opt/MailScanner/etc /etc/MailScanner
do
  if [ -f $VSWHERE/virus.scanners.conf ]; then
    echo Setting ClamAV location in $VSWHERE/virus.scanners.conf
    perl -pi.bak -e 's#^(clam(d|av)\s+\S+\s+)\S+.*$#$1'"$CLAMPATH"'#;' $VSWHERE/virus.scanners.conf
    FOUNDIT=yes
  fi
done

if [ $FOUNDIT = "no" ]; then
  echo
  echo '*** IMPORTANT ***'
  sleep 2
  echo I could not find your MailScanner virus.scanners.conf file.
  echo Please locate the file yourself and edit the clamav and clamd lines in it.
  echo On those 2 lines, the path at the end of each line needs to be $CLAMPRINT.
  sleep 10
fi

if [ -f $LDSOCONF ] ; then
  if fgrep -q $CLAMPRINT'/'$CLAMLIB $LDSOCONF ; then
    echo Good, your $LDSOCONF file looks okay.
  else
    echo I am adding $CLAMPRINT/$CLAMLIB to your $LDSOCONF file so that
    echo the ClamAV library can be found by the clamavmodule and
    echo clamav virus scanners.
    echo $CLAMPRINT/$CLAMLIB >> $LDSOCONF
  fi
  echo Refreshing run-time linker cache...
  /sbin/ldconfig
  sleep 2
else
  echo You may need to add $CLAMPRINT/$CLAMLIB to the directories searched
  echo for run-time libraries. Read the man pages for ld.so and/or ldd.
  echo The symptom will be that the testing stage of the Mail::ClamAV
  echo Perl module fails completely.
  sleep 5
fi


echo
echo Rebuilding all the Perl modules for your version of Perl
echo
sleep 2

while read MODNAME MODFILE CHECKVERS FILEVERS BUILD TEST ARC PATCHSFX
do
  # If the module version is already installed, go onto the next one
  # (unless it is MIME-tools which is always rebuilt.
  if $PERL ./CheckModuleVersion ${MODNAME} ${CHECKVERS} 2>/dev/null ; then
    echo Oh good, module ${MODNAME} version ${FILEVERS} is already installed.
    echo
    sleep 2
  else
    perlinstmod
  fi
done << EOF
Digest		Digest		1.15	1.15	1	yes	noarch
Text::Balanced	Text-Balanced	1.98	1.98	1	yes	noarch
Digest::MD5	Digest-MD5	2.36	2.36	1	yes	noarch
Parse::RecDescent Parse-RecDescent 1.94	1.94	1	yes	noarch
Inline		Inline		0.44	0.44	1	yes	noarch
Test::Harness	Test-Harness	2.56	2.56	1	yes	noarch
Test::Simple	Test-Simple	0.70	0.70	1	yes	noarch
Mail::ClamAV	Mail-ClamAV	0.29	0.29	1	yes	noarch
DB_File		DB_File		1.814	1.814	1	yes	noarch
Digest::SHA	Digest-SHA	5.48	5.48	1	yes	noarch
Digest::SHA1	Digest-SHA1	2.10	2.10	1	yes	noarch
Net::CIDR::Lite	Net-CIDR-Lite	0.20	0.20	1	yes	noarch
Test::Manifest  Test-Manifest   0.95	0.95    1       yes     noarch
HTML::Parser	HTML-Parser	3.56	3.56	1	yes	noarch
Business::ISBN::Data	Business-ISBN-Data 1.10	1.10 1	yes	noarch
Business::ISBN  Business-ISBN   1.82	1.82    1       yes     noarch
Sys::Hostname::Long	Sys-Hostname-Long 1.4	1.4	1	yes	noarch
Digest::HMAC	Digest-HMAC	1.01	1.01	1	yes	noarch
Net::IP		Net-IP		1.25	1.25	1	yes	noarch
YAML		YAML		0.62	0.62	1	yes	noarch
ExtUtils::CBuilder ExtUtils-CBuilder 0.18 0.18	1	yes	noarch
ExtUtils::ParseXS ExtUtils-ParseXS 2.18 2.18	1	yes	noarch
version		version		0.7203	0.7203	1	yes	noarch
Module::Build	Module-Build	0.2808	0.2808	1	yes	noarch
Net::DNS	Net-DNS		0.62	0.62	1	no	noarch
Net::DNS::Resolver::Programmable Net-DNS-Resolver-Programmable 0.002.2 0.002.2 1 yes noarch
Error		Error		0.17008	0.17008	1	yes	noarch
NetAddr::IP	NetAddr-IP	4.004	4.004	1	yes	noarch
URI		URI		1.35	1.35	1	yes	noarch
IP::Country	IP-Country	2.21	2.21	1	yes	noarch
IO::Zlib	IO-Zlib		1.04	1.04	1	yes	noarch
IO::String	IO-String	1.08	1.08	1	yes	noarch
Socket6		Socket6		0.23	0.23	1	yes	noarch
IO::Socket::INET6	IO-Socket-INET6	2.57	2.57	1	yes	noarch
Archive::Tar	Archive-Tar	1.29	1.29	1	yes	noarch
Data::Dump	Data-Dump	1.08	1.08	1	yes	noarch
Encode::Detect	Encode-Detect	1.00	1.00	1	yes	noarch
Mail::SPF	Mail-SPF	2.004	2.004	1	yes	noarch
Crypt::OpenSSL::Random	Crypt-OpenSSL-Random	0.04	0.04	1	yes	noarch
Crypt::OpenSSL::RSA	Crypt-OpenSSL-RSA	0.26	0.26	1	yes	noarch
Mail::DKIM	Mail-DKIM	0.37	0.37	1	yes	noarch
libnet		libnet		1.22	1.22	1	yes	noarch
libwww-perl	libwww-perl	5.810	5.810	1	yes	noarch
Mail::SpamAssassin Mail-SpamAssassin 3.003001	3.3.1	1	yes	noarch
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

echo 'Setting a soft-link from spam.assassin.prefs.conf into the SpamAssassin'
echo 'site rules directory.'
echo 'spam.assassin.prefs.conf is read directly by the SpamAssassin startup'
echo 'code, so make sure you have a link from the site_rules directory to'
echo 'this file in your MailScanner/etc directory.'
sleep 10

SADIR=`$PERL -MMail::SpamAssassin -e 'print Mail::SpamAssassin->new->first_existing_path(@Mail::SpamAssassin::site_rules_path)' 2>/dev/null`

if [ "x$SADIR" = "x" ]; then
  echo 'Perl could not find your SpamAssassin installation.'
  echo 'Strange, I just installed it.'
  echo 'You should fix this!'
  sleep 10
else
  echo Good, SpamAssassin site rules found in \"${SADIR}\"
  if [ \! -f ${SADIR}/mailscanner.cf ]; then
   if [ -d /etc/MailScanner ]; then
    ln -s -f /etc/MailScanner/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    echo Good, the link was created to /etc/MailScanner
   elif [ -d /opt/MailScanner/etc ]; then
    ln -s -f /opt/MailScanner/etc/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    echo Good, the link was created to /opt/MailScanner/etc
   elif [ -d /usr/local/MailScanner/etc ]; then
    ln -s -f /usr/local/MailScanner/etc/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
    echo Good, the link was created to /usr/local/MailScanner/etc
   elif [ -d /usr/local/etc/MailScanner ]; then
    ln -s -f /usr/local/etc/MailScanner/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
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
fi
echo

echo Making backup of pre files to /tmp/backup.pre.$$.tar
cd $SADIR
tar cf /tmp/backup.pre.$$.tar *pre

# Save their old init.pre and move the new one into place
for F in v330.pre v320.pre v310.pre init.pre
do
  # Print final info for the user
  if [ -f /etc/mail/spamassassin/$F ]; then
    echo 'Now go and edit the file /etc/mail/spamassassin/'$F
    echo 'You need to uncomment (remove the #) the loadplugin lines for DCC.'
  else
    echo 'Now go and find your v310.pre and v320.pre files,
    echo 'which may well be in the /etc/mail/spamassassin directory.
    echo You need to save a copy of your old $F file and rename
    echo the $F file to v320.pre.
    echo
    echo "You then need to edit the new $F file and uncomment"
    echo '(remove the #) the loadplugin lines for DCC.'
  fi

  PRE=/etc/mail/spamassassin/$F
  if [ -f $PRE ]; then
    echo
    echo "I am adding up to 5 more loadplugin lines to $F"
    echo 'to add the missing plugins for RelayCountry, SPF, Razor2, DKIM and URIDNSBL.'
    for P in RelayCountry SPF URIDNSBL Razor2 DKIM # ASN
    do
      if grep -q '^loadplugin  *Mail::SpamAssassin::Plugin::'$P $PRE; then
        echo Loading plugin $P is already done.
      else
        echo Added plugin $P.
        echo 'loadplugin Mail::SpamAssassin::Plugin::'$P >> $PRE
      fi
    done
  else
    echo
    echo 'Also add these lines to the end of it:'
    echo 'loadplugin Mail::SpamAssassin::Plugin::RelayCountry'
    echo 'loadplugin Mail::SpamAssassin::Plugin::SPF'
    echo 'loadplugin Mail::SpamAssassin::Plugin::URIDNSBL'
    echo 'loadplugin Mail::SpamAssassin::Plugin::Razor2'
    echo 'loadplugin Mail::SpamAssassin::Plugin::DKIM'
    #echo 'loadplugin Mail::SpamAssassin::Plugin::ASN'
  fi
done

echo
echo Make sure your MailScanner.conf says \"Use SpamAssassin = yes\"
echo
echo 'Now you need to install:'
echo '1) Razor-agents-sdk and Razor2 from http://razor.sourceforge.net/ and'
echo '2) DCC from http://www.rhyolite.com/anti-spam/dcc/ and'
#echo '3) Rules_Du_Jour from http://www.fsl.com/support'
echo

update_sa

echo

