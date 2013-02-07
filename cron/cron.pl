#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use FileHandle;
use File::Basename;
use YAML::XS;
BEGIN { push @INC, join("/", dirname($0), "../lib/")  }
use sensors;

my $path=join("/", dirname($0), "../");
my $logPath="/opt/tmp/";
my $temperature;
my $humidity;
my $fh;


my $conf = YAML::XS::LoadFile("$path/conf.yml");
my %yml = %$conf;

foreach my $type(keys %yml){
        print "\t$type\n";
        if (defined $yml{$type}->{id}){
	my $i=0;
                foreach my $id ( @{$yml{$type}->{id}} ){
                        if($type eq "dht11"){
                                ($temperature, $humidity) =  fillArray($func{$type}, 3, 3, $id);
                                print "\t\t$yml{$type}->{name}->[$i]\t$id\t$temperature $humidity\n";
				$yml{$type}->{'temperature'}->[$i]= "$temperature";
				$yml{$type}->{'humidity'}->[$i]= "$humidity";
				$yml{$type}->{'time'}->[$i] = time;
                        }
                        else{  
                                $temperature =  fillArray($func{$type}, 3, 3, $id);
                                print "\t\t$yml{$type}->{name}->[$i]\t$id\t$temperature [$i]\n";
				$yml{$type}->{'temperature'}->[$i]= "$temperature";
				$yml{$type}->{'time'}->[$i] = time;
                        }
		$i++;
                }
        }
        else{   
                $temperature =  fillArray($func{$type}, 3, 3);
                print "\t\t$yml{$type}->{name}->[0]\t$temperature\n";
		$yml{$type}->{'temperature'}->[0]= "$temperature";
		$yml{$type}->{'time'}->[0] = time;
        }
}

YAML::XS::DumpFile("$logPath/test.yml", $conf);
`$path/net/send.pl`;

