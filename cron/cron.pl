#!/usr/bin/perl

use strict;
use warnings;
use Cwd;

#BEGIN { push @INC, join('/', cwd(), "../lib")  }
BEGIN { push @INC, "/opt/rpi-sensors/lib/"  }
use sensors;

my $temp;
my $humi;
my $fh;
my $sensorID;
my $path="/tmp/cron/";
my $filename;

$filename="bcm2708";
$temp = fillArray(\&getBCM2708, 3, 3, 3);
print "cpu: $temp\n";
open ($fh, join('', ">", $path, $filename)) || die "cant open file: $!\n";
print $fh "$temp";
close $fh;


$sensorID=14;
$filename="dht11_";
($temp, $humi) = fillArray(\&getDHT11, 3, 3, 3, $sensorID);
print "dht11: $temp, $humi\n";
open ($fh, join('', ">", $path, $filename, $sensorID)) || die "cant open file: $!\n";
print $fh "$temp $humi";
close $fh;
system("echo `date +%Y-%m-%d_%H:%M:%S` $temp $humi >> $path/dht11_DEBUG_$sensorID");

$sensorID="10-0008028a96de";
$filename="ds1820_";
$temp = fillArray(\&getTempDS1820, 3, 3, 3, $sensorID);
print "$filename $sensorID $temp\n";
open ($fh, join('', ">", $path, $filename, $sensorID)) || die "cant open file: $!\n";
print $fh "$temp";
close $fh;


$sensorID="10-0008028a9788";
$filename="ds1820_";
$temp = fillArray(\&getTempDS1820, 3, 3, 3, $sensorID);
print "$filename $sensorID $temp\n";
open ($fh, join('', ">", $path, $filename, $sensorID)) || die "cant open file: $!\n";
print $fh "$temp";
close $fh;


$temp = fillArray(\&getHidTEMPer, 3, 3, 3);
$filename="hidtemper";
print "$filename $temp\n";
open ($fh, join('', ">", $path, $filename)) || die "cant open file: $!\n";
print $fh "$temp";
close $fh;
