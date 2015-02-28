#
#   MailScanner - SMTP E-Mail Virus Scanner
#   Copyright (C) 2002  Julian Field
#
#   $Id: RBLs.pm 5078 2011-01-30 12:44:27Z sysjkf $
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

package MailScanner::RBLs;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use POSIX qw(:signal_h); # For Solaris 9 SIG bug workaround
use IO::Pipe;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5078 $, 10;

#my %spamlistfailures; # Number of consecutive failures for both lists

# Queues of history of spam list responses so we can detect failures
my %RBLsuccessqueue;    # values are lists of failure flags (1=failed)
my %RBLsuccessqsum;     # current sum of failure flags
my %RBLdead;            # has the RBL been killed

#
# Constructor.
#
#sub new {
#  my $type = shift;
#  my @params = @_;
#  my $this = {};
#
#  # no attributes, not really a class!
#
#  return bless $this, $type;
#}

# Setup all the class variables
sub initialise {
  %RBLsuccessqueue = ();
  %RBLsuccessqsum  = ();
  %RBLdead         = ();
}

# Do all the RBL checks for a message. Involves forking.
# Return a comma-separated list of all the hits, suitable for putting
# into a header.
# Return a list:
#   ($rblcounter, $rblspamheader) = MailScanner::RBLs::Checks($this);
#   1st parameter is number of rbl lists containing this message
sub Checks {
  my $message = shift;

  my($reverseip, $senderdomain, @slisttotry, @dlisttotry);
  my(@IPwords, $pipe);
  my($maxfailures, $queuelength, $spamliststring);
  my(@HitList, $Checked, $HitOrMiss);

  @IPwords      = (split(/\./, $message->{clientip}));
  $reverseip    = join('.', reverse @IPwords);
  $senderdomain = $message->{fromdomain};

  # Build lists of spam lists and spam domain lists to test with this message
  $spamliststring = MailScanner::Config::Value('spamlist', $message);
  if ($spamliststring) {
    $spamliststring =~ tr/,//d; # Delete any stray commas
    @slisttotry     = split(" ", $spamliststring);
  }

  $spamliststring = MailScanner::Config::Value('spamdomainlist', $message);
  if ($spamliststring) {
    $spamliststring =~ tr/,//d; # Delete any stray commas
    @dlisttotry     = split(" ", $spamliststring);
  }

  # Bail out if there is nothing to do
  return (0,"") unless @slisttotry || @dlisttotry;

  $maxfailures  = MailScanner::Config::Value('maxspamlisttimeouts', $message);
  $queuelength  = MailScanner::Config::Value('rbltimeoutlen', $message);

  $pipe = new IO::Pipe
    or MailScanner::Log::DieLog('Failed to create pipe, %s, try reducing ' .
                  'the maximum number of unscanned messages per batch', $!);

  my $PipeReturn = 0;
  my $GotAHit = 0;

  #(($readerfh, $writerfh) = FileHandle::pipe)
  #  or MailScanner::Log::DieLog('Failed to create pipe, %s', $!);

  my $pid = fork();
  die "Can't fork: $!" unless defined($pid);

  if ($pid == 0) {
    # In the child
    my $IsSpam = 0;
    my $RBLEntry;
    $pipe->writer();
    POSIX::setsid();

    # Switch to line buffering
    #select $pipe;
    #$| = 1;
    $pipe->autoflush();

    # Do the actual tests
    my($SpamName);
    foreach $SpamName (@slisttotry) {
      # Look up $reverseip in each of the spam domains we have
      print $pipe $SpamName . "\n";
      # If there have been too many consecutive failures, fake a "Miss"
      #if ($spamlistfailures{$SpamName} >= $maxfailures && $maxfailures > 0) {
      if ($RBLdead{$SpamName}) {
        print $pipe "Dead\n";
        next;
      }

      $RBLEntry = gethostbyname("$reverseip." .
                                MailScanner::Config::SpamLists($SpamName));
      if ($RBLEntry) {
        $RBLEntry = Socket::inet_ntoa($RBLEntry);
        if ($RBLEntry =~ /^127\.[01]\.[0-9]\.[123456789]\d*$/) {
          # Got a hit!
          $IsSpam = 1;
          print $pipe "Hit\n";
        } else {
          print $pipe "Miss\n";
        }
      } else {
        print $pipe "Miss\n";
      }
    }
    foreach $SpamName (@dlisttotry) {
      # Look up $SenderDomain in each of the named spam domains we have
      print $pipe $SpamName . "\n";
      # If there have been too many consecutive failures, fake a "Miss"
      #if ($spamlistfailures{$SpamName} >= $maxfailures && $maxfailures > 0) {
      if ($RBLdead{$SpamName}) {
        print $pipe "Dead\n";
        next;
      }
      # Fix for Steve Freegard.
      $RBLEntry = undef;
      if (MailScanner::Config::SpamLists($SpamName)) {
        $RBLEntry = gethostbyname("$senderdomain." .
                                  MailScanner::Config::SpamLists($SpamName));
      }
      if ($RBLEntry) {
        $RBLEntry = Socket::inet_ntoa($RBLEntry);
        if ($RBLEntry =~ /^127\.[01]\.0\.[123456789]$/) {
          # Got a hit!
          $IsSpam = 1;
          print $pipe "Hit\n";
        } else {
          print $pipe "Miss\n";
        }
      } else {
        print $pipe "Miss\n";
      }
    }

    $pipe->close();
    exit $IsSpam;
  }

  eval {
    $pipe->reader();
    local $SIG{ALRM} = sub { die "Command Timed Out" };
    alarm MailScanner::Config::Value('spamlisttimeout');
    # Read the list of matching RBL's printed by the child
    while(<$pipe>) {
      chomp;
      $Checked = $_;
      $HitOrMiss = <$pipe>;
      chomp $HitOrMiss;
      push @HitList, $Checked if $HitOrMiss eq 'Hit';
      # Did we get a response at all?
      unless ($HitOrMiss eq 'Dead') {
        # Got a response, store a success
        push @{$RBLsuccessqueue{$Checked}}, 0;
        # Roll the queue along one
        $RBLsuccessqsum{$Checked} += (shift @{$RBLsuccessqueue{$Checked}})?1:-1
          if @{$RBLsuccessqueue{$Checked}}>$queuelength;
        $RBLsuccessqsum{$Checked} = 0 if $RBLsuccessqsum{$Checked}<0;
      }
      ## We got a response, so zero the consecutive timouts counter
      #$spamlistfailures{"$Checked"} = 0 unless $HitOrMiss eq 'Dead';
    }
    $pipe->close();
    waitpid $pid, 0;
    $PipeReturn = $?;
    alarm 0;
    $pid = 0;
  };
  alarm 0;
  # Workaround for bug in perl shipped with Solaris 9,
  # it doesn't unblock the SIGALRM after handling it.
  eval {
    my $unblockset = POSIX::SigSet->new(SIGALRM);
    sigprocmask(SIG_UNBLOCK, $unblockset)
      or die "Could not unblock alarm: $!\n";
  };

  # Note to self: I only close the KID in the parent, not in the child.

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("RBL Checks failed with real error: $@")
    if $@ and $@ !~ /Command Timed Out/;

  # In which case any failures must be the alarm
  #if ($@ or $pid>0) {
  if ($pid>0) {
    if ($maxfailures>0) {
      # The lookup for RBL $Checked failed
      push @{$RBLsuccessqueue{$Checked}}, 1;
      $RBLsuccessqsum{$Checked}++;
      # Roll the queue along one
      $RBLsuccessqsum{$Checked} += (shift @{$RBLsuccessqueue{$Checked}})?1:-1
        if @{$RBLsuccessqueue{$Checked}}>$queuelength;
      $RBLsuccessqsum{$Checked} = 0 if $RBLsuccessqsum{$Checked}<0;
      # Mark the queue as dead if we have exceeded the limit
      if ($RBLsuccessqsum{$Checked}>$maxfailures &&
          @{$RBLsuccessqueue{$Checked}}>=$queuelength) {
        $RBLdead{$Checked} = 1;
        MailScanner::Log::WarnLog("Disabled RBL %s as reached %d/%d " .
                                  "timeouts", $Checked, $maxfailures,
                                  $queuelength);
      }
    } else {
      # Not tracking RBL lookup failures at all
      MailScanner::Log::WarnLog("RBL Check $Checked timed out and was killed");
    }

    # Kill the running child process
    my($i);
    kill -15, $pid;
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
  #MailScanner::Log::WarnLog("8 PID is $pid");

  # The return from the pipe is a measure of how spammy it was
  MailScanner::Log::NoticeLog("RBL checks: %s found in %s", $message->{id},
                            join(', ', @HitList))
    if @HitList && MailScanner::Config::Value('logspam');
  MailScanner::Log::DebugLog("RBL Checks: returned $PipeReturn");

  # No point actually using $PipeReturn, as we want to get a
  # useful result even when the child never reached its exit()
  #$PipeReturn = $PipeReturn>>8;
  # JKF 3/10/2005
  my $temp = @HitList;
  $temp = $temp + 0;
  $temp = 0 unless $HitList[0] =~ /[a-z]/i;
  return ($temp, join(', ', @HitList));
}

1;
