#!/usr/bin/perl -w

=pod

=head1 COPYRIGHT

 
This software is Copyright (c) 2007 NETWAYS GmbH, William Preston
                               <support@netways.de>

(Except where explicitly superseded by other copyright notices)

=head1 LICENSE

This work is made available to you under the terms of Version 2 of
the GNU General Public License. A copy of that license should have
been provided with this software, but in any event can be snarfed
from http://www.fsf.org.

This work is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301 or visit their web page on the internet at
http://www.fsf.org.


CONTRIBUTION SUBMISSION POLICY:

(The following paragraph is not intended to limit the rights granted
to you to modify and distribute this software under the terms of
the GNU General Public License and is only of importance to you if
you choose to contribute your changes and enhancements to the
community by submitting them to NETWAYS GmbH.)

By intentionally submitting any modifications, corrections or
derivatives to this work, or any other work intended for use with
this Software, to NETWAYS GmbH, you confirm that
you are the copyright holder for those contributions and you grant
NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
royalty-free, perpetual, license to use, copy, create derivative
works based on those contributions, and sublicense and distribute
those contributions and any derivatives thereof.

Nagios and the Nagios logo are registered trademarks of Ethan Galstad.

=head1 NAME

check_sms3status

=head1 SYNOPSIS

Retrieves the status of an SMS Modem via smstools3.

=head1 OPTIONS

check_sms3status [options] F<status_file>

=over

=item   B<--warning>

warning level for percentage signal strength (default 40)

=item   B<--critical>

critical level for percentage signal strength (default 20)

=item   B<--timeout>

how long to wait for the file (default 30)

=item   B<--age>

the maximum age of the file in seconds (default 300)

=back

=head1 DESCRIPTION

This plugin checks the status of an SMS modem using the regular_run functionality
provided in smstools3

It does not directly access the modem, but instead reads a status file generated
by smstools3.

In order to work the following options need to be set in smsd.conf

=over

=item 

regular_run_interval = 60

=item 

regular_run_cmd = AT+CREG?;+CSQ;+COPS?

=item 

regular_run_statfile = F<status_file>

=back

The following performance data is returned
<signal dBm>;<% signal strength>;<Error rate>;<Network ID/Name>

=head1 FILES

F<status_file> the status file e.g. /dev/shm/sms_stat

=head1 HISTORY

16.11.2009 Perfdata Patch contributed by Gerd v. Egidy

=cut

use Getopt::Long;
use Pod::Usage;
use lib '/usr/local/nagios/libexec/';
use lib '/usr/lib/nagios/plugins/';
use utils qw(%ERRORS);

sub nagexit($$);

$warning = 40;
$critical = 20;
$tout = 30;
$maxage = 300;
# check the command line options
GetOptions('help|?' => \$help,
           'age=i' => \$maxage,
           't|timeout=i' => \$tout,
           'w|warn|warning=i' => \$warning,
           'c|crit|critical=i' => \$critical);

if ($#ARGV!=0) {$help=1;} # wrong number of command line options
# pod2usage( -verbose => 99, -sections => "NAME|COPYRIGHT|SYNOPSIS|OPTIONS") if $help;
pod2usage(1) if $help;


$file = shift;

while ($tout > 0) {
	open (IN,"<".$file) and last;
	sleep 1;
	$tout -= 1 or nagexit('CRITICAL', "Cannot open $file");
}

$fileage = (stat(IN))[9];

$fileage_sec = (time() - $fileage);
if ($fileage_sec > $maxage) {
	nagexit('CRITICAL', "Status file was last updated $fileage_sec seconds ago");
}

while (<IN>) {

	if (/\+CSQ:\s*(\d+),(\d+)/) { $signal = $1; $sigber = $2 };
    if (/\+COPS:\s*\d+,\d+,\"(.*)\"/) { $netz = $1 }
	elsif (/\+COPS:\s*\d+,\d+,([^ ]*)/) { $netz = $1 };
	if (!/\+CREG:\s*(\d,1)/) { $unreg = TRUE };


	$sigdb = ((2*$signal)-113);
	$sigproc = (($signal*100)/31);

}
close (IN);

$unreg and nagexit('CRITICAL', "Modem not registered on network");

if ($signal > 31) {
	nagexit('UNKNOWN', "Signal strength returned an invalid value");
}

$retstr = sprintf ("Registered on network '%5\$s' with signal strength %2\$.0f%% | dBm=%1\$d;;;; signal=%2\$.0f%%;%3\$.0f;%4\$.0f;;", $sigdb, $sigproc, $warning, $critical, $netz);

# bit error rate 99 means unknown, don't output it
if ($sigber != 99) {
    $retstr = sprintf ("%1\$s bit_error_rate=%2\$d;;;;", $retstr, $sigber);
}

if ($sigproc < $critical) {
	nagexit('CRITICAL', $retstr);
}

if ($sigproc < $warning) {
	nagexit('WARNING', $retstr);
}

nagexit('OK', $retstr);


sub nagexit($$) {
	my $errlevel = shift;
	my $string = shift;

	print "$errlevel: $string\n";
	exit $ERRORS{$errlevel};
}
