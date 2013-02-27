#!/usr/bin/perl
use strict;
use warnings;

use DBI;
use File::Basename;
use Data::Dumper;
use YAML::XS;
use RRD::Simple ();
use Cwd 'abs_path';
use HTML::Template;
BEGIN { push @INC, join( "/", dirname( abs_path($0) ), "../../lib/" ) }
use sensors;
use sql;

my $DEBUG=3;

my $path = join("/", dirname( abs_path($0) ), "../..");


sub sqlSync {
    my $conf   = YAML::XS::LoadFile("$path/mysql.yml");
    my %config = %$conf;
    my $dbhLocal;
    my $sthLocal;

    system("rm /tmp/*rrd");

    $dbhLocal = DBI->connect(
        "dbi:mysql::$config{'DB'}->{'host'}",
        $config{'DB'}->{'user'},
        $config{'DB'}->{'pass'}
    ) or die $dbhLocal->errstr;
    $dbhLocal->do("use $config{'DB'}->{'database'}") or die $_[0]->errstr;

    $sthLocal = $dbhLocal->prepare("select * from host") or die $dbhLocal->errstr;
    $sthLocal->execute();
    while (my $hashRefHost = $sthLocal->fetchrow_hashref) {
	my $template = HTML::Template->new(filename => "$path/bin/net/host.tmpl");
	my @templateData;
	$template->param(HOST => $hashRefHost->{name});
	my $sthSensor = $dbhLocal->prepare("select sensor.host_id, sensor.sensor_id, sensor.uuid, sensor.typ, sensor.name as sensorname, host.name as hostname from sensor inner join host using(host_id) where sensor.host_id = ?") or die $dbhLocal->errstr;
	$sthSensor->execute($hashRefHost->{host_id});
	while(my $hashRefSensor = $sthSensor->fetchrow_hashref) {
#		print Dumper $hashRefSensor;
		my $rrdFileName = "$hashRefSensor->{hostname}_$hashRefSensor->{typ}_$hashRefSensor->{sensorname}";
		my $rrd = RRD::Simple->new( file => "/tmp/$rrdFileName.rrd") ;
		if($hashRefSensor->{typ} eq "dht11"){
			$rrd->create(
        		        temperature => "GAUGE",
				humidity => "GAUGE",
       	        	);
		}
		else{
                        $rrd->create(
                                temperature => "GAUGE",
                        ); 
		}
#		print Dumper $hashRefSensor;
		my $sthData = $dbhLocal->prepare("select data.sensor_id, data.temp, data.hydro, UNIX_TIMESTAMP(data.time) as time from data inner join sensor using(sensor_id) where data.sensor_id = ?") or die $dbhLocal->errstr;
		$sthData->execute($hashRefSensor->{sensor_id});
		while(my $hashRefData = $sthData->fetchrow_hashref){
			if($DEBUG >2){
				print "UPDATE:$hashRefData->{time} SENSOR_ID:$hashRefSensor->{sensor_id}\n"
			}
			if($hashRefSensor->{typ} eq "dht11"){
                                $rrd->update(
                                        "/tmp/$rrdFileName.rrd",
                                        $hashRefData->{time},
                                        temperature => $hashRefData->{temp},
					humidity => $hashRefData->{hydro},
                                );
			}
			else{
				$rrd->update(
					"/tmp/$rrdFileName.rrd",
					$hashRefData->{time},
					temperature => $hashRefData->{temp}
				);
			}
		}
		my %rtn = $rrd->graph(
			destination => "/var/www/tmp",
			title => "Temperature $hashRefSensor->{typ} $hashRefSensor->{sensorname}",
			vertical_label => "C",
			interlaced => "",
			extended_legend => 1,
		);
#		printf("Created %s\n",join(", ",map { $rtn{$_}->[0] } keys %rtn));
#		printf("Created %s\n",map { $rtn{$_}->[0] } keys %rtn);
#		print Dumper $rtn{monthly};
		   push(@templateData, {"DAY" => "$rrdFileName-daily.png", "WEEK" => "$rrdFileName-weekly.png", MONTH => "$rrdFileName-monthly.png", YEAR => "$rrdFileName-annual.png" });	
	}
    $template->param(SENSOR => \@templateData);
    open FH,">/var/www/tmp/$hashRefHost->{name}.html";
    $template->output(print_to => \*FH);
    close FH;
    }
    $sthLocal->finish() or die $dbhLocal->errstr;
    $dbhLocal->disconnect();
#	print Dumper @templateData;
	system("rm /tmp/*rrd");
}


sqlSync()
