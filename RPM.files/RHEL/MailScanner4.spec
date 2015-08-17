%define name    mailscanner
%define version VersionNumberHere
%define release ReleaseNumberHere

# make the rpm backwards compatible
%define _source_payload w0.gzdio
%define _binary_payload w0.gzdio

Name:        %{name}
Version:     %{version}
Release:     %{release}
Summary:     Email Gateway Virus Scanner with Malware, Phishing, and Spam Detection
Group:       System Environment/Daemons
License:     GPLv2+
Vendor:      MailScanner Community
Packager:    Jerry Benton <mailscanner@mailborder.com>
URL:         http://www.mailscanner.info
#Requires:    sendmail, perl >= 5.005, tnef >= 1.1.1, perl-MIME-tools >= 5.412, perl-IO-stringy >= 1.211, perl-MailTools >= 1.46, perl-Convert-TNEF
#Requires:    sendmail, perl >= 5.005, tnef >= 1.1.1, perl-MIME-tools >= 5.412, perl-Convert-TNEF
#Requires:    sendmail, perl >= 5.005, tnef >= 1.1.1, perl-MIME-tools >= 5.412
#Requires:    perl >= 5.005, tnef >= 1.1.1, perl-MIME-tools >= 5.412
#Requires:    perl >= 5.005, perl-MIME-tools >= 5.412
Requires:     perl >= 5.005, binutils, gcc, glibc-devel, libaio, make, man-pages, man-pages-overrides, patch, rpm, tar, time, unzip, which, zip, openssl-devel, perl(Archive::Zip), perl(bignum), perl(Carp), perl(Compress::Zlib), perl(Compress::Raw::Zlib), perl(Convert::TNEF), perl(Data::Dumper), perl(Date::Parse), perl(DBD::SQLite), perl(DBI), perl(Digest::HMAC), perl(Digest::MD5), perl(Digest::SHA1), perl(DirHandle), perl(ExtUtils::MakeMaker), perl(Fcntl), perl(File::Basename), perl(File::Copy), perl(File::Path), perl(File::Spec), perl(File::Temp), perl(FileHandle), perl(Filesys::Df), perl(Getopt::Long), perl(Inline::C), perl(IO), perl(IO::File), perl(IO::Pipe), perl(IO::Stringy), perl(HTML::Entities), perl(HTML::Parser), perl(HTML::Tagset), perl(HTML::TokeParser), perl(Mail::Field), perl(Mail::Header), perl(Mail::IMAPClient), perl(Mail::Internet), perl(Math::BigInt), perl(Math::BigRat), perl(MIME::Base64), perl(MIME::Decoder), perl(MIME::Decoder::UU), perl(MIME::Head), perl(MIME::Parser), perl(MIME::QuotedPrint), perl(MIME::Tools), perl(MIME::WordDecoder), perl(Net::CIDR), perl(Net::DNS), perl(Net::IP), perl(OLE::Storage_Lite), perl(Pod::Escapes), perl(Pod::Simple), perl(POSIX), perl(Scalar::Util), perl(Socket), perl(Storable), perl(Test::Harness), perl(Test::Pod), perl(Test::Simple), perl(Time::HiRes), perl(Time::localtime), perl(Sys::Hostname::Long), perl(Sys::SigAction), perl(Sys::Syslog)
Provides:	  perl(MailScanner), perl(MailScanner::Antiword), perl(MailScanner::BinHex), perl(MailScanner::Config), perl(MailScanner::ConfigSQL), perl(MailScanner::CustomConfig), perl(MailScanner::FileInto), perl(MailScanner::GenericSpam), perl(MailScanner::LinksDump), perl(MailScanner::Lock), perl(MailScanner::Log), perl(MailScanner::Mail), perl(MailScanner::MCP), perl(MailScanner::MCPMessage), perl(MailScanner::Message), perl(MailScanner::MessageBatch), perl(MailScanner::Quarantine), perl(MailScanner::Queue), perl(MailScanner::RBLs), perl(MailScanner::MCPMessage), perl(MailScanner::Message), perl(MailScanner::MCP), perl(MailScanner::SA), perl(MailScanner::Sendmail), perl(MailScanner::SMDiskStore), perl(MailScanner::SweepContent), perl(MailScanner::SweepOther), perl(MailScanner::SweepViruses), perl(MailScanner::TNEF), perl(MailScanner::Unzip), perl(MailScanner::WorkArea), perl(MIME::Parser::MailScanner)
#Source:      %{name}-%{version}-%{release}.tgz
Source:      %{name}-%{version}.tgz
BuildRoot:   %{_tmppath}/%{name}-root
BuildArchitectures: noarch
AutoReqProv: yes


%description
MailScanner is a freely distributable email gateway virus scanner with
malware, phishing, and spam detection. It supports Postfix, sendmail, 
ZMailer, Qmail or Exim mail transport agents and a choice of 22 
open source and commercial virus scanning engines for virus scanning.  
It can decode and scan attachments intended solely for Microsoft Outlook 
users (MS-TNEF). If possible, it will disinfect infected documents and 
deliver them automatically. It provides protection against many security 
vulnerabilities in widely-used e-mail programs such as Eudora and 
Microsoft Outlook. It will also selectively filter the content of email 
messages to protect users from offensive content such as pornographic spam. 
It also has features which protect it against Denial Of Service attacks.

After installation, you must install one of the supported open source or
commercial antivirus packages if not installed using the MailScanner
installation script.

This has been tested on Red Hat Linux, but should work on other RPM 
based Linux distributions.

%prep
%setup

%build

%install
perl -pi - bin/MailScanner/ConfigDefs.pl bin/MailScanner/CustomConfig.pm etc/MailScanner.conf etc/virus.scanners.conf bin/mailscanner bin/Sophos.install bin/clean.SA.cache bin/update_virus_scanners bin/update_phishing_sites bin/update_bad_phishing_sites <<EOF
s+/opt/MailScanner/etc/mailscanner.conf+/etc/MailScanner/MailScanner.conf+;
s+/opt/MailScanner/etc/virus.scanners.conf+/etc/MailScanner/virus.scanners.conf+;
s./opt/MailScanner/var./var/run.;
s./opt/MailScanner/bin/mailscanner_create_locks./usr/sbin/mailscanner_create_locks.;
s./opt/MailScanner/bin/tnef./usr/bin/tnef.;
s#/opt/MailScanner/bin/Quick.Peek#/usr/sbin/Quick.Peek#;
s./opt/MailScanner/etc/reports./etc/MailScanner/reports.;
s./opt/MailScanner/etc/rules./etc/MailScanner/rules.;
s./opt/MailScanner/etc./etc/MailScanner.;
s./opt/MailScanner/lib./usr/share/MailScanner.;
s./opt/MailScanner/bin./usr/share/MailScanner.;
s./usr/lib/sendmail./usr/sbin/sendmail.;
EOF
perl -pi - check_MailScanner bin/mailscanner_create_locks bin/processing_messages_alert <<EOF
s+/opt/MailScanner/etc/mailscanner.conf+/etc/MailScanner/MailScanner.conf+;
s./opt/MailScanner/var./var/run.;
s./opt/MailScanner/bin/tnef./usr/bin/tnef.;
s#/opt/MailScanner/bin/Quick.Peek#/usr/sbin/Quick.Peek#;
s./opt/MailScanner/etc/reports./etc/MailScanner/reports.;
s./opt/MailScanner/etc/rules./etc/MailScanner/rules.;
s./opt/MailScanner/etc/mcp./etc/MailScanner/mcp.;
s./opt/MailScanner/etc./etc/MailScanner.;
s./opt/MailScanner/lib./usr/share/MailScanner.;
s./opt/MailScanner/bin./usr/sbin.;
s./usr/lib/sendmail./usr/sbin/sendmail.;
EOF
#gzip doc/MailScanner.8
gzip doc/MailScanner.8 doc/MailScanner.conf.5

mkdir -p $RPM_BUILD_ROOT
mkdir -p ${RPM_BUILD_ROOT}%{_sysconfdir}/rc.d/init.d
mkdir -p ${RPM_BUILD_ROOT}/usr/sbin/
mkdir -p ${RPM_BUILD_ROOT}/usr/share/man/man8
mkdir -p ${RPM_BUILD_ROOT}/usr/share/man/man5
#mkdir -p ${RPM_BUILD_ROOT}/usr/share/man/man1
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/conf.d
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/cy+en
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/de
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/en
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/fr
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/es
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/nl
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/pt_br
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/dk
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/sk
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/it
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/ro
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/se
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/cz
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/hu
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/reports/ca
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/rules
mkdir -p ${RPM_BUILD_ROOT}/etc/MailScanner/mcp
# mkdir -p ${RPM_BUILD_ROOT}/usr/lib/MailScanner/
# mkdir -p ${RPM_BUILD_ROOT}/usr/lib/MailScanner/MailScanner
mkdir -p ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/CustomFunctions
# mkdir -p ${RPM_BUILD_ROOT}/usr/share/MailScanner/
mkdir -p ${RPM_BUILD_ROOT}/etc/cron.hourly
mkdir -p ${RPM_BUILD_ROOT}/etc/cron.daily
mkdir -p ${RPM_BUILD_ROOT}/etc/sysconfig
mkdir -p ${RPM_BUILD_ROOT}/var/spool/mqueue
mkdir -p ${RPM_BUILD_ROOT}/var/spool/mqueue.in
mkdir -p ${RPM_BUILD_ROOT}/var/spool/MailScanner/incoming
mkdir -p ${RPM_BUILD_ROOT}/var/spool/MailScanner/quarantine
mkdir -p ${RPM_BUILD_ROOT}/var/run

install bin/df2mbox            ${RPM_BUILD_ROOT}/usr/sbin/df2mbox
install bin/d2mbox             ${RPM_BUILD_ROOT}/usr/sbin/d2mbox
install bin/mailscanner        ${RPM_BUILD_ROOT}/usr/sbin/MailScanner
install bin/mailscanner_create_locks ${RPM_BUILD_ROOT}/usr/sbin/mailscanner_create_locks
install bin/processing_messages_alert ${RPM_BUILD_ROOT}/usr/sbin/processing_messages_alert
install check_MailScanner      ${RPM_BUILD_ROOT}/usr/sbin/check_MailScanner
ln -s   check_MailScanner      ${RPM_BUILD_ROOT}/usr/sbin/check_mailscanner
install bin/Sophos.install     ${RPM_BUILD_ROOT}/usr/sbin/Sophos.install
install bin/Quick.Peek         ${RPM_BUILD_ROOT}/usr/sbin/Quick.Peek
install bin/update_virus_scanners ${RPM_BUILD_ROOT}/usr/sbin/update_virus_scanners
install bin/update_spamassassin ${RPM_BUILD_ROOT}/usr/sbin/update_spamassassin
install bin/update_phishing_sites ${RPM_BUILD_ROOT}/usr/sbin/update_phishing_sites
install bin/update_bad_phishing_sites ${RPM_BUILD_ROOT}/usr/sbin/update_bad_phishing_sites
install bin/analyse_SpamAssassin_cache ${RPM_BUILD_ROOT}/usr/sbin/analyse_SpamAssassin_cache
ln -sf analyse_SpamAssassin_cache ${RPM_BUILD_ROOT}/usr/sbin/analyze_SpamAssassin_cache
install bin/upgrade_MailScanner_conf ${RPM_BUILD_ROOT}/usr/sbin/upgrade_MailScanner_conf
ln -sf upgrade_MailScanner_conf ${RPM_BUILD_ROOT}/usr/sbin/upgrade_languages_conf
install update_spamassassin.opts.rh ${RPM_BUILD_ROOT}/etc/sysconfig/update_spamassassin
install MailScanner.opts.rh    ${RPM_BUILD_ROOT}/etc/sysconfig/MailScanner
install MailScanner.init.rh    ${RPM_BUILD_ROOT}%{_sysconfdir}/rc.d/init.d/MailScanner
install check_MailScanner.cron ${RPM_BUILD_ROOT}/etc/cron.hourly/check_MailScanner
install update_virus_scanners.cron ${RPM_BUILD_ROOT}/etc/cron.hourly/update_virus_scanners
install update_phishing_sites.cron ${RPM_BUILD_ROOT}/etc/cron.daily/update_phishing_sites
install update_bad_phishing_sites.cron ${RPM_BUILD_ROOT}/etc/cron.hourly/update_bad_phishing_sites
install clean.quarantine.cron  ${RPM_BUILD_ROOT}/etc/cron.daily/clean.quarantine
install update_spamassassin.cron  ${RPM_BUILD_ROOT}/etc/cron.daily/update_spamassassin
install processing_messages_alert.cron  ${RPM_BUILD_ROOT}/etc/cron.hourly/processing_messages_alert
#install clean.SA.cache.cron  ${RPM_BUILD_ROOT}/etc/cron.daily/clean.SA.cache
install doc/MailScanner.8.gz   ${RPM_BUILD_ROOT}/usr/share/man/man8/
install doc/MailScanner.conf.5.gz ${RPM_BUILD_ROOT}/usr/share/man/man5/

while read f 
do
  install etc/$f ${RPM_BUILD_ROOT}/etc/MailScanner/
done << EOF
filename.rules.conf
filetype.rules.conf
archives.filename.rules.conf
archives.filetype.rules.conf
MailScanner.conf
spam.assassin.prefs.conf
spam.lists.conf
virus.scanners.conf
phishing.safe.sites.conf
phishing.bad.sites.conf
country.domains.conf
EOF

install etc/conf.d/README ${RPM_BUILD_ROOT}/etc/MailScanner/conf.d/

while read f
do
  install etc/mcp/$f ${RPM_BUILD_ROOT}/etc/MailScanner/mcp/
done << EOF2
10_example.cf
mcp.spam.assassin.prefs.conf
v320.pre
EOF2


for lang in en cy+en de fr es nl pt_br sk dk it ro se cz hu ca
do
  while read f 
  do
    install etc/reports/$lang/$f ${RPM_BUILD_ROOT}/etc/MailScanner/reports/$lang
  done << EOF
deleted.content.message.txt
deleted.filename.message.txt
deleted.size.message.txt
deleted.virus.message.txt
disinfected.report.txt
inline.sig.html
inline.sig.txt
inline.spam.warning.txt
inline.warning.html
inline.warning.txt
languages.conf
recipient.spam.report.txt
recipient.mcp.report.txt
rejection.report.txt
sender.content.report.txt
sender.error.report.txt
sender.filename.report.txt
sender.spam.rbl.report.txt
sender.spam.report.txt
sender.spam.sa.report.txt
sender.mcp.report.txt
sender.size.report.txt
sender.virus.report.txt
stored.content.message.txt
stored.filename.message.txt
stored.size.message.txt
stored.virus.message.txt
EOF
done

while read f 
do
  install etc/rules/$f ${RPM_BUILD_ROOT}/etc/MailScanner/rules
done << EOF
EXAMPLES
README
spam.whitelist.rules
bounce.rules
max.message.size.rules
EOF

while read f 
do
  install lib/$f ${RPM_BUILD_ROOT}/usr/share/MailScanner
done << EOF
antivir-autoupdate
antivir-wrapper
avast-autoupdate
avast-wrapper
avastd-wrapper
avg-autoupdate
avg-wrapper
bitdefender-wrapper
bitdefender-autoupdate
clamav-autoupdate
clamav-wrapper
css-autoupdate
css-wrapper
command-wrapper
drweb-wrapper
esets-autoupdate
esets-wrapper
f-prot-autoupdate
f-prot-wrapper
f-prot-6-autoupdate
f-prot-6-wrapper
f-secure-wrapper
f-secure-autoupdate
etrust-autoupdate
etrust-wrapper
generic-autoupdate
generic-wrapper
inoculan-autoupdate
inoculan-wrapper
inoculate-wrapper
kaspersky.prf
kaspersky-autoupdate
kaspersky-wrapper
kavdaemonclient-wrapper
mcafee-autoupdate
mcafee-autoupdate.old
mcafee-wrapper
mcafee6-autoupdate
mcafee6-wrapper
nod32-wrapper
nod32-autoupdate
norman-wrapper
norman-autoupdate
panda-wrapper
panda-autoupdate
rav-autoupdate
rav-wrapper
sophos-autoupdate
sophos-wrapper
symscanengine-autoupdate
symscanengine-wrapper
trend-autoupdate
trend-wrapper
vba32-autoupdate
vba32-wrapper
vexira-autoupdate
vexira-wrapper
EOF

install bin/MailScanner.pm ${RPM_BUILD_ROOT}/usr/share/MailScanner/

#BinHex.pm
while read f 
do
  install bin/MailScanner/$f ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/
done << EOF
ConfigDefs.pl
Antiword.pm
Config.pm
ConfigSQL.pm
CustomConfig.pm
Exim.pm
EximDiskStore.pm
FileInto.pm
GenericSpam.pm
Lock.pm
Log.pm
Mail.pm
MessageBatch.pm
Message.pm
PFDiskStore.pm
Postfix.pm
Qmail.pm
QMDiskStore.pm
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
MCP.pm
MCPMessage.pm
TNEF.pm
Unzip.pm
WorkArea.pm
ZMailer.pm
ZMDiskStore.pm
EOF

install bin/MailScanner/CustomFunctions/GenericSpamScanner.pm ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/CustomFunctions
install bin/MailScanner/CustomFunctions/MyExample.pm ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/CustomFunctions
install bin/MailScanner/CustomFunctions/CustomAction.pm ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/CustomFunctions
install bin/MailScanner/CustomFunctions/Ruleset-from-Function.pm ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/CustomFunctions
install bin/MailScanner/CustomFunctions/ZMRouterDirHash.pm ${RPM_BUILD_ROOT}/usr/share/MailScanner/MailScanner/CustomFunctions

install var/run/MailScanner.pid ${RPM_BUILD_ROOT}/var/run/

%clean
rm -rf ${RPM_BUILD_ROOT}

%pre

%post
echo
# Create the SpasAssassin sym-link to mailscanner.cf
SADIR=`perl -MMail::SpamAssassin -e 'print Mail::SpamAssassin->new->first_existing_path(@Mail::SpamAssassin::site_rules_path)' 2>/dev/null`
if [ "x$SADIR" = "x" ]; then
  echo No SpamAssassin installation found.
else
  #mkdir -p ${RPM_BUILD_ROOT}${SADIR}
  if [ -e ${SADIR}/mailscanner.cf ]; then
    echo Leaving mailscanner.cf link or file alone.
  else
    ln -s -f /etc/MailScanner/spam.assassin.prefs.conf ${SADIR}/mailscanner.cf
  fi
  echo SpamAssassin site rules found in ${SADIR}
fi

# Create the incoming and quarantine dirs if needed
for F in incoming quarantine incoming/Locks;
do
  if [ \! -d /var/spool/MailScanner/$F ]; then
    mkdir -p /var/spool/MailScanner/$F
    chown root.root /var/spool/MailScanner/$F
    chmod 0755 /var/spool/MailScanner/$F
  fi
done

# Sort out the rc.d directories
chkconfig --add MailScanner
#chkconfig MailScanner off
#chkconfig --level 2 sendmail off # To fix bug in some RedHat dist's
echo
echo To activate MailScanner run the following commands:
echo
echo    service sendmail stop
echo    chkconfig sendmail off
echo    chkconfig MailScanner on
#echo    chkconfig --level 2345 MailScanner on
echo    service MailScanner start
echo
echo Note that you will need to replace the 'sendmail' option
echo above with your respective MTA. Sendmail, Postfix, Exim, etc.
echo
echo If you are using Clam AV, ensure that you check that the user
echo and group specified in /usr/share/MailScanner/clamav-wrapper
echo matches the user specified in /etc/passwd.
echo
%preun
if [ $1 = 0 ]; then
    # We are being deleted, not upgraded
    service MailScanner stop >/dev/null 2>&1
    chkconfig MailScanner off
    chkconfig --del MailScanner
fi
exit 0

%postun
# copy old ms files if this is an upgrade
if [ -d "/usr/lib/MailScanner" ]; then
	rm -rf /usr/lib/MailScanner
fi

# symlink
rm -rf /etc/MailScanner/CustomFunctions
ln -s /usr/share/MailScanner/MailScanner/CustomFunctions/ /etc/MailScanner/CustomFunctions

if [ "$1" -ge "1" ]; then
    # We are being upgraded or replaced, not deleted
    #echo 'To upgrade your MailScanner.conf and languages.conf files automatically, run'
    #echo '    upgrade_MailScanner_conf'
    #echo '    upgrade_languages_conf'
    #service MailScanner restart </dev/null >/dev/null 2>&1
fi
exit 0

%files
%defattr (644,root,root)
%attr(700,root,mail) %dir /var/spool/mqueue
%attr(700,root,mail) %dir /var/spool/mqueue.in
%attr(750,root,root) %dir /var/spool/MailScanner/incoming
%attr(750,root,root) %dir /var/spool/MailScanner/quarantine
%attr(700,root,root) /var/run/MailScanner.pid
%attr(755,root,root) /usr/sbin/df2mbox
%attr(755,root,root) /usr/sbin/d2mbox
%attr(755,root,root) /usr/sbin/MailScanner
%attr(755,root,root) /usr/sbin/mailscanner_create_locks
%attr(755,root,root) /usr/sbin/processing_messages_alert
%attr(755,root,root) /usr/sbin/check_MailScanner
%attr(755,root,root) /usr/sbin/check_mailscanner
%attr(755,root,root) /usr/sbin/Sophos.install
%attr(755,root,root) /usr/sbin/Quick.Peek
%attr(755,root,root) /usr/sbin/update_virus_scanners
%attr(755,root,root) /usr/sbin/update_spamassassin
%attr(755,root,root) /usr/sbin/update_phishing_sites
%attr(755,root,root) /usr/sbin/update_bad_phishing_sites
%attr(755,root,root) /usr/sbin/analyse_SpamAssassin_cache
%attr(755,root,root) /usr/sbin/analyze_SpamAssassin_cache
%attr(755,root,root) /usr/sbin/upgrade_MailScanner_conf
%attr(755,root,root) /usr/sbin/upgrade_languages_conf
%attr(755,root,root) /%{_sysconfdir}/rc.d/init.d/MailScanner
%attr(755,root,root) /etc/cron.hourly/check_MailScanner
%config(noreplace) %attr(755,root,root) /etc/cron.hourly/update_virus_scanners
%attr(755,root,root) /etc/cron.daily/update_phishing_sites
%attr(755,root,root) /etc/cron.hourly/update_bad_phishing_sites
%attr(755,root,root) /etc/cron.hourly/processing_messages_alert
%config(noreplace) %attr(755,root,root) /etc/cron.daily/update_spamassassin
%config(noreplace) %attr(755,root,root) /etc/cron.daily/clean.quarantine
#%config(noreplace) %attr(755,root,root) /etc/cron.daily/clean.SA.cache
%config(noreplace) %attr(644,root,root) /etc/sysconfig/MailScanner
%config(noreplace) %attr(644,root,root) /etc/sysconfig/update_spamassassin

%doc /usr/share/man/man8/MailScanner.8.gz
#%doc /usr/share/man/man1/MailScanner.1.gz
%doc /usr/share/man/man5/MailScanner.conf.5.gz

/etc/MailScanner/conf.d/README
%config(noreplace) /etc/MailScanner/filename.rules.conf
%config(noreplace) /etc/MailScanner/filetype.rules.conf
%config(noreplace) /etc/MailScanner/archives.filename.rules.conf
%config(noreplace) /etc/MailScanner/archives.filetype.rules.conf
%config(noreplace) /etc/MailScanner/MailScanner.conf
%config(noreplace) /etc/MailScanner/spam.assassin.prefs.conf
%config(noreplace) /etc/MailScanner/spam.lists.conf
/etc/MailScanner/virus.scanners.conf
%config(noreplace) /etc/MailScanner/phishing.safe.sites.conf
%config(noreplace) /etc/MailScanner/phishing.bad.sites.conf
%config(noreplace) /etc/MailScanner/country.domains.conf

%config(noreplace) /etc/MailScanner/mcp/10_example.cf
%config(noreplace) /etc/MailScanner/mcp/mcp.spam.assassin.prefs.conf
%config(noreplace) /etc/MailScanner/mcp/v320.pre

%config(noreplace) /etc/MailScanner/reports/en/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/en/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/en/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/en/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/en/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/en/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/en/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/en/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/en/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/en/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/en/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/en/languages.conf
%config(noreplace) /etc/MailScanner/reports/en/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/en/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/en/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/en/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/en/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/en/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/en/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/cy+en/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/cy+en/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/languages.conf
%config(noreplace) /etc/MailScanner/reports/cy+en/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/cy+en/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/de/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/de/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/de/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/de/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/de/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/de/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/de/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/de/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/de/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/de/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/de/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/de/languages.conf
%config(noreplace) /etc/MailScanner/reports/de/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/de/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/de/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/de/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/de/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/de/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/de/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/fr/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/fr/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/fr/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/fr/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/fr/languages.conf
%config(noreplace) /etc/MailScanner/reports/fr/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/fr/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/fr/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/es/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/es/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/es/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/es/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/es/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/es/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/es/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/es/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/es/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/es/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/es/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/es/languages.conf
%config(noreplace) /etc/MailScanner/reports/es/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/es/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/es/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/es/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/es/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/es/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/es/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/nl/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/nl/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/nl/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/nl/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/nl/languages.conf
%config(noreplace) /etc/MailScanner/reports/nl/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/nl/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/nl/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/pt_br/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/pt_br/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/languages.conf
%config(noreplace) /etc/MailScanner/reports/pt_br/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/pt_br/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/sk/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/sk/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/sk/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/sk/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/sk/languages.conf
%config(noreplace) /etc/MailScanner/reports/sk/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/sk/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/sk/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/dk/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/dk/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/dk/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/dk/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/dk/languages.conf
%config(noreplace) /etc/MailScanner/reports/dk/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/dk/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/dk/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/it/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/it/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/it/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/it/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/it/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/it/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/it/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/it/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/it/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/it/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/it/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/it/languages.conf
%config(noreplace) /etc/MailScanner/reports/it/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/it/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/it/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/it/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/it/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/it/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/it/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/ro/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/ro/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/ro/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/ro/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/ro/languages.conf
%config(noreplace) /etc/MailScanner/reports/ro/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/ro/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/ro/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/se/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/se/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/se/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/se/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/se/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/se/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/se/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/se/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/se/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/se/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/se/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/se/languages.conf
%config(noreplace) /etc/MailScanner/reports/se/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/se/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/se/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/se/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/se/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/se/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/se/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/cz/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/cz/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/cz/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/cz/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/cz/languages.conf
%config(noreplace) /etc/MailScanner/reports/cz/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/cz/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/cz/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/hu/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/hu/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/hu/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/hu/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/hu/languages.conf
%config(noreplace) /etc/MailScanner/reports/hu/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/hu/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/hu/stored.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/deleted.content.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/stored.content.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.content.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/deleted.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/deleted.size.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/deleted.virus.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/disinfected.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/inline.sig.html
%config(noreplace) /etc/MailScanner/reports/ca/inline.sig.txt
%config(noreplace) /etc/MailScanner/reports/ca/inline.spam.warning.txt
%config(noreplace) /etc/MailScanner/reports/ca/inline.warning.html
%config(noreplace) /etc/MailScanner/reports/ca/inline.warning.txt
%config(noreplace) /etc/MailScanner/reports/ca/languages.conf
%config(noreplace) /etc/MailScanner/reports/ca/recipient.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/recipient.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/rejection.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.error.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.filename.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.spam.rbl.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.spam.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.spam.sa.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.mcp.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.size.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/sender.virus.report.txt
%config(noreplace) /etc/MailScanner/reports/ca/stored.filename.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/stored.size.message.txt
%config(noreplace) /etc/MailScanner/reports/ca/stored.virus.message.txt

/etc/MailScanner/rules/EXAMPLES
/etc/MailScanner/rules/README
%config(noreplace) /etc/MailScanner/rules/spam.whitelist.rules
%config(noreplace) /etc/MailScanner/rules/max.message.size.rules
%config(noreplace) /etc/MailScanner/rules/bounce.rules

%attr(755,root,root) /usr/share/MailScanner/antivir-autoupdate
%attr(755,root,root) /usr/share/MailScanner/antivir-wrapper
%attr(755,root,root) /usr/share/MailScanner/avast-autoupdate
%attr(755,root,root) /usr/share/MailScanner/avast-wrapper
%attr(755,root,root) /usr/share/MailScanner/avastd-wrapper
%attr(755,root,root) /usr/share/MailScanner/avg-autoupdate
%attr(755,root,root) /usr/share/MailScanner/avg-wrapper
%attr(755,root,root) /usr/share/MailScanner/bitdefender-autoupdate
%attr(755,root,root) /usr/share/MailScanner/bitdefender-wrapper
%attr(755,root,root) /usr/share/MailScanner/clamav-autoupdate
%attr(755,root,root) /usr/share/MailScanner/clamav-wrapper
%attr(755,root,root) /usr/share/MailScanner/css-autoupdate
%attr(755,root,root) /usr/share/MailScanner/css-wrapper
%attr(755,root,root) /usr/share/MailScanner/command-wrapper
%attr(755,root,root) /usr/share/MailScanner/drweb-wrapper
%attr(755,root,root) /usr/share/MailScanner/esets-autoupdate
%attr(755,root,root) /usr/share/MailScanner/esets-wrapper
%attr(755,root,root) /usr/share/MailScanner/etrust-autoupdate
%attr(755,root,root) /usr/share/MailScanner/etrust-wrapper
%attr(755,root,root) /usr/share/MailScanner/f-prot-autoupdate
%attr(755,root,root) /usr/share/MailScanner/f-prot-wrapper
%attr(755,root,root) /usr/share/MailScanner/f-prot-6-autoupdate
%attr(755,root,root) /usr/share/MailScanner/f-prot-6-wrapper
%attr(755,root,root) /usr/share/MailScanner/f-secure-autoupdate
%attr(755,root,root) /usr/share/MailScanner/f-secure-wrapper
%attr(755,root,root) /usr/share/MailScanner/generic-autoupdate
%attr(755,root,root) /usr/share/MailScanner/generic-wrapper
%attr(755,root,root) /usr/share/MailScanner/inoculan-autoupdate
%attr(755,root,root) /usr/share/MailScanner/inoculan-wrapper
%attr(755,root,root) /usr/share/MailScanner/inoculate-wrapper
%attr(755,root,root) /usr/share/MailScanner/kaspersky-autoupdate
%attr(644,root,root) /usr/share/MailScanner/kaspersky.prf
%attr(755,root,root) /usr/share/MailScanner/kaspersky-wrapper
%attr(755,root,root) /usr/share/MailScanner/kavdaemonclient-wrapper
%attr(755,root,root) /usr/share/MailScanner/mcafee-autoupdate
%attr(755,root,root) /usr/share/MailScanner/mcafee-autoupdate.old
%attr(755,root,root) /usr/share/MailScanner/mcafee-wrapper
%attr(755,root,root) /usr/share/MailScanner/mcafee6-autoupdate
%attr(755,root,root) /usr/share/MailScanner/mcafee6-wrapper
%attr(755,root,root) /usr/share/MailScanner/nod32-autoupdate
%attr(755,root,root) /usr/share/MailScanner/nod32-wrapper
%attr(755,root,root) /usr/share/MailScanner/norman-autoupdate
%attr(755,root,root) /usr/share/MailScanner/norman-wrapper
%attr(755,root,root) /usr/share/MailScanner/panda-autoupdate
%attr(755,root,root) /usr/share/MailScanner/panda-wrapper
%attr(755,root,root) /usr/share/MailScanner/rav-autoupdate
%attr(755,root,root) /usr/share/MailScanner/rav-wrapper
%attr(755,root,root) /usr/share/MailScanner/sophos-autoupdate
%attr(755,root,root) /usr/share/MailScanner/sophos-wrapper
%attr(755,root,root) /usr/share/MailScanner/symscanengine-autoupdate
%attr(755,root,root) /usr/share/MailScanner/symscanengine-wrapper
%attr(755,root,root) /usr/share/MailScanner/trend-autoupdate
%attr(755,root,root) /usr/share/MailScanner/trend-wrapper
%attr(755,root,root) /usr/share/MailScanner/vba32-autoupdate
%attr(755,root,root) /usr/share/MailScanner/vba32-wrapper
%attr(755,root,root) /usr/share/MailScanner/vexira-autoupdate
%attr(755,root,root) /usr/share/MailScanner/vexira-wrapper

/usr/share/MailScanner/MailScanner.pm

#/usr/share/MailScanner/MailScanner/BinHex.pm
/usr/share/MailScanner/MailScanner/Antiword.pm
/usr/share/MailScanner/MailScanner/ConfigDefs.pl
/usr/share/MailScanner/MailScanner/Config.pm
/usr/share/MailScanner/MailScanner/ConfigSQL.pm
%config(noreplace) /usr/share/MailScanner/MailScanner/CustomConfig.pm
%config(noreplace) /usr/share/MailScanner/MailScanner/CustomFunctions/GenericSpamScanner.pm
%config(noreplace) /usr/share/MailScanner/MailScanner/CustomFunctions/MyExample.pm
%config(noreplace) /usr/share/MailScanner/MailScanner/CustomFunctions/CustomAction.pm
%config(noreplace) /usr/share/MailScanner/MailScanner/CustomFunctions/Ruleset-from-Function.pm
%config(noreplace) /usr/share/MailScanner/MailScanner/CustomFunctions/ZMRouterDirHash.pm
/usr/share/MailScanner/MailScanner/Exim.pm
/usr/share/MailScanner/MailScanner/EximDiskStore.pm
/usr/share/MailScanner/MailScanner/FileInto.pm
/usr/share/MailScanner/MailScanner/GenericSpam.pm
/usr/share/MailScanner/MailScanner/Lock.pm
/usr/share/MailScanner/MailScanner/Log.pm
/usr/share/MailScanner/MailScanner/Mail.pm
/usr/share/MailScanner/MailScanner/MessageBatch.pm
/usr/share/MailScanner/MailScanner/Message.pm
/usr/share/MailScanner/MailScanner/PFDiskStore.pm
/usr/share/MailScanner/MailScanner/Postfix.pm
/usr/share/MailScanner/MailScanner/Qmail.pm
/usr/share/MailScanner/MailScanner/QMDiskStore.pm
/usr/share/MailScanner/MailScanner/Quarantine.pm
/usr/share/MailScanner/MailScanner/Queue.pm
/usr/share/MailScanner/MailScanner/RBLs.pm
/usr/share/MailScanner/MailScanner/SA.pm
/usr/share/MailScanner/MailScanner/Sendmail.pm
/usr/share/MailScanner/MailScanner/SMDiskStore.pm
/usr/share/MailScanner/MailScanner/SweepContent.pm
/usr/share/MailScanner/MailScanner/SweepOther.pm
/usr/share/MailScanner/MailScanner/SweepViruses.pm
/usr/share/MailScanner/MailScanner/SystemDefs.pm
/usr/share/MailScanner/MailScanner/MCP.pm
/usr/share/MailScanner/MailScanner/MCPMessage.pm
/usr/share/MailScanner/MailScanner/TNEF.pm
/usr/share/MailScanner/MailScanner/Unzip.pm
/usr/share/MailScanner/MailScanner/WorkArea.pm
/usr/share/MailScanner/MailScanner/ZMailer.pm
/usr/share/MailScanner/MailScanner/ZMDiskStore.pm


%doc %attr(755,root,root) doc/COPYING
%doc %attr(755,root,root) doc/MailScanner.conf.index.html
%doc %attr(755,root,root) doc

%changelog
* Sun Mar 1 2015 Jerry Benton <mailscanner@mailborder.com>
- Moved structure to /usr/share/MailScanner

* Thu Feb 12 2015 Jerry Benton <mailscanner@mailborder.com>
- Many updates. See the ChangeLog for details.
  
* Mon Jan 09 2006 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added analyse_SpamAssassin_cache

* Sun Oct 09 2005 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added update_phishing_sites

* Thu Jan 22 2004 Julian Field <mailscanner@ecs.soton.ac.uk>
- Changed version numbering scheme, added recipient spam/mcp reports

* Thu Jun 26 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added bitdefender-autoupdate

* Sun May 18 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added */inline.spam.warning.txt

* Thu May 15 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added bitdefender-wrapper

* Mon May 12 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added Hungarian (hu) translation

* Mon Apr 28 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added Czech (cz) translation

* Sat Mar 01 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added nod32 and kaspersky autoupdate scripts

* Sat Feb 15 2003 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added upgrade_MailScanner_conf script

* Fri Dec 27 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for 4.11-1, added se translation

* Sun Nov 17 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for 4.06-2, added EximDiskStore.pm and languages.conf

* Sun Nov 10 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for 4.06-1, added /usr/sbin/df2mbox

* Sun Oct 27 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for 4.03-1, added CustomConfig.pm and trend-wrapper

* Sun Oct 20 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for 4.01-1

* Thu Oct 10 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for 4.00.0a12

* Sat Oct 05 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added SweepContent.pm and updated for 4.00.0a9

* Fri Oct 04 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Updated for RedHat 8.0

* Tue Oct 01 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Added German reports

* Sun Sep 29 2002 Julian Field <mailscanner@ecs.soton.ac.uk>
- Rewritten for MailScanner version 4

* Fri Jul 26 2002 Richard Keech <rkeech@ender.keech.cx>
- initial tested version

* Fri Jul 19 2002 Richard Keech <rkeech@redhat.com>
- v3.22 Re-packaged entirely.

