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
my $debug=3;
my $conf = YAML::XS::LoadFile("$path/etc/sensor.yml");
my %yml = %$conf;

foreach my $type(keys %yml){
	my $temperature;
	my $humidity;
	my $fh;

	 if($debug >= 3){
	        print "\t$type\n";
		}
	my $i=0;
                foreach my $id ( @{$yml{$type}->{id}} ){
                        if($type eq "dht11"){
                                ($temperature, $humidity) =  fillArray($func{$type}, 3, 3, $id);
				$yml{$type}->{'humidity'}->[$i]= "$humidity";
                        }
                        else{  
                                $temperature =  fillArray($func{$type}, 3, 3, $id);
                        }
		$yml{$type}->{'temperature'}->[$i]= "$temperature";
		$yml{$type}->{'time'}->[$i] = time;
		if($debug >= 3){
			if($type eq "dht11"){
				print "\t\t$yml{$type}->{name}->[$i]\t$id\t$temperature $humidity\n";
			}
			else{
				print "\t\t$yml{$type}->{name}->[$i]\t$id\t$temperature [$i]\n";
			}
		}
		$i++;
	}
}
YAML::XS::DumpFile("$path/tmp/current.yml", $conf);

print "run $path/bin/net/send.pl\n";
`$path/bin/net/send.pl`;
