#!/bin/sh

# MailScanner tarball source installer
#
# Installs MailScanner with the option of installing 
# required perl modules via CPAN. Does not build any
# packages from source.
#
# Jerry Benton <mailscanner@mailborder.com>
# 15 FEB 2015

# Function used to Wait for n seconds
timewait () {
	DELAY=$1
	sleep $DELAY
}

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

# Check for root user
if [ $(whoami) != "root" ]; then
	ROOTWARN='WARNING: root privileges nto detected!';
else
	ROOTWARN=
fi


TMPBUILDDIR=/tmp
PERL_DIR="perl-tar"

# Need GNU tar and make
TARPATH="/usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin"
CCPATH="/opt/SUNWspro/bin /usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin"
MAKEPATH="/usr/local/bin /usr/sfw/bin /usr/freeware/bin /usr/ccs/bin /usr/bin /bin"
GUNZIPPATH="/usr/local/bin /usr/sfw/bin /usr/freeware/bin /usr/bin /bin"
TNEFPATH="/usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin"

TAR=`findprog tar $TARPATH`
GTAR=`findprog gtar $TARPATH`
MAKE=`findprog make $MAKEPATH`
GUNZIP=`findprog gunzip $GUNZIPPATH`
CC=`findprog cc $CCPATH`
GCC=`findprog gcc $TARPATH`
TNEF=`findprog tar $TNEFPATH`

# clear the screen. yay!
clear

# where i started the install
THISCURRPMDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# user info screen before the install process starts
echo "MailScanner Installation From Source"; echo; echo;
echo "This will install or upgrade the required software for MailScanner on *NIX systems";
echo "from source. A number of requirements are needed by MailScanner. If you have not";
echo "reviewed and installed these requirements, please do so before continuing with the"; 
echo "installation."; echo;
echo $ROOTWARN;
echo;
echo "You may press CTRL + C at any time to abort the installation.";
echo;
echo "When you are ready to continue, press return ... ";
read foobar

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install in /etc or /opt ?"; echo;
echo "I can install MailScanner in either of these directory structures.";
echo;
echo "1 - /etc";
echo "2 - /opt";
echo;
echo "Recommended: 1 "; echo;
read -r -p "Where should I install MailScanner? [1] : " response

if [[ $response =~ 2 ]]; then
	ETC='/opt';
else
    ETC='/etc';
fi

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I can check and attempt to install missing Perl modules via CPAN, which will save";
echo "you time. This requires internet connectivity. Note that if you select this option";
echo "I will check for $HOME/.cpan/CPAN/MyConfig.pm and if missing will install a vanilla";
echo "configuration file for you. If you already have one in place, make sure that you";
echo "have specified that newly installed Perl modules are available system-wide.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install missing Perl modules via CPAN? [y/N] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # user wants to use CPAN for missing modules
	CPANOPTION=1
else
    # user does not want to use CPAN
    CPANOPTION=0
fi

# create the cpan config if there isn't one and the user
# elected to use CPAN
if [ $CPANOPTION == 1 ]; then
	# user elected to use CPAN option
	if [ ! -f "$HOME/.cpan/CPAN/MyConfig.pm" ]; then
		echo;
		echo "CPAN config missing. Creating one ..."; echo;
		mkdir -p $HOME/.cpan/CPAN
		cd $HOME/.cpan/CPAN
		$CURL -O https://s3.amazonaws.com/mailscanner/install/cpan/MyConfig.pm
		cd $THISCURRPMDIR
		timewait 1
	fi
fi

# the array of perl modules needed
ARMOD=();
ARMOD+=('Archive::Tar'); 		ARMOD+=('Archive::Zip');		ARMOD+=('bignum');				
ARMOD+=('Carp');				ARMOD+=('Compress::Zlib');		ARMOD+=('Compress::Raw::Zlib');	
ARMOD+=('Convert::BinHex'); 	ARMOD+=('Convert::TNEF');		ARMOD+=('Data::Dumper');		
ARMOD+=('Date::Parse');			ARMOD+=('DBD::SQLite');			ARMOD+=('DBI');					
ARMOD+=('Digest::HMAC');		ARMOD+=('Digest::MD5');			ARMOD+=('Digest::SHA1'); 		
ARMOD+=('DirHandle');			ARMOD+=('ExtUtils::MakeMaker');	ARMOD+=('Fcntl');				
ARMOD+=('File::Basename');		ARMOD+=('File::Copy');			ARMOD+=('File::Path');			
ARMOD+=('File::Spec');			ARMOD+=('File::Temp');			ARMOD+=('FileHandle');			
ARMOD+=('Filesys::Df');			ARMOD+=('Getopt::Long');		ARMOD+=('Inline::C');			
ARMOD+=('IO');					ARMOD+=('IO::File');			ARMOD+=('IO::Pipe');			
ARMOD+=('IO::Stringy');			ARMOD+=('HTML::Entities');		ARMOD+=('HTML::Parser');		
ARMOD+=('HTML::Tagset');		ARMOD+=('HTML::TokeParser');	ARMOD+=('Mail::Field');			
ARMOD+=('Mail::Header');		ARMOD+=('Mail::IMAPClient');	ARMOD+=('Mail::Internet');		
ARMOD+=('Math::BigInt');		ARMOD+=('Math::BigRat');		ARMOD+=('MIME::Base64');		
ARMOD+=('MIME::Decoder');		ARMOD+=('MIME::Decoder::UU');	ARMOD+=('MIME::Head');			
ARMOD+=('MIME::Parser');		ARMOD+=('MIME::QuotedPrint');	ARMOD+=('MIME::Tools');			
ARMOD+=('MIME::WordDecoder');	ARMOD+=('Net::CIDR');			ARMOD+=('Net::DNS');			
ARMOD+=('Net::IP');				ARMOD+=('OLE::Storage_Lite');	ARMOD+=('Pod::Escapes');		
ARMOD+=('Pod::Simple');			ARMOD+=('POSIX');				ARMOD+=('Scalar::Util');		
ARMOD+=('Socket'); 				ARMOD+=('Storable'); 	 	 	ARMOD+=('Test::Harness');		
ARMOD+=('Test::Pod');			ARMOD+=('Test::Simple');		ARMOD+=('Time::HiRes');			
ARMOD+=('Time::localtime'); 	ARMOD+=('Sys::Hostname::Long');	ARMOD+=('Sys::SigAction');		
ARMOD+=('Sys::Syslog'); 		ARMOD+=('Env'); 				ARMOD+=('File::ShareDir::Install');

# add to array if the user is installing spamassassin
if [ $SA == 1 ]; then
	ARMOD+=('Mail::SpamAssassin');
fi

# add to array if the user is installing clam av
if [ $CAV == 1 ]; then
	ARMOD+=('Mail::ClamAV');
fi



