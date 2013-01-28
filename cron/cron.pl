#!/usr/bin/perl


use strict;
use warnings;
use Data::Dumper;
use FileHandle;
use File::Basename;

BEGIN { push @INC, join("/", dirname($0), "../lib/")  }
#BEGIN { push @INC, "/opt/rpi-sensors/lib/" }
use sensors;

my $path="/opt/tmp/cron/";
my $fh;
my $temperature;
my $humidity;

print Dumper %sensor;
print dirname($0);

print "\nforeach \n";
foreach my $type(keys %sensor){
	
	print "\t$sensor{$type}->{name} \n";
	if (defined $sensor{$type}->{ID}){
		foreach my $id ( @{$sensor{$type}->{ID}} ){
			open ($fh, join('', ">", $path, $sensor{$type}->{name}, "_", $id)) || die "cant open file: $!\n";
			if($type eq "dht11"){
				($temperature, $humidity) =  fillArray($sensor{$type}->{command}, 3, 3, $id);
				print "\t\t$sensor{$type}->{name}\t$id\t$temperature $humidity\n";
				print $fh "$temperature $humidity";
			}
			else{
                                $temperature =  fillArray($sensor{$type}->{command}, 3, 3, $id);
                                print "\t\t$sensor{$type}->{name}\t$id\t$temperature\n";
                                print $fh "$temperature";

			}
			close $fh;
		}
	}
	else{
		open ($fh, join('', ">", $path, $sensor{$type}->{name})) || die "cant open file: $!\n";
		$temperature =  fillArray($sensor{$type}->{command}, 3, 3);
		print "\t\t$sensor{$type}->{name}\t$temperature\n";
		print $fh "$temperature";
	}
}
