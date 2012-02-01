%define version 1.4.5
%define name    tnef

Name: %{name}
Version: %{version}
Release: 2
Packager: Julian Field <mailscanner@ecs.soton.ac.uk>
Summary: Decodes MS-TNEF attachments
License: distributable
Group: Applications/Internet
URL: http://sourceforge.net/projects/tnef/
Vendor: verdammelt@users.sourceforge.net
Buildarch: i386
Prefix: /usr
Source: %{name}-%{version}.tar.gz
#Patch0: %{name}-%{version}.sizelimit.patch
BuildRoot: %{_tmppath}/%{name}-%{version}-root

%description
TNEF is a program for unpacking MIME attachments of type
"application/ms-tnef". This is a Microsoft only attachment.

Due to the proliferation of Microsoft Outlook and Exchange mail servers,
more and more mail is encapsulated into this format.

The TNEF program allows one to unpack the attachments which were
encapsulated into teh TNEF attachment.  Thus alleviating the need to use
Microsoft Outlook to view the attachment.

%prep
%setup
#%patch0 -p1

%build
CFLAGS=${RPM_OPT_FLAGS} ./configure --prefix=%{prefix}
make all

%install
make "DESTDIR=${RPM_BUILD_ROOT}" install

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%doc README COPYING ChangeLog AUTHORS NEWS TODO BUGS
%{prefix}/bin/tnef
%{prefix}/share/man/man1/tnef.1.gz

%changelog
* Wed Apr 19 2006 mailscanner@ecs.soton.ac.uk
- Updated for tnef 1.4
* Wed Dec 28 2005 mailscanner@ecs.soton.ac.uk
- Updated for tnef 1.3.4
* Thu May 06 2004 mailscanner@ecs.soton.ac.uk
- Updated for tnef 1.2.3.1
* Sat Feb 22 2003 mailscanner@ecs.soton.ac.uk
- Updated for tnef 1.1.4
* Sun Sep 29 2002 mailscanner@ecs.soton.ac.uk
- 1st release

