#
#   MailScanner - SMTP E-Mail Virus Scanner
#   Copyright (C) 2002  Julian Field
#
#   $Id: IMAPspam.pm,v 1.1.2.1 2004/03/23 09:23:43 jkf Exp $
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

use Mail::IMAPClient;

package MailScanner::CustomConfig;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 1.1.2.1 $, 10;

my $globalimap = 0;
my(%domain2user, %domain2password, %domain2server, %domain2folder);

sub IMAPerror {
  my($line) = @_;
  MailScanner::Log::WarnLog("IMAPspam error: syntax error in line %d of configuration file", $line);
}

sub InitIMAPspam {
  my($filename) = @_;

  MailScanner::Log::InfoLog("Initialising IMAPspam");

  my $fh = new FileHandle;
  unless ($fh->open("<$filename")) {
    MailScanner::Log::WarnLog("IMAPspam: Could not open configuration file \"$filename\"");
    return;
  }

  # Read in the config file which contains lines like
  # domain.com username password hostname folder
  # To put in the global setting use global instead of domain.com
  # 
  # The keys of the hashes are username@domainname
  # The values of the hashes are the password and the IMAP hostname.

  my $linecount = 0;
  my $records   = 0;
  my($domain, $username, $password, $server, $folder);
  while(defined($_=<$fh>)) {
    $linecount++;
    chomp;
    print STDERR "Read \"$_\"\n";
    s/^#//;
    s/^\s*//g;
    s/\s*$//g;
    next if /^$/;

    $folder = "";
    ($domain, $username, $password, $server, $folder) = split " ", $_, 5;
    &IMAPerror($linecount),next unless $server && $folder;
    $domain2user{$domain} = $username;
    $domain2password{$domain} = $password;
    $domain2server{$domain}   = $server;
    $domain2folder{$domain}   = $folder;
    $records++;
  }
    
  MailScanner::Log::InfoLog("IMAPspam: Read imap details for $records domains");

  $fh->close;
}

sub EndIMAPspam {
  # This function could log total stats, close databases, etc.
  MailScanner::Log::InfoLog("Ending IMAPspam");
}

# This will return "deliver" for any relevant messages, as well as saving the
# message in RFC822 format to the correct imap server for the user/domain.
# computer.
sub IMAPspam {
  my($message) = @_;

  print STDERR "In IMAPspam, message is $message\n";
  return 'deliver' unless $message; # Default if no message passed in
  return 'deliver' unless $message->{to};

  # We have a relevant message, so set the line-endings with a temp file
  print STDERR "We have a relevant message\n";
  my $tmphandle = new FileHandle;
  my $tmpname   = "/tmp/IMAPspam.tmp.$$";
  unless ($tmphandle->open(">$tmpname")) {
    MailScanner::Log::WarnLog("Could not create temp file $tmpname");
    return 'store';
  }
  
  $message->{store}->WriteEntireMessage($message, $tmphandle);
  $tmphandle->close;
  $tmphandle = new FileHandle;
  $tmphandle->open("<$tmpname") or MailScanner::Log::WarnLog("Could not read back temp file $tmpname");
  
  # Now read it into a string, converting line endings as we go
  my $messagetext = "";
  while(defined($_=<$tmphandle>)) {
    chomp;
    s/$/\r\n/;
    $messagetext .= $_;
  }
  $tmphandle->close;
  unlink $tmpname;

  print STDERR "I now have the message in tmpname, length = " . length($messagetext) . "\n";

  #
  # Now do the IMAP work to append the message to the mailboxes
  #


  # Do the global box first
  if (!$globalimap) {
    $globalimap = Mail::IMAPClient->new(Server   => $domain2server{'global'},
                                        User     => $domain2user{'global'},
                                        Password => $domain2password{'global'});
    print STDERR "Global connect 1 said $globalimap\n";
    if ($globalimap) {
      unless($globalimap->select($domain2folder{'global'})) {
        # 1st attempt failed so let is reconnect and try again
        MailScanner::Log::WarnLog("Failed to connect to global IMAP folder, retrying");
        print STDERR "Global IMAP select 1 failed\n";
        $globalimap = Mail::IMAPClient->new(Server   => $domain2server{'global'},
                                            User     => $domain2user{'global'},
                                            Password => $domain2password{'global'});
        print STDERR "Global connect 2 said $globalimap\n";
        if ($globalimap) {
          MailScanner::Log::WarnLog("Failed to connect to global IMAP folder, giving up till next message") unless $globalimap->select($domain2folder{'global'});
        }
      }
    }
  }

  unless ($globalimap->append($domain2folder{'global'}, $messagetext)) {
    print STDERR "Global append failed\n";
    MailScanner::Log::WarnLog("Failed to append new message to global IMAP folder");
  }
  print STDERR "Appended global message\n";

  # Build a list of all the domains we are working with.
  my %build = ();
  my $todomain;
  foreach $todomain (@{$message->{todomain}}) {
    $build{$todomain} = 1;
  }
  my @domains = keys %build;
  print STDERR "Working with domains: " . join(', ', @domains) . "\n";

  my $domain;
  foreach $domain (@domains) {
    my $imap = Mail::IMAPClient->new(Server => $domain2server{$domain},
                                     User   => $domain2user{$domain},
                                     Password => $domain2password{$domain});
    print STDERR "Imap connect to " . $domain2server{$domain} . "said $imap\n";
    if ($imap) {
      print STDERR "Writing message to domain.\n";
      $imap->select($domain2folder{$domain});
      $imap->append($domain2folder{$domain}, $messagetext);
      print STDERR "Wrote message to folder '" . $domain2folder{$domain} . "'\n";
    } else {
      print STDERR "Imap connect failed for this message.\n";
      MailScanner::Log::WarnLog("Failed to connect to IMAP server %s as %s", $domain2server{$domain}, $domain2user{$domain});
    }
  }

  print STDERR "All done for this message.\n\n\n";
  return 'deliver';
}

1;

