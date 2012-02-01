

TMPBUILDDIR=/tmp
PERL_DIR="perl-tar"
TNEFVERSION=1.3.4

# Need GNU tar and make
TARPATH="/usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin"
CCPATH="/opt/SUNWspro/bin /usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin"
MAKEPATH="/usr/local/bin /usr/sfw/bin /usr/freeware/bin /usr/ccs/bin /usr/bin /bin"
GUNZIPPATH="/usr/local/bin /usr/sfw/bin /usr/freeware/bin /usr/bin /bin"

TAR=`findprog tar $TARPATH`
MAKE=`findprog make $MAKEPATH`
GUNZIP=`findprog gunzip $GUNZIPPATH`
CC=`findprog cc $CCPATH`
GCC=`findprog gcc $TARPATH`

# Make a temp dir we use for a few things
TMPINSTALL=${TMPBUILDDIR}/MStmpinstall.$$
mkdir $TMPINSTALL
chmod go-rwx $TMPINSTALL

if [ \! "x$CC" = "x" ]; then
  CCISGCC=no
elif [ "x$GCC" = "x" ]; then
  CCISGCC=no
else
  echo Found gcc.
  if [ \! -f /usr/local/bin/cc ]; then
    echo Making cc a link to gcc.
    ln -s $GCC ${TMPINSTALL}/cc
    PATH=${TMPINSTALL}:$PATH
    export PATH
  fi
  CCISGCC=yes
fi

# Now we have tar, check it is GNU tar as we need the "z" option
TARCHECK=`$TAR --version 2>/dev/null | grep GNU`
if [ "x$TARCHECK"  = "x" ]; then
  echo Bother, could not find GNU tar.
  TARISGNU=no
  if [ "x$GUNZIP" = "x" ]; then
    echo Could not find gunzip either. You will have to decompress the
    echo .tar.gz files yourself, to leave a collection of .tar files.
    sleep 2
  else
    echo No problem, will decompress them with gunzip.
    sleep 2
  fi
else
  echo Good, I have found GNU tar in $TAR.
  TARISGNU=yes
fi

# If we are using gcc on Solaris, we need to fix up the command-line flags
if [ "x$CCISGCC" = "xyes" -a "x$ARCHITECT" = "xsolaris" ]; then
  CONFIGPM=`$PERL -e 'foreach (@INC) { print("$_"),exit if (-f "$_/Config.pm"); }'`
  echo
  echo As you are running gcc on Solaris, the Makefiles created when
  echo installing Perl modules won\'t work properly, so I am temporarily
  echo installing a fix for this problem. I will put it all back in place
  echo when I have finished.
  echo Found Config.pm in $CONFIGPM
  mkdir -p ${TMPINSTALL}${CONFIGPM}
  $PERL -p -e 's/-KPIC|-xO3|-xdepend//g' $CONFIGPM/Config.pm > ${TMPINSTALL}${CONFIGPM}/Config.pm
  PERL5OPT="-I${TMPINSTALL}${CONFIGPM}"
  export PERL5OPT
  sleep 10
  echo
fi

unpackarchive () {
  DIR=$1
  SOURCE=$2

  if [ "x$TARISGNU" = "xyes" ]; then
    ( cd $DIR && $TAR xzBpf - ) < $SOURCE
  else
    # Not GNU tar, so try to gunzip ourselves
    if [ "x$GUNZIP" = "x" ]; then
      SOURCE2=`echo $SOURCE | sed -e 's/\.gz$//'`
      if [ -f "$SOURCE2" ]; then
        ( cd $DIR && $TAR xBpf - ) < $SOURCE2
      else
        echo Could not find ${SOURCE2}.
        echo As I could not find GNU tar or gunzip, you need to
        echo uncompress each of the .gz files yourself.
        echo Sorry about that.
        exit 1
      fi
    else
      $GUNZIP -c $SOURCE | ( cd $DIR && $TAR xBpf - )
    fi
  fi
}

################################################################
# The function to install a perl module.
# Uses as quasi-arguments:
#	PERL_DIR: directory of perl modules
#	MODFILE: filename
#	VERS: version
#	TEST: yes or no
#	PATCHSFX: patch suffix, optional (MIME-Tools)
perlinstmod () {
    FILENAME=${MODFILE}-${VERS}${PATCHSFX}
    PERL_SOURCE=${PERL_DIR}/${FILENAME}.tar.gz
    echo Attempting to build and install ${FILENAME}
    sleep 2
    echo Unpacking $PERL_SOURCE
    if [ -f $PERL_SOURCE ]; then
      unpackarchive $TMPBUILDDIR $PERL_SOURCE
      echo
    else
      echo Missing file $PERL_SOURCE . Are you in the right directory\?
      sleep 2
      echo
    fi
    if [ -d ${TMPBUILDDIR}/${MODFILE}-${VERS} ]; then
      echo
      echo Do not worry too much about errors from the next command.
      echo It is quite likely that some of the Perl modules are
      echo already installed on your system.
      echo
      echo The important ones are HTML-Parser and MIME-tools.
      echo
      sleep 2
      (
        cd ${TMPBUILDDIR}/${MODFILE}-${VERS}
        if [ "x$TEST" = "xyes" ]; then
          # echo y is for Inline and Net::DNS
          echo y | $PERL Makefile.PL
          #[ "x$CCISGCC" = "xyes" ] && $PERL -pi.bak -e 's/-KPIC|-xO3|-xdepend//g' Makefile
          # Remove spamc and spamd tests from Mail-SpamAssassin
          if [ "x$MODFILE" = "xMail-SpamAssassin" ]; then
            echo Removing tests for spamc/d as MailScanner does not use them
            sleep 5
            rm -f t/spamc* t/spamd*
          fi
          $MAKE && $MAKE test && $MAKE install
        else
          # echo y is for Inline and Net::DNS
          echo y | $PERL Makefile.PL && $MAKE && $MAKE install
          [ "x$CCISGCC" = "xyes" ] && $PERL -pi.bak -e 's/-KPIC|-xO3|-xdepend//g' Makefile
          $MAKE && $MAKE install
        fi
      )
      rm -rf ${TMPBUILDDIR}/${MODFILE}-${VERS}
      sleep 2
      echo
      echo
      echo
    else
      echo Missing directory ${TMPBUILDDIR}/${MODFILE}-${VERS} .
      echo Maybe it did not build correctly\?
      sleep 2
      echo
    fi
}

#
# Call this after all the Perl modules have been installed.
# It will restore the settings on some architectures.
#
afterperlmodules () {
  if [ \! "x$CONFIGPM" = "x" ]; then
    PERL5OPT=""
    export PERL5OPT
    rm -rf $TMPINSTALL
  fi
}

#
# Install the tnef decoder
#
tnefinstall () {
  if [ -x /usr/local/bin/tnef ]; then
    echo Oh good, I have found the tnef program is in /usr/local/bin.
  else
    unpackarchive $TMPBUILDDIR ${PERL_DIR}/tnef-${TNEFVERSION}.tar.gz
    (
      cd ${TMPBUILDDIR}/tnef-${TNEFVERSION}
      echo
      echo About to build the TNEF decoder
      ./configure
      make
      TNEFBIN="${TMPBUILDDIR}/tnef-${TNEFVERSION}/src/tnef"
    )
  fi
}

#
# Install MailScanner itself
#
mailscannerinstall () {
  echo Installing MailScanner into /opt.
  echo If you do not want it there, just move it to where you want it
  echo and then edit MailScanner.conf and check_mailscanner
  echo to set the correct locations.
  if [ \! -d /opt ]; then
    mkdir /opt
    chmod a+rx /opt
  fi
  unpackarchive /opt `ls ${PERL_DIR}/MailScanner*.tar.gz | tail -1`

  VERNUM=`cd ${PERL_DIR}; ls MailScanner*.tar.gz | $PERL -pe 's/^MailScanner-([0-9.]+).*$/$1/' | tail -1`
  echo Have just installed version ${VERNUM} into /opt/MailScanner-${VERNUM}.

  # Create the symlink if not already present
  if [ -d /opt/MailScanner ]; then
    echo You will need to update the symlink /opt/MailScanner to point
    echo to the new version before starting it.
  else
    ln -sf MailScanner-${VERNUM} /opt/MailScanner
  fi
  echo

  # Copy in the tnef binary if possible
  if [ -f "$TNEFBIN" ]; then
    cd /opt/MailScanner-${VERNUM}/bin
    if [ -f tnef ]; then
      mv tnef tnef.original
    fi
    cp "$TNEFBIN" tnef
    echo 'I have setup tnef (which decodes Microsoft Outlook Rich Text attachments)'
    echo 'in the /opt/MailScanner/bin directory.'
  else
    echo 'For some reason the tnef decoder did not compile properly.'
    echo 'As an alternative, in MailScanner.conf set'
    echo 'TNEF Expander = internal'
  fi
  echo

  # Create the spool directories if there aren't already signs of them
  if [ \! -d /var/spool/MailScanner ]; then
    mkdir -p /var/spool/MailScanner/incoming
    mkdir -p /var/spool/MailScanner/quarantine
    mkdir -p /var/spool/mqueue.in
    chown root /var/spool/mqueue.in
    chgrp bin  /var/spool/mqueue.in
    chmod u=rwx,g=rx,o-rwx /var/spool/mqueue.in
    echo It looks like this is your first MailScanner installation so I have
    echo created the working directories and quarantine for you in /var/spool.
  fi
}

