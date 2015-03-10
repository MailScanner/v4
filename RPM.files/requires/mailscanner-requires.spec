%define version 4.60.1
%define release 1
%define name    mailscanner-requires

Name:        %{name}
Version:     %{version}
Release:     %{release}
Summary:     E-Mail Gateway Virus Scanner and Spam Detector
Group:       System Environment/Daemons
License:     GPL
Vendor:      Electronics and Computer Science, University of Southampton
Packager:    Julian Field <mailscanner@ecs.soton.ac.uk>
URL:         http://www.mailscanner.info/
Requires:    mailscanner >= 4.60.1, perl >= 5.6.1, tnef >= 1.1.1, perl-MIME-tools >= 5.412, perl-MIME-Base64, perl-Archive-Zip, perl-Compress-Zlib, perl-Convert-BinHex, perl-Convert-TNEF, perl-DBD-SQLite, perl-DBI, perl-Filesys-Df, perl-File-Temp, perl-Getopt-Long, perl-IO-stringy, perl-HTML-Parser, perl-HTML-Tagset, perl-MailTools, perl-Net-CIDR, perl-Net-IP, perl-Sys-Hostname-Long, perl-Sys-Syslog, perl-TimeDate, perl-Time-HiRes
Source:      motd
#BuildRoot:   %{_tmppath}/%{name}-root
BuildArchitectures: noarch

%description
This is an RPM that exists solely for use by 'yum' to list all the
requirements of MailScanner. If you 'yum localinstall' this package, then
yum will go and fetch all the required packages and Perl modules.
See the 'mailscanner' rpm for more information about MailScanner itself.

#%prep
#%setup
#%build
%install
mkdir -p ${RPM_BUILD_ROOT}/tmp
install /etc/motd ${RPM_BUILD_ROOT}/tmp/motd
%clean
rm -rf ${RPM_BUILD_ROOT}

%files
/tmp/motd

%changelog
* Thu May 24 2007 Julian Field <mailscanner@ecs.soton.ac.uk>
- Created.
