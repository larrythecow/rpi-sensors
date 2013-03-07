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

my $DEBUG=2;
my $path = join("/", dirname( abs_path($0) ), "../..");

#** @function public rrdGraph() 
# @brief create graph's and html page from mysql DB 
#*
sub rrdGraph {
    my $conf   = YAML::XS::LoadFile("$path/mysql.yml");
    my %config = %$conf;
    my $dbhLocal;
    my $sthLocal;
    my $templateIndex = HTML::Template->new(filename => "$path/bin/net/index.tmpl");
    my @templateIndexData;

    system("rm /opt/rpi-sensors/tmp/*rrd");
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
	push(@templateIndexData, {"HOSTURL" => "$hashRefHost->{name}.html", "HOSTNAME" => "$hashRefHost->{name}"});
	my $templateHost = HTML::Template->new(filename => "$path/bin/net/host.tmpl");
	my @templateHostDataSensor;
	my @templateHostDataTable;
	$templateHost->param(HOST => $hashRefHost->{name});
	$templateHost->param(TITLE => "Sensor details $hashRefHost->{name}");
	$templateHost->param(IP => join '.', unpack 'C4', pack 'N', $hashRefHost->{ip});
	my $sthSensor = $dbhLocal->prepare("select sensor.host_id, sensor.sensor_id, sensor.uuid, sensor.typ, sensor.name as sensorname, host.name as hostname from sensor inner join host using(host_id) where sensor.host_id = ?") or die $dbhLocal->errstr;
	$sthSensor->execute($hashRefHost->{host_id});
	while(my $hashRefSensor = $sthSensor->fetchrow_hashref) {
		push(@templateHostDataTable, {"ANCHORNAME" => "$hashRefSensor->{typ}$hashRefSensor->{sensorname}", "TYPE" => $hashRefSensor->{typ}, "NAME" => $hashRefSensor->{sensorname}, "ID" => $hashRefSensor->{uuid} });

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
		my $sthData = $dbhLocal->prepare("select data.sensor_id, data.temp, data.humi, UNIX_TIMESTAMP(data.time) as time from data inner join sensor using(sensor_id) where data.sensor_id = ? ORDER BY time") or die $dbhLocal->errstr;
		$sthData->execute($hashRefSensor->{sensor_id});
		while(my $hashRefData = $sthData->fetchrow_hashref){
			if($DEBUG >2){
				print "UPDATE:$hashRefData->{time} SENSOR_ID:$hashRefSensor->{sensor_id}\n"
			}
			if($hashRefSensor->{typ} eq "dht11"){
                                $rrd->update(
                                        "$path/tmp/$rrdFileName.rrd",
                                        $hashRefData->{time},
                                        temperature => $hashRefData->{temp},
					humidity => $hashRefData->{humi},
                                );
			}
			else{
				$rrd->update(
					"$path/tmp/$rrdFileName.rrd",
					$hashRefData->{time},
					temperature => $hashRefData->{temp}
				);
			}
		}
		my %rtn = $rrd->graph(
			destination => "/var/www/monitoring",
			title => "$hashRefSensor->{typ} $hashRefSensor->{sensorname}",
			vertical_label => "C",
			interlaced => "",
			extended_legend => 1,
			width => "600",
			height => "220",
			color => [ ( "BACK#CCCCCC", "SHADEA#C8C8FF",
				"SHADEB#9696BE", "ARROW#61B51B",
				"GRID#404852", "MGRID#67C6DE" ) ],
		);
#		printf("Created %s\n",join(", ",map { $rtn{$_}->[0] } keys %rtn));
#		printf("Created %s\n",map { $rtn{$_}->[0] } keys %rtn);
#		print Dumper $rtn{monthly};
		   push(@templateHostDataSensor, {"ANCHORNAME"=> "$hashRefSensor->{typ}$hashRefSensor->{sensorname}" , "TYPE" => $hashRefSensor->{typ}, "NAME" => $hashRefSensor->{sensorname}, "ID" => $hashRefSensor->{uuid}, "DAY" => "$rrdFileName-daily.png", "WEEK" => "$rrdFileName-weekly.png", MONTH => "$rrdFileName-monthly.png", YEAR => "$rrdFileName-annual.png" });	
	}
    $templateHost->param(SENSOR => \@templateHostDataSensor);
    $templateHost->param(TABLE => \@templateHostDataTable);
    open FH,">/var/www/monitoring/$hashRefHost->{name}.html";
    $templateHost->output(print_to => \*FH);
    close FH;
    }
    $sthLocal->finish() or die $dbhLocal->errstr;
    $dbhLocal->disconnect();

   $templateIndex->param(HOSTS => \@templateIndexData);
   open FH,">/var/www/monitoring/index.html";
   $templateIndex->output(print_to => \*FH);
   close FH;
}


rrdGraph()
