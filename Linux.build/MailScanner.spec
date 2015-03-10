Name: mailscanner
Version: 3.21
Release: 1
Summary: E-Mail Gateway Virus Scanner and Spam Detector
Group: System Environment/Daemons
Copyright: distributable
#Distribution: none
#Icon: none
Vendor: Electronics and Computer Science, University of Southampton
Packager: Julian Field <mailscanner@ecs.soton.ac.uk>
URL: http://www.mailscanner.info/
Requires: sendmail, perl, wget, gcc, make, unzip, gcc, cpp, binutils, glibc-devel, kernel-headers
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
# Nothing to do here as no source code or compiling is involved.

%pre
# Do all this before copying in any files.
#if [ -d /usr/local/MailScanner/etc ]; then
#  cd /usr/local/MailScanner/etc
#  for F in deleted.filename.message.txt deleted.virus.message.txt disinfected.report.txt domains.to.scan.conf filename.rules.conf localdomains.conf mailscanner.conf sender.error.report.txt sender.filename.report.txt sender.virus.report.txt spam.actions.conf spam.assassin.prefs.conf spam.whitelist.conf stored.filename.message.txt stored.virus.message.txt
#  do
#    [ -f $F ] && /bin/cp $F $F.rpmsave
#  done
#  cd /
#fi

%post
chkconfig --add mailscanner
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
      patch -p0 < mime-tools-patch.txt
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
IO::Stringy   1.211  IO-stringy-1.211
MIME::Base64  2.11   MIME-Base64-2.11
IsABundle     1.46   MailTools-1.46
File::Spec    0.82   File-Spec-0.82
MIME::Tools   5.420  MIME-tools-5.411
File::Temp    0.12   File-Temp-0.12
Convert::TNEF 0.17   Convert-TNEF-0.17
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
echo '====     /usr/local/MailScanner/bin/Sophos.install'
echo
echo ==== Then run the command
echo '====     /etc/rc.d/init.d/mailscanner start'
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
if [ -e /usr/local/MailScanner/etc/mailscanner.conf.rpmnew ]; then
  echo '****'
  echo '**** Please look for any new options in mailscaner.conf.rpmnew'
  echo '**** and update your mailscanner.conf file appropriately.'
  echo '****'
fi

%preun
if [ $1 = 0 ]; then
    # We are being deleted, not upgraded
    /etc/rc.d/init.d/mailscanner stop >/dev/null 2>&1
    chkconfig mailscanner off
    chkconfig --del mailscanner
    chkconfig sendmail on
    chkconfig --level 2345 sendmail on
    /etc/rc.d/init.d/sendmail start >/dev/null 2>&1
fi
exit 0

%postun
if [ "$1" -ge "1" ]; then
    # We are being upgraded or replaced, not deleted
    /etc/rc.d/init.d/mailscanner restart >/dev/null 2>&1
fi
exit 0

%files
%dir /var/spool/mqueue.in
/tmp/MailScanner.perl.modules/File-Spec-0.82.tar.gz
/tmp/MailScanner.perl.modules/MIME-Base64-2.11.tar.gz
/tmp/MailScanner.perl.modules/MailTools-1.46.tar.gz
/tmp/MailScanner.perl.modules/IO-stringy-1.211.tar.gz
/tmp/MailScanner.perl.modules/MIME-tools-5.411a.tar.gz
/tmp/MailScanner.perl.modules/MIME-tools-5.411.tar.gz
/tmp/MailScanner.perl.modules/Convert-TNEF-0.17.tar.gz
/tmp/MailScanner.perl.modules/File-Temp-0.12.tar.gz
/tmp/MailScanner.perl.modules/mime-tools-patch.txt
%dir /usr/local/Sophos/lib
%dir /usr/local/Sophos/man/man1
/usr/local/Sophos/bin/sophoswrapper
/usr/local/Sophos/bin/autoupdate
/usr/local/uvscan/mcafeewrapper
/usr/local/uvscan/autoupdate
#/usr/local/mcafee/mcafeewrapper
#/usr/local/mcafee/autoupdate
#%dir /usr/local/mcafee/dat
#/usr/local/commandav
%config(noreplace) /usr/local/f-prot/f-protwrapper
/usr/local/f-prot/autoupdate
/usr/local/f-secure
#/usr/local/inoculate
/usr/local/kaspersky
/usr/local/panda
/usr/local/rav
%dir /var/spool/MailScanner/incoming
%dir /var/spool/MailScanner/quarantine
/usr/local/MailScanner/bin
%config(noreplace) /usr/local/MailScanner/etc/deleted.filename.message.txt
%config(noreplace) /usr/local/MailScanner/etc/deleted.virus.message.txt
%config(noreplace) /usr/local/MailScanner/etc/disinfected.report.txt
%config(noreplace) /usr/local/MailScanner/etc/domains.to.scan.conf
%config(noreplace) /usr/local/MailScanner/etc/filename.rules.conf
%config(noreplace) /usr/local/MailScanner/etc/localdomains.conf
%config(noreplace) /usr/local/MailScanner/etc/mailscanner.conf
%config(noreplace) /usr/local/MailScanner/etc/sender.error.report.txt
%config(noreplace) /usr/local/MailScanner/etc/sender.filename.report.txt
%config(noreplace) /usr/local/MailScanner/etc/sender.virus.report.txt
%config(noreplace) /usr/local/MailScanner/etc/spam.actions.conf
%config(noreplace) /usr/local/MailScanner/etc/spam.assassin.prefs.conf
%config(noreplace) /usr/local/MailScanner/etc/spam.whitelist.conf
%config(noreplace) /usr/local/MailScanner/etc/stored.filename.message.txt
%config(noreplace) /usr/local/MailScanner/etc/stored.virus.message.txt
%config(noreplace) /usr/local/MailScanner/etc/viruses.to.delete.conf
/usr/local/MailScanner/var
/usr/local/MailScanner/COPYING
%config(noreplace) /etc/sysconfig/mailscanner
/etc/rc.d/init.d/mailscanner
/etc/cron.hourly/check_mailscanner
/etc/cron.daily/Sophos.autoupdate
%doc /usr/share/doc/MailScanner-3.21
