%define version 4.00.0a9
%define name    mailscanner

Name:        %{name}
Version:     %{version}
Release: NonRedHat.1
Summary: E-Mail Gateway Virus Scanner and Spam Detector
Group: System Environment/Daemons
Copyright: distributable
Vendor: Electronics and Computer Science, University of Southampton
Packager: Julian Field <mailscanner@ecs.soton.ac.uk>
URL: http://www.mailscanner.info/
Requires: sendmail, perl, wget, gcc, make, unzip, gcc, cpp, binutils, glibc-devel, kernel-headers
BuildRoot:   %{_tmppath}/%{name}-root
#Source: autoupdate

%description
MailScanner is a freely distributable E-Mail gateway virus scanner
and spam detector. It uses sendmail or Exim as its basis, and a choice of
10 commercial virus scanning engines to do the actual virus scanning.
It can decode and scan attachments intended solely for Microsoft Outlook
users (MS-TNEF). If possible, it will disinfect infected documents and
deliver them automatically. It also has features which protect it against
Denial Of Service attacks.

After installation, you must install one of the supported commercial anti-
virus packages.

%prep
# Nothing to do here as no source code or compiling is involved.

%build
# Nothing to do here as no source code or compiling is involved.

%install
CVS_ROOT=/root/unstable/mailscanner
SRC_DIR=${CVS_ROOT}/mailscanner
export CVS_ROOT
export SRC_DIR

mkdir -p $RPM_BUILD_ROOT
mkdir -p ${RPM_BUILD_ROOT}%{_sysconfdir}/rc.d/init.d
mkdir -p ${RPM_BUILD_ROOT}/etc/cron.hourly
mkdir -p ${RPM_BUILD_ROOT}/etc/cron.daily
mkdir -p ${RPM_BUILD_ROOT}/etc/sysconfig
mkdir -p ${RPM_BUILD_ROOT}/opt/MailScanner
mkdir -p ${RPM_BUILD_ROOT}/usr/sbin
mkdir -p ${RPM_BUILD_ROOT}/usr/sbin/MailScanner
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/rules
mkdir -p ${RPM_BUILD_ROOT}/usr/share/MailScanner/reports
mkdir -p ${RPM_BUILD_ROOT}/usr/share/MailScanner/reports/de
mkdir -p ${RPM_BUILD_ROOT}/usr/share/MailScanner/reports/en
mkdir -p ${RPM_BUILD_ROOT}/opt/MailScanner/var
mkdir -p ${RPM_BUILD_ROOT}/var/spool/MailScanner
mkdir -p ${RPM_BUILD_ROOT}/var/spool/MailScanner/incoming
mkdir -p ${RPM_BUILD_ROOT}/var/spool/MailScanner/quarantine
mkdir -p ${RPM_BUILD_ROOT}/var/spool/mqueue.in
mkdir -p ${RPM_BUILD_ROOT}/var/spool/mqueue
mkdir -p ${RPM_BUILD_ROOT}/tmp
mkdir -p ${RPM_BUILD_ROOT}/tmp/MailScanner.perl.modules
mkdir -p ${RPM_BUILD_ROOT}/usr/share/man/man8

# /etc/rc.d/init.d
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/MailScanner.init       ${RPM_BUILD_ROOT}%{_sysconfdir}/rc.d/init.d/MailScanner
# /etc/sysconfig
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/MailScanner.opts       ${RPM_BUILD_ROOT}/etc/sysconfig/MailScanner
# /etc/cron.*
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/check_MailScanner.cron ${RPM_BUILD_ROOT}/etc/cron.hourly/check_MailScanner
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/Sophos.autoupdate.cron ${RPM_BUILD_ROOT}/etc/cron.daily/Sophos.autoupdate
# man page
gzip -c ${CVS_ROOT}/RPM.files/Non-RedHat/MailScanner.8 > ${RPM_BUILD_ROOT}/usr/share/man/man8/MailScanner.8.gz
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/COPYING     ${RPM_BUILD_ROOT}/opt/MailScanner

# /usr/sbin
install -m 755 -g root -o root ${SRC_DIR}/bin/mailscanner ${RPM_BUILD_ROOT}/usr/sbin
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/check_MailScanner.linux ${RPM_BUILD_ROOT}/usr/sbin/check_MailScanner
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/tnef.linux ${RPM_BUILD_ROOT}/usr/sbin/tnef
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/CheckModuleVersion ${RPM_BUILD_ROOT}/usr/sbin
install -m 755 -g root -o root ${CVS_ROOT}/RPM.files/Non-RedHat/Sophos.install ${RPM_BUILD_ROOT}/usr/sbin
install -m 644 -g root -o root ${SRC_DIR}/bin/MailScanner.pm ${RPM_BUILD_ROOT}/usr/sbin
rm -f ${RPM_BUILD_ROOT}/usr/sbin/check_mailscanner
ln -sf check_MailScanner ${RPM_BUILD_ROOT}/usr/sbin/check_mailscanner


while read f
do
  install -m 755 -g root -o root ${SRC_DIR}/etc/$f ${RPM_BUILD_ROOT}/etc/MailScanner
done << EOF
filename.rules.conf
mailscanner.conf
spam.assassin.prefs.conf
spam.lists.conf
virus.scanners.conf
EOF

while read f
do
  install -m 755 -g root -o root ${SRC_DIR}/etc/rules/$f ${RPM_BUILD_ROOT}/etc/MailScanner/rules
done << EOF
EXAMPLES
README
spam.whitelist.rules
EOF

while read f
do
  install -m 755 -g root -o root ${SRC_DIR}/etc/reports/en/$f ${RPM_BUILD_ROOT}/usr/share/MailScanner/reports/en
done << EOF
deleted.filename.message.txt
deleted.virus.message.txt
disinfected.report.txt
inline.sig.html
inline.sig.txt
inline.warning.html
inline.warning.txt
sender.error.report.txt
sender.filename.report.txt
sender.spam.rbl.report.txt
sender.spam.report.txt
sender.spam.sa.report.txt
sender.virus.report.txt
stored.filename.message.txt
stored.virus.message.txt
EOF

while read f
do
  install -m 755 -g root -o root ${SRC_DIR}/etc/reports/de/$f ${RPM_BUILD_ROOT}/usr/share/MailScanner/reports/de
done << EOF
deleted.filename.message.txt
deleted.virus.message.txt
disinfected.report.txt
inline.sig.html
inline.sig.txt
inline.warning.html
inline.warning.txt
README.1ST
sender.error.report.txt
sender.filename.report.txt
sender.spam.rbl.report.txt
sender.spam.report.txt
sender.spam.sa.report.txt
sender.virus.report.txt
stored.filename.message.txt
stored.virus.message.txt
EOF

while read f
do
  install -m 755 -g root -o root ${SRC_DIR}/lib/$f ${RPM_BUILD_ROOT}/var/lib/MailScanner
done << EOF
f-prot-autoupdate
f-prot-wrapper
f-secure-wrapper
kaspersky.prf
kaspersky-wrapper
mcafee-autoupdate
mcafee-wrapper
panda-wrapper
rav-autoupdate
rav-wrapper
sophos-autoupdate
sophos-wrapper
EOF

while read f
do
  install -m 755 -g root -o root ${SRC_DIR}/bin/MailScanner/$f ${RPM_BUILD_ROOT}/usr/sbin/MailScanner
done << EOF
ConfigDefs.pl
Config.pm
Exim.pm
Lock.pm
Log.pm
Mail.pm
MessageBatch.pm
Message.pm
Quarantine.pm
Queue.pm
RBLs.pm
SA.pm
Sendmail.pm
SMDiskStore.pm
SweepContent.pm
SweepOther.pm
SweepViruses.pm
SystemDefs.pm
TNEF.pm
WorkArea.pm
EOF

# Now for the Perl modules we build at install time
while read f
do
  install -m 644 -g root -o root ${CVS_ROOT}/RPM.files/perl-module-src/$f ${RPM_BUILD_ROOT}/tmp/MailScanner.perl.modules
done << EOF
Convert-TNEF-0.17.tar.gz
File-Spec-0.82.tar.gz
File-Temp-0.12.tar.gz
HTML-Parser-3.26.tar.gz
HTML-Tagset-3.03.tar.gz
IO-stringy-2.108.tar.gz
MailTools-1.50.tar.gz
MIME-Base64-2.12.tar.gz
MIME-tools-5.411.tar.gz
mime-tools-patch1.txt
mime-tools-patch2.txt
mime-tools-patch3.txt
EOF


%pre
# Do all this before copying in any files.

%post
chkconfig --add MailScanner
/etc/rc.d/init.d/sendmail stop
chkconfig sendmail off
chkconfig --level 2345 sendmail off
rm -f /etc/rc.d/rc2.d/S30sendmail

# Next do Perl modules
echo MailScanner: About to install Perl modules you do not already have
sleep 1
MODDIR=/tmp/MailScanner.perl.modules
while read modname modver tarball
do
  if /usr/local/MailScanner/bin/CheckModuleVersion $modname $modver
  then
    echo MailScanner: Module $modname $modver already installed
  else
    echo MailScanner: Installing Perl Module $modname
    cd $MODDIR
    tar xzf ${tarball}.tar.gz
    if [ "$modname" = 'MIME::Tools' ]; then
      echo '==== Patching MIME::Tools module (see Bugtraq)'
      patch -p0 < mime-tools-patch1.txt
      echo '==== Applying 2nd patch to MIME::Tools module (see Bugtraq)'
      patch -p0 < mime-tools-patch2.txt
      echo '==== Applying 3rd patch to MIME::Tools module (see Bugtraq)'
      patch -p0 < mime-tools-patch3.txt
    fi
    cd $tarball
    perl Makefile.PL
    make
    make test
    make install
    cd $MODDIR
    rm -rf $tarball
  fi
done <<PERLMODLIST
IO::Stringy   2.108  IO-stringy-2.108
MIME::Base64  2.12   MIME-Base64-2.12
IsABundle     1.46   MailTools-1.50
File::Spec    0.82   File-Spec-0.82
MIME::Tools   5.420  MIME-tools-5.411
File::Temp    0.12   File-Temp-0.12
Convert::TNEF 0.17   Convert-TNEF-0.17
HTML::Tagset  3.03   HTML-Tagset-3.03
HTML::Parser  3.26   HTML-Parser-3.26
PERLMODLIST
# Yes, I know MIME::Tools searches for 5.420 then installs 5.411a. This
# is so that it always re-installs as there is no way to detect whether
# you have the patched version or not.

echo MailScanner: Perl modules installed
echo
echo ==== You now need to download '(or get off CD)' the latest Sophos virus
echo ==== virus scanner. Be sure to get the version for Linux with \'libc6\'.
echo ==== Copy this onto your system, change into the directory where you have
echo ==== copied it, and type the command
echo '====     /usr/sbin/Sophos.install'
echo
echo ==== Then run the command
echo '====     /etc/rc.d/init.d/MailScanner start'
echo ==== and it should all start working...
echo

# Check for old McAfee installation
if [ -d /usr/local/mcafee ]; then
  echo '****'
  echo '**** Note: the correct installation directory for McAfee'
  echo '**** has changed from /usr/local/mcafee and /usr/local/mcafee/dat'
  echo '**** to /usr/local/uvscan. Please update your system and then run'
  echo '****        /usr/local/uvscan/mcafeewrapper'
  echo '**** to test it.'
  echo '****'
fi

# Check to see if mailscanner.conf has been customised
if [ -e /etc/MailScanner/mailscanner.conf.rpmnew ]; then
  echo '****'
  echo '**** Please look for any new options in mailscanner.conf.rpmnew'
  echo '**** and update your mailscanner.conf file appropriately.'
  echo '****'
fi

%preun
if [ $1 = 0 ]; then
    # We are being deleted, not upgraded
    /etc/rc.d/init.d/MailScanner stop >/dev/null 2>&1
    chkconfig MailScanner off
    chkconfig --del MailScanner
    chkconfig sendmail on
    /etc/rc.d/init.d/sendmail start >/dev/null 2>&1
fi
exit 0

%postun
if [ "$1" -ge "1" ]; then
    # We are being upgraded or replaced, not deleted
    /etc/rc.d/init.d/MailScanner restart >/dev/null 2>&1
fi
exit 0

%files

%dir /var/spool/mqueue.in
%dir /var/spool/MailScanner/incoming
%dir /var/spool/MailScanner/quarantine
%dir /opt/MailScanner/var

/%{_sysconfdir}/rc.d/init.d/MailScanner
%config(noreplace) /etc/sysconfig/MailScanner
/etc/cron.hourly/check_MailScanner
/etc/cron.daily/Sophos.autoupdate

%doc /usr/share/man/man8/MailScanner.8.gz
%doc /opt/MailScanner/COPYING

/usr/sbin/mailscanner
/usr/sbin/check_mailscanner
/usr/sbin/check_MailScanner
/usr/sbin/tnef
/usr/sbin/CheckModuleVersion
/usr/sbin/Sophos.install
/usr/sbin/MailScanner.pm


/tmp/MailScanner.perl.modules/Convert-TNEF-0.17.tar.gz
/tmp/MailScanner.perl.modules/File-Spec-0.82.tar.gz
/tmp/MailScanner.perl.modules/File-Temp-0.12.tar.gz
/tmp/MailScanner.perl.modules/HTML-Parser-3.26.tar.gz
/tmp/MailScanner.perl.modules/HTML-Tagset-3.03.tar.gz
/tmp/MailScanner.perl.modules/IO-stringy-2.108.tar.gz
/tmp/MailScanner.perl.modules/MailTools-1.50.tar.gz
/tmp/MailScanner.perl.modules/MIME-Base64-2.12.tar.gz
/tmp/MailScanner.perl.modules/MIME-tools-5.411.tar.gz
/tmp/MailScanner.perl.modules/mime-tools-patch1.txt
/tmp/MailScanner.perl.modules/mime-tools-patch2.txt
/tmp/MailScanner.perl.modules/mime-tools-patch3.txt

/var/lib/MailScanner
/usr/sbin/MailScanner

%config(noreplace) /etc/MailScanner/filename.rules.conf
%config(noreplace) /etc/MailScanner/mailscanner.conf
%config(noreplace) /etc/MailScanner/spam.assassin.prefs.conf
%config(noreplace) /etc/MailScanner/spam.lists.conf
%config(noreplace) /etc/MailScanner/virus.scanners.conf
/etc/MailScanner/rules/EXAMPLES
/etc/MailScanner/rules/README
%config(noreplace) /etc/MailScanner/rules/spam.whitelist.rules
%config(noreplace) /usr/share/MailScanner/reports/en/deleted.filename.message.txt
%config(noreplace) /usr/share/MailScanner/reports/en/deleted.virus.message.txt
%config(noreplace) /usr/share/MailScanner/reports/en/disinfected.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/inline.sig.html
%config(noreplace) /usr/share/MailScanner/reports/en/inline.sig.txt
%config(noreplace) /usr/share/MailScanner/reports/en/inline.warning.html
%config(noreplace) /usr/share/MailScanner/reports/en/inline.warning.txt
%config(noreplace) /usr/share/MailScanner/reports/en/sender.error.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/sender.filename.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/sender.spam.rbl.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/sender.spam.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/sender.spam.sa.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/sender.virus.report.txt
%config(noreplace) /usr/share/MailScanner/reports/en/stored.filename.message.txt
%config(noreplace) /usr/share/MailScanner/reports/en/stored.virus.message.txt
%config(noreplace) /usr/share/MailScanner/reports/de/deleted.filename.message.txt
%config(noreplace) /usr/share/MailScanner/reports/de/deleted.virus.message.txt
%config(noreplace) /usr/share/MailScanner/reports/de/disinfected.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/inline.sig.html
%config(noreplace) /usr/share/MailScanner/reports/de/inline.sig.txt
%config(noreplace) /usr/share/MailScanner/reports/de/inline.warning.html
%config(noreplace) /usr/share/MailScanner/reports/de/inline.warning.txt
/usr/share/MailScanner/reports/de/README.1ST
%config(noreplace) /usr/share/MailScanner/reports/de/sender.error.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/sender.filename.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/sender.spam.rbl.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/sender.spam.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/sender.spam.sa.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/sender.virus.report.txt
%config(noreplace) /usr/share/MailScanner/reports/de/stored.filename.message.txt
%config(noreplace) /usr/share/MailScanner/reports/de/stored.virus.message.txt


#%doc /root/stable/mailscanner/docs

