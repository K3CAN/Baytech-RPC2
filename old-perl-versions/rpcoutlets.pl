#!/usr/bin/perl

use strict;
use Device::SerialPort;

my $tty = "/dev/ttyUSB0";

my $port = new Device::SerialPort ($tty) || die "can't open device";
$port->baudrate(9600);
$port->databits(8);
$port->stopbits(1);

$port->write_settings;
sleep(2);

if ("$ARGV[0] $ARGV[1]" =~ /[on|off] [1-6]/) {
	print "Turning $ARGV[0] outlet number $ARGV[1]\n";
	$port->write("$ARGV[0] $ARGV[1]\r\n");
	sleep(1);
	$port->write("y\r\n");

} elsif ("$ARGV[0] $ARGV[1]" =~ /read [1-6]/) {
	my @map;
	for (split (/^/m, $port->read(255))) {
		$_ =~ /([1-6])\)\.{3}(\w+)\s*: (On|Off)/ or next;
		$map[$1] = {device=>"$2", state=>"$3"};
	}
	print "$map[$ARGV[1]]->{state}";

} else {
    print "Invalid syntax. Ex: rpcoutlets (on|off|read) (1...6)";
}

sleep(1);
$port->close;