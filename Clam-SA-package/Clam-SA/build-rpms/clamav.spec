# Conditional build (--with/--without option)
#   --without milter
Summary:		An antivirus toolkit for Unix
Name:			clamav
Version:		0.85.1
Release:		1
License:		GPL
Group:			Applications/System
URL:			http://www.clamav.net/
Source0:		http://switch.dl.sourceforge.net/sourceforge/clamav/clamav-%{version}.tar.gz
Source1:		clamd.sh
Source2:		clamav-milter.sh
Source3:		freshclam.sh
Source4:		clamav-milter.sysconfig
Source5:		freshclam.sysconfig
Source6:		clamd.logrotate
Source7:		freshclam.logrotate
Source8:		http://www.schimkat.dk/clamav/clamav-milter-logwatch-0.40.tar.gz
Source9:		RPM-clamav-milter.txt
Source10:		milter-clamav.mc
Packager:		Oliver Falk <oliver@linux-kernel.at>
BuildRequires:	autoconf automake
BuildRoot:		%{_tmppath}/%{name}-%{version}-root

%description
Clam AntiVirus is a GPL anti-virus toolkit for UNIX. The main purpose of this
software is the integration with mail servers (attachment scanning).
The package provides a flexible and scalable multi-threaded daemon,
a command line scanner, and a tool for automatic updating via Internet.
The programs are based on a shared library distributed with package,
which you can use with your own software.
Most importantly, the virus database is kept up to date .

%if %{!?_without_milter:1}%{?_without_milter:0}
%package 	milter
Summary:	Clamav milter
Group:		System Environment/Daemons
License:	GPL
Requires:	%{name} = %{version}-%{release}
# milter-common.mc is included in this sendmail release
Requires:	sendmail >= 8.13.1-7
BuildRequires:	sendmail-devel >= 8.11

%description 	milter
ClamAV sendmail filter using MILTER interface.
%endif

%package 	devel
Summary:	Clamav - Development header files and libraries
Group:		Development/Libraries
Requires:	%{name} = %{version}-%{release}

%description 	devel
This package contains the development header files and libraries
necessary to develope your own clamav based applications.


%prep
%setup -q
%setup -D -a 8

%build
%configure \
	--enable-debug \
	--program-prefix=%{?_program_prefix} \
	%{!?_without_milter:--enable-milter} \
	--enable-id-check \
	--disable-clamav \
	--with-user=clamav \
	--with-group=clamav \
	--with-dbdir=%{_localstatedir}/lib/clamav
%{__make}


%install
rm -rf $RPM_BUILD_ROOT

install -d $RPM_BUILD_ROOT%{_initrddir}/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/log.d/scripts/services/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/log.d/conf/services/
install -d $RPM_BUILD_ROOT%{_localstatedir}/lib/clamav/
install -d $RPM_BUILD_ROOT%{_localstatedir}/log/clamav/
install -d $RPM_BUILD_ROOT%{_localstatedir}/run/clamav/

%{__make} install DESTDIR=$RPM_BUILD_ROOT

%{?_without_milter:rm -f $RPM_BUILD_ROOT%{_mandir}/man8/clamav-milter.8*}
install %{SOURCE1}  $RPM_BUILD_ROOT%{_initrddir}/clamd
install %{SOURCE3}  $RPM_BUILD_ROOT%{_initrddir}/freshclam
install %{SOURCE5}  $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/freshclam
install %{SOURCE6}  $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/clamd
install %{SOURCE7}  $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/freshclam
install etc/freshclam.conf $RPM_BUILD_ROOT%{_sysconfdir}/freshclam.conf
# Milter
%if %{!?_without_milter:1}%{?_without_milter:0}
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/mail
install %{SOURCE10} $RPM_BUILD_ROOT%{_sysconfdir}/mail
install %{SOURCE2} $RPM_BUILD_ROOT%{_initrddir}/clamav-milter
install %{SOURCE4} $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/clamav-milter
install %{SOURCE9} RPM-clamav-milter.txt
mv clamav/HOWTO HOWTO-logwatch.txt
%endif
#

%clean
rm -rf $RPM_BUILD_ROOT


%pre
if [ -z "`id -g clamav 2>/dev/null`" ]; then
	/usr/sbin/groupadd -g 46 -r -f clamav
fi
if [ -z "`id -u clamav 2>/dev/null`" ]; then
	/usr/sbin/useradd -u 46 -r -d /tmp  -s /sbin/nologin -c "Clam AV Checker" -g clamav clamav 1>&2
fi

%post
/sbin/chkconfig --add clamd
/sbin/chkconfig --add freshclam

%preun
if [ $1 = 0 ]; then
	service clamd stop > /dev/null 2>&1
	service freshclam stop > /dev/null 2>&1
	/sbin/chkconfig --del clamd
	/sbin/chkconfig --del freshclam
fi

%postun
if [ $1 = 0 ]; then
	/usr/sbin/userdel -r clamav > /dev/null 2>&1 || :
fi
if [ "$1" -ge "1" ]; then
	service clamd condrestart > /dev/null 2>&1
	service freshclam condrestart > /dev/null 2>&1
fi

# Milter
%if %{!?_without_milter:1}%{?_without_milter:0}
%post milter
/sbin/chkconfig --add clamav-milter

%preun milter
if [ $1 = 0 ]; then
	service clamav-milter stop > /dev/null 2>&1
	/sbin/chkconfig --del clamav-milter
fi

%postun milter
if [ "$1" -ge "1" ]; then
	service clamav-milter condrestart > /dev/null 2>&1
fi
%endif
#


%files
%defattr(0644,root,root,0755)
%doc AUTHORS BUGS COPYING ChangeLog FAQ INSTALL NEWS README TODO
%doc docs/*.pdf docs/*.tex docs/Makefile
%attr(0640,root,clamav) %config(noreplace) %{_sysconfdir}/clamd.conf
%attr(0640,root,clamav) %config(noreplace) %{_sysconfdir}/freshclam.conf
%attr(0640,root,clamav) %config(noreplace) %{_sysconfdir}/sysconfig/freshclam
%attr(0755,root,root) %{_initrddir}/clamd
%attr(0755,root,root) %{_initrddir}/freshclam
%attr(0755,root,root) %{_sysconfdir}/logrotate.d/clamd
%attr(0755,root,root) %{_sysconfdir}/logrotate.d/freshclam
%attr(0755,root,root) %{_bindir}/*
%attr(0755,root,root) %{_sbindir}/clamd
%attr(0755,root,root) %{_libdir}/libclamav.so.*
%attr(0755,root,root) %{_libdir}/pkgconfig/libclamav.pc
%attr(0755,clamav,clamav) %dir %{_localstatedir}/lib/clamav/
#%attr(0644,clamav,clamav) %{_localstatedir}/lib/clamav/mirrors.txt
%attr(0644,clamav,clamav) %config(noreplace) %verify(user group mode) %{_localstatedir}/lib/clamav/main.cvd
%attr(0644,clamav,clamav) %config(noreplace) %verify(user group mode) %{_localstatedir}/lib/clamav/daily.cvd
%attr(0755,clamav,clamav) %{_localstatedir}/log/clamav/
%attr(0755,clamav,clamav) %{_localstatedir}/run/clamav/
%{_mandir}/man1/clamdscan.1*
%{_mandir}/man1/clamscan.1*
%{_mandir}/man5/freshclam.conf.5*
%{_mandir}/man1/freshclam.1*
%{_mandir}/man1/sigtool.1*
%{_mandir}/man5/clamd.conf.5*
%{_mandir}/man8/clamd.8*

# Milter
%if %{!?_without_milter:1}%{?_without_milter:0}
%files milter
%defattr(0644,root,root,0755)
%doc RPM-clamav-milter.txt HOWTO-logwatch.txt
%config(noreplace) %{_sysconfdir}/sysconfig/clamav-milter
%config(noreplace) %attr(0644,root,root) %{_sysconfdir}/mail/milter-clamav.mc
%attr(0755,root,root) %{_initrddir}/clamav-milter
%attr(0755,root,root) %{_sbindir}/clamav-milter
#%attr(0755,root,root) %{_sysconfdir}/log.d/scripts/services/clamav-milter
#%attr(0644,root,root) %{_sysconfdir}/log.d/conf/services/clamav-milter.conf
%{_mandir}/man8/clamav-milter.8*
%endif
#

%files devel
%defattr(0644,root,root,0755)
%attr(0755,root,root) %{_libdir}/*.a
%attr(0755,root,root) %{_libdir}/*.la
%attr(0644,root,root) %{_includedir}/*.h


%changelog
* Thu Jan 27 2005 Oliver Falk <oliver@linux-kernel.at>		- 0.81-1
- Update

* Mon Oct 18 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc-1
- Update

* Thu Oct 14 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc4-3
- Update clamav-milter.mc
- Fix permissions

* Wed Oct 12 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc4-2
- Add noreplace option to config files

* Tue Oct 12 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc4-1
- Update

* Tue Sep 28 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc3-1
- Update to latest RC

* Tue Sep 21 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc-3
- Add Sendmail .mc file

* Tue Sep 21 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc-2
- Fix initscript

* Tue Sep 21 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.80rc-1
- Update to Release Candidate
- Drop log.d stuff; Conflicts with logwatch

* Thu Sep 16 2004 Oliver Falk <oliver@linux-kernel.at>		- 0.75.1-2
- My name changed
- Added Packager Name
- Rebuild

* Wed Feb 11 2004 Oliver Pitzeier <oliver@linux-kernel.at>	- 0.66-1
- Update
- Remove patches, that don't work with 0.66-1
- Remove epoch stuff

* Sun Dec 7 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Fix Epoch dependencies by Eduardo Kaftanski <eduardo@linuxcenter.cl>

* Sun Nov 23 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Update .spec file
- Fix RH-7.3 program-prefix by Kenneth Porter <shiva@sewingwitch.com>
- Rebuild on FC1

* Sun Nov 16 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Fix doc errors
- Fix dependencies
- Patch for RH-7.3 by Lionel Bouton <Lionel.Bouton@inet6.fr>
- Patch for RH-7.3 by Chris de Vidal <chris@devidal.tv>
- Option --without-milter by Ján Ondrej (SAL) <ondrejj@salstar.sk>

* Wed Nov 12 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Removed package db
- Added LogWatch support
- Added FreshClam support
- Moved logfiles to own subdirectory
- Update to 0.65

* Wed Sep 10 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Option for build without clamavdb

* Thu Jul 10 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Split package to clamav, db, milter, devel

* Sun Jun 22 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Update to 0.60

* Tue Jun 10 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Fixed post, preun, postun scripts
- Update to 2003xxxx snapshots

* Tue Feb 4 2003 Petr Kri¹tof <Petr@Kristof.CZ>
- Rebuild on RH-8.0

* Sun Dec 1 2002 Petr Kri¹tof <Petr@Kristof.CZ>
- Based on PLD package
- Initial RH-7.3 build

