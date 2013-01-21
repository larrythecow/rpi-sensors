#!/usr/bin/perl

BEGIN { push @INC, '/opt/rpi-sensors/lib' }
use strict;
use warnings;

use sensors;

my $temp;
my $humi;
my $fh;
my $sensorID;

$temp = avgTemp(\&getBCM2708, 1, 3, 3);
print "cpu: $temp\n";
open ($fh, ">/tmp/cron/bcm2708") || die "cant open file: $!\n";
print $fh "$temp";
close $fh;

$sensorID=14;
($temp, $humi) = avgTemp(\&getDHT11, 1, 3, 3, $sensorID);
print "dht11: $temp, $humi\n";
open ($fh, ">/tmp/cron/dht11_$sensorID") || die "cant open file: $!\n";
print $fh "$temp $humi";
close $fh;

$sensorID="10-0008028a96de";
$temp = avgTemp(\&getTempDS1820, 1, 3, 3, $sensorID);
print "$sensorID $temp\n";
open ($fh, ">/tmp/cron/ds1820_$sensorID") || die "cant open file: $!\n";
print $fh "$temp";
close $fh;


$sensorID="10-0008028a9788";
$temp = avgTemp(\&getTempDS1820, 1, 3, 3, $sensorID);
print "$sensorID $temp\n";
open ($fh, ">/tmp/cron/ds1820_$sensorID") || die "cant open file: $!\n";
print $fh "$temp";
close $fh;


$temp = avgTemp(\&getHidTEMPer, 1, 3, 3);
print "HidTemper $temp\n";
open ($fh, ">/tmp/cron/hidtemper") || die "cant open file: $!\n";
print $fh "$temp";
close $fh;

