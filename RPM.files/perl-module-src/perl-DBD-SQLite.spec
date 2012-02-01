Summary: DBD-SQLite Perl module
Name: perl-DBD-SQLite
Version: 1.25
Release: 2
Packager: mailscanner@ecs.soton.ac.uk
License: GPL or Artistic
Group: Development/Libraries
URL: http://search.cpan.org/dist/DBD-SQLite/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
#BuildArch: noarch
#BuildRequires: perl >= 0:5.00503
Source0: DBD-SQLite-1.25.tar.gz

%description
DBD-SQLite Perl module

%description
DBD-SQLite Perl module
%prep
%setup -q -n DBD-SQLite-%{version} 1

%build
CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL
make
make test

%clean
rm -rf $RPM_BUILD_ROOT
%install

rm -rf $RPM_BUILD_ROOT
eval `perl '-V:installarchlib'`
mkdir -p $RPM_BUILD_ROOT/$installarchlib
make install DESTDIR=$RPM_BUILD_ROOT

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT/usr -type f -print | \
	sed "s@^$RPM_BUILD_ROOT@@g" | \
	grep -v perllocal.pod | \
	grep -v "\.packlist" > DBD-SQLite-%{version}-filelist
if [ "$(cat DBD-SQLite-%{version}-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit 1
fi

%files -f DBD-SQLite-%{version}-filelist
%defattr(-,root,root)

%changelog
* Mon Jan 02 2006 Julian Field <mailscanner@ecs.soton.ac.uk>
- Specfile generated from perl-Net-CIDR.spec

