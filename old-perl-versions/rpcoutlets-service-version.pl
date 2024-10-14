#!/usr/bin/perl

#Serial port settings:
#stty -F /dev/ttyUSB0 0:4:cbd:a30:3:1c:7f:15:4:0:1:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0

#This requires lm_sensors to monitor temperature. 

use strict;
use Device::SerialPort;

my $limit = 55;
my $delay = 5; #time in minutes between checks.
my $fanport = 5;

my $port = new Device::SerialPort ("/dev/ttyUSB0") || die "can't open device";
$port->baudrate(9600); # 
$port->databits(8);
$port->parity("none");
$port->stopbits(1);
$port->handshake("none");

$port->write_settings;
sleep(2);

#If arguments are provided, just do what is asked and exit.
if ("$ARGV[0] $ARGV[1]" =~ /[on|off] [1-6]/) {
	print "Turning $ARGV[0] outlet number $ARGV[1]\n";
	$port->write("$ARGV[0] $ARGV[1]\r\n");
	sleep(1);
	$port->write("y\r\n");
} else {
	my $fan;
#If this is run without arguments, assume that we want to control the case fan.
	while() {
		`sensors | grep Package` =~ m/\+(\d{1,3}\.\d+)/i;
		warn "cpu temp is $1\n";
		

		if ($1 > $limit and $fan ne "on") {
			warn "turning on fan\n";
			$port->write("on $fanport\r\n");
			sleep(1);
			$port->write("y\r");
			$fan = "on";
			warn "fan is now $fan\n";
			
		} elsif ($1 <= $limit and $fan ne "off") {
			warn "turning off fan\n";
		 	$port->write("off $fanport\r\n");
		 	sleep(1);
			$port->write("y\r");
			$fan = "off";
			warn "fan is now $fan\n";
			
		} else {warn "Temperature is $1 and fan is already $fan\n"} 

		
		sleep(60*$delay);
	}
}

sleep(1);
$port->close;

