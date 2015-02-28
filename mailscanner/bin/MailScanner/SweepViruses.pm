#
#   MailScanner - SMTP E-Mail Virus Scanner
#   Copyright (C) 2002  Julian Field
#
#   $Id: SweepViruses.pm 5086 2011-03-16 19:37:02Z sysjkf $
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#   The author, Julian Field, can be contacted by email at
#      Jules@JulianField.net
#   or by paper mail at
#      Julian Field
#      Dept of Electronics & Computer Science
#      University of Southampton
#      Southampton
#      SO17 1BJ
#      United Kingdom
#

package MailScanner::SweepViruses;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use POSIX qw(:signal_h setsid); # For Solaris 9 SIG bug workaround
use DirHandle;
use IO::Socket::INET;
use IO::Socket::UNIX;

use vars qw($VERSION $ScannerPID);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5086 $, 10;

# Locking definitions for flock() which is used to lock the Lock file
my($LOCK_SH) = 1;
my($LOCK_EX) = 2;
my($LOCK_NB) = 4;
my($LOCK_UN) = 8;

# Sophos SAVI Library object and ide directory modification time
my($SAVI, $SAVIidedirmtime, $SAVIlibdirmtime, $SAVIinuse, %SAVIwatchfiles);
$SAVIidedirmtime = 0;
$SAVIlibdirmtime = 0;
$SAVIinuse       = 0;
%SAVIwatchfiles  = ();
# ClamAV Module object and library directory modification time
my($Clam, $Claminuse, %Clamwatchfiles);
$Claminuse       = 0;
%Clamwatchfiles  = ();
# So we can kill virus scanners when we are HUPped
$ScannerPID = 0;
my $scannerlist = "";



#
# Virus scanner definitions table
#
my (
    $S_NONE,         # Not present
    $S_UNSUPPORTED,  # Present but you're on your own
    $S_ALPHA,        # Present but not tested -- we hope it works!
    $S_BETA,         # Present and tested to some degree -- we think it works!
    $S_SUPPORTED,    # People use this; it'd better work!
   ) = (0,1,2,3,4);

my %Scanners = (
  generic => {
    Name		=> 'Generic',
    Lock		=> 'genericBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '-disinfect',
    ScanOptions		=> '',
    InitParser		=> \&InitGenericParser,
    ProcessOutput	=> \&ProcessGenericOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_NONE,
  },
  sophossavi => {
    Name		=> 'SophosSAVI',
    Lock		=> 'sophosBusy.lock',
    # In next line, '-ss' makes it work nice and quietly
    CommonOptions	=> '',
    DisinfectOptions	=> '',
    ScanOptions		=> '',
    InitParser		=> \&InitSophosSAVIParser,
    ProcessOutput	=> \&ProcessSophosSAVIOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_NONE,
  },
  sophos => {
    Name		=> 'Sophos',
    Lock		=> 'sophosBusy.lock',
    # In next line, '-ss' makes it work nice and quietly
    CommonOptions	=> '-sc -f -all -rec -ss -archive -cab -loopback ' .
                           '--no-follow-symlinks --no-reset-atime -TNEF',
    DisinfectOptions	=> '-di',
    ScanOptions		=> '',
    InitParser		=> \&InitSophosParser,
    ProcessOutput	=> \&ProcessSophosOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  mcafee		=> {
    Name		=> 'McAfee',
    Lock		=> 'mcafeeBusy.lock',
    CommonOptions	=> '--recursive --ignore-links --analyze --mime ' .
                           '--secure --noboot',
    DisinfectOptions	=> '--clean',
    ScanOptions		=> '',
    InitParser		=> \&InitMcAfeeParser,
    ProcessOutput	=> \&ProcessMcAfeeOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  mcafee6		=> {
    Name		=> 'McAfee6',
    Lock		=> 'mcafee6Busy.lock',
    CommonOptions	=> '--recursive --ignore-links --analyze --mime ' .
                           '--secure --noboot',
    DisinfectOptions	=> '--clean',
    ScanOptions		=> '',
    InitParser		=> \&InitMcAfee6Parser,
    ProcessOutput	=> \&ProcessMcAfee6Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  command		=> {
    Name		=> 'Command',
    Lock		=> 'commandBusy.lock',
    CommonOptions	=> '-packed -archive',
    DisinfectOptions	=> '-disinf',
    ScanOptions		=> '',
    InitParser		=> \&InitCommandParser,
    ProcessOutput	=> \&ProcessCommandOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  etrust	=> {
    Name		=> 'eTrust',
    Lock		=> 'etrustBusy.lock',
    CommonOptions	=> '-nex -arc -mod reviewer -spm h ',
    DisinfectOptions	=> '-act cure -sca mf',
    ScanOptions		=> '',
    InitParser		=> \&InitInoculateParser,
    ProcessOutput	=> \&ProcessInoculateOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  inoculate	=> {
    Name		=> 'Inoculate',
    Lock		=> 'inoculateBusy.lock',
    CommonOptions	=> '-nex -arc -mod reviewer -spm h ',
    DisinfectOptions	=> '-act cure -sca mf',
    ScanOptions		=> '',
    InitParser		=> \&InitInoculateParser,
    ProcessOutput	=> \&ProcessInoculateOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  inoculan	=> {
    Name		=> 'Inoculan',
    Lock		=> 'inoculanBusy.lock',
    CommonOptions	=> '-nex -rev ',
    DisinfectOptions	=> '-nex -cur',
    ScanOptions		=> '',
    InitParser		=> \&InitInoculanParser,
    ProcessOutput	=> \&ProcessInoculanOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "kaspersky-4.5"	=> {
    Name		=> 'Kaspersky',
    Lock		=> 'kasperskyBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '-i2',
    ScanOptions		=> '-i0',
    InitParser		=> \&InitKaspersky_4_5Parser,
    ProcessOutput	=> \&ProcessKaspersky_4_5Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  kaspersky	=> {
    Name		=> 'Kaspersky',
    Lock		=> 'kasperskyBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '-- -I2',
    ScanOptions		=> '-I0',
    InitParser		=> \&InitKasperskyParser,
    ProcessOutput	=> \&ProcessKasperskyOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  kavdaemonclient	=> {
    Name		=> 'KavDaemon',
    Lock		=> 'kasperskyBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '-- -I2',
    ScanOptions		=> '',
    InitParser		=> \&InitKavDaemonClientParser,
    ProcessOutput	=> \&ProcessKavDaemonClientOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_NONE,
  },
  "f-secure"	=> {
    Name		=> 'F-Secure',
    Lock		=> 'f-secureBusy.lock',
    CommonOptions	=> '--dumb --archive',
    DisinfectOptions	=> '--auto --disinf',
    ScanOptions		=> '',
    InitParser		=> \&InitFSecureParser,
    ProcessOutput	=> \&ProcessFSecureOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "f-prot"	=> {
    Name		=> 'F-Prot',
    Lock		=> 'f-protBusy.lock',
    CommonOptions	=> '-old -archive -dumb',
    DisinfectOptions	=> '-disinf -auto',
    ScanOptions		=> '',
    InitParser		=> \&InitFProtParser,
    ProcessOutput	=> \&ProcessFProtOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "f-prot-6"	=> {
    Name		=> 'F-Prot6',
    Lock		=> 'f-prot-6Busy.lock',
    CommonOptions	=> '-s 4 --adware',
    DisinfectOptions	=> '--disinfect --macros_safe',
    ScanOptions		=> '--report',
    InitParser		=> \&InitFProt6Parser,
    ProcessOutput	=> \&ProcessFProt6Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "f-protd-6"	=> {
    Name		=> 'F-Protd6',
    Lock		=> 'f-prot-6Busy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '',
    ScanOptions		=> '',
    InitParser		=> \&InitFProtd6Parser,
    ProcessOutput	=> \&ProcessFProtd6Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_NONE,
  },
  nod32		=> {
    Name		=> 'Nod32',
    Lock		=> 'nod32Busy.lock',
    CommonOptions	=> '-log- -all',
    DisinfectOptions	=> '-clean -delete',
    ScanOptions		=> '',
    InitParser		=> \&InitNOD32Parser,
    ProcessOutput	=> \&ProcessNOD32Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "nod32-1.99"		=> {
    Name		=> 'Nod32',
    Lock		=> 'nod32Busy.lock',
    CommonOptions	=> '--arch --all -b',
    DisinfectOptions	=> '--action clean --action-uncl none',
    ScanOptions		=> '',
    InitParser		=> \&InitNOD32199Parser,
    ProcessOutput	=> \&ProcessNOD32Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "antivir"	=> {
    Name		=> 'AntiVir',
    Lock		=> 'antivirBusy.lock',
    CommonOptions	=> '-allfiles -s -noboot -rs -z',
    DisinfectOptions	=> '-e -ren',
    ScanOptions		=> '',
    InitParser		=> \&InitAntiVirParser,
    ProcessOutput	=> \&ProcessAntiVirOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "panda"	=> {
    Name		=> 'Panda',
    Lock                => 'pandaBusy.lock',
    CommonOptions       => '-nor -nos -nob -heu -eng -aex -auto -cmp',
    DisinfectOptions    => '-clv',
    ScanOptions         => '-nor',
    InitParser          => \&InitPandaParser,
    ProcessOutput       => \&ProcessPandaOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "rav"	=> {
    Name		=> 'Rav',
    Lock		=> 'ravBusy.lock',
    CommonOptions	=> '--all --mail --archive',
    DisinfectOptions	=> '--clean',
    ScanOptions		=> '',
    InitParser		=> \&InitRavParser,
    ProcessOutput	=> \&ProcessRavOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "clamavmodule" => {
    Name                => 'ClamAVModule',
    Lock                => 'clamavBusy.lock',
    CommonOptions       => '',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitClamAVModParser,
    ProcessOutput       => \&ProcessClamAVModOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "clamd"  => {
    Name                => 'Clamd',
    Lock                => 'clamavBusy.lock',
    CommonOptions       => '',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitClamAVModParser,
    ProcessOutput       => \&ProcessClamAVModOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "clamav"  => {
    Name		=> 'ClamAV',
    Lock                => 'clamavBusy.lock',
    CommonOptions       => '-r --no-summary --stdout',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitClamAVParser,
    ProcessOutput       => \&ProcessClamAVOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "trend"   => {
    Name		=> 'Trend',
    Lock                => 'trendBusy.lock',
    CommonOptions       => '-a -za -r',
    DisinfectOptions    => '-c',
    ScanOptions         => '',
    InitParser          => \&InitTrendParser,
    ProcessOutput       => \&ProcessTrendOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "bitdefender"   => {
    Name		=> 'Bitdefender',
    Lock                => 'bitdefenderBusy.lock',
    CommonOptions       => '--arc --mail --all',
    DisinfectOptions    => '--disinfect',
    ScanOptions         => '',
    InitParser          => \&InitBitdefenderParser,
    ProcessOutput       => \&ProcessBitdefenderOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "drweb"   => {
    Name		=> 'DrWeb',
    Lock                => 'drwebBusy.lock',
    CommonOptions       => '-ar -fm -ha- -fl- -ml -sd -up',
    DisinfectOptions    => '-cu',
    ScanOptions         => '',
    InitParser          => \&InitDrwebParser,
    ProcessOutput       => \&ProcessDrwebOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "norman"   => {
    Name		=> 'Norman',
    Lock                => 'normanBusy.lock',
    CommonOptions       => '-c -sb:1 -s -u',
    DisinfectOptions    => '-cl:2',
    ScanOptions         => '',
    InitParser          => \&InitNormanParser,
    ProcessOutput       => \&ProcessNormanOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "css" => {
    Name                => 'SYMCScan',
    Lock                => 'symscanengineBusy.lock',
    CommonOptions       => '',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitCSSParser,
    ProcessOutput       => \&ProcessCSSOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "avg"   => {
    Name                => 'Avg',
    Lock                => 'avgBusy.lock',
    CommonOptions       => '--arc', # Remove by Chris Richardson:  -ext=*',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitAvgParser,
    ProcessOutput       => \&ProcessAvgOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "vexira"   => {
    Name                => 'Vexira',
    Lock                => 'vexiraBusy.lock',
    #CommonOptions       => '--allfiles -s -z -noboot -nombr -r1 -rs -lang=EN --alltypes',
    #DisinfectOptions    => '-e',
    CommonOptions       => '-qq --scanning=full',
    DisinfectOptions    => '--remove-macro --action=kill',
    ScanOptions         => '--action=skip',
    InitParser          => \&InitVexiraParser,
    ProcessOutput       => \&ProcessVexiraOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "symscanengine"	=> {
    Name		=> 'SymantecScanEngine',
    Lock		=> 'symscanengineBusy.lock',
    CommonOptions	=> '-details -recurse',
    DisinfectOptions	=> '-mode scanrepair',
    ScanOptions		=> '-mode scan',
    InitParser		=> \&InitSymScanEngineParser,
    ProcessOutput	=> \&ProcessSymScanEngineOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "avast"		=> {
    Name		=> 'Avast',
    Lock		=> 'avastBusy.lock',
    CommonOptions	=> '-n -t=A',
    DisinfectOptions	=> '-p=3',
    ScanOptions		=> '',
    InitParser		=> \&InitAvastParser,
    ProcessOutput	=> \&ProcessAvastOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "avastd"		=> {
    Name		=> 'AvastDaemon',
    Lock		=> 'avastBusy.lock',
    CommonOptions	=> '-n',
    DisinfectOptions	=> '',
    ScanOptions		=> '',
    InitParser		=> \&InitAvastdParser,
    ProcessOutput	=> \&ProcessAvastdOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "esets"		=> {
    Name		=> 'esets',
    Lock		=> 'esetsBusy.lock',
    CommonOptions	=> '--arch --subdir',
    DisinfectOptions	=> '--action clean',
    ScanOptions		=> '--action none',
    InitParser		=> \&InitesetsParser,
    ProcessOutput	=> \&ProcessesetsOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "vba32"		=> {
    Name		=> 'vba32',
    Lock		=> 'vba32Busy.lock',
    CommonOptions	=> '-ok- -af+ -ar+ -ha+ -ml+ -rw+ -qu+',
    DisinfectOptions	=> '-fc+',
    ScanOptions		=> '',
    InitParser		=> \&Initvba32Parser,
    ProcessOutput	=> \&Processvba32Output,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "none"		=> {
    Name		=> 'None',
    Lock		=> 'NoneBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '',
    ScanOptions		=> '',
    InitParser		=> \&NeverHappens,
    ProcessOutput	=> \&NeverHappens,
    SupportScanning	=> $S_NONE,
    SupportDisinfect	=> $S_NONE,
  },
);

# Initialise the Sophos SAVI library if we are using it.
sub initialise {
  my(@scanners);
  $scannerlist = MailScanner::Config::Value('virusscanners');

  # If they have not configured the list of virus scanners, then try to
  # use all the scanners they have installed, by using the same system
  # that update_virus_scanners uses to locate them all.
  #print STDERR "Scanner list read from MailScanner.conf is \"$scannerlist\"\n";
  if ($scannerlist =~ /^\s*auto\s*$/i) {
    # If we have multiple clam types, then tend towards clamd
    my %installed = map { $_ => 1 } InstalledScanners();
    delete $installed{'clamavmodule'} if $installed{'clamavmodule'} &&
                                         $installed{'clamd'};
    delete $installed{'clamav'}       if $installed{'clamav'} &&
                                         ($installed{'clamd'} ||
                                          $installed{'clamavmodule'});
    $scannerlist = join(' ', keys %installed);
    MailScanner::Log::InfoLog("I have found %s scanners installed, and will use them all by default.", $scannerlist);
    if ($scannerlist =~ /^\s*$/) {
      MailScanner::Log::WarnLog("You appear to have no virus scanners installed at all! This is not good. If you have installed any, then check your virus.scanners.conf file to make sure the locations of your scanners are correct");
      #print STDERR "No virus scanners found to be installed at all!\n";
      $scannerlist = "none";
    }
  }


  $scannerlist =~ tr/,//d;
  @scanners = split(" ", $scannerlist);
  # Import the SAVI code and initialise the SAVI library
  if (grep /^sophossavi$/, @scanners) {
    $SAVIinuse = 1;
    #print STDERR "SAVI in use\n";
    InitialiseSAVI();
  }
  # Import the ClamAV code and initialise the ClamAV library
  if (grep /^clamavmodule$/, @scanners) {
    $Claminuse = 1;
    #print STDERR "ClamAV Module in use\n";
    InitialiseClam();
  }
  # Set the Unrar command path for the ClamAV code
  #if (grep /^clamav$/, @scanners) {
  #  my $rarcmd = MailScanner::Config::Value('unrarcommand');
  #  if ($rarcmd && -x $rarcmd) {
  #    $Scanners{clamav}->{CommonOptions} .= " --unrar=$rarcmd";
  #    MailScanner::Log::InfoLog("ClamAV scanner using unrar command %s",
  #                              $rarcmd);
  #  }
  #}
}

sub InitialiseClam {
  # Initialise ClamAV Module
  MailScanner::Log::DieLog("ClamAV Perl module not found, did you install it?")
    unless eval 'require Mail::ClamAV';

  my $ver = $Mail::ClamAV::VERSION + 0.0;
  MailScanner::Log::DieLog("ClamAV Perl module must be at least version 0.12" .
                           " and you only have version %.2f, and ClamAV must" .
                           " be at least version 0.80", $ver)
    unless $ver >= 0.12;

  $Clam = new Mail::ClamAV(Mail::ClamAV::retdbdir())
    or MailScanner::Log::DieLog("ClamAV Module ERROR:: Could not load " .
       "databases from %s", Mail::ClamAV::retdbdir());
  $Clam->buildtrie;
  # Impose limits
  $Clam->maxreclevel(MailScanner::Config::Value('clamavmaxreclevel'));
  $Clam->maxfiles   (MailScanner::Config::Value('clamavmaxfiles'));
  $Clam->maxfilesize(MailScanner::Config::Value('clamavmaxfilesize'));
  #0.93 $Clam->maxratio   (MailScanner::Config::Value('clamavmaxratio'));


  # Build the hash of the size of all the watch files
  my(@watchglobs, $glob, @filelist, $file, $filecount);
  @watchglobs = split(" ", MailScanner::Config::Value('clamwatchfiles'));
  $filecount = 0;
  foreach $glob (@watchglobs) {
    @filelist = map { m/(.*)/ } glob($glob);
    foreach $file (@filelist) {
      $Clamwatchfiles{$file} = -s $file;
      $filecount++;
    }
  }
  MailScanner::Log::DieLog("None of the files matched by the \"Monitors " .
    "For ClamAV Updates\" patterns exist!") unless $filecount>0;

  #MailScanner::Log::WarnLog("\"Allow Password-Protected Archives\" should be set to just yes or no when using clamavmodule virus scanner")
  #  unless MailScanner::Config::IsSimpleValue('allowpasszips');
}


sub InitialiseSAVI {
  # Initialise Sophos SAVI library
  MailScanner::Log::DieLog("SAVI Perl module not found, did you install it?")
    unless eval 'require SAVI';

  my $SAVIidedir = MailScanner::Config::Value('sophoside');
  $SAVIidedir = '/usr/local/Sophos/ide' unless $SAVIidedir;
  my $SAVIlibdir = MailScanner::Config::Value('sophoslib');
  $SAVIlibdir = '/usr/local/Sophos/lib' unless $SAVIlibdir;

  $ENV{'SAV_IDE'} = $SAVIidedir;
  print "INFO:: Meaningless output that goes nowhere, to keep SAVI happy\n";
  $SAVI = new SAVI();
  MailScanner::Log::DieLog("SophosSAVI ERROR:: initializing savi: %s (%s)",
                           SAVI->error_string($SAVI), $SAVI)
    unless ref $SAVI;
  my $version = $SAVI->version();
  MailScanner::Log::DieLog("SophosSAVI ERROR:: getting version: %s (%s)",
                           $SAVI->error_string($version), $version)
    unless ref $version;
  MailScanner::Log::InfoLog("SophosSAVI %s (engine %d.%d) recognizing " .
                            "%d viruses", $version->string, $version->major,
                            $version->minor, $version->count);
  my($ide,$idecount);
  $idecount = 0;
  foreach $ide ($version->ide_list) {
    #MailScanner::Log::InfoLog("SophosSAVI IDE %s released %s",
    #                          $ide->name, $ide->date);
    $idecount++;
  }
  MailScanner::Log::InfoLog("SophosSAVI using %d IDE files", $idecount);

  # I have removed "Mac" and "SafeMacDfHandling" from here as setting
  # them gives an error.
  my @options = qw(
      FullSweep DynamicDecompression FullMacroSweep OLE2Handling
      IgnoreTemplateBit VBA3Handling VBA5Handling OF95DecryptHandling
      HelpHandling DecompressVBA5 Emulation PEHandling ExcelFormulaHandling
      PowerPointMacroHandling PowerPointEmbeddedHandling ProjectHandling
      ZipDecompression ArjDecompression RarDecompression UueDecompression
      GZipDecompression TarDecompression CmzDecompression HqxDecompression
      MbinDecompression !LoopBackEnabled
      Lha SfxArchives MSCabinet TnefAttachmentHandling MSCompress
      !DeleteAllMacros Vbe !ExecFileDisinfection VisioFileHandling
      Mime ActiveMimeHandling !DelVBA5Project
      ScrapObjectHandling SrpStreamHandling Office2001Handling
      Upx PalmPilotHandling HqxDecompression
      Pdf Rtf Html Elf WordB OutlookExpress
    );
  my $error = $SAVI->set('MaxRecursionDepth', 30, 1);
  MailScanner::Log::DieLog("SophosSAVI ERROR:: setting MaxRecursionDepth:" .
                           " %s", $error) if defined $error;
  foreach (@options) {
    my $value = ($_ =~ s/^!//) ? 0 : 1;
    $error = $SAVI->set($_, $value);
    MailScanner::Log::WarnLog("SophosSAVI ERROR:: Setting %s: %s", $_, $error)
      if defined $error;
  }

  ## Store the last modified time of the SAVI lib directory, so we can check
  ## for major upgrades
  my(@statresults);
  #@statresults = stat($SAVIidedir);
  #$SAVIidedirmtime = $statresults[9] or
  # MailScanner::Log::WarnLog("Failed to read mtime of IDE dir %s",$SAVIidedir);
  @statresults = stat($SAVIlibdir);
  $SAVIlibdirmtime = $statresults[9] or
    MailScanner::Log::WarnLog("Failed to read mtime of lib dir %s",$SAVIlibdir);
  #MailScanner::Log::InfoLog("Watching modification date of %s and %s",
  #                          $SAVIidedir, $SAVIlibdir);

  # Build the hash of the size of all the watch files
  my(@watchglobs, $glob, @filelist, $file, $filecount);
  @watchglobs = split(" ", MailScanner::Config::Value('saviwatchfiles'));
  $filecount = 0;
  foreach $glob (@watchglobs) {
    @filelist = map { m/(.*)/ } glob($glob);
    foreach $file (@filelist) {
      $SAVIwatchfiles{$file} = -s $file;
      $filecount++;
    }
  }
  MailScanner::Log::DieLog("None of the files matched by the \"Monitors " .
    "For Sophos Updates\" patterns exist!") unless $filecount>0;
}

# Are there new Sophos IDE files?
# If so, abandon this child process altogether and start again.
# This is called from the main WorkForHours() loop
#
# If the lib directory has been updated, then a major Sophos update has
# happened. If the watch files have changed their size at all, or any
# of them have disappeared, then an IDE updated has happened.
# Normally just watch /u/l/S/ide/*.zip.
#
sub SAVIUpgraded {
  my(@result, $idemtime, $libmtime, $watch, $size);

  # If we aren't even using SAVI, then obviously we don't want to restart
  return 0 unless $SAVIinuse;

  #@result = stat(MailScanner::Config::Value('sophoside') ||
  #               '/usr/local/Sophos/ide');
  #$idemtime = $result[9];
  @result = stat(MailScanner::Config::Value('sophoslib') ||
                 '/usr/local/Sophos/lib');
  $libmtime = $result[9];

  #if ($idemtime != $SAVIidedirmtime || $libmtime != $SAVIlibdirmtime) {
  if ($libmtime != $SAVIlibdirmtime) {
    MailScanner::Log::InfoLog("Sophos library update detected, " .
                              "resetting SAVI");
    return 1;
  }

  while (($watch, $size) = each %SAVIwatchfiles) {
    if ($size != -s $watch) {
      MailScanner::Log::InfoLog("Sophos update of $watch detected, " .
                                "resetting SAVI");
      keys %SAVIwatchfiles; # Necessary line to reset each()
      return 1;
    }
  }

  # No update detected
  return 0;
}

# Have the ClamAV database files been modified? (changed size)
# If so, abandon this child process altogether and start again.
# This is called from the main WorkForHours() loop
#
sub ClamUpgraded {
  my($watch, $size);

  return 0 unless $Claminuse;

  while (($watch, $size) = each %Clamwatchfiles) {
    if ($size != -s $watch) {
      MailScanner::Log::InfoLog("ClamAV update of $watch detected, " .
                                "resetting ClamAV Module");
      keys %Clamwatchfiles; # Necessary line to reset each()
      return 1;
    }
  }

  # No update detected
  return 0;
}



# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  #$this->{dir} = shift;

  bless $this, $type;
  return $this;
}

# Do all the commercial virus checking in here.
# If 2nd parameter is "disinfect", then we are disinfecting not scanning.
sub ScanBatch {
  my $batch = shift;
  my $ScanType = shift;

  my($NumInfections, $success, $id, $BaseDir);
  my(%Types, %Reports);
  #%Types = ();   # Create the has structure
  #%Reports = (); # for each one.

  $NumInfections = 0;
  $BaseDir = $global::MS->{work}->{dir};

  chdir $BaseDir or die "Cannot chdir $BaseDir for virus scanning, $!";

  #print STDERR (($ScanType =~ /dis/i)?"Disinfecting":"Scanning") . " using ".
  #             "commercial virus scanners\n";
  $success = TryCommercial($batch, '.', $BaseDir, \%Reports, \%Types,
                           \$NumInfections, $ScanType);
  #print STDERR "Found $NumInfections infections\n";
  if ($success eq 'ScAnNeRfAiLeD') {
    # Delete all the messages from this batch as if we weren't scanning
    # them, and reject the batch.
    MailScanner::Log::WarnLog("Virus Scanning: No virus scanners worked, so message batch was abandoned and re-tried!");
    $batch->DropBatch();
    return 1;
  } 
  unless ($success) {
    # Virus checking the whole batch of messages timed out, so now check them
    # one at a time to find the one with the DoS attack in it.
    my $BaseDirH = new DirHandle;
    MailScanner::Log::WarnLog("Virus Scanning: Denial Of Service attack " .
                              "detected!");
    $BaseDirH->open('.') 
      or MailScanner::Log::DieLog("Can't open directory for scanning 1 message, $!");
    while(defined($id = $BaseDirH->read())) {
      next unless -d "$id";   # Only check directories
      next if $id =~ /^\.+$/; # Don't check myself or my parent
      $id =~ /^(.*)$/;
      $id = $1;
      next unless MailScanner::Config::Value('virusscan',$batch->{messages}{id}) =~ /1/;
      # The "./" is important as it gets the path right for parser code
      $success = TryCommercial($batch, "./$id", $BaseDir, \%Reports,
                               \%Types, \$NumInfections, $ScanType);
      # If none of the scanners worked, then we need to abandon this batch
      if ($success eq 'ScAnNeRfAiLeD') {
        # Delete all the messages from this batch as if we weren't scanning
        # them, and reject the batch.
        MailScanner::Log::WarnLog("Virus Scanning: No virus scanners worked, so message batch was abandoned and re-tried!");
        $batch->DropBatch();
        last;
      } 

      unless ($success) {
        # We have found the DoS attack message
        $Reports{"$id"}{""} .=
          MailScanner::Config::LanguageValue($batch->{messages}{$id},
                                             'dosattack') . "\n";
        $Types{"$id"}{""}   .= "d";
        MailScanner::Log::WarnLog("Virus Scanning: Denial Of Service " .
                                  "attack is in message %s", $id);
        # No way here of incrementing the "otherproblems" counter. Ho hum.
      }
    }
    $BaseDirH->close();
  }

  # Add all the %Reports and %Types to the message batch fields
  MergeReports(\%Reports, \%Types, $batch);

  # Return value is the number of infections we found
  #print STDERR "Found $NumInfections infections!\n";
  return $NumInfections;
}


# Merge all the virus reports and types into the properties of the
# messages in the batch. Doing this separately saves me changing
# the code of all the parsers to support the new OO structure.
# If we have at least 1 report for a message, and the "silent viruses" list
# includes the special keyword "All-Viruses" then mark the message as silent
# right now.
sub MergeReports {
  my($Reports, $Types, $batch) = @_;

  my($id, $reports, $attachment, $text);
  my($cachedid, $cachedsilentflag);
  my(%seenbefore);

  # Let's do all the reports first...
  $cachedid = 'uninitialised';
  while (($id, $reports) = each %$Reports) {
    #print STDERR "Report merging for \"$id\" and \"$reports\"\n";
    next unless $id && $reports;
    my $message = $batch->{messages}{"$id"};
    # Skip this message if we didn't actually want it to be scanned.
    next unless MailScanner::Config::Value('virusscan', $message) =~ /1/;
    #print STDERR "Message is $message\n";
    $message->{virusinfected} = 1;

    # If the cached message id matches the current one, we are working on
    # the same message as last time, so don't re-fetch the silent viruses
    # list for this message.
    if ($cachedid ne $id) {
      my $silentlist = ' ' . MailScanner::Config::Value('silentviruses',
                       $message) . ' ';
      $cachedsilentflag = ($silentlist =~ / all-viruses /i)?1:0;
      $cachedid = $id;
    }
    # We can't be here unless there was a virus report for this message
    $message->{silent} = 1 if $cachedsilentflag;

    while (($attachment, $text) = each %$reports) {
      #print STDERR "\tattachment \"$attachment\" has text \"$text\"\n";
      #print STDERR "\tEntity of \"$attachment\" is \"" . $message->{file2entity} . "\"\n";
      next unless $text;

      # Sanitise the reports a bit
      $text =~ s/\s{20,}/ /g;
      $message->{virusreports}{"$attachment"} .= $text;
    }
    unless ($seenbefore{$id}) {
      MailScanner::Log::NoticeLog("Infected message %s came from %s",
                                $id, $message->{clientip});
      $seenbefore{$id} = 1;
    }
  }

  # And then all the report types...
  while (($id, $reports) = each %$Types) {
    next unless $id && $reports;
    my $message = $batch->{messages}{"$id"};
    while (($attachment, $text) = each %$reports) {
      next unless $text;
      $message->{virustypes}{"$attachment"} .= $text;
    }
  }
}


# Try all the installed commercial virus scanners
# We are passed the directory to start scanning from,
#               the message batch we are scanning,
#               a ref to the infections counter.
# $ScanType can be one of "scan", "rescan", "disinfect".
sub TryCommercial {
  my($batch, $dir, $BaseDir, $Reports, $Types, $rCounter, $ScanType) = @_;

  my($scanner, @scanners, $disinfect, $result, $counter);
  my($logtitle, $OneScannerWorked);

  # If we aren't virus scanning *anything* then don't call the scanner
  return 1 if MailScanner::Config::IsSimpleValue('virusscan') &&
              !MailScanner::Config::Value('virusscan');

  # $scannerlist is now a global for this file. If it was set to "auto"
  # then I will have searched for all the scanners that appear to be
  # installed. So by the time we get here, it should never be "auto" either.
  # Unless of course they really have no scanners installed at all!
  #$scannerlist = MailScanner::Config::Value('virusscanners');
  $scannerlist =~ tr/,//d;
  $scannerlist = "none" unless $scannerlist; # Catch empty setting
  @scanners = split(" ", $scannerlist);
  $counter = 0;

  # Change actions and outputs depending on what we are trying to do
  $disinfect = 0;
  $disinfect = 1 if $ScanType !~ /scan/i;
  $logtitle = "Virus Scanning";
  $logtitle = "Virus Re-scanning"  if $ScanType =~ /re/i;  # Rescanning
  $logtitle = "Disinfection" if $ScanType =~ /dis/i; # Disinfection

  # Work out the regexp for matching the spam-infected messages
  # This is given by the user as a space-separated list of simple wildcard
  # strings. Must split it up, escape everything, spot the * characters
  # and join them together into one big regexp. Use lots of tricks from the
  # Phishing regexp generator I wrote a month or two back.
  my $spaminfsetting = MailScanner::Config::Value('spaminfected');
  #$spaminfsetting = '*UNOFFICIAL HTML/* Sanesecurity.*'; # Test data
  $spaminfsetting =~ s/\s+/ /g; # Squash multiple spaces
  $spaminfsetting =~ s/^\s+//; # Trim leading and
  $spaminfsetting =~ s/\s+$//; # trailing space.
  $spaminfsetting =~ s/\s/ /g; # All tabs to spaces
  $spaminfsetting =~ s/[^0-9a-z_ -]/\\$&/ig; # Quote every non-alnum except space.
  $spaminfsetting =~ s/\\\*/.*/g; # Unquote any '*' characters as they map to .*
  my @spaminfwords = split " ", $spaminfsetting;
  # Combine all the words into an "or" list in a fast regexp,
  # and anchor them all to the start and end of the string.
  my $spaminfre   = '(?:^\s*' . join('\s*$|^\s*', @spaminfwords) . '\s*$)';

  $OneScannerWorked = 0;
  foreach $scanner (@scanners) {
    my $r1Counter = 0;
    #print STDERR "Trying One Commercial: $scanner\n";
    $result = TryOneCommercial($scanner,
                               MailScanner::Config::ScannerCmds($scanner),
                               $batch, $dir, $BaseDir, $Reports, $Types,
                               \$r1Counter, $disinfect, $spaminfre);
    # If all the scanners failed, we flag it and abandon the batch.
    # If even just one of them worked, we carry on.
    if ($result ne 'ScAnNeRfAiLeD') {
      $OneScannerWorked = 1;
    }
    unless ($result) {
      MailScanner::Log::WarnLog("%s: Failed to complete, timed out", $scanner);
      return 0;
    }
    $counter += $result;
    MailScanner::Log::NoticeLog("%s: %s found %d infections", $logtitle,
                                $Scanners{$scanner}{Name}, $r1Counter)
      if $r1Counter;
    # Update the grand total of viruses found
    $$rCounter += $r1Counter;
  }

  # If none of the scanners worked, then reject this batch.
  if (!$OneScannerWorked) {
    return 'ScAnNeRfAiLeD';
  }

  return $counter;
}

# Try one of the commercial virus scanners
sub TryOneCommercial {
  my($scanner, $sweepcommandAndPath, $batch, $subdir, $BaseDir,
     $Reports, $Types, $rCounter, $disinfect, $spaminfre) = @_;

  my($sweepcommand, $instdir, $ReportScanner);
  my($rScanner, $VirusLock, $voptions, $Name);
  my($Counter, $TimedOut, $PipeReturn, $pid);
  my($ScannerFailed);

  MailScanner::Log::DieLog("Virus scanner \"%s\" not found " .
                           "in virus.scanners.conf file. Please check your " .
                           "spelling in \"Virus Scanners =\" line of " .
                           "MailScanner.conf", $scanner)
    if $sweepcommandAndPath eq "";

  # Split the sweepcommandAndPath into its 2 elements
  $sweepcommandAndPath =~ /^([^,\s]+)[,\s]+([^,\s]+)$/
    or MailScanner::Log::DieLog("Your virus.scanners.conf file does not " .
                                " have 3 words on each line. See if you " .
                                " have an old one left over by mistake.");
  ($sweepcommand, $instdir) = ($1, $2);

  MailScanner::Log::DieLog("Never heard of scanner '$scanner'!")
    unless $sweepcommand;

  $rScanner = $Scanners{$scanner};

  # November 2008: Always log the scanner name, strip it from the reports
  #                if the user doesn't want it.
  # If they want the scanner name, then set it to non-blank
  $Name = $rScanner->{"Name"}; # if MailScanner::Config::Value('showscanner');
  $ReportScanner = MailScanner::Config::Value('showscanner');

  if ($rScanner->{"SupportScanning"} == $S_NONE){
    MailScanner::Log::DebugLog("Scanning using scanner \"$scanner\" " .
                               "not supported; not scanning");
    return 1;
  }

  if ($disinfect && $rScanner->{"SupportDisinfect"} == $S_NONE){
    MailScanner::Log::DebugLog("Disinfection using scanner \"$scanner\" " .
                               "not supported; not disinfecting");
    return 1;
  }

  CheckCodeStatus($rScanner->{$disinfect?"SupportDisinfect":"SupportScanning"})
    or MailScanner::Log::DieLog("Bad return code from CheckCodeStatus - " .
                                "should it have quit?");

  $VirusLock = MailScanner::Config::Value('lockfiledir') . "/" .
               $rScanner->{"Lock"}; # lock file
  $voptions  = $rScanner->{"CommonOptions"}; # Set common command line options

  # Add the configured value for scanner time outs  to the command line
  # if the scanner is  Panda
  $voptions .= " -t:".MailScanner::Config::Value('virusscannertimeout')
  				if $rScanner->{"Name"} eq 'Panda';

  # Add command line options to "scan only", or to disinfect
  $voptions .= " " . $rScanner->{$disinfect?"DisinfectOptions":"ScanOptions"};
  &{$$rScanner{"InitParser"}}($BaseDir, $batch); # Initialise scanner-specific parser

  my $Lock = new FileHandle;
  my $Kid  = new FileHandle;
  my $pipe;

  # Check that the virus checker files aren't currently being updated,
  # and wait if they are.
  if (open($Lock, ">$VirusLock")) {
    print $Lock  "Virus checker locked for " .
          ($disinfect?"disinfect":"scann") . "ing by $scanner $$\n";
  } else {
    #The lock file already exists, so just open for reading
    open($Lock, "<$VirusLock")
      or MailScanner::Log::WarnLog("Cannot lock $VirusLock, $!");
  }
  flock($Lock, $LOCK_SH);

  MailScanner::Log::DebugLog("Commencing " .
        ($disinfect?"disinfect":"scann") . "ing by $scanner...");

  $disinfect = 0 unless $disinfect; # Make sure it's not undef

  $TimedOut = 0;
  eval {
    $pipe = $disinfect?'|-':'-|';
    die "Can't fork: $!" unless defined($pid = open($Kid, $pipe));
    if ($pid) {
      # In the parent
      local $SIG{ALRM} = sub { $TimedOut = 1; die "Command Timed Out" };
      alarm MailScanner::Config::Value('virusscannertimeout');
      $ScannerPID = $pid;
      # Only process the output if we are scanning, not disinfecting
      if ($disinfect) {
        # Tell sweep to disinfect all files
        print $Kid "A\n" if $scanner eq 'sophos';
        #print STDERR "Disinfecting...\n";
      } else {
        my($ScannerOutput, $line);
        while(defined ($line = <$Kid>)) {
          # Note: this is a change in the spec for all the parsers
          if ($line =~ /^ScAnNeRfAiLeD/) {
            # The virus scanner failed for some reason, remove this batch
            $ScannerFailed = 1;
            last;
          }

          $ScannerOutput = &{$$rScanner{"ProcessOutput"}}($line, $Reports,
                                                     $Types, $BaseDir, $Name,
                                                     $spaminfre);
          #print STDERR "Processing line \"$_\" produced $Counter\n";
          if ($ScannerOutput eq 'ScAnNeRfAiLeD') {
            $ScannerFailed = 1;
            last;
          }
          $Counter += $ScannerOutput if $ScannerOutput > 0;
          #print STDERR "Counter = \"$Counter\"\n";

          # 20090730 Add support for spam-viruses, ie. spam reported as virus
          #print STDERR "ScannerOutput = \"$ScannerOutput\"\n";
          if ($ScannerOutput =~ s/^0\s+//) {
            # It's a spam-virus and the infection name for the spam report
            # is in $ScannerOutput
            $ScannerOutput =~ /^(\S+)\s+(\S+)\s*$/;
            my ($messageid, $report) = ($1, $2);
            #print STDERR "Found spam-virus: $messageid, $report\n";
            MailScanner::Log::WarnLog("Found spam-virus %s in %s",
                                      $report, $messageid);
            $batch->{messages}{"$messageid"}->{spamvirusreport} .= ', '
              if $batch->{"$messageid"}->{spamvirusreport};
            $batch->{messages}{"$messageid"}->{spamvirusreport} .= $report;
            #print STDERR "id=" . $batch->{messages}{"$messageid"}->{id} . "\n";
          }
        }

        # If they don't want the scanner name reported, strip the scanner name
        $line =~ s/^$Name: // unless $ReportScanner;
      }
      close $Kid;
      $PipeReturn = $?;
      $pid = 0; # 2.54
      alarm 0;
      # Workaround for bug in perl shipped with Solaris 9,
      # it doesn't unblock the SIGALRM after handling it.
      eval {
        my $unblockset = POSIX::SigSet->new(SIGALRM);
        sigprocmask(SIG_UNBLOCK, $unblockset)
          or die "Could not unblock alarm: $!\n";
      };
    } else {
      # In the child
      POSIX::setsid();
      if ($scanner eq 'sophossavi') {
        SophosSAVI($subdir, $disinfect);
        exit;
      } elsif ($scanner eq 'clamavmodule') {
        ClamAVModule($subdir, $disinfect, $batch);
        exit;
      } elsif ($scanner eq 'clamd') {
        ClamdScan($subdir, $disinfect, $batch);
        exit;
      } elsif ($scanner eq 'f-protd-6') {
        Fprotd6Scan($subdir, $disinfect, $batch);
        exit;
      } else {
        exec "$sweepcommand $instdir $voptions $subdir";
        MailScanner::Log::WarnLog("Can't run commercial checker $scanner " .
                                  "(\"$sweepcommand\"): $!");
        exit 1;
      }
    }
  };
  alarm 0; # 2.53

  # Note to self: I only close the KID in the parent, not in the child.
  MailScanner::Log::DebugLog("Completed scanning by $scanner");
  $ScannerPID = 0; # Not running a scanner any more

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("Commercial virus checker failed with real error: $@")
    if $@ and $@ !~ /Command Timed Out|[sS]yslog/;

  #print STDERR "pid = $pid and \@ = $@\n";

  # In which case any failures must be the alarm
  if ($@ or $pid>0) {
    # Kill the running child process
    my($i);
    kill -15, $pid;
    # Wait for up to 5 seconds for it to die
    for ($i=0; $i<5; $i++) {
      sleep 1;
      waitpid($pid, &POSIX::WNOHANG);
      ($pid=0),last unless kill(0, $pid);
      kill -15, $pid;
    }
    # And if it didn't respond to 11 nice kills, we kill -9 it
    if ($pid) {
      kill -9, $pid;
      waitpid $pid, 0; # 2.53
    }
  }

  flock($Lock, $LOCK_UN);
  close $Lock;
  # Use the maximum value of all the numbers of viruses found by each of
  # the virus scanners. This should hopefully reflect the real number of
  # viruses in the messages, in the case where all of them spot something,
  # but only a subset spot more/all of the viruses.
  # Viruses = viruses or phishing attacks in the case of ClamAV.
  $$rCounter = $Counter if $Counter>$$rCounter; # Set up output value

  # If the virus scanner failed, bail out and tell the boss
  return 'ScAnNeRfAiLeD' if $ScannerFailed;

  # Return failure if the command timed out, otherwise return success
  MailScanner::Log::WarnLog("Commercial scanner $scanner timed out!") if $TimedOut;
  return 0 if $TimedOut;
  return 1;
}

# Use the ClamAV module (already initialised) to scan the contents of
# a directory. Outputs in a very simple format that ProcessClamAVModOutput()
# expects. 3 output fields separated by ":: ".
sub ClamAVModule {
  my($dirname, $disinfect, $messagebatch) = @_;

  my($dir, $child, $childname, $filename, $results, $virus);

  # Do we have an unrar on the path?
  my $unrar = MailScanner::Config::Value('unrarcommand');
  MailScanner::Log::WarnLog("Unrar command %s does not exist or is not " .
    "executable, please either install it or remove the setting from " .
    "MailScanner.conf", $unrar)
    unless $unrar eq "" || -x $unrar;
  my $haverar = 1 if $unrar && -x $unrar;

  $| = 1;
  $dir   = new DirHandle;
  $child = new DirHandle;

  $dir->open($dirname)
      or MailScanner::Log::DieLog("Can't open directory %s for scanning, %s",
                                  $dirname, $!);

  # Find all the subdirectories
  while($childname = $dir->read()) {
    # Scan all the *.header and *.message files
    if (-f "$dirname/$childname") {
      my $tmpname = "$dirname/$childname";
      $tmpname =~ /^(.*)$/;
      $tmpname = $1;
      $results = $Clam->scan($tmpname,
                             Mail::ClamAV::CL_SCAN_STDOPT() |
                             Mail::ClamAV::CL_SCAN_ARCHIVE() |
                             Mail::ClamAV::CL_SCAN_PE() |
                             Mail::ClamAV::CL_SCAN_BLOCKBROKEN() |
                             Mail::ClamAV::CL_SCAN_OLE2());
                             #0.93 Mail::ClamAV::CL_SCAN_PHISHING_DOMAINLIST());
      $childname =~ s/\.(?:header|message)$//;
      unless ($results) {
        print "ERROR:: $results" . ":: $dirname/$childname/\n";
        next;
      }
      if ($results->virus) {
        print "INFECTED::";
        print " $results" . ":: $dirname/$childname/\n";
      } else {
        print "CLEAN:: :: $dirname/$childname/\n";
      }
      next;
    }
    #next unless -d "$dirname/$childname"; # Only search subdirs
    next if $childname eq '.' || $childname eq '..';

    # Now work through each subdirectory of attachments
    $child->open("$dirname/$childname")
      or MailScanner::Log::DieLog("Can't open directory %s for scanning, %s",
                                  "$dirname/$childname", $!);

    # Scan all the files in the subdirectory
    # check to see if rar is available. If it is we don't want to
    # have clamav check for password protected since that has already
    # been done and will be reported correctly
    # if we are not allowing password protected archives and do not have rar
    # then have clamav check for password protected archives but it will
    # be reported as a virus (at least it will block passworded rar files)

    while($filename = $child->read()) {
      next unless -f "$dirname/$childname/$filename"; # Only check files
      #if (MailScanner::Config::Value('allowpasszips',
      #          $messagebatch->{messages}{$childname})) { # || $haverar) {
      my $tmpname = "$dirname/$childname/$filename";
      $tmpname =~ /^(.*)$/;
      $tmpname = $1;
        $results = $Clam->scan($tmpname,
                               Mail::ClamAV::CL_SCAN_STDOPT() |
                               Mail::ClamAV::CL_SCAN_ARCHIVE() |
                               Mail::ClamAV::CL_SCAN_PE() |
                               Mail::ClamAV::CL_SCAN_BLOCKBROKEN() |
                               Mail::ClamAV::CL_SCAN_OLE2());
                               #0.93 Mail::ClamAV::CL_SCAN_PHISHING_DOMAINLIST());
      #} else {
      #  $results = $Clam->scan("$dirname/$childname/$filename",
      #                         Mail::ClamAV::CL_SCAN_STDOPT() |
      #                         Mail::ClamAV::CL_SCAN_ARCHIVE() |
      #                         Mail::ClamAV::CL_SCAN_PE() |
      #                         Mail::ClamAV::CL_SCAN_BLOCKBROKEN() |
      #  # Let MS find these:  #Mail::ClamAV::CL_SCAN_BLOCKENCRYPTED() |
      #                         Mail::ClamAV::CL_SCAN_OLE2());
      #}

      unless ($results) {
        print "ERROR:: $results" . ":: $dirname/$childname/$filename\n";
        next;
      }
      if ($results->virus) {
        print "INFECTED::";
        print " $results" . ":: $dirname/$childname/$filename\n";
      } else {
        print "CLEAN:: :: $dirname/$childname/$filename\n";
      }
    }
    $child->close;
  }
  $dir->close;
}





# Use the Sophos SAVI library (already initialised) to scan the contents of
# a directory. Outputs in a very simple format that ProcessSophosSAVIOutput()
# expects. 3 output fields separated by ":: ".
sub SophosSAVI {
  my($dirname, $disinfect) = @_;

  my($dir, $child, $childname, $filename, $results, $virus);

  # Cannot disinfect yet
  #if ($disinfect) {
  #  # Enable the disinfection options
  #  ;
  #} else {
  #  # Disable the disinfection options
  #  ;
  #}

  $| = 1;
  $dir   = new DirHandle;
  $child = new DirHandle;

  $dir->open($dirname)
      or MailScanner::Log::DieLog("Can't open directory %s for scanning, %s",
                                  $dirname, $!);

  # Find all the subdirectories
  while($childname = $dir->read()) {
    next unless -d "$dirname/$childname"; # Only search subdirs
    next if $childname eq '.' || $childname eq '..';

    my $tmpchild = "$dirname/$childname";
    $tmpchild =~ /^(.*)$/;
    $tmpchild = $1;
    $child->open($tmpchild)
      or MailScanner::Log::DieLog("Can't open directory %s for scanning, %s",
                                  "$dirname/$childname", $!);

    # Scan all the files in the subdirectory
    while($filename = $child->read()) {
      next unless -f "$dirname/$childname/$filename"; # Only check files
      my $tmpfile = "$dirname/$childname/$filename";
      $tmpfile =~ /^(.*)$/;
      $tmpfile = $1;
      $results = $SAVI->scan($tmpfile);
      unless (ref $results) {
        print "ERROR:: " . $SAVI->error_string($results) . " ($results):: " .
              "$dirname/$childname/$filename\n";
        next;
      }
      if ($results->infected) {
        print "INFECTED::";
        foreach $virus ($results->viruses) {
          print " $virus";
        }
        print ":: $dirname/$childname/$filename\n";
      } else {
        print "CLEAN:: :: $dirname/$childname/$filename\n";
      }
    }
    $child->close;
  }
  $dir->close;
}

# Initialise any state variables the Generic output parser uses
sub InitGenericParser {
  ;
}

# Initialise any state variables the Sophos SAVI output parser uses
sub InitSophosSAVIParser {
  ;
}

# Initialise any state variables the Sophos output parser uses
sub InitSophosParser {
  ;
}

# Initialise any state variables the McAfee output parser uses
my($currentline);
sub InitMcAfeeParser {
  $currentline = '';
}

# Initialise any state variables the McAfee6 output parser uses
sub InitMcAfee6Parser {
  ;
}

# Initialise any state variables the Command (CSAV) output parser uses
sub InitCommandParser {
  ;
}

# Initialise any state variables the Inoculate-IT output parser uses
sub InitInoculateParser {
  ;
}

# Initialise any state variables the Inoculan 4.x output parser uses
sub InitInoculanParser {
  ;
}

# Initialise any state variables the Kaspersky 4.5 output parser uses
my ($kaspersky_4_5Version);
sub InitKaspersky_4_5Parser {
  $kaspersky_4_5Version = 0;
}

# Initialise any state variables the Kaspersky output parser uses
my ($kaspersky_CurrentObject);
sub InitKasperskyParser {
  $kaspersky_CurrentObject = "";
}

# Initialise any state variables the Kaspersky Daemon Client output parser uses
sub InitKavDaemonClientParser {
  ;
}

# Initialise any state variables the F-Secure output parser uses
my ($fsecure_InHeader, $fsecure_Version, %fsecure_Seen);
sub InitFSecureParser {
  $fsecure_InHeader=(-1);
  $fsecure_Version = 0;
  %fsecure_Seen = ();
}

# Initialise any state variables the F-Prot output parser uses
my ($fprot_InCruft);
sub InitFProtParser {
  $fprot_InCruft=(-3);
}

# Initialise any state variables the F-Prot-6 output parser uses
sub InitFProt6Parser {
  ;
}

# Initialise any state variables the F-Protd-6 output parser uses
my (%FPd6ParserFiles);
sub InitFProtd6Parser {
  %FPd6ParserFiles = ();
}

# Initialise any state variables the Nod32 output parser uses
my ($NOD32Version, $NOD32InHeading);
sub InitNOD32Parser {
  $NOD32Version = undef;
  $NOD32InHeading = 1;
}

# Initialise any state variables the Nod32 1.99 and above output parser uses
sub InitNOD32199Parser {
  $NOD32Version = undef;
  $NOD32InHeading = 2;
}

# Initialise any state variables the AntiVir output parser uses
sub InitAntiVirParser {
  ;
}

# Initialise any state variables the Panda output parser uses
sub InitPandaParser {
  ;
}

# Initialise any state variables the RAV output parser uses
sub InitRavParser {
  ;
}

# Initialise any state variables the ClamAV output parser uses
my ($clamav_archive, $qmclamav_archive);
my (%ClamAVAlreadyLogged);
sub InitClamAVParser {
  my($BaseDir, $batch) = @_;

  $clamav_archive = "";
  $qmclamav_archive = "";

  InitClamAVModParser($BaseDir, $batch);
}

# Initialise any state variables the ClamAV Module output parser uses
sub InitClamAVModParser {
  my($BaseDir, $batch) = @_;

  %ClamAVAlreadyLogged = ();
  if (MailScanner::Config::Value('clamavspam')) {
    # Write the whole message into $id.message in the headers directory
    my($id, $message);
    while(($id, $message) = each %{$batch->{messages}}) {
      next if $message->{deleted};
      my $filename = "$BaseDir/$id.message";
      my $target = new IO::File $filename, "w";
      MailScanner::Log::DieLog("writing to $filename: $!")
        if not defined $target;
      $message->{store}->WriteEntireMessage($message, $target);
      $target->close;
      # Set the ownership and permissions on the .message like .header
      chown $global::MS->{work}->{uid}, $global::MS->{work}->{gid}, $filename
        if $global::MS->{work}->{changeowner};
      chmod 0664, $filename;
    }
  }
}

# Initialise any state variables the Vscan output parser uses
my ($trend_prevline);
sub InitTrendParser {
  $trend_prevline = "";
}

# Initialise any state variables the Bitdefender output parser uses
sub InitBitdefenderParser {
  ;
}

# Initialise any state variables the DrWeb output parser uses
sub InitDrwebParser {
  ;
}

# Initialise any state variables the Norman output parser uses
sub InitNormanParser {
  ;
}

# Initialise any state variables the Symantec output parser uses
my ($css_filename, $css_infected);
sub InitCSSParser {
  $css_filename="";
  $css_infected="";
}

# Initialise any state variables the AVG output parser uses
sub InitAvgParser {
  ;
}

# Initialise any state variables the Vexira output parser uses
my($VexiraPathname);
sub InitVexiraParser {
  $VexiraPathname = '';
}

# Initialise any state variables the ScanEngine output parser uses
my($SSEFilename, $SSEVirusname, $SSEVirusid, $SSEFilenamelog);
sub InitSymScanEngineParser {
  $SSEFilename = '';
  $SSEVirusname = '';
  $SSEVirusid = 0;
  $SSEFilenamelog = '';
}

# Initialise any state variables the Avast output parser uses
sub InitAvastParser {
  ;
}

# Initialise any state variables the Avastd output parser uses
sub InitAvastdParser {
  ;
}

# Initialise any state variables the esets output parser uses
sub InitesetsParser {
  ;
}

# Initialise any state variables the vba32 output parser uses
sub Initvba32Parser {
  ;
}

# These functions must be called with, in order:
# * The line of output from the scanner
# * The MessageBatch object the reports are written to
# * The base directory in which we are working.
#
# The base directory must contain subdirectories named
# per message ID, and must have no trailing slash.
#
#
# These functions must return with:
# * return code 0 if no problem, 1 if problem.
# * type of problem (currently only "v" for virus)
#   appended to $types{messageid}{messagepartname}
# * problem report from scanner appended to
#   $infections{messageid}{messagepartname}
#   -- NOTE: Don't forget the terminating newline.
#
# If the scanner may refer to the same file multiple times,
# you should consider appending to the $infections rather
# than just setting it, I guess.
#


sub ProcessClamAVModOutput {
  my($line, $infections, $types, $BaseDir, $Name, $spaminfre) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($dot, $id, $part, @rest, $report);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #$logout =~ s/%/%%/g;

  #print STDERR "Output is \"$logout\"\n";
  ($keyword, $virusname, $filename) = split(/:: /, $line, 3);
  # Remove any rogue spaces in virus names!
  # Thanks to Alvaro Marin <alvaro@hostalia.com> for this.
  $virusname =~ s/\s+//g;

  if ($keyword =~ /^error/i && $logout !~ /rar module failure/i) {
    MailScanner::Log::InfoLog("%s::%s", $Name, $logout);
    return 1;
  } elsif ($keyword =~ /^info/i || $logout =~ /rar module failure/i) {
    return 0;
  } elsif ($keyword =~ /^clean/i) {
    return 0;
  } else {
    # Must be an infection report
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog("%s::%s", $Name, $logout)
      unless $ClamAVAlreadyLogged{"$id"} && $part eq '';
    $ClamAVAlreadyLogged{"$id"} = 1;

    #print STDERR "virus = \"$virusname\" re = \"$spaminfre\"\n";
    if ($virusname =~ /$spaminfre/) {
      # It's spam found as an infection
      # This is for clamavmodule and clamd
      # Use "u" to signify virus reports that are really spam
      # 20090730
      return "0 $id $virusname";
    }

    # Only log the whole message if no attachment has been logged
    #print STDERR "Part = \"$part\"\n";
    #print STDERR "Logged(\"$id\") = \"" . $ClamAVAlreadyLogged{"$id"} . "\"\n";

    $report = $Name . ': ' if $Name;
    if ($part eq '') {
      # No part ==> entire message is infected.
      $infections->{"$id"}{""}
        .= "$report message was infected: $virusname\n";
    } else {
      $infections->{"$id"}{"$part"}
        .= "$report$notype was infected: $virusname\n";
    }
    $types->{"$id"}{"$part"} .= 'v'; # it's a real virus
    return 1;
  }
}

sub ProcessGenericOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($id, $part, @rest, $report);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  ($keyword, $virusname, $filename) = split(/::/, $line, 3);

  if ($keyword =~ /^error/i) {
    MailScanner::Log::InfoLog("GenericScanner::%s", $logout);
    return 1;
  }

  # Must be an infection report
  ($id, $part, @rest) = split(/\//, $filename);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("GenericScanner::%s", $logout);
  return 0 if $keyword =~ /^clean|^info/i;

  $report = $Name . ': ' if $Name;
  $infections->{"$id"}{"$part"} .= "$report$notype was infected by $virusname\n";
  $types->{"$id"}{"$part"} .= "v"; # it's a real virus
  return 1;
}


sub ProcessSophosSAVIOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($dot, $id, $part, @rest, $report);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #$logout =~ s/%/%%/g;

  ($keyword, $virusname, $filename) = split(/:: /, $line, 3);

  if ($keyword =~ /^error/i) {
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    $report = $Name . ': ' if $Name;

    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    # Allow any error messages that are mentioned in the
    # Allowed Sophos Error Messages option.
    my($errorlist, @errorlist, @errorregexps, $choice);
    $errorlist = MailScanner::Config::Value('sophosallowederrors');
    $errorlist =~ s/^\"(.+)\"$/$1/; # Remove leading and trailing quotes
    @errorlist = split(/\"\s*,\s*\"/, $errorlist); # Split up the list
    foreach $choice (@errorlist) {
      push @errorregexps, quotemeta($choice) if $choice =~ /[^\s]/;
    }
    $errorlist = join('|',@errorregexps); # Turn into 1 big regexp

    if ($errorlist ne "" && $virusname =~ /$errorlist/) {
      MailScanner::Log::WarnLog("Ignored SophosSAVI '%s' error in %s",
                                $virusname, $id);
      return 0;
    } else {
      MailScanner::Log::InfoLog("SophosSAVI::%s", $logout);
      $infections->{"$id"}{"$part"}
        .= "$report$notype caused an error: $virusname\n";
      $types->{"$id"}{"$part"} .= "v"; # it's a real virus
      return 1;
    }
  } elsif ($keyword =~ /^info/i) {
    return 0;
  } elsif ($keyword =~ /^clean/i) {
    return 0;
  } else {
    # Must be an infection reports
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog("SophosSAVI::%s", $logout);

    $report = $Name . ': ' if $Name;
    $infections->{"$id"}{"$part"}
      .= "$report$notype was infected by $virusname\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }
}

sub ProcessSophosOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest, $error);
  my($logout);

  #print "$line";
  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::InfoLog($logout) if $line =~ /error/i;
  # JKF Improved to handle multi-part split archives,
  # JKF which Sophos whinges about
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.com
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.doc
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.rar/eicar.com
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.rar3a/eicar.doc
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.rar3a/eicar.com
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.zip/eicar.com

  return 0 unless $line =~ /(virus.*found)|(could not check)|(password[\s-]*protected)/i;
  $report = $line;
  $infected = $line;
  $infected =~ s/^.*found\s*in\s*file\s*//i;
  # Catch the extra stuff on the end of the line as well as the start
  $infected =~ s/^Could not check\s*(.+) \(([^)]+)\)$/$1/i;
  #print STDERR "Infected = \"$infected\"\n";
  $error = $2;
  #print STDERR "Error = \"$error\"\n";
  if ($error eq "") {
    $error = "Sophos detected password protected file"
      if $infected =~ s/^Password[ -]*protected\s+file\s+(.+)$/$1/i;
    #print STDERR "Error 2 = \"$error\"\n";
  }

  # If the error is one of the allowed errors, then don't report any
  # infections on this file.
  if ($error ne "") {
    # Treat their string as a command-separated list of strings, each of
    # which is in quotes. Any of the strings given may match.
    # If there are no quotes, then there is only 1 string (for backward
    # compatibility).
    my($errorlist, @errorlist, @errorregexps, $choice);
    $errorlist = MailScanner::Config::Value('sophosallowederrors');
    $errorlist =~ s/^\"(.+)\"$/$1/; # Remove leading and trailing quotes
    @errorlist = split(/\"\s*,\s*\"/, $errorlist); # Split up the list
    foreach $choice (@errorlist) {
      push @errorregexps, quotemeta($choice) if $choice =~ /[^\s]/;
    }
    $errorlist = join('|',@errorregexps); # Turn into 1 big regexp

    if ($errorlist ne "" && $error =~ /$errorlist/i) {
      MailScanner::Log::InfoLog($logout);
      MailScanner::Log::WarnLog("Ignored Sophos '%s' error", $error);
      return 0;
    }
  }
  
  #$infected =~ s/^Could not check\s*//i;
  # JKF 10/08/2000 Used to split into max 3 parts, but this doesn't handle
  # viruses in zip files in attachments. Now pull out first 3 parts instead.
  ($dot, $id, $part, @rest) = split(/\//, $infected);
  #system("echo $dot, $id, $part, @rest >> /tmp/jkf");
  #system("echo $infections >> /tmp/jkf");
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;
  MailScanner::Log::InfoLog($logout);
  $report = $Name . ': ' . $report if $Name;
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # it's a real virus
  return 1;
}

sub ProcessMcAfeeOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  my($lastline, $report, $dot, $id, $part, @rest);
  my($logout);

  chomp $line;
  $lastline = $currentline;
  $currentline = $line;

  #MailScanner::Log::InfoLog("McAfee said \"$line\"");

  # SEP: need to add code to log warnings
  return 0 unless $line =~ /Found/;

  # McAfee prints the whole path as opposed to
  # ./messages/part so make it the same
  $lastline =~ s/$BaseDir//;

  # make an equivalent report line from the last 2
  $report = "$lastline$currentline";
  $logout = $report;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  # note: '$dot' does not become '.'
  ($dot, $id, $part, @rest) = split(/\//, $lastline);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;
  MailScanner::Log::InfoLog($logout);

  $report = $Name . ': ' . $report if $Name;

  # Infections found in the header must be handled specially here
  if ($id =~ /\.(?:header|message)/) {
    # The attachment name is "" ==> infection is whole messsage
    $part = "";
    # Correct the message id by deleting all from .header onwards
    $id =~ s/\.(?:header|message).*$//;
  }
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v";
  return 1;
}

# McAfee6 parser provided in its entirety by Michael Miller
# <michaelm@aquaorange.net>
sub ProcessMcAfee6Output {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  my($report, $dot, $id, $part, @rest);
  my($logout);
  my($filename, $virusname);

  chomp $line;

  #MailScanner::Log::InfoLog("McAfee6 said \"$line\"");

  # Should we worry about any warnings/errors?
  return 0 unless $line =~ /Found/;

  # McAfee prints the whole path including
  # ./message/part so make it the same
  # eg: /var/spool/MailScanner/incoming/4118/./o3B07pUD004176/eicar.com
  #
  # strip off leading BaseDir
  $line =~ s/^$BaseDir//;
  # and then remaining /. (which may be removed in future as per v5 uvscan)
  $line =~ s/^\/\.//;
  # and put the leading . back in place
  $line =~ s/^/\./;

  $filename = $line;
  $filename =~ s/ \.\.\. Found.*$//;

  #get the virus name - not used currently
  #$virusname = $line;
  #$virusname =~ s/^.* \.\.\. Found.?//;

  $report = $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  # note: '$dot' does become '.'
  ($dot, $id, $part, @rest) = split(/\//, $filename);

  # Infections found in the header must be handled specially here
  if ($id =~ /\.(?:header|message)/) {
    # The attachment name is "" ==> infection is whole messsage
    $part = "";
    # Correct the message id by deleting all from .header onwards
    $id =~ s/\.(?:header|message).*$//;
  }

  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;
  $report =~ s/ \.\.\. Found/ Found/;
  MailScanner::Log::InfoLog($logout);

  $report = $Name . ': ' . $report if $Name;

  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v";
  return 1;
}

# This next function originally contributed in its entirety by
# "Richard Brookhuis" <richard@brookhuis.ath.cx>
#
# ./gBJNiNQG014777/eicar.zip->eicar.com is what a zip file looks like.
sub ProcessCommandOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  #my($line) = @_;

  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  #print "$line";
  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::InfoLog($logout) if $line =~ /error/i;
  if ($line =~ /(is|could be) a (security risk|virus construction|joke program)/) {
    # Reparse the rest of the line to turn it into an infection report
    $line =~ s/(is|could be) a (security risk|virus construction|joke program).*$/Infection: /;
  }

  return 0 unless $line =~ /Infection:/i;
  $report = $line;
  $infected = $line;
  $infected =~ s/\s+Infection:.*$//i;
  # JKF 10/08/2000 Used to split into max 3 parts, but this doesn't handle
  # viruses in zip files in attachments. Now pull out first 3 parts instead.
  $infected =~ s/-\>/\//; # JKF Handle archives rather better
  ($dot, $id, $part, @rest) = split(/\//, $infected);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog($logout);
  $report = $Name . ': ' . $report if $Name;
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # it's a real virus
  #print "ID: $id  PART: $part  REPORT: $report\n";
  return 1;
}

# This next function contributed in its entirety by
# <sfarrell@icconsulting.com.au>
#
sub ProcessInoculateOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  #print "$line";

  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::InfoLog($logout) if $line =~ /error/i;
  #JKF MailScanner::Log::WarnLog($line) if $line =~ /Error/i;
  return 0 unless $line =~ /is infected by virus:/i;

  # Ino prints the whole path as opposed to
  # ./messages/part so make it the same
  # Scott Farrell's system definitely requires the extra /
  # Output looks like this:
  # File: /var/spool/MailScanner/incoming/./message-id/filename
  $line =~ s/$BaseDir\///;

  # ino uses <file.ext> instead of /files.ext/ in archives
  $line =~ s/</\//;
  $line =~ s/>/\//;

  $report = $line;
  $infected = $line;
#  $infected =~ s/^.*found\s*in\s*file\s*//i;
  # Next 2 lines added on advice from <FCamilo@multirede.com.br>.
  $infected =~ s/File //;
  $infected =~ s/ is infected by virus:.*//;
  # JKF 10/08/2000 Used to split into max 3 parts, but this doesn't handle
  # viruses in zip files in attachments. Now pull out first 3 parts instead.
  ($dot, $id, $part, @rest) = split(/\//, $infected);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog($logout);
  $report = $Name . ': ' . $report if $Name;
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
  return 1;
}

# Inoculan 4.x parser, contributed in its entirety by <Gabor.Funk@hunetkft.hu>
#
# Comment from <Gabor.Funk@hunetkft.hu>:
# This next function is the modified version of sfarrell@icconsulting.com.au's
# inoculateit 6.0 section by gabor.funk@hunetkft.hu - 2002.03.01 - v1.0
# It works with Inoculan 4.x inocucmd which is a beta/test/unsupported version
# Can be downloaded from: ftp://ftp.ca.com/getbbs/linux.eng/inoctar.LINUX.Z
# This package is rarely modified but you can download virsig.dat from other
# 4.x package such as the NetWare package (smallest and non MS compressed)
# It can be found at: ftp://ftp.ca.com/pub/InocuLAN/il0156.zip
# wget it; unzip il0156.zip VIRSIG.DAT; mv VIRSIG.DAT virsig.dat
# and since the last engine was "corrected" not to accept newer signature
# files, you have to patch the major version number to the same or below as
# the one which come with the inoctar.LINUX.Z (currently 34.19) otherwise
# it would refuse to run and misleadingly report the following:
# "Error during Initialization. Please check configuration."
# In virsig.dat the major version number is located at address 10h, for
# virsig.dat version 35.15 this would be 35h. You simply have to change it
# to 34h and it should work. Note: using a higher version virsig.dat with a
# lower version engine is highly discouraged by CA and can result not to
# recognize newer viruses. Automatic procedure for this: Get bview (bvi) from
# http://bvi.sourceforge.net, create a file called "patch" containing the
# following: "16 c h[LF]34[LF].[LF]w[LF]q[LF]" where [LF] means linefeed
# and of course without the quotes. Run "bvi -f patch virsig.dat" to change
# major version number automatically to 34 in virsig.dat.
# inocucmd needs libstdc++-libc6.1-1.so.2 so you need to link it to your
# closest one (it was libstdc++-3-libc6.2-2-2.10.0.so on my debian testing).
# location: inocucmd and virsig.dat (the two required files) should be at
# /opt/CA, /usr/local/bin or other location specified in $CAIGLBL0000
# test: inocucmd .  (inocucmd without argument can report bogus virsig.dat
# version number but it's ok if it scans the file with no error)
# I like inocucmd because it needs 2 file alltogether, requires no building
# and/or "installation" so is very ideal for testing.
#
# [text updated and expanded at 2002. April 22.]

sub ProcessInoculanOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::InfoLog($logout) if $line =~ /error/i;
  #JKF MailScanner::Log::WarnLog($line) if $line =~ /Error/i;
  return 0 unless $line =~ /was infected by virus/i;

  # Sample outputs for an unpacked and a packed virus
  # "[././cih-sfl.exe] was infected by virus [Win95/CIH.1003]"
  # "[././w95.arj:SLIDER10.EXE] was infected by virus [Win95/Slider 1.0.Trojan]"

  $report   = $line;
  $infected = $line;
  $infected =~ s/^\[\.\///i;
  $infected =~ s/([:\]]).*//i;

  ($dot, $id, $part, @rest) = split(/\//, $infected);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog($logout);
  $report = $Name . ': ' . $report if $Name;
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
  return 1;
}

# Kaspersky 4.5 onwards is totally different to its predecessors.
# It looks like they finally made a decent interface to it.
sub ProcessKaspersky_4_5Output {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  my($logout, $report, $infected, $id, $part, @rest);

  chomp $line;

  if (!$kaspersky_4_5Version) {
    # Version is on a line before any files are scanned
    $kaspersky_4_5Version = $1 if $line =~ /version\D+([\d.]+)/i;
    return 0;
  }

  return 0 unless $line =~ /\s(INFECTED|SUSPICION)\s/i;
  $line =~ s/^\[[^\]]+\] //;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;

  # Sample outputs for an unpacked and a packed virus
  # /tmp/bernhard/message.zip
  # /tmp/bernhard/message.zip/message.html INFECTED I-Worm.Mimail.a
  # /tmp/bernhard/message.html INFECTED I-Worm.Mimail.a

  $report = $line; # Save a copy
  $line =~ s/^$BaseDir\///; # Remove basedir/ off the front
  # Now have id/part followed possibly by /rest
  $line =~ /^(.+)\s(INFECTED|SUSPICION)\s[^\s]+$/;
  $infected = $1;
  ($id, $part, @rest) = split(/\//, $infected);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog($logout);

  $report = $Name . ': ' . $report if $Name;
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
  return 1;
}


# If you use Kaspersky, look at this code carefully
# and then be very grateful you didn't have to write it.
# Note that Kaspersky will now change long paths so they have "..."
# in the middle of them, removing the middle of the path.
# *WHY* do people have to do dumb things like this?
#
sub ProcessKasperskyOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  #my($line) = @_;

  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  # Don't know what kaspersky means by "object" yet...

  # Lose trailing cruft
  return 0 unless defined $kaspersky_CurrentObject;

  if ($line =~ /^Current\sobject:\s(.*)$/) {
    $kaspersky_CurrentObject = $1;
  }
  elsif ($kaspersky_CurrentObject eq "") {
    # Lose leading cruft
    return 0;
  }
  else {
    chomp $line;
    $line =~ s/^\r//;
    # We can rely on BaseDir not having trailing slash.
    # Prefer s/// to m// as less likely to do unpredictable things.
    if ($line =~ / infected: /) {
      $line =~ s/.* \.\.\. (.*)/\.$1/; # Kav will now put ... in long paths
      $report = $line;
      $logout = $line;
      $logout =~ s/%/%%/g;
      $logout =~ s/\s{20,}/ /g;
      $line =~ s/^$BaseDir//;
      $line =~ s/(.*) infected:.*/\.$1/; # To handle long paths again
      ($dot,$id,$part,@rest) = split(/\//, $line);
      my $notype = substr($part,1);
      $logout =~ s/\Q$part\E/$notype/;
      $report =~ s/\Q$part\E/$notype/;

      MailScanner::Log::InfoLog($logout);
      $report = $Name . ': ' . $report if $Name;
      $infections->{"$id"}{"$part"} .= $report . "\n";
      $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
      return 1;
    }
    # see commented code below if you think this regexp looks fishy
    if ($line =~ /^([\r ]*)Scan\sprocess\scompleted\.\s*$/) {
      undef $kaspersky_CurrentObject;
      # uncomment this to see just one reason why I hate kaspersky AVP -- nwp
      # foreach(split //, $1) {
      #   print ord($_) . "\n";
      # }
    }
  }
  return 0;
}

# It uses AvpDaemonClient from /opt/AVP/DaemonClients/Sample
# or AvpTeamDream from /opt/AVP/DaemonClients/Sample2.
# This was contributed in its entirety by
# Nerijus Baliunas <nerijus@USERS.SOURCEFORGE.NET>.
#
sub ProcessKavDaemonClientOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  #my($line) = @_;

  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  chomp $line;
  $line =~ s/^\r//;
  # We can rely on BaseDir not having trailing slash.
  # Prefer s/// to m// as less likely to do unpredictable things.
  if ($line =~ /infected: /) {
    $line =~ s/.* \.\.\. (.*)/\.$1/; # Kav will now put ... in long paths
    $report = $line;
    $logout = $line;
    $logout =~ s/%/%%/g;
    $logout =~ s/\s{20,}/ /g;
    $line =~ s/^$BaseDir//;
    $line =~ s/(.*)\sinfected:.*/\.$1/; # To handle long paths again
    ($dot,$id,$part,@rest) = split(/\//, $line);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    return 1;
  }
  return 0;
}

# Sample output from version 4.50 of F-Secure:
# [./eicar2/eicar.zip] eicar.com: Infected: EICAR-Test-File [AVP]
# ./eicar2/eicar.co: Infected: EICAR_Test_File [F-Prot]
sub ProcessFSecureOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  my($report, $infected, $dot, $id, $part, @rest);
  my($logout, $virus, $BeenSeen);

  chomp $line;
  #print STDERR "$line\n";
  #print STDERR "InHeader $fsecure_InHeader\n";
  #system("echo -n '$line' | od -c");

  # Lose header
  if ($fsecure_InHeader < 0 && $line =~ /version ([\d.]+)/i &&
      !$fsecure_Version) {
    $fsecure_Version = $1 + 0.0;
    $fsecure_InHeader -= 2 if $fsecure_Version >= 4.51 &&
                              $fsecure_Version < 4.60;
    $fsecure_InHeader -= 2 if $fsecure_Version <= 3.0; # For F-Secure 5.5
    #MailScanner::Log::InfoLog("Found F-Secure version $1=$fsecure_Version\n");
    #print STDERR "Version = $fsecure_Version\n";
    return 0;
  }
  if ($line eq "") {
    $fsecure_InHeader++;
    return 0;
  }
  # This test is more vague than it used to be, but is more tolerant to
  # output changes such as extra headers. Scanning non-scanning data is
  # not a great idea but causes no harm.
  # Before version 7.01 this was 0, but header changed again!
  $fsecure_InHeader >= -1 or return 0;

  $report = $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;

  # If we are running the new version then there's a totally new parser here
  # F-Secure 5.5 reports version 1.10
  if ($fsecure_Version <= 3.0 || $fsecure_Version >= 4.50) {

    #./g4UFLJR23090/Keld Jrn Simonsen: Infected: EICAR_Test_File [F-Prot]
    #./g4UFLJR23090/Keld Jrn Simonsen: Infected: EICAR-Test-File [AVP]
    #./g4UFLJR23090/cokegift.exe: Infected:   is a joke program [F-Prot]
    # Version 4.61:
    #./eicar.com: Infected: EICAR_Test_File [Libra]
    #./eicar.com: Infected: EICAR Test File [Orion]
    #./eicar.com: Infected: EICAR-Test-File [AVP]
    #./eicar.doc: Infected: EICAR_Test_File [Libra]
    #./eicar.doc: Infected: EICAR Test File [Orion]
    #./eicar.doc: Infected: EICAR-Test-File [AVP]
    #[./eicar.zip] eicar.com: Infected: EICAR_Test_File [Libra]
    #[./eicar.zip] eicar.com: Infected: EICAR Test File [Orion]
    #[./eicar.zip] eicar.com: Infected: EICAR-Test-File [AVP]


    return 0 unless $line =~ /: Infected: /;
    # The last 3 words are "Infected:" + name of virus + name of scanner
    $line =~ s/: Infected: +(.+) \[.*?\]$//;
    #print STDERR "Line is \"$line\"\n";
    MailScanner::Log::NoticeLog("Virus Scanning: F-Secure found virus %s", $1);
    # We are now left with the filename, or
    # then archive name followed by the filename within the archive.
    $line =~ s/^\[(.*?)\] .*$/$1/; # Strip signs of an archive

    # We now just have the filename
    ($dot,$id,$part,@rest) = split(/\//, $line);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    # Only report results once for each file
    return 0 if $fsecure_Seen{$line};
    $fsecure_Seen{$line} = 1;
    return 1;
  } else {
    # We are running the old version, so use the old parser
    # Prefer s/// to m// as less likely to do unpredictable things.
    # We hope.
    if ($line =~ /\tinfection:\s/) {
      # Get to relevant filename in a reasonably but not
      # totally robust manner (*impossible* to be totally robust
      # if we have square brackets and spaces in filenames)
      # Strip archive bits if present
      $line =~ s/^\[(.*?)\] .+(\tinfection:.*)/$1$2/;
  
      # Get to the meat or die trying...
      $line =~ s/\tinfection:([^:]*).*$//
        or MailScanner::Log::DieLog("Dodgy things going on in F-Secure output:\n$report\n");
      $virus = $1;
      $virus =~ s/^\s*(\S+).*$/$1/; # 1st word after Infection: is the virus
      MailScanner::Log::NoticeLog("Virus Scanning: F-Secure found virus %s",$virus);
  
      ($dot,$id,$part,@rest) = split(/\//, $line);
      my $notype = substr($part,1);
      $logout =~ s/\Q$part\E/$notype/;
      $report =~ s/\Q$part\E/$notype/;

      MailScanner::Log::InfoLog($logout);
      $report = $Name . ': ' . $report if $Name;
      $infections->{"$id"}{"$part"} .= $report . "\n";
      $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
      return 1;
    }
    MailScanner::Log::DieLog("Either you've found a bug in MailScanner's F-Secure output parser, or F-Secure's output format has changed! Please mail the author of MailScanner!\n");
  }
}

sub ProcessFProtOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  #my($line) = @_;

  my($report, $infected, $dot, $id, $part, $virus, @rest);
  my($logout);

  #print STDERR "$fprot_InCruft $line";

  chomp $line;

  # Look for the "Program version: 4...." line which shows we are running
  # version 4 and therefore have different headers at the start of the
  # scan output.
  if ($fprot_InCruft==-2) {
    my $version = $1 if $line =~ /program\s+version:\s*([\d.]+)/i;
    if ($version > 3.12) {
      $fprot_InCruft -= 1;
      return 0;
    }
  }
  return 0 if $fprot_InCruft > 0; # Return if we are still in headers
  # One header paragraph has finished, count it
  if ($line eq "") {
    $fprot_InCruft += 1;
    return 0;
  }
  $fprot_InCruft == 0 or return 0;

  # Prefer s/// to m// as less likely to do unpredictable things.
  # We hope.
  # JKF 5+11/1/2002 Make "security risk" and "joke program" lines look like
  #                 virus infections for easier parsing.
  # JKF 25/02/2002  Add all sorts of patterns gleaned from a coredump of F-Prot
  # JKF 24/07/2002  Reparse the lines to turn them into infection reports
  # JKF 07/06/2005  Make log output contain the whole path of the file.
  $report = $line;
  $report =~ s/^.+\/(.+\/.+$)/\.\/$1/; # New
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  my $reallog = $logout;
  $logout =~ s/^.+\/(.+\/.+$)/\.\/$1/; # New
  if ($line =~ /(is|could be) a (security risk|virus construction)/) {
    $line =~ s/(is|could be) a (security risk|virus construction).*$/Infection: /;
  }
  if ($line =~ /(is|could be) a mass-mailing worm/) {
    $line =~ s/(is|could be) a mass-mailing worm.*$/Infection: /;
  } elsif ($line =~ /(is|could be) a( boot sector)? virus dropper/) {
    $line =~ s/(is|could be) a( boot sector)? virus dropper.*$/Infection: /;
  } elsif ($line =~ /(is|could be) a corrupted or intended/) {
    $line =~ s/(is|could be) a corrupted or intended.*$/Infection: /;
  } elsif ($line =~ /(is|could be) a (joke|destructive) program/) {
    $line =~ s/(is|could be) a (joke|destructive) program.*$/Infection: /;
  } elsif ($line =~ /(is|could be) infected with an unknown virus/) {
    $line =~ s/(is|could be) infected with an unknown virus.*$/Infection: /;
  } elsif ($line =~ /(is|could be) a suspicious file/) {
    $line =~ s/(is|could be) a suspicious file.*$/Infection: /;
  } elsif ($line =~ /(is|could be) an archive bomb/) {
    $line =~ s/(is|could be) an archive bomb.*$/Infection: /;
  } elsif ($line =~ /(could\s*)?contain.*the exploit/i) {
    $line =~ s/(could\s*)?contains?\s*/Infection: /i;
  } elsif ($line =~ /contains.*\(non-working\)/) {
    $line =~ s/contains /Infection: /;
  #} elsif ($line =~ /[Nn]ot scanned \(encrypted\)/) {
  #  $line =~ s/[Nn]ot scanned \(encrypted\).*$/Infection: /;
  }
  if ($line =~ /\s\sInfection:\s/) {
    # Get to relevant filename in a reasonably but not
    # totally robust manner (*impossible* to be totally robust
    # if we have slashes, spaces and "->" in filenames)
    $line =~ s/^(.*?)->.+(\s\sInfection:.*)/$1$2/; # strip archive bits if present
    $line =~ s/^.*(\/.*\/.*)\s\sInfection:([^:]*).*$/$1/ # get to the meat or die trying
      or MailScanner::Log::DieLog("Dodgy things going on in F-Prot output:\n$report\n");
    #print STDERR "**$line\n";
    $virus = $2;
    $virus =~ s/^\s*(\S+).*$/$1/; # 1st word after Infection: is the virus
    MailScanner::Log::NoticeLog("Virus Scanning: F-Prot found virus %s", $virus);
    ($dot,$id,$part,@rest) = split(/\//, $line);
    my $notype = substr($part,1);
    $reallog =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($reallog);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    return 1;
  }

  # Have now seen F-Prot produce infection lines without Infection: in them!
  # Look for W32 in the last word of the line
  if ($line =~ /W32\/\S+$/) {
    # Get to relevant filename in a reasonably but not
    # totally robust manner (*impossible* to be totally robust
    # if we have slashes, spaces and "->" in filenames)
    $line =~ s/^(.*?)->.+(\sW32\/\S+)/$1$2/; # strip archive bits if present
    $line =~ s/^.*(\/.*\/.*)\s(W32\/\S+)$/$1/ # get to the meat or die trying
      or MailScanner::Log::DieLog("Dodgy things going on in F-Prot output2:\n$report\n");
    #print STDERR "**$line\n";
    $virus = $2;
    MailScanner::Log::NoticeLog("Virus Scanning: F-Prot found problem %s",
                              $virus);
    ($dot,$id,$part,@rest) = split(/\//, $line);
    my $notype = substr($part,1);
    $reallog =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($reallog);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    return 1;
  }

  # Ignore files we couldn't scan as they were encrypted
  if ($line =~ /\s\sNot scanned \(unsupported compression method\)/ ||
      $line =~ /\s\sNot scanned \(unknown file format\)/ ||
      $line =~ /[Nn]ot scanned \(encrypted\)/ ||
      $line =~ /Virus-infected files in archives cannot be deleted\./) {
    return 0;
  }

  MailScanner::Log::WarnLog("Either you've found a bug in MailScanner's F-Prot output parser, or F-Prot's output format has changed! F-Prot said this \"$line\". Please mail the author of MailScanner");
  return 0;
}

#
# Process the output of the F-Prot Version 6 command-line scanner
#
sub ProcessFProt6Output {
  my($line, $infections, $types, $BaseDir, $Name, $spaminfre) = @_;
  my($report, $dot, $id, $part, @rest);
  my($logout);

  #Output looks like this:
  #
  #[Unscannable] <File is encrypted>	eicarnest.rar->eicar.rar
  #[Clean]    eicarnest.rar
  #[Found virus] <EICAR_Test_File (exact, not disinfectable)> 	eicar.rar->eicar.com
  #[Contains infected objects]	eicar.rar
  #[Found virus] <EICAR_Test_File (exact, not disinfectable)> 	eicar.zip->eicar.exe
  #[Contains infected objects]	eicar.zip

  chomp $line;
  $logout = $line;
  $logout =~ s/\s+/ /g;

  return 0 unless $line =~ /^\[([^\]]+)\]\s+(\<([^>]+)\>)?\s+(.+)$/;
  my $Result = $1; # Clean or Unscannable or report of a nasty
  my $Infection = $3; # What it found in the file, optional
  my $Filepath = $4; # Relative path and an optional multiple '->member_name'
  #print STDERR "Result    = \"$Result\"\n";
  #print STDERR "Infection = \"$Infection\"\n";
  #print STDERR "Filepath  = \"$Filepath\"\n";

  return 0 if $Result =~ /^Clean|Unscannable$/i;

  # Now dismantle $Filepath
  ($dot, $id, $part, @rest) = split(/\//, $Filepath);
  $part =~ s/\-\>.*$//; # Scrap all the sub-parts
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;

  MailScanner::Log::WarnLog($logout);

  if ($Infection =~ /$spaminfre/) {
    # It's spam found as an infection
    # 20090730
    return "0 $id $Infection";
  }

  $report = "Found virus $Infection in $notype";
  $report = $Name . ': '. $logout if $Name;
  #print STDERR "$report\n";
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # it's a real virus
  return 1;
}

# This function provided in its entirety by Ing. Juraj Hanták <hantak@wg.sk>
#
sub ProcessNOD32Output {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::WarnLog($logout) if $line =~ /error/i;

  # Yet another new NOD32 parser! :-(
  # This one is for 2.04 in which the output, again, looks totally different
  # to all the previous versions.
  if ($line =~
      /^object=\"file\",\s*name=\"([^\"]+)\",\s*(virus=\"([^\"]+)\")?/i) {
    my($fileentry, $virusname) = ($1,$3);
    $fileentry =~ s/^$BaseDir//;
    ($dot, $id, $part, @rest) = split(/\//, $fileentry);
    $part =~ s/^.*\-\> //g;
    my $notype = substr($part,1);
    #$logout =~ s/$part/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    $report = "Found virus $virusname in $notype";
    $report = $Name . ': '. $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }


  if (!$NOD32Version && $NOD32InHeading>0 && $line =~ /^NOD32.*Version[^\d]*([\d.]+)/) {
    $NOD32Version = $1;
    $NOD32InHeading--; # = 0;
    return 0;
  }
  $NOD32InHeading-- if /^$/; # Was = 0
  return 0 unless $line =~ /\s-\s/i;

  if ($NOD32Version >= 1.990) {
    # New NOD32 output parser
    $line =~ /(.*) - (.*)$/;
    my($file, $virus) = ($1, $2);
    return 0 if $virus =~ /not an archive file|is OK/;
    return 0 if $file  =~ /^  /;
    ($dot, $id, $part, @rest) = split(/\//, $file);
    my $notype = substr($part,1);
    $line =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog("%s", $line);
    $report = $line;
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  } else {
    # Pull out the last line of the output text
    my(@lines);
    chomp $line;
    chomp $line;
    @lines = split(/[\r\n]+/, $line);
    $line = $lines[$#lines];
    #my ($part1,$part2,$part3,$part4,@ostatne)=split(/\.\//,$line);
    #$line="./".$part4;
    $logout = $line;
    $logout =~ s/%/%%/g;
    $logout =~ s/\s{20,}/ /g;
    $report = $line;
    $infected = $line;
    $infected =~ s/^.*\s*-\s*//i;

    # JKF 10/08/2000 Used to split into max 3 parts, but this doesn't handle
    # viruses in zip files in attachments. Now pull out first 3 parts instead.
    ($dot, $id, $part, @rest) = split(/[\/,-]/, $report);
    $part =~ s/\s$//g;
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus

    return 1;
  }
}

# This function originally contributed by Cornelius Kölbel <nelischnuck@web.de>
#
sub ProcessAntiVirOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  #  my($line) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  # From CK's mail:
  #
  # checking drive/path (list): /etc/mail
  # !Virus! /etc/mail/eicar.com Eicar-Test-Signatur (exact)
  # !Virus! /etc/mail/eicar file.com Eicar-Test-Signatur (exact)
  #
  # And I am not very sure, where I should to the sepeartion, if the file
  # (attachment) has a space in it (as in the second case).
  # So I took this regular expression:
  # $part=~ s/^(.*)\s\S*\s\S*$/$1/g;
  #
  # Since I asume, that the output has always a column with the Name of the
  # Virus (Eicar-Test-Signatur) and something, that says "exact".

  # Open questions:
  # - Does it *always* say "!Virus!" or can it sometimes say, for example,
  #   "!Trojan!" or "!Joke!"??
  # - I am assuming that they are not braindead and therefore never have
  #   spaces in their virus names...
  # - What does the output of antivir look like when invoked on "." (does
  #   it report relative paths?
  #
  # -- nwp 6/5/02

  # Now produces output like this:
  # ALERT: [Eicar-Test-Signatur virus] ./eicar1.zip -->  eicar.com <<< Contains code of the Eicar-Test-Signatur virus
  # ALERT: [Eicar-Test-Signatur virus] ./eicar2.com <<< Contains code of the Eicar-Test-Signatur virus


  chomp $line;
  $report = $line;
  if ($line =~ /.*!Virus!.*/) {
    $logout = $line;
    $logout =~ s/%/%%/g;
    $logout =~ s/\s{20,}/ /g;
    ($dot,$id,$part,@rest) = split(/\//, $line);
    # The Filename is all, except the last two comma seperated elements
    $part =~ s/^(.*)\s\S*\s\S*$/$1/g;
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    #print STDERR "dot: $dot, id: $id, part: $part, rest: @rest\n";
    return 1;
    #print STDERR "dot: $dot, id: $id, part: $part, rest: @rest\n";
    # dot: , id: g28C22m03310, part: eicar.com, rest:
  }

  # New output format?
  if ($line =~ /^ALERT:/) {
    $logout = $line;
    $logout =~ s/%/%%/g;
    $logout =~ s/\s{20,}/ /g;
    # Get rid of the virus name
    $line =~ s/^ALERT: \[[^\]]+\] //;
    if ($line =~ / --\> .*\<\<\</) {
      # Line describes an archive
      $line =~ s/ --\> .*\<\<\<.*$//;
    } else {
      # Line describes a normal file
      $line =~ s/ \<\<\<.*$//;
    }
    ($dot,$id,$part,@rest) = split(/\//, $line);
    chomp $part;
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    #print STDERR "ID = $id and PART = $part\n";
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v";
    return 1;
  }


  # Don't warn any more, new output format includes other gumph we aren't
  # interested in.
  #MailScanner::Log::WarnLog("Either you've found a bug in MailScanner's AntiVir output parser, or AntiVir's output format has changed! AntiVir said this \"$line\". Please mail the author of MailScanner");
  return 0;
}

# This function originally contributed by Héctor García Álvarez
# <hector@lared.es>
# From comment (now removed), it looks to be based on Sophos parser at
# some point in its history.
# Updated by Rick Cooper <rcooper@dwford.com> 05/10/2005
#
sub ProcessPandaOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($numviruses);

  # Return if there were no viruses found
  return 0 if $line =~ /^Virus: 0/i;

  my $ErrStr = "";
  $ErrStr = $line if $line =~ /^Panda:ERROR:/;
  $ErrStr =~ s/^Panda:ERROR:(.+)/$1/ if $ErrStr ne "";
  chomp($ErrStr) if $ErrStr ne "";
  MailScanner::Log::InfoLog("Panda WARNING: %s",$ErrStr) if $ErrStr ne "";
  return 0 if $ErrStr ne "";

  # the wrapper returns the information in the following format
  # EXAMPLE OUTPUT PLEASE? -- nwp 6/5/02
  # FOUND: EICAR-AV-TEST-FILE  ##::##eicar_com.zip##::##1DVXmB-0006R4-Fv##::##/var/spool/mailscanner/incoming/24686
  #          Virus Name                File Name          Message Dir               Base Dir

  my $temp = $line;
  $numviruses = 0;

  # If the line is a virus report line parse it
  # Simple
  while($temp =~ /\t\tFOUND:(.+?)##::##(.+?)##::##(.+?)##::##(.+?)$/){
        $part = $2;
	$BaseDir = $4;
        $id = $3;
        $report = $1;
	$report =~ s/^\s+|\s+$|\t|\n//g;
	$report = $report." found in $part";
        $report = $Name . ": " . $report if $Name;
	$report =~ s/\s{2,}/ /g;
	# Make Sure $part is the parent for reporting, otherwise this
	# doesn't show up in user reports.
	$part =~ s/^(.+)\-\>(.+)/$1/;
        my $notype = substr($part,1);
        $report =~ s/\Q$part\E/$notype/;

	MailScanner::Log::InfoLog("%s",$report);
        $infections->{"$id"}{"$part"} .= "$report\n";
	#print STDERR "'$part'\n";
        $types->{"$id"}{"$part"} .= "v";
        $numviruses++;
        $temp = $';
  }

  return $numviruses;

}

# This function originally contributed by Luigino Masarati <lmasarati@outsys.it>
# Looks like it's based on F-Secure function...
#
sub ProcessRavOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  # Sample output:
  #
  # [root@pico /tmp]# /usr/local/rav8/ravwrapper --all --mail --archive ./eicar
  # RAV AntiVirus command line for Linux i686.
  # Version: 8.3.0.
  # Copyright (c) 1996-2001 GeCAD The Software Company. All rights reserved.
  #
  # Scan engine 8.5 for i386.
  # Last update: Wed May  1 16:57:02 2002
  # Scanning for 66321 malwares (viruses, trojans and worms).
  #
  # Scan started on Wed May  8 08:52:55 2002
  #
  # ./eicar/eicarcom2.zip->eicar_com.zip->eicar.com Infected: EICAR_Test_File
  # ./eicar/eicar.com       Infected: EICAR_Test_File
  # ./eicar/eicar.com.txt   Infected: EICAR_Test_File
  # ./eicar/eicar_com.zip->eicar.com        Infected: EICAR_Test_File
  #
  # Scan ended on Wed May  8 08:52:55 2002
  #
  # Objects scanned: 7.
  # Infected: 4.
  # Warnings: 0.
  # Time: 0 second(s).
  # [root@pico /tmp]#
  #print STDERR ">>$line";

  #
  # This is the original code contributed. It's not perfect.
  #
  #chomp $line;

  #$report = $line;
  #if ($line =~ /\s+Infected:/i) {
  #  MailScanner::Log::InfoLog($line);
  #  # Get to relevant filename in a reasonably but not
  #  # totally robust manner (*impossible* to be totally robust
  #  # if we have slashes, spaces and "->" in filenames)
  #  $line =~ s/^(.*?)\-\>.+(\s+Infected:.*)/$1$2/; # strip archive bits if present
  #  $line =~ s/^.*(\/.*\/.*)\s+Infected:[^:]*$/$1/ # get to the meat or die trying
  #    or MailScanner::Log::DieLog("Dodgy things going on in Rav output:\n$report\n");
  #  #print STDERR "**$line\n";
  #  ($dot,$id,$part,@rest) = split(/\//, $line);
  #  $infections->{"$id"}{"$part"} .= $report . "\n";
  #  $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
  #  return 1;
  #}
  #return 0;

  #
  # This is my rewritten code (JKF). Now supporting RAV officially.
  #
  # Syntax of infection report lines is like this:
  # pathname->zippart\tInfected: virusname
  # pathname->zippart\tSuspicious: virusname
  #
  chomp $line;

  $report = $line;
  if ($line =~ /\t+(Infected|Suspicious): /i) {
    $logout = $line;
    $logout =~ s/%/%%/g;
    $logout =~ s/\s{20,}/ /g;
    # Get to relevant filename in a reasonably but not
    # totally robust manner (*impossible* to be totally robust
    # if we have slashes, spaces and "->" in filenames)
    # Strip the infection report off the end, leaves us with the path
    # and the archive element name
    $line =~ s/\t(Infected|Suspicious): \S+$//;
    # Strip any archive elements so we should just have the path and filename
    $line =~ s/^(.*?)\-\>.*$/$1/;
    $line =~ /\-\>/
      and MailScanner::Log::DieLog("Dodgy things going on in Rav " .
                                   "output:\n%s\n", $report);
    #print STDERR "**$line\n";
    ($dot,$id,$part,@rest) = split(/\//, $line);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    return 1;
  }
  return 0;
}


# Parse the output of the DrWeb output.
# Konrad Madej <kmadej@nask.pl>
sub ProcessDrwebOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;

  return 0 unless $line =~ /^(.+)\s+infected\s+with\s+(.*)$/i;

  my ($file, $virus) = ($1, $2);
  my $logout = $line;
  $logout =~ s/\s{20,}/ /g;

  # Sample output:
  #
  # /tmp/del.com infected with EICAR Test File (NOT a Virus!)
  # or
  # >/tmp/del1.com infected with EICAR Test File (NOT a Virus!)

  # Remove path elements before /./, // if any and 
  # , >, $BaseDir leaving just id/part/rest
  $file =~ s/\/\.\//\//g;
  $file =~ s/\/\//\//g;
  $file =~ s/^>+//g;
  $file =~ s/^$BaseDir//;
  $file =~ s/^\///g;

  my($id, $part, @rest) = split(/\//, $file);
  #MailScanner::Log::InfoLog("#### $BaseDir - $id - $part");
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("%s", $logout);

  $infections->{$id}{$part} .= $Name . ': ' if $Name;
  $infections->{$id}{$part} .= "Found virus $virus in file $notype\n";
  $types->{$id}{$part}      .= "v"; # so we know what to tell sender
  return 1;
}


# Process ClamAV (v0.22) output
# This code contributed in its entirety by
# Adrian Bridgett <adrian@smop.co.uk>.
# Please contact him with any support questions.
sub ProcessClamAVOutput {
  my($line, $infections, $types, $BaseDir, $Name, $spaminfre) = @_;

  my($logline);

  if ($line =~ /^ERROR:/ or $line =~ /^execv\(p\):/ or
      $line =~ /^Autodetected \d+ CPUs/)
  {
    chomp $line;
    $logline = $line;
    $logline =~ s/%/%%/g;
    $logline =~ s/\s{20,}/ /g;
    MailScanner::Log::WarnLog($logline);
    return 0;
  }

  # clamscan currently stops as soon as one virus is found
  # therefore there is little point saying which part
  # it's still a start mind!

  # Only tested with --unzip since only windows boxes get viruses ;-)

  $_ = $line;
  if (/^Archive:  (.*)$/)
  {
    $clamav_archive = $1;
    $qmclamav_archive = quotemeta($clamav_archive);
    return 0;
  }
  return 0 if /Empty file\.?$/;
  # Normally means you just havn't asked for it
  if (/: (\S+ module failure\.)/)
  {
    MailScanner::Log::InfoLog("ProcessClamAVOutput: %s", $1);
    return 0;
  }
  return 0 if /^  |^Extracting|module failure$/;  # "  inflating", "  deflating.." from --unzip
  if ($clamav_archive ne "" && /^$qmclamav_archive:/)
  {
    $clamav_archive = "";
    $qmclamav_archive = "";
    return 0;
  }

  return 0 if /OK$/; 
  
  $logline = $line;
  $logline =~ s/\s{20,}/ /g;

  #(Real infected archive: /var/spool/MailScanner/incoming/19746/./i75EFmSZ014248/eicar.rar)
  if (/^\(Real infected archive: (.*)\)$/)
  {
     my ($file, $ReportStart);
     $file = $1;
     $file =~ s/^(.\/)?$BaseDir\/?//;
     $file =~ s/^\.\///;
     my ($id,$part) = split /\//, $file, 2;
     my $notype = substr($part,1);
     $logline =~ s/\Q$part\E/$notype/;

     # Only log the whole message if no attachment has been logged
     MailScanner::Log::InfoLog("%s", $logline)
       unless $ClamAVAlreadyLogged{"$id"} && $part eq '';
     $ClamAVAlreadyLogged{"$id"} = 1;

     $ReportStart = $notype;
     $ReportStart = $Name . ': ' . $ReportStart if $Name;
     $infections->{"$id"}{"$part"} .= "$ReportStart contains a virus\n";
     $types->{"$id"}{"$part"} .= "v";
     return 1;
  }

  if (/^(\(raw\) )?(.*?): (.*) FOUND$/)
  {
    my ($file, $subfile, $virus, $report, $ReportStart);
    $virus = $3;

    if ($clamav_archive ne "")
    {
      $file = $clamav_archive;
      ($subfile = $2) =~ s/^.*\///;  # get basename of file
      $report = "in $subfile (possibly others)";
    }
    else
    {
      $file = $2;
    }     
     
    $file =~ s/^(.\/)?$BaseDir\/?//;
    $file =~ s/^\.\///;
    my ($id,$part) = split /\//, $file, 2;
    # JKF 20090125 Full message check.
    my $notype = substr($part,1);
    $logline =~ s/\Q$part\E/$notype/;

    $part = "" if $id =~ s/\.(message|header)$//;

    # Only log the whole message if no attachment has been logged
    MailScanner::Log::InfoLog("%s", $logline)
      unless $ClamAVAlreadyLogged{"$id"} && $part eq '';
    $ClamAVAlreadyLogged{"$id"} = 1;

    if ($virus =~ /$spaminfre/) {
      # It's spam found as an infection
      # 20090730
      return "0 $id $virus";
    }

    ## If it doesn't start with $BaseDir/./ then it isn't a real report
    # Don't release this just yet
    #return 0 unless $file =~ /^\/$BaseDir\/\.\//;

    $ReportStart = $notype;
    $ReportStart = $Name . ': ' . $ReportStart if $Name;
    $infections->{"$id"}{"$part"} .= "$ReportStart contains $virus $report\n";
    $types->{"$id"}{"$part"} .= "v";
    return 1;
  }

  return 0 if /^(.*?): File size limit exceeded\.$/;

  chomp $line;
  return 0 if $line =~ /^$/; # Catch blank lines
  $logline = $line;
  $logline =~ s/%/%%/g;
  return 0;
}

# Parse the output of the Trend VirusWall vscan output.
# Contributed in its entirety by Martin Lorensen <mlo@uni2.dk>
sub ProcessTrendOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;

  return if $line =~ /^\s*(=====|Directory:|Searched :|File:|Searched :|Scan :|Infected :|Time:|Start :|Stop :|Used :|Configuration:|$)/;

  # Next line didn't work with zip (and other) archives
  #$line =~ y/\t//d and $trend_prevline = $line;
  $line =~ s/^\t+\././ and $trend_prevline = $line;

  #MailScanner::Log::InfoLog("%s", $line);

  # Sample output:
  #
  # Scanning 2 messages, 1944 bytes
  # Virus Scanner v3.1, VSAPI v5.500-0829
  # Trend Micro Inc. 1996,1997
  # ^IPattern version 329
  # ^IPattern number 46849
  # Configuration: -e'{*
  # Directory .
  # Directory ./g72CdVd6018935
  # Directory ./g72CdVd7018935
  # ^I./g72CdVd7018935/eicar.com
  # *** Found virus Eicar_test_file in file /var/spool/MailScanner/incoming_virus/g72CdVd7018935/eicar.com

  if ( $line =~ /Found virus (\S+) in file/i )
   {
    my($virus ) = $1; # Name of virus found

    # Unfortunately vscan shows the full filename even though it was given
    # a relative name to scan. The previous line is relative, though.
    # So use that instead.

    my($dot, $id, $part, @rest) = split(/\//, $trend_prevline);
    my $notype = substr($part,1);
    $trend_prevline =~ s/\Q$part\E/$notype/;

    $infections->{$id}{$part} .= $Name . ': ' if $Name;
    $infections->{$id}{$part} .= "Found virus $virus in file $trend_prevline\n";
    $types->{$id}{$part}      .= "v"; # so we know what to tell sender
    MailScanner::Log::NoticeLog("Trend found %s in %s", $virus, $trend_prevline);
    return 1;
   }
  return 0;
}


# Parse the output of the Bitdefender bdc output.
sub ProcessBitdefenderOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;

  #print STDERR "$line\n";
  return 0 unless $line =~ /\t(infected|suspected): ([^\t]+)$/;

  my $virus = $2;
  my $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #print STDERR "virus = \"$virus\"\n";
  # strip the base from the message dir and remove the ^I junk
  $logout =~ s/^.+\/\.\///; # New
  $logout =~ s/\cI/:/g; # New

  # Sample output:
  #
  # /var/spool/MailScanner/incoming/1234/./msgid/filename	infected: virus
  # /var/spool/MailScanner/incoming/1234/./msgid/filename=>subpart	infected: virus

  # Remove path elements before /./ leaving just id/part/rest
  # 20090311 Remove leading BaseDir if it's there too.
  $line =~ s/^$BaseDir\///;
  $line =~ s/^.*\/\.\///;
  my($id, $part, @rest) = split(/\//, $line);

  $part =~ s/\t.*$//;
  $part =~ s/=\>.*$//;

  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("%s", $logout);
  #print STDERR "id = $id\npart = $part\n";
  $infections->{$id}{$part} .= $Name . ': ' if $Name;
  $infections->{$id}{$part} .= "Found virus $virus in file $notype\n";
  $types->{$id}{$part}      .= "v"; # so we know what to tell sender
  return 1;
}


# Process Norman virus scanner output
# NORMAN
#Norman Virus Control Version 5.60.10  Sep  9 2003 12:31:01
#Copyright (c) 1993-2003 Norman ASA
#
#NSE revision 5.60.13
#nvcbin.def revision 5.60 of 2003/10/03 (49233 variants)
#nvcmacro.def revision 5.60 of 2003/09/30 (9514 variants)
#Total number of variants: 58747
#
#Logging to '/opt/norman/logs/nvc00002.log'
#Possible virus in './q11/barendsesaunastoom.doc' -> 'W97M/Verlor.A'
#Possible virus in '/root/q/./q4/new : eicar.com' -> 'EICAR_Test_file_not_a_virus!'
#Possible virus in '/root/q/./q4/new2 : eicar.com' -> 'EICAR_Test_file_not_a_virus!'
#Possible virus in '/root/q/./qeicar/dfgBJNiNQG014777 : eicar.doc' -> 'EICAR_Test_file_not_a_virus!'
#Possible virus in '/root/q/./qeicar/message : eicar.com' -> 'EICAR_Test_file_not_a_virus!'
sub ProcessNormanOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;

  #print STDERR "$line\n";
  return 0 unless $line =~ /^[^']+'([^']+)' -> '([^']+)'\s*$/;
  my ($filename, $virus) = ($1, $2);

  #print STDERR "virus = \"$virus\"\n";
  my $logout = $line;
  $logout =~ s/\s{20,}/ /g;

  # Remove $BaseDir from front of filename if it's there
  $filename =~ s/^$BaseDir\///;
  # Remove the leading './'
  $filename =~ s/^\.\///;

  my($id, $part, @rest) = split(/\//, $filename);

  $part =~ s/ : .*$//; # Remove archive member filename

  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("%s", $logout);
  #print STDERR "id = $id\npart = $part\n";
  $infections->{$id}{$part} .= $Name . ': ' if $Name;
  $infections->{$id}{$part} .= "Found virus $virus in file $notype\n";
  $types->{$id}{$part}      .= "v"; # so we know what to tell sender
  return 1;
}

# Parse Symantec CSS Output.
# Written by Martin Foster <martin_foster@pacific.net.au>.
# Modified by Kevin Spicer <kevin@kevinspicer.co.uk> to handle output
# of cscmdline.
sub ProcessCSSOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($css_virus, $css_report, $logline, $file, $ReportStart);
  
  chomp $line;
  $logline = $line;
  $logline =~ s/%/%%/g;
  $logline =~ s/\s{20,}/ /g;
  if ($line =~ /^\*\*\*\*\s+ERROR!/ )
  {
    MailScanner::Log::WarnLog($logline);
    return 0;
  }

  if ($line =~ /^File:\s+(.*)$/)
  {
    $css_filename = $1;
    $css_infected = "";
    return 0;
  }
  if ($line =~ /^Infected:\s+(.*)$/)
  {
    $css_infected = $1;
    return 0;
  }
  if ($line =~ /^Info:\s+(.*)\s*\(.*\)$/)
  {
    $css_virus = $1;
    # Okay, we have three pieces of information...
    # $css_filename - the name of the scanned file
    # $css_infected - the name of the infected file (maybe subpart of 
    #                 an archive)
    # $css_virus    - virus name etc.
    
    # Wipe out the original filename from the infected report
    $css_infected =~ s/^\Q$css_filename\E(\/)?//;
    # If anything is left this is a subfile of an archive
    if ($css_infected ne "") { $css_infected = "in part $css_infected" }
    
    $file=$css_filename;
    $file =~ s/^(.\/)?$BaseDir\/?//;
    $file =~ s/^\.\///;
    my ($id,$part) = split /\//, $file, 2;
    my $notype = substr($part,1);
    $logline =~ s/\Q$part\E/$notype/;
    MailScanner::Log::WarnLog($logline);

    $ReportStart = $notype;
    $ReportStart = $Name . ': ' . $ReportStart if $Name;
    $infections->{"$id"}{"$part"} .= "$ReportStart contains $css_virus $css_infected\n";
    $types->{"$id"}{"$part"} .= "v";
    return 1;
  }

  # Drop through - weed out known reporting lines
  if ($line =~ /^Symantec CarrierScan Version/ ||
      $line =~ /^Cscmdline Version/ ||
      $line =~ /^Command Line:/ ||
      $line =~ /^Completed.\s+Directories:/ ||
      $line =~ /^Virus Definitions:/ ||
      $line =~ /^File \[.*\] was infected/ ||
      $line =~ /^Scan (start)|(end):/ ||
      $line =~ /^\s+(Files Scanned:)|(Files Infected:)|(Files Repaired:)|(Errors:)|(Elapsed:)/) { return 0 }

  return 0 if $line =~ /^$/; # Catch blank lines
  $logline = $line;
  $logline =~ s/%/%%/g;
  MailScanner::Log::WarnLog("ProcessCSSOutput: unrecognised " .
                            "line \"$logline\". Please contact the authors!");
 
  return 0; 
}

# Line: ./gBJNiNQG014777/eicar.doc  Virus identified EICAR_Test
# Line: ./gBJNiNQG014777/eicar.zip:\eicar.com  Virus identified EICAR_Test (+2)
# JKF Version 8 :\ is now :/ and there are ESC[2K sequences at BOL

sub ProcessAvgOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;
  # Sample output:
  #./1B978O-0000g2-Iq/eicar.com  Virus identified  EICAR_Test (+2)
  #./1B978O-0000g2-Iq/eicar.zip:\eicar.com  Virus identified  EICAR_Test (+2)

  # Remove all the duff carriage-returns from the line
  $line =~ s/[\r\n]//g;
  # Removed the (+2) type stuff at the end of the virus name
  $line =~ s/^(.+)(?:\s+\(.+\))$/$1/;
  # JKF AVG8 Remove the control chars from start of the line
  $line =~ s/\e\[2K//g;

  #print STDERR "Line: $line\n";
  # Patch supplied by Chris Richardson to fix AVG7 problem
  # return 0 unless $line =~ /Virus (identified|found) +(.+)$/;
  #
  # Rick - This, used with my $virus = $4, doesn't work (always). End up with
  # missing virus name in postmaster/user reports. Lets just check here and use
  # the next two lines, without check all the extra junk that may or may not
  # be there, to pull the virus name which will always be in $1
  return 0 unless $line =~ /(virus.*(identified|found))|(trojan.*horse)\s+(.+)$/i; # Patch supplied by Chris Richardson /Virus (identified|found) +(.+)$/;

  my $virus = $line;
  $virus =~ s/^.+\s+(.+?)$/$1/;

  #print STDERR "Line: $line\n";
  #print STDERR "virus = \"$virus\"\n";
  my $logout = $line;
  $logout =~ s/\s{2,}/ /gs;
  $logout =~ s/:./->/;

  # Change all the spaces into / for the split coming up
  # Also the second variant prepends the archive name to the
  # infected filename with a:\ so we need to change that to
  # something else. I chose another / so it would end up in the
  # @rest wich is also why I changed the \s+ to /
  # then Remove path elements before /./ leaving just id/part/rest

  $line =~ s/\s+/\//g;
  $line =~ s/:\\/\//g;
  $line =~ s/:\//\//g; # JKF AVG8 :/ separates archives now too.
  $line =~ s/\.\///;
  my($id, $part, @rest) = split(/\//, $line);
  $part =~ s/\t.*$//;
  $part =~ s/=\>.*$//;
  #print STDERR "id:$id:part = $part\n";
  #print STDERR "$Name : Found virus $virus in file $part ID:$id\n";

  # If avg finds both the archive and file to be infected and the file
  # exists in more than one (because of SafeName) archive the archive is
  # reported twice so check and make sure the archive is only reported once

  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  $logout =~ /^.+\/(.+?)\s+(.+)\s*$/;
  MailScanner::Log::InfoLog("Avg: %s in %s", $2,$1);

  my $Report = $Name . ': ' if $Name;
  $Report .= "Found virus $virus in file $notype";
  my $ReportPattern = quotemeta($Report);

  $infections->{$id}{$part} .= "$Report\n" unless $infections->{$id}{$part} =~ /$ReportPattern/s;
  $types->{$id}{$part} .= "v" unless $types->{$id}{$part}; # so we know what to tell sender

  return 1;
}

sub ProcessVexiraOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;

  # Interesting output is either a filename starting with ./ or
  # a virus report starting with whitespace
  return 0 unless $line =~ /^\.\/|^\s+/;

  # Is it a filename?
  if ($line =~ /^\.\//) {
    $VexiraPathname = $line;
    return 0;
  }

  # Dig the message id and attachment filename out of the VexiraPathname
  my($dot, $id, $part, @rest, $virusname);
  ($dot, $id, $part, @rest) = split(/\//, $VexiraPathname);

  $line =~ s/^\s+//g;
  $line =~ s/\s+$//g;

  my $notype = substr($part,1);

  # virus found: EICAR_test_file ... (NOT killable) skipped
  #print STDERR "Line is \"$line\"\n";
  $virusname = $2 if $line =~ /(found:|virus:)\s+(\S+)\s+\.\.\./i;
  #print STDERR "Virusname is \"$virusname\"\n";
  MailScanner::Log::NoticeLog("Vexira: found %s in %s (%s)", $virusname,
                            $id, $notype);
  #print STDERR "Id is \"$id\"\nPart is \"$part\"\n";

  $infections->{$id}{$part} .= $Name . ': ' if $Name;
  $infections->{$id}{$part} .= "Found virus $virusname in file $notype\n";
  $types->{$id}{$part}      .= "v"; # so we know what to tell sender
  return 1;
}

#sub ProcessVexiraOutput {
#  my($line, $infections, $types, $BaseDir, $Name) = @_;
#  chomp $line;
#  # Sample output:
#  # ALERT: [Eicar-Test-Signatur virus] ./gBJNiNQG014777/eicar.zip --> eicar.com <<< Contains code of the Eicar-Test-Signatur virus
#  # ALERT: [Eicar-Test-Signatur virus] ./gBJNiNQG014777/eicar.com <<< Contains code of the Eicar-Test-Signatur virus
#  # ALERT: [Eicar-Test-Signatur virus] ./gBJNiNQG014777/eicar.doc <<< Contains code of the Eicar-Test-Signatur virus
#
#  print STDERR "Line: $line\n";
#  return 0 unless $line =~ /^ALERT: \[([^\]]+)\] /;
#
#  my $virus = $1;
#  print STDERR "Line = $line\n";
#  print STDERR "virus = \"$virus\"\n";
#  my $logout = $line;
#  $logout =~ s/\s{20,}/ /g;
#  MailScanner::Log::InfoLog("%s", $logout);
#
#  # Change all the spaces into / for the split coming up
#  # Also the second variant prepends the archive name to the
#  # infected filename with a:\ so we need to change that to
#  # something else. I chose another / so it would end up in the
#  # @rest wich is also why I changed the \s+ to /
#  # then Remove path elements before /./ leaving just id/part/rest
#
#  #$line =~ s/^ALERT: //g; Patch provided by Alex Kerkhove
#  $line =~ s/^ALERT: //;
#  $line =~ s/\[.+\] *//g;
#  $line =~ s/\.\///;
#  #$line =~ s/^([^\/]+)\///g; Patch provided by Alex Kerkhove
#  $line =~ s/^([^\/]+)\///;
#  my $id = $1;
#  $line =~ /^(.+) <<< (.+)$/;
#  my $part = $1;
#  $part =~ s/ -->.*$//g;
#  print STDERR "id:$id:part = $part\n";
#  print STDERR "$Name : Found virus $virus in file $part ID:$id\n";
#  $infections->{$id}{$part} .= $Name . ': ' if $Name;
#  $infections->{$id}{$part} .= "Found $virus in file $part\n";
#  $types->{$id}{$part}      .= "v"; # so we know what to tell sender
#  return 1;
#}

#my($SSEFilename, $SSEVirusname, $SSEVirusid, $SSEFilenamelog);
sub ProcessSymScanEngineOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  chomp $line;

  if ($line =~ /^(\.\/.*) had [0-9]+ infection\(s\):/) {
    # Start of the report for a new file. Initialise state machine.
    #print STDERR "Found report about $1\n";
    $SSEFilename = $1;
    $SSEVirusname = '';
    $SSEVirusid = 0;
    $SSEFilenamelog = '';
    return 0;
  }
  if ($line =~ /^\s+File Name:\s+(.*)$/) {
    #print STDERR "Filenamelog = $1\n";
    $SSEFilenamelog = $1;
    return 0;
  }
  if ($line =~ /^\s+Virus Name:\s+(.*)$/) {
    #print STDERR "Virusname = $1\n";
    $SSEVirusname = $1;
    return 0;
  }
  if ($line =~ /^\s+Virus ID:\s+(.*)$/) {
    #print STDERR "Virusid = $1\n";
    $SSEVirusid = $1 + 0;
    return 0;
  }
  if ($line =~ /^\s+Disposition:\s+(.*)$/) {
    #print STDERR "Got Disposition\n";
    # This is the last lin of each file report, so use as the trigger
    # to process the file. But we can have multiple reports for the same
    # $SSEFilename, the other lines are just repeated.

    # If the Virusid < 0 then we don't care about this report.
    # If the report was about a message header then we also don't care.
    return 0 if $SSEVirusid<0 || $SSEFilename =~ /\.header$/;
    # # If the report was about the full message file, then handle that too.
    # $SSEFilename =~ s/\/message$// if $SSEFilename =~ /^\.\/[^/]+\/message/;

    # If there were lines missing, then scream about it!
    if ($SSEVirusname eq '' || $SSEFilenamelog eq '') {
      MailScanner::Log::WarnLog("SymantecScanEngine: Output Parser Failure! Please report this urgently to mailscanner\@ecs.soton.ac.uk");
    }

    #print STDERR "Building report about $SSEFilename $SSEVirusname\n";
    # It's a report we care about
    my($dot, $id, $part, @rest) = split(/\//, $SSEFilename);
    my $notype = substr($part,1);
    
    MailScanner::Log::InfoLog("SymantecScanEngine::$notype $SSEVirusname");
    my $report = $Name . ': ' if $Name;
    $infections->{"$id"}{"$part"}
    .= "$report$notype was infected: $SSEVirusname\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    #print STDERR "id=$id\tpart=$part\tVirusname=$SSEVirusname\n";
    return 1;
  }
  return 0;
}


# This is old code written by someone else. Does not appear to work, and
# is totally impossible to understand. Sorry.
#
#sub ProcessSymScanEngineOutput {
#  my($line, $infections, $types, $BaseDir, $Name) = @_;
#  my($logout, $virusid, $virusname, $filename, $action, $shortname);
#  my($file, @files, $virus_found);
#  my($dot, $id, $part, @rest, $report);
#
#  chomp $line;
#
#  # Split all lines that start with a '.'
#  @files=split(/\|\./, $line);
#  $virus_found=0;
#  foreach $file (@files) {
#	$file=~/^(.*) had [0-9]+ infection\(s\):\|File Name:\s+([^\|]*)\|Virus Name:\s+([^\|]*)\|Virus ID:\s+([^\|]*)\|(.*)$/ || next;
#	$filename=".$1";	# We removed the '.', so put it back
#	$shortname=$2;
#	$virusname=$3;
#	$virusid=$4;
#	$action=$5;
#	# Ignore it if it's not a real virus
#	if(int($virusid) < 0) {
#		next;
#	}
#	($dot, $id, $part, @rest) = split(/\//, $filename);
#	MailScanner::Log::InfoLog("SymantecScanEngine::$shortname $virusname ");
#	$report = $Name . ': ' if $Name;
#	$infections->{"$id"}{"$part"}
#	.= "$report$part was infected: $virusname\n";
#	$types->{"$id"}{"$part"} .= "v"; # it's a real virus
#	$virus_found=1;
#  }
#  return $virus_found;
#}

sub ProcessAvastOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;


  chomp $line;
  #MailScanner::Log::InfoLog("Avast said \"$line\"");

  # Extract the infection report. Return 0 if it's not there or is OK.
  return 0 unless $line =~ /\t\[(.+)\]$/;
  my $infection = $1;
  return 0 if $infection =~ /^OK$/i;
  my $logout = $line;

  # Avast prints the whole path as opposed to
  # ./messages/part so make it the same
  $line =~ s/^Archived\s//i;
  $line =~ s/^$BaseDir//;

  #my $logout = $line;
  #$logout =~ s/%/%%/g;
  #$logout =~ s/\s{20,}/ /g;
  #$logout =~ s/^\///;
  #MailScanner::Log::InfoLog("%s found %s", $Name, $logout);

  # note: '$dot' does not become '.'
  # This removes the "Archived" bit off the front if present, too :)
  $line =~ s/\t\[.+\]$//; # Trim the virus report off the end
  my ($dot, $id, $part, @rest) = split(/\//, $line);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $infection =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("%s", $logout);
  #print STDERR "Dot, id, part = \"$dot\", \"$id\", \"$part\"\n";
  $infection = $Name . ': ' . $infection if $Name;
  $infections->{"$id"}{"$part"} .= $infection . "\n";
  $types->{"$id"}{"$part"} .= "v";
  #print STDERR "Infection = $infection\n";
  return 1;
}

sub ProcessAvastdOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;


  chomp $line;
  #MailScanner::Log::InfoLog("Avastd said \"$line\"");

  # Extract the infection report. Return 0 if it's not there or is OK.
  return 0 unless $line =~ /\t\[([^[]+)\](\t(.*))?$/;
  my $result = $1;
  my $infection = $3;
  return 0 if $result eq '+';
  my $logout = $line;
  MailScanner::Log::WarnLog("Avastd scanner found new response type \"%s\", report this to mailscanner\@ecs.soton.ac.uk immediately!", $result) if $result ne 'L';

  # Avast prints the whole path as opposed to
  # ./messages/part so make it the same
  $line =~ s/^$BaseDir//;

  #my $logout = $line;
  #$logout =~ s/%/%%/g;
  #$logout =~ s/\s{20,}/ /g;
  #$logout =~ s/^\///;
  #MailScanner::Log::InfoLog("%s found %s", $Name, $logout);

  # note: '$dot' does not become '.'
  # This removes the "Archived" bit off the front if present, too :)
  $line =~ s/\t\[[^[]+\]\t.*$//; # Trim the virus report off the end
  my ($dot, $id, $part, @rest) = split(/\//, $line);
  #print STDERR "Dot, id, part = \"$dot\", \"$id\", \"$part\"\n";
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $infection =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("%s", $logout);
  $infection = $Name . ': ' . $infection if $Name;
  $infections->{"$id"}{"$part"} .= $infection . "\n";
  $types->{"$id"}{"$part"} .= "v";
  #print STDERR "Infection = $infection\n";
  return 1;
}

# This function provided in its entirety by Phil (UxBoD)
#
sub ProcessesetsOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::WarnLog($logout)
    if $line =~ /error/i && $line !~ /error - unknown compression method/i;

  if ($line =~
      /^object=\"file\",\s*name=\"([^\"]+)\",\s*(virus=\"([^\"]+)\")?/i) {
    my($fileentry, $virusname) = ($1,$3);
    $fileentry =~ s/^$BaseDir//;
    ($dot, $id, $part, @rest) = split(/\//, $fileentry);
    $part =~ s/^.*\-\> //g;
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = "Found virus $virusname in $notype";
    $report = $Name . ': '. $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }
  # This is for Esets 3.0.
  # name="./1/eicar.com", threat="Eicar test file", action="", info=""
  # Added modified patch from Alex Broens to pull out virus members.
  if ($line =~
      /^\s*name=\"([^\"]+)\",\s*threat=\"([^\"]+)\"/i) {
    my($filename, $virusname) = ($1,$2);
    #print STDERR "Found filename \"$filename\" and virusname $virusname\n";
    $filename =~ s/ \xbb .*$//; # Delete rest of archive internal names
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = "Found virus $virusname in $notype";
    $report = $Name . ': '. $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }
}


# Generate a list of all the virus scanners that are installed. It may
# include extras that are not installed in the case where there are
# scanners whose name includes a version number and we could not tell
# the difference.
sub InstalledScanners {

  my(@installed, $scannername, $nameandpath, $name, $path, $command, $result);

  # Get list of all the names of the scanners to look up. There are a few
  # rogue ones!
  my @scannernames = keys %Scanners;

  foreach $scannername (@scannernames) {
    next unless $scannername;
    next if $scannername =~ /generic|none/i;
    $nameandpath = MailScanner::Config::ScannerCmds($scannername);
    ($name, $path) = split(',', $nameandpath);
    $command = "$name $path -IsItInstalled";
    #print STDERR "$command gave: ";
    $result = system($command) >> 8;
    #print STDERR "\"$result\"\n";
    push @installed, $scannername unless $result;
  }

  # Now look for clamavmodule and sophossavi library-based scanners.
  # Assume they are installed if I can read the code at all.
  # They over-ride the command-line based versions of the same product.
  if (eval 'require Mail::ClamAV') {
    foreach (@installed) {
      s/^clamav$/clamavmodule/i;
    }
  }
  if (eval 'require SAVI') {
    foreach (@installed) {
      s/^sophos$/sophossavi/i;
    }
  }
  if (ClamdScan('ISITINSTALLED') eq 'CLAMDOK') {
    # If clamav is in the list, replace it with clamd, else add clamd
    my $foundit = 0;
    foreach (@installed) {
      if ($_ eq 'clamav') {
        s/^clamav$/clamd/;
        $foundit = 1;
        last;
      }
    }
    push @installed, 'clamd' unless $foundit;
  }
  if (Fprotd6Scan('ISITINSTALLED') eq 'FPSCANDOK') {
    # If f-prot-6 is in the list, replace it with f-protd6, else add f-protd6
    my $foundit = 0;
    foreach (@installed) {
      if ($_ eq 'f-prot-6') {
        s/^f-prot-6$/f-protd-6/;
        $foundit = 1;
        last;
      }
    }
    push @installed, 'f-protd-6' unless $foundit;
  }

  #print STDERR "Found list of installed scanners \"" . join(', ', @installed) . "\"\n";
  return @installed;
}


# Should be called when we're about to try to run some code to
# scan or disinfect (after checking that code is present).
# Nick: I'm not convinced this is really worth the bother, it causes me
#       quite a lot of work explaining it to people, and I don't think
#       that the people who should be worrying about this understand
#       enough about it all to know that they *should* worry about it.
sub CheckCodeStatus {
  my($codestatus) = @_;

  my($allowedlevel);

  my $statusname = MailScanner::Config::Value('minimumcodestatus');

  $allowedlevel = $S_SUPPORTED;
  $allowedlevel = $S_BETA        if $statusname =~ /^beta/i;
  $allowedlevel = $S_ALPHA       if $statusname =~ /^alpha/i;
  $allowedlevel = $S_UNSUPPORTED if $statusname =~ /^unsup/i;
  $allowedlevel = $S_NONE        if $statusname =~ /^none/i;

  return 1 if $codestatus>=$allowedlevel;

  #MailScanner::Log::WarnLog("Looks like a problem... dumping " .
  #                          "status information");
  #MailScanner::Log::WarnLog("Minimum acceptable stability = $allowedlevel " .
  #                          "($Config::CodeStatus)");
  #MailScanner::Log::WarnLog("Using Scanner \"$Config::VirusScanner\"");
  #foreach (keys %Scanners) {
  #  my $statusinfo = "Scanner \"$_\": scanning code status ";
  #  $statusinfo .= $Scanners{$_}{"SupportScanning"};
  #  $statusinfo .= " - disinfect code status ";
  #  $statusinfo .= $Scanners{$_}{"SupportDisinfect"};
  #  MailScanner::Log::WarnLog($statusinfo);
  #}
  MailScanner::Log::WarnLog("FATAL: Encountered code that does not meet " .
                            "configured acceptable stability"); 
  MailScanner::Log::DieLog("FATAL: *Please go and READ* " .
      "http://www.sng.ecs.soton.ac.uk/mailscanner/install/codestatus.shtml" .
      " as it will tell you what to do."); 
}

sub ClamdScan {
  my($dirname, $disinfect, $messagebatch) = @_;
  my($dir, $child, $childname, $filename, $results, $virus);

  my $lintonly = 0;
  $lintonly = 1 if $dirname eq 'ISITINSTALLED';

  # Clamd MUST have the full path to the file/dir it's scanning
  # so let's build the scan dir here and remove that pesky \. at the end
  my $ScanDir = "$global::MS->{work}->{dir}/$dirname";
  $ScanDir =~ s/\/\.$//;

  # If we don't have the required perl libs exit in a fashion the
  # parser will understand
  unless (eval ' require IO::Socket::INET ' ){
    print "ERROR:: You Need IO-Socket-INET To Use clamd As A " .
          "Scanner :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }
    unless (eval ' require IO::Socket::UNIX ' ){
    print "ERROR:: You Need IO-Socket-INET To Use clamd As A " .
          "Scanner :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # The default scan type is set here and if threading has been enabled
  # switch to threaded scanning
  my $ScanType = "CONTSCAN";
  my $LockFile = MailScanner::Config::Value('clamdlockfile');
  my $LockFile = '' if $lintonly; # Not dependent on this for --lint
  my $TCP = 1;
  my $TimeOut = MailScanner::Config::Value('virusscannertimeout');
  my $UseThreads = MailScanner::Config::Value('clamdusethreads');
  $ScanType = "MULTISCAN" if $UseThreads;

  my $PingTimeOut = 90; # should respond much faster than this to PING
  my $Port = MailScanner::Config::Value('clamdport');
  my $Socket = MailScanner::Config::Value('clamdsocket');
  my $line = '';
  my $sock;

  # If we did not receive a socket file name then we run in TCP mode

  $TCP = 0 if $Socket =~ /^\//;

  # Print our current parameters if we are in debug mode
  MailScanner::Log::DebugLog("Debug Mode Is On");
  MailScanner::Log::DebugLog("Use Threads : YES") if $UseThreads;
  MailScanner::Log::DebugLog("Use Threads : NO") unless $UseThreads;
  MailScanner::Log::DebugLog("Socket    : %s", $Socket)  unless $TCP;
  MailScanner::Log::DebugLog("IP        : %s", $Socket) if $TCP;
  MailScanner::Log::DebugLog("IP        : Using Sockets") unless $TCP;
  MailScanner::Log::DebugLog("Port      : %s", $Port) if $TCP;
  MailScanner::Log::DebugLog("Lock File : %s", $LockFile) if $LockFile ne '';
  MailScanner::Log::DebugLog("Lock File : NOT USED", $LockFile) unless $LockFile ne '';
  MailScanner::Log::DebugLog("Time Out  : %s", $TimeOut);
  MailScanner::Log::DebugLog("Scan Dir  : %s", $ScanDir);

  # Exit if we cannot find the socket file, or we find the file but it's not
  # a socket file (and of course we are not using TCP sockets)

  if (!$TCP && ! -e $Socket) {
    MailScanner::Log::WarnLog("Cannot find Socket (%s) Exiting!",
                              $Socket) if !$TCP && ! -e $Socket && !$lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  if (!$TCP && ! -S $Socket) {
    MailScanner::Log::WarnLog("Found %s but it is not a valid UNIX Socket. " .
                              "Exiting", $Socket) if !$TCP && ! -S $Socket && !$lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # If there should be a lock file, and it's missing the we assume
  # the daemon is not running and warn, pass error to parser and leave
  if ( $LockFile ne '' && ! -e $LockFile ){
    MailScanner::Log::WarnLog("Lock File %s Not Found, Assuming Clamd " .
                              "Is Not Running", $LockFile) && !$lintonly;
    print "ERROR:: Lock File $LockFile was not found, assuming Clamd  " .
          "is not currently running :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # Connect to the clamd daemon, If we don't connect send the log and
  # parser an error message and exit.
  $sock = ConnectToClamd($TCP,$Socket,$Port, $TimeOut);
  unless ($sock || $lintonly) {
    print "ERROR:: COULD NOT CONNECT TO CLAMD, RECOMMEND RESTARTING DAEMON " .
          ":: $dirname\n";
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }
  unless ($sock) {
    MailScanner::Log::WarnLog("ERROR:: COULD NOT CONNECT TO CLAMD, ".
                              "RECOMMEND RESTARTING DAEMON ") unless $sock || $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # If we got here we know we have a socket file but it could be dead
  # or clamd may not be listening on the TCP socket we are using, either way
  # we exit with error if we could not open the connection

  if (!$sock) { # socket file from a dead clamd or clamd is not listening
    MailScanner::Log::WarnLog("Could not connect to clamd") unless $lintonly;
    print "ERROR:: COULD NOT CONNECT TO CLAMD DAEMON  " .
          ":: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  } else {
    # Make sure the daemon is responsive before passing it something to
    # scan
    if ($sock->connected) {
      MailScanner::Log::DebugLog("Clamd : Sending PING");
      $sock->send("PING\n");
      $PingTimeOut += time();
      $line = '';

      while ($line eq '') {
        $line = <$sock>;
        # if we timeout then print error (if debugging) and exit with erro
        MailScanner::Log::WarnLog("ClamD Timed Out During PING " .
                                  "Check!") if $PingTimeOut < time && !$lintonly;
        print "ERROR:: CLAM PING TIMED OUT! :: " .
              "$dirname\n" if time > $PingTimeOut && !$lintonly;
        if (time > $PingTimeOut) {
          print "ScAnNeRfAiLeD\n" unless $lintonly;
          return 1;
        }
        last if time > $PingTimeOut;
        chomp($line);
      }

      MailScanner::Log::DebugLog("Clamd : GOT '%s'",$line);
      MailScanner::Log::WarnLog("ClamD Responded '%s' Instead of PONG " .
                            "During PING Check, Recommend Restarting Daemon",
                                $line) if $line ne 'PONG' && !$lintonly;
      unless ($line eq "PONG" || $lintonly) {
        print "ERROR:: CLAMD DID NOT RESPOND PROPERLY TO PING! PLEASE " .
              "RESTART DAEMON :: $dirname\n";
        print "ScAnNeRfAiLeD\n" unless $lintonly;
      }
      close($sock);
      return 1 unless $line eq "PONG";
      MailScanner::Log::DebugLog("ClamD is running\n");
    } else {
      MailScanner::Log::WarnLog("ClamD has an Unknown problem, recommend you re-start the daemon!") unless $lintonly;
      print "ERROR:: CLAMD HAS AN UNKNOWN PROBLEM, RECOMMEND YOU " .
            "RESTART THE DAEMON :: $dirname\n" unless $lintonly;
      print "ScAnNeRfAiLeD\n" unless $lintonly;
      return 1;
    }
  }

  # If we are just checking to see if it's installed, bail out now
  return 'CLAMDOK' if $lintonly;

  # Attempt to reopen the connection to clamd
  $sock = ConnectToClamd($TCP,$Socket,$Port, $TimeOut);
  unless ($sock) {
    print "ERROR:: COULD NOT CONNECT TO CLAMD, RECOMMEND RESTARTING DAEMON " .
          ":: $dirname\n";
    MailScanner::Log::WarnLog("ERROR:: COULD NOT CONNECT TO CLAMD, ".
                              "RECOMMEND RESTARTING DAEMON ");
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  if ( $sock->connected ) {
    # Going to Scan the entire batch at once, should really speed things
    # up especially on SMP hosts running mutli-threaded scaning
    $TimeOut += time();

    $sock->send("$ScanType $ScanDir\n");
    MailScanner::Log::DebugLog("SENT : $ScanType %s ", "$ScanDir");
    $results = '';
    my $ResultString = '';

    while($results = <$sock>) {
      # if we timeout then print error and exit with error
      if (time > $TimeOut) {
        MailScanner::Log::WarnLog("ClamD Timed Out!");
        close($sock);
        print "ERROR:: CLAM TIMED OUT! :: " .
              "$dirname\n";
        print "ScAnNeRfAiLeD\n" unless $lintonly;
        return 1;
      }
      # Append this file to any others already found
      $ResultString .= $results;
    }

    # Remove the trailing line feed and create an array of
    # lines for sending to the parser
    chomp($ResultString);
    my @report = split("\n",$ResultString) ;

    foreach $results (@report) {
      #print STDERR "Read \"$results\"\n";
      # Pull the basedir out and change it to a dot for the parser
      $results =~ s/$ScanDir/\./;
      $results =~ s/:\s/\//;

      # If we get an access denied error then print the properly
      # formatted error and leave
      print STDERR "ERROR::Permissions Problem. Clamd was denied access to " .
            "$ScanDir::$ScanDir\n"
        if $results =~ /\.\/Access denied\. ERROR/;
      last if $results =~ /\.\/Access denied\. ERROR/;

      # If scanning full batch clamd returns OK on the directory
      # name at the end of the scan so we discard that result when
      # we get to it
      next if $results =~ /^\.\/OK/;
      # Workaround for MSRBL-Images (www.msrbl.com/site/msrblimagesabout)
      $results =~ s#MSRBL-Images/#MSRBL-Images\.#;
      my ($dot,$childname,$filename,$rest) = split('/', $results, 4);

      unless ($results) {
        print "ERROR:: $results :: $dirname/$childname/$filename\n";
        next;
      }

      # SaneSecurity ClamAV database can find things in the headers
      # of the message. The parser above results in $childname ending
      # in '.header' and $rest ends in ' FOUND'. In this case we need
      # to report a null childname so the infection is mapped to the
      # entire message.
      if ($childname =~ /\.(?:header|message)$/ && $filename =~ /\sFOUND$/) {
	$rest = $filename;
        $filename = '';
        $childname =~ s/\.(?:header|message)$//;
        print "INFECTED::";
        $rest =~ s/\sFOUND$//;
        print " $rest :: $dirname/$childname/$filename\n";
      }

      elsif ($rest =~ s/\sFOUND$//) {
        print "INFECTED::";
        print " $rest :: $dirname/$childname/$filename\n";
      } elsif ($rest =~ /\sERROR$/) {
        print "ERROR:: $rest :: $dirname/$childname/$filename\n";
        next;
      } else {
        print "ERROR:: UNKNOWN CLAMD RETURN $results :: $ScanDir\n";
      }
    }

    close($sock);
  } else {
    # We were able to open the socket but could not actually connect
    # to the daemon so something odd is amiss and we send error to
    # parser and log, then exit
    print "ERROR:: UNKNOWN ERROR HAS OCCURED WITH CLAMD, SUGGEST YOU " .
          "RESTART DAEMON :: $dirname\n";
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    MailScanner::Log::DebugLog("UNKNOWN ERROR HAS OCCURED WITH THE CLAMD " .
                               "DAEMON SUGGEST YOU RESTART CLAMD!");
    return 1;
  }

} # EO ClamdScan

# This function just opens the connection to the clamd daemon
# and returns either a valid resource or undef if the connection
# fails
sub ConnectToClamd {
  my($TCP,$Socket,$Port, $TimeOut) = @_;
  my $sock;
  # Attempt to open the appropriate socket depending on the type (TCP/UNIX)
  if ($TCP) {
    $sock = IO::Socket::INET->new(PeerAddr => $Socket,
                                  PeerPort => $Port,
                                  Timeout => $TimeOut,
                                  Proto     => 'tcp');
  } else {
    $sock = IO::Socket::UNIX->new(Timeout => $TimeOut,
                                  Peer => $Socket );
  }
  return undef unless $sock;
  return $sock;
} # EO ConnectToClamd

sub ConnectToFpscand {
  my($Port, $TimeOut) = @_;
  #print STDERR "Fpscand Port = $Port\nTimeout = $TimeOut\n";
  my $sock = IO::Socket::INET->new(PeerAddr => "localhost",
                                   PeerPort => $Port,
                                   Timeout  => $TimeOut,
                                   Proto    => 'tcp',
                                   Type     => SOCK_STREAM);
  #print STDERR "Fpscand sock is $sock\n";
  return undef unless $sock;
  return $sock;
}

sub Fprotd6Scan {
  my($dirname, $disinfect, $messagebatch) = @_;

  my $lintonly = 0;
  $lintonly = 1 if $dirname eq 'ISITINSTALLED';

  # Clamd MUST have the full path to the file/dir it's scanning
  # so let's build the scan dir here and remove that pesky \. at the end
  my $ScanDir = "$global::MS->{work}->{dir}/$dirname";
  $ScanDir =~ s/\/\.$//;

  # If we don't have the required perl libs exit in a fashion the
  # parser will understand
  unless (eval ' require IO::Socket::INET ' ){
    print "ERROR:: You Need IO-Socket-INET To Use f-protd-6 As A " .
          "Scanner :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  my $TimeOut = MailScanner::Config::Value('virusscannertimeout');
  my $Port = MailScanner::Config::Value('fprotd6port');
  my $line = '';
  my $sock;

  # Attempt to open the connection to fpscand
  $sock = ConnectToFpscand($Port, $TimeOut);
  print "ERROR:: COULD NOT CONNECT TO FPSCAND, RECOMMEND RESTARTING DAEMON " .
        ":: $dirname\n" unless $sock || $lintonly;
  print "ScAnNeRfAiLeD\n" unless $sock || $lintonly;
  MailScanner::Log::WarnLog("ERROR:: COULD NOT CONNECT TO FPSCAND, ".
                            "RECOMMEND RESTARTING DAEMON ") unless $sock || $lintonly;
  return 1 unless $sock;

  return 'FPSCANDOK' if $lintonly;

  # Walk the directory tree from $ScanDir downwards
  %FPd6ParserFiles = ();
  #MailScanner::Log::InfoLog("fpscand: RESET");
  print $sock "QUEUE\n";
  Fpscand($ScanDir, $sock);
  print $sock "SCAN\n";
  $sock->flush;

  # Read back all the reports
  while(keys %FPd6ParserFiles) {
    $_ = <$sock>;
    chomp;
    next unless /^(\d+) <(.+)> (.+)$/; # Assume virus name is 1 word for now
    my ($code, $text, $path) = ($1, $2, $3);
    #print STDERR "Code = *$code* Text = *$text* Path = *$path*\n";
    my $attach = $path;
    $attach =~ s/-\>.*$//;
    #MailScanner::Log::InfoLog("fpscand: Removed \"%s\"", $attach);
    delete $FPd6ParserFiles{$attach};

    # Strip any surrounding <> braces
    $path =~ s/^$ScanDir/./; # Processor expects ./id/attachname/.....

    #JJnext if $code == 0 || $text eq 'clean'; # Skip clean files

    if (($code & 3) || $text =~ /^infected: /i) {
      $text =~ s/^infected: //i;
      $path =~ s/\.(?:header|message)$//; # Look for infections in headers
      #print "INFECTED:: $text :: $path\n";
      print "INFECTED:: $text :: $path\n";
    } elsif ($code == 0 || $text =~ /^clean/i) {
      print "CLEAN:: $text :: $path\n";
    } else {
      print "ERROR:: $code $text :: $path\n";
    }
  }
  $sock->close;
}

# Recursively walk the directory tree from $dir downwards, sending instructions
# to $sock as we go, one line for each file
sub Fpscand {
  my($dir, $sock) = @_;

  my $dh = new DirHandle $dir or MailScanner::Log::WarnLog("FProt6d: failed to process directory %s", $dir);
  my $file;
  while (defined($file = $dh->read)) {
    my $f = "$dir/$file";
    $f =~ /^(.*)$/;
    $f = $1;
    next if $file =~ /^\./ && -d $f; # Is it . or ..
    if (-d $f) {
      Fpscand($f, $sock);
    } else {
      print $sock "SCAN FILE $f\n";
      #print STDERR "Added $f to list\n";
      #MailScanner::Log::InfoLog("fpscand: Added \"%s\"", $f);
      $FPd6ParserFiles{$f} = 1;
    }
  }
  $dh->close;
}

sub ProcessFProtd6Output {
  my($line, $infections, $types, $BaseDir, $Name, $spaminfre) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($dot, $id, $part, @rest, $report, $attach);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #$logout =~ s/%/%%/g;

  #print STDERR "Output is \"$logout\"\n";
  ($keyword, $virusname, $filename) = split(/:: /, $line, 3);

  if ($keyword =~ /^error/i) {
    MailScanner::Log::InfoLog("%s::%s", 'FProtd6', $logout);
    return 1;
  } elsif ($keyword =~ /^info|^clean/i || $logout =~ /rar module failure/i) {
    return 0;
  } else {
    # Must be an infection reports

    ($dot, $id, $part, @rest) = split(/\//, $filename);
    $attach = $part;
    $attach =~ s/-\>.*$//; # This gives us the actual attachment name
    my $notype = substr($attach,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;
    MailScanner::Log::InfoLog("%s::%s", 'FProtd6', $logout);

    if ($virusname =~ /$spaminfre/) {
      # It's spam found as an infection
      # 20090730
      return "0 $id $virusname";
    }

    $report = $Name . ': ' if $Name;
    #print STDERR "Got an infection report of \"$virusname\" for \"$id\" \"$attach\"\n";
    if ($attach eq '') {
      # No part ==> entire message is infected.
      $infections->{"$id"}{""}
        .= "$report message was infected: $virusname\n";
    } else {
      $infections->{"$id"}{"$attach"}
        .= "$report$notype was infected: $virusname\n";
    }
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }
}

sub Processvba32Output {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest);
  my($logout);

  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  #MailScanner::Log::WarnLog($logout)
  #  if $line =~ /^\..*( infected | is suspected of )/i;

  $line =~ s/^$BaseDir/./; # Newer versions put BaseDir instead of .
  if ($line =~
      /^(\..*) : (infected|is suspected of) (.*)$/i) {
    my($fileentry, $virusname) = ($1,$3);
    #$fileentry =~ s/^$BaseDir//;
    ($dot, $id, $part, @rest) = split(/\//, $fileentry);
    $part =~ s/:\<[A-Z]+\>\\.*$//g;
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = "Found virus $virusname in $notype";
    $report = $Name . ': '. $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }
}

1;
