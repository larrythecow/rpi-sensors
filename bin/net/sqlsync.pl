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
	my $tmpCount=0;
	my $NAcount=0;

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
    my $sthRemoteHost = $dbhRemote->prepare("select ip, name, host_id from host where name like ?") or die $dbhRemote->errstr;
    my $sthRemoteSensorCheck = $dbhRemote->prepare("select * from host inner join sensor using (host_id) where sensor.host_id=? and typ like ? and sensor.name like ? and uuid like ?;");

    $sthLocalHost->execute();
    while (my $hashRefLocalHost = $sthLocalHost->fetchrow_hashref) {
	$sthRemoteHost->execute($hashRefLocalHost->{name});
	my $hashRefRemoteHost = $sthRemoteHost->fetchrow_hashref;
	if(defined $hashRefRemoteHost){
		print "remote: $hashRefLocalHost->{host_id} $hashRefLocalHost->{name}\t$hashRefLocalHost->{ip}\n";
	}
	else{
		sqlInsertHost( $dbhRemote, $hashRefLocalHost->{name}, join '.', unpack 'C4', pack 'N', $hashRefLocalHost->{ip} );
	}
	$sthRemoteHost->finish() or die $dbhRemote->errstr;

	my $sthLocalSensor = $dbhLocal->prepare("select sensor_id, host_id, uuid, typ, name from sensor where host_id = ?") or die $dbhLocal->errstr;
	$sthLocalSensor->execute($hashRefLocalHost->{host_id});
	while (my $hashRefLocalSensor = $sthLocalSensor->fetchrow_hashref) {
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
	}

    }
    $sthLocalHost->finish() or die $dbhLocal->errstr;
    $sthRemoteHost->finish() or die $dbhLocal->errstr;
    $sthRemoteSensorCheck->finish() or die $dbhLocal->errstr;

	my $sthLocalData = $dbhLocal->prepare("select *, host.name as hostname, sensor.name as sensorname from data left join sensor using (sensor_id) left join host using (host_id)") or die $dbhLocal->errstr;
	my $sthRemoteDataCheck = $dbhRemote->prepare("select *, host.name as hostname, sensor.name as sensorname from data left join sensor using (sensor_id) left join host using (host_id)
		where ip=? and host.name like ? and typ like ? and sensor.name like ? and time=TIMESTAMP(?)");
	my $sthRemoteDataInsert = $dbhRemote->prepare("INSERT INTO data (sensor_id, temp, hydro, radiation, time) VALUES(?,?,?,?,?) ");
	my $sthRemoteSensor = $dbhRemote->prepare("select sensor_id from sensor inner join host using (host_id) where ip=? and host.name like ? and typ like ? and sensor.name like ?");
	$sthLocalData->execute();
	while(my $hashRefLocalData = $sthLocalData->fetchrow_hashref){
		$tmpCount++;
		$sthRemoteDataCheck->execute($hashRefLocalData->{ip}, $hashRefLocalData->{hostname}, $hashRefLocalData->{typ}, $hashRefLocalData->{sensorname}, $hashRefLocalData->{time});
		my $hashRefRemoteDataCheck = $sthRemoteDataCheck->fetchrow_hashref;
#		print Dumper $hashRefRemoteDataCheck;
		if( !(defined $hashRefRemoteDataCheck) ){
			$NAcount++;
			$sthRemoteSensor->execute($hashRefLocalData->{ip}, $hashRefLocalData->{hostname}, $hashRefLocalData->{typ}, $hashRefLocalData->{sensorname});
			my $hashRefRemoteSensor = $sthRemoteSensor->fetchrow_hashref;
			print "rem:$hashRefRemoteSensor->{sensor_id} ";
			print "$hashRefLocalData->{ip}, $hashRefLocalData->{time}, $hashRefLocalData->{hostname}, $hashRefLocalData->{uuid}, $hashRefLocalData->{typ}, $hashRefLocalData->{sensorname}\n";
			$sthRemoteDataInsert->execute($hashRefRemoteSensor->{sensor_id}, $hashRefLocalData->{temp}, $hashRefLocalData->{hydro}, $hashRefLocalData->{radiation}, $hashRefLocalData->{time});
		}
		
		
	}
	$sthLocalData->finish() or die $dbhLocal->errstr;
	$sthRemoteDataCheck->finish() or die $dbhLocal->errstr;
	$sthRemoteDataInsert->finish() or die $dbhLocal->errstr;
	$sthRemoteSensor->finish() or die $dbhLocal->errstr;
		
print "\ncount: $tmpCount++\t NAcount: $NAcount";

    $dbhLocal->disconnect();
    $dbhRemote->disconnect();
}

sqlSync();
