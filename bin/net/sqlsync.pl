#!/usr/bin/perl
use strict;
use warnings;

use DBI;
use File::Basename;
use IO::Socket::INET;
use Data::Dumper;
use Storable;
use FreezeThaw qw(freeze thaw cmpStr safeFreeze cmpStrHard);
use YAML::XS;
use Cwd 'abs_path';
BEGIN { push @INC, join( "/", dirname( abs_path($0) ), "../../lib/" ) }
use sensors;
use sql;

my $path = join("/", dirname( abs_path($0) ), "../..");


sub sqlSync {
    my $conf   = YAML::XS::LoadFile("$path/mysql.yml");
    my %config = %$conf;
    my $dbhLocal;
    my $dbhRemote;

    $dbhLocal = DBI->connect(
        "dbi:mysql::$config{'DB'}->{'host'}",
        $config{'DB'}->{'user'},
        $config{'DB'}->{'pass'}
    ) or die $dbhLocal->errstr;
    $dbhLocal->do("use $config{'DB'}->{'database'}") or die $_[0]->errstr;

    $dbhRemote = DBI->connect(
        "dbi:mysql::$config{'REMOTE1'}->{'host'}",
        $config{'REMOTE1'}->{'user'},
        $config{'REMOTE1'}->{'pass'}
    ) or die $dbhLocal->errstr;
    $dbhRemote->do("use $config{'REMOTE1'}->{'database'}") or die $_[0]->errstr;

    my $sthLocalHost = $dbhLocal->prepare("select ip, name, host_id from host") or die $dbhLocal->errstr;
    $sthLocalHost->execute();
    while (my $hashRefLocalHost = $sthLocalHost->fetchrow_hashref) {
	my $sthRemoteHost = $dbhRemote->prepare("select ip, name, host_id from host where name like ?") or die $dbhRemote->errstr;
	$sthRemoteHost->execute($hashRefLocalHost->{name});
	my $hashRefRemoteHost = $sthRemoteHost->fetchrow_hashref;
	if(defined $hashRefRemoteHost){
		print "remote: $hashRefLocalHost->{host_id} $hashRefLocalHost->{name}\t$hashRefLocalHost->{ip}\n";
	}
	else{
		sqlInsertHost( $dbhRemote, $hashRefLocalHost->{name}, join '.', unpack 'C4', pack 'N', $hashRefLocalHost->{ip} );
	}
	$sthRemoteHost->finish() or die $dbhRemote->errstr;

	my $sthLocalSensor = $dbhLocal->prepare("select sensor_id, host_id, uuid, typ, name from sensor") or die $dbhLocal->errstr;
	$sthLocalSensor->execute();
	while (my $hashRefLocalSensor = $sthLocalSensor->fetchrow_hashref) {
		my $sthRemoteSensorCheck = $dbhRemote->prepare(
			"select * from host inner join sensor using (host_id) where sensor.host_id=? and typ like ? and sensor.name like ? and uuid like ?;"
			);
		$sthRemoteSensorCheck->execute($hashRefRemoteHost->{host_id}, $hashRefLocalSensor->{typ}, $hashRefLocalSensor->{name}, $hashRefLocalSensor->{uuid});
		my $hashRefRemoteSensorCheck = $sthRemoteSensorCheck->fetchrow_hashref;
		if(defined $hashRefRemoteSensorCheck){
			print "\t\tDEF: $hashRefRemoteHost->{host_id} $hashRefLocalSensor->{sensor_id}\t$hashRefLocalSensor->{uuid}\t$hashRefLocalSensor->{typ}\t$hashRefLocalSensor->{name}\n";
		}
		else{   
			print "\t\tUNDEF: $hashRefRemoteHost->{host_id} $hashRefLocalSensor->{sensor_id}\t$hashRefLocalSensor->{uuid}\t$hashRefLocalSensor->{typ}\t$hashRefLocalSensor->{name}\n";
			my $sthRemoteSensorInsert = $dbhRemote->prepare("INSERT INTO sensor(host_id, typ, name, uuid) VALUES (?,?,?,?);");
			$sthRemoteSensorInsert->execute( $hashRefRemoteHost->{'host_id'}, $hashRefLocalSensor->{typ}, $hashRefLocalSensor->{name}, $hashRefLocalSensor->{uuid} );
		}
		$sthRemoteSensorCheck->execute($hashRefRemoteHost->{host_id}, $hashRefLocalSensor->{typ}, $hashRefLocalSensor->{name}, $hashRefLocalSensor->{uuid});
		my $hashRefRemoteSensorCheck = $sthRemoteSensorCheck->fetchrow_hashref;

		my $sthLocalDataCheck = $dbhLocal->prepare("select name, temp, hydro, UNIX_TIMESTAMP(time) as time from data inner join sensor using (sensor_id)");
		$sthLocalDataCheck->execute();
		while (my $hashRefLocalDataCheck = $sthLocalDataCheck->fetchrow_hashref) {
			my $sthRemoteDataCheck = $dbhRemote->prepare("select * from data where sensor_id = ? and time = ?");
			$sthRemoteDataCheck->execute($hashRefLocalDataCheck->{sensor_id}, $hashRefLocalDataCheck->{time});
			my $hashRefRemoteDataCheck = $sthRemoteDataCheck->fetchrow_hashref;
			if(!(defined $hashRefRemoteDataCheck)){
				print "\t\t\t$hashRefLocalDataCheck->{time}\t$hashRefLocalDataCheck->{name}\t$hashRefLocalDataCheck->{temp}\t\n";
				my $sthRemoteDataInsert = $dbhRemote->prepare("INSERT INTO data(sensor_id, temp, hydro, time ) VALUES(?,?,?, FROM_UNIXTIME(?));");
				$sthRemoteDataInsert->execute($hashRefRemoteSensorCheck->{sensor_id}, $hashRefLocalDataCheck->{temp}, $hashRefLocalDataCheck->{hydro}, $hashRefLocalDataCheck->{time});
			}
#			if(defined $hashRefLocalDataCheck->{hydro}){
#				print "\t\t\t$hashRefLocalDataCheck->{data_id}\t$hashRefLocalDataCheck->{sensor_id}\t$hashRefLocalDataCheck->{temp}\t$hashRefLocalDataCheck->{hydro}\t$hashRefLocalDataCheck->{time}\n";
#			}
#			else{
#				print "\t\t\t$hashRefLocalDataCheck->{data_id}\t$hashRefLocalDataCheck->{sensor_id}\t$hashRefLocalDataCheck->{temp}\t\t$hashRefLocalDataCheck->{time}\n";
#			}
		}
		
		#$sthRemoteSensorCheck->execute($hashRefRemoteHost->{host_id}, $hashRefLocalSensor->{typ}, $hashRefLocalSensor->{name}, $hashRefLocalSensor->{uuid});
		#my $sthRemoteSensor = $dbhRemote->prepare("INSERT INTO sensor(host_id, typ, name, uuid) VALUES (?,?,?,?);");
		#$sthRemoteSensor->execute($hashRefLocalSensor->{host_id}, $hashRefLocalSensor->{typ}, $hashRefLocalSensor->{name}, $hashRefLocalSensor->{uuid});
	}

    }
    $sthLocalHost->finish() or die $dbhLocal->errstr;


    $dbhLocal->disconnect();
    $dbhRemote->disconnect();
}

sqlSync();
