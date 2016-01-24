#!/usr/bin/env perl -w
use strict; 
use Net::DNS::Resolver;
use LWP::UserAgent;
use FileHandle;
use DirHandle;


# Work out Quarantine Directory from MailScanner.conf
my $base = '/var/spool/MailScanner/quarantine'; # Default value
my $msconf = new FileHandle("< /etc/MailScanner/MailScanner.conf") or warn "Cannot open main configuration file /etc/MailScanner/MailScanner.conf";
while(<$msconf>) {
  $base = $1 if /^\s*Quarantine\s*Dir\s*=\s*(\S+)/;
}
close($msconf);

my $current = $base."/phishingupdate/";
my $cache = $current."cache/";
my $status = $current."status";
my $urlbase = "http://www.mailscanner.tv/";
my $target= "/etc/MailScanner/phishing.bad.sites.conf";
my $query="msupdate.greylist.bastionmail.com";

my $baseupdated=0;

if (! -s $target) {
	open (FILE,">$target") or die "Failed to open target file so creating a blank file";
	print FILE "# Wibble";
	close FILE;
}

if (! -d $current) {
	print "Working directory is not present - making.....";
	mkdir ($current) or die "failed";
	print " ok!\n";
}
else{
	utime(time(), time(), $current); # So that clean quarantine doesn't delete it!
}

if (! -d $cache) {
	print "Cache directory is not present - making.....";
	mkdir ($cache) or die "failed";
	print " ok!\n";
}

my ($status_base, $status_update);

$status_base=-1;
$status_update=-1;

if (! -s $status) {
	print "This is the first run of this program.....\n";
}
else {
	print "Reading status from $status\n";
	open(STATUS_FILE, $status) or die "Unable to open status file\n";
	my $line=<STATUS_FILE>;
	close (STATUS_FILE);
	
	# The status file is text.text
	if ($line =~ /^(.+)\.(.+)$/) {
		$status_base=$1;
		$status_update=$2;
	}
}

print "Checking that $cache$status_base exists...";
if ((! -s "$cache$status_base") && (!($status_base eq "-1"))) {
	print " no - resetting.....";
	$status_base=-1;
}
print " ok\n";

print "Checking that $cache$status_base.$status_update exists...";
if ((! -s "$cache$status_base.$status_update") && ($status_update>0)) {
	print " no - resetting.....";
	$status_update=-1;
}
print " ok\n";

my ($currentbase, $currentupdate);

$currentbase=-1;
$currentupdate=-1;



# Lets get the current version
my $res = Net::DNS::Resolver->new();
 my $RR = $res->query($query, 'TXT');
	my @result;

	if ($RR) {
		foreach my $rr ($RR->answer) {
			my $text = $rr->rdatastr;
			if ($text =~ /^"(.+)\.(.+)"$/) {
				$currentbase=$1;
				$currentupdate=$2;
				last;
			}
		}
}

die "Failed to retrieve valid current details\n" unless (!($currentbase eq "-1"));

print "I am working with: Current: $currentbase - $currentupdate and Status: $status_base - $status_update\n"; 

my $generate=0;

# Create a user agent object
my $ua = LWP::UserAgent->new;
$ua->agent("MyApp/0.1 ");

if (!($currentbase eq $status_base)) {
	print "This is base update\n";
	$status_update=-1;
	$baseupdated=1;

	# Create a request
	my $req = HTTP::Request->new(GET => $urlbase.$currentbase);

	# Pass request to the user agent and get a response back
	my $res = $ua->request($req);

	# Check the outcome of the response
	if ($res->is_success) {
			open (FILE, ">$cache/$currentbase") or die "Unable to write base file ($cache/$currentbase)\n";
			print FILE $res->content;
			close (FILE);
	}
	else {
			die "Unable to retrieve $urlbase.$currentbase :".$res->status_line, "\n";
	}
	$generate=1;  
}
else {
	print "No base update required\n";
}



# Now see if the sub version is different
if (!($status_update eq $currentupdate)) {

	my %updates=();

	print "Update required\n";
	if ($currentupdate<$status_update) {
		# In the unlikely event we roll back a patch - we have to go from the base
		print "Error!: $currentupdate<$status_update\n";
		$generate=1;
		$status_update=0;
	}
	# If there are updates avaliable and we haven't donloaded them yet we need to reset the counter
	if ($currentupdate>0) {
		if ($status_update<1) {
			$status_update=0;
		}
		my $i;
		# Loop through each of the updates, retrieve it and then add the information into the update array
		for ($i=$status_update+1; $i<=$currentupdate; $i++) {
			print "Retrieving $urlbase$currentbase.$i\n";
			my $req = HTTP::Request->new(GET => $urlbase.$currentbase.".".$i);
			my $res = $ua->request($req);
			die "Failed to retrieve $urlbase$currentbase.$i" unless ($res->is_success) ;
					my $line;
				 foreach $line (split("\n", $res->content)) {
					# Is it an addition?
					if ($line =~ /^\> (.+)$/) {
						if (defined $updates{$1}) {
							if ($updates{$1} eq "<") {
								delete $updates{$1};
							}
						}
						else {
							$updates{$1}=">";
						}
					}
					# Is it an removal?
					if ($line =~ /^\< (.+)$/) {
						if (defined $updates{$1}) {
							if ($updates{$1} eq ">") {
								delete $updates{$1};
							}
						}
						else {
							$updates{$1}="<";
						}
					}
				}
		}
		# OK do we have a previous version to work from?
		if ($status_update>0) {
			# Yes - we open the most recent version
			open (FILE, "$cache$currentbase.$status_update") or die "Unable to open base file ($cache/$currentbase.$status_update)\n";
		}
		else {
			# No - we open the the base file
			open (FILE, "$cache$currentbase") or die "Unable to open base file ($cache/$currentbase)\n";
		}
		# Now open the new update file
		print "$cache$currentbase.$currentupdate\n";
		open (FILEOUT, ">$cache$currentbase.$currentupdate") or die "Unable to open new base file ($cache$currentbase.$currentupdate)\n";

		# Loop through the base file (or most recent update)
		while (<FILE>) {
			chop;
			my $line=$_;

			if (defined ($updates{$line})) {
				# Does the line need removing?
				if ($updates{$line} eq "<") {
					$generate=1;
					next;
				}
				# Is it marked as an addition but already present?
				elsif ($updates{$line} eq ">") {
					delete $updates{$line};
				}
			}
			print FILEOUT $line."\n";
		}
		close (FILE);
		my $line;
		# Are there any additions left
		foreach $line (keys %updates) {
			if ($updates{$line} eq ">") {
				print FILEOUT $line."\n" ;
				$generate=1;
			}
		}
		close (FILEOUT);
	}
		
}

# Changes have been made
if ($generate) {

	print "Updating live file $target\n";

	my $file="";

	if ($currentupdate>0) {
		$file="$cache/$currentbase.$currentupdate";
	}
	else {
		$file="$cache/$currentbase";
	}

	if ($file eq "") {
		die "Unable to work out file!\n";
	}
		
	system ("mv -f $target $target.old");
	system ("cp $file $target");


	

	open(STATUS_FILE, ">$status") or die "Unable to open status file\n";
	print STATUS_FILE "$currentbase.$currentupdate\n";
	close (STATUS_FILE);
		
}

my $queuedir = new DirHandle;
my $file;
my $match1="^".$currentbase."\$";
my $match2="^".$currentbase.".".$currentupdate."\$";
$queuedir->open($cache) or die "Unable to do clean up\n";
while(defined($file = $queuedir->read())) {
	next if $file =~ /^\.{1,2}$/;
	next if $file =~ /$match1/;
	next if $file =~ /$match2/;
	print "Deleting cached file: $file.... ";
	unlink($cache.$file) or die "failed";
	print "ok\n";
	
}
$queuedir->close();
