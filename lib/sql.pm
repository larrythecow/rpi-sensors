#!/usr/bin/perl

package sql;

use strict;
use warnings;
use DBI;
use Data::Dumper;
use Exporter;
use Cwd 'abs_path';
use File::Basename;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.0.1';
@ISA         = qw(Exporter);
@EXPORT      = qw(sqlCreate sqlInsertHost sqlGetHost sqlInsertSensor sqlInsertValues sqlInsertYML sqlSync);

#** @var $debug debug flag
my $debug=0;
#** @var $LogPath debug log path
my $LogPath="/opt/tmp/sensor-debug";


#** @function public sqlCreate($dbh, %mysql) 
# @brief create mysql DB and Tables if it does not exist
# @param dbh required $_[0] data base handler
# @param mysql required $_[1] mysql login 
#*
sub sqlCreate {
    my %mysql = %{ $_[1] };

    $_[0]->do("CREATE DATABASE IF NOT EXISTS $mysql{'DB'}->{'database'}")
      or die $_[0]->errstr;

    $_[0]->do("use $mysql{'DB'}->{'database'}") or die $_[0]->errstr;

    $_[0]->do(
        "CREATE TABLE IF NOT EXISTS  host(
        host_id INT PRIMARY KEY AUTO_INCREMENT,
        name CHAR(30),
        location CHAR(30),
        ip INT UNSIGNED
        ) engine innodb;"
    ) or die $_[0]->errstr;

    $_[0]->do(
        "CREATE TABLE IF NOT EXISTS  sensor(
        sensor_id INT PRIMARY KEY AUTO_INCREMENT,
        host_id INT,
        FOREIGN KEY (host_id) REFERENCES host(host_id),
        uuid CHAR(30),
        typ CHAR(30),
        name CHAR(30)
        ) engine innodb;"
    ) or die $_[0]->errstr;

    $_[0]->do(
        "CREATE TABLE IF NOT EXISTS  data(
        data_id INT PRIMARY KEY AUTO_INCREMENT,
        sensor_id INT,
        FOREIGN KEY (sensor_id) REFERENCES sensor(sensor_id),
        temp FLOAT,
        hydro FLOAT,
        radiation FLOAT,
        time TIMESTAMP
        ) engine innodb;"
    ) or die $_[0]->errstr;
}

#** @function public sqlInsertHost($dbh, $hostname, $ip) 
# @brief insert host into table if it does not exist
# @param dbh required $_[0] data base handler
# @param hostname required $_[1] string Hostname
# @param ip required $_[2] dot separated IP string
#*
sub sqlInsertHost{
    #** insert host if not in DB
    my $sthCheck = $_[0]->prepare("select * from host where host.name like ? and host.ip=INET_ATON(?);")
      or die $_[0]->errstr;
    $sthCheck->execute( $_[1], $_[2] );
    my $sth = $_[0]->prepare("INSERT INTO host(name, ip) VALUES (?, INET_ATON(?));");
    if ( !( $sthCheck->rows ) ) {
        $sth->execute( $_[1], $_[2] ) or die $_[0]->errstr;
        print "host insert into DB $_[1], $_[2] ";
    }
    $sth->finish()      or die $_[0]->errstr;
    $sthCheck->finish() or die $_[0]->errstr;

}

#** @function public sqlGetHost($dbh, $hostname, $ip) 
# @brief insert host into table if it does not exist
# @param dbh required $_[0] data base handler
# @param hostname required $_[1] string Hostname
# @param ip required $_[2] dot separated IP string
# @retval string hostname 
# @retval undefined if not in DB
#*
sub sqlGetHost{
    #** get current host
    my $sthCheck = $_[0]->prepare("select * from host where host.name like ? and host.ip=INET_ATON(?);");
    $sthCheck->execute( $_[1], $_[2] );
    my $host = $sthCheck->fetchrow_hashref;
    $sthCheck->finish() or die $_[0]->errstr;
    return $host;
    }

#** @function public sqlInsertSensor($dbh, %yml) 
# @brief insert Sensor into table if it does not exist
# @param dbh required $_[0] data base handler
# @param yml required $_[1] hash with sensor details
#*
sub sqlInsertSensor{
    my %yml    = %{ $_[1] };
    #** insert sensor if not in DB
    my $sth = $_[0]->prepare("INSERT INTO sensor(host_id, typ, name, uuid) VALUES (?,?,?,?);")
      or die $_[0]->errstr;
    my $sthCheck = $_[0]->prepare(
    "select * from host inner join sensor using (host_id) where host.host_id=? and typ like ? and sensor.name like ? and uuid like ?;"
    );
    foreach my $type ( keys %yml ) {
            my $i = 0;
            foreach my $id ( @{ $yml{$type}->{id} } ) {
                $sthCheck->execute( $_[2]->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                if ( my $hash_ref = $sthCheck->rows ) {
                }
                else {
                    $sth->execute( $_[2]->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id )
                      or die $_[0]->errstr;
                }
                $i++;
            }
    }
    $sthCheck->finish();
    $sth->finish() or die $_[0]->errstr;
}

#** @function public sqlInsertValues($dbh, %yml) 
# @brief insert Sensor values into table
# @param dbh required $_[0] data base handler
# @param yml required $_[1] hash with sensor details
#*
sub sqlInsertValues{
    my %yml    = %{ $_[1] };
    my $sensor;
    my $sthCheck = $_[0]->prepare("select sensor.sensor_id from host inner join sensor using (host_id) where host.host_id=? and typ like ? and sensor.name like ? and uuid like ?;");
    my $sth = $_[0]->prepare("INSERT INTO data(sensor_id, temp, hydro, time ) VALUES (?,?,?, FROM_UNIXTIME(?));");
    foreach my $type ( keys %yml ) {
        print "\t$type\n";
            my $i = 0;
            foreach my $id ( @{ $yml{$type}->{id} } ) {
	      	if( ($yml{$type}->{'temperature'}->[$i] eq 'U') ){
			$i++;
			next;
	      	}
		print "\t\t$id\t";
                if ( $type eq "dht11") {
		    print "$yml{$type}->{'temperature'}->[$i]\t$yml{$type}->{'humidity'}->[$i]\n";
                    $sthCheck->execute($_[2]->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                    $sensor = $sthCheck->fetchrow_hashref;
                    $sth->execute($sensor->{sensor_id}, $yml{$type}->{'temperature'}->[$i], $yml{$type}->{'humidity'}->[$i], $yml{$type}->{'time'}->[$i]);
                }
                else {
		    print "$yml{$type}->{'temperature'}->[$i]\n";
                    $sthCheck->execute($_[2]->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                    $sensor = $sthCheck->fetchrow_hashref;
                    $sth->execute($sensor->{sensor_id}, $yml{$type}->{'temperature'}->[$i], $yml{$type}->{'humidity'}->[$i], $yml{$type}->{'time'}->[$i]);
                }
                $i++;
	  }
    }
    $sthCheck->finish();
    $sth->finish() or die $_[0]->errstr;
}


#** @function public sqlInsertYML(%yml, $sourceHost, $sourceIP) 
# @brief insert received YML file into DB
# @param yml required $_[0] hash with sensor data
# @param sourceHost required $_[1] string Hostname
# @param sourceIP required $_[2] dot separated IP string
# @retval string hostname 
# @retval undefined if not in DB
#*
sub sqlInsertYML {
    my $path = join("/", dirname( abs_path($0) ), "../..");
    my %yml    = %{ $_[0] };
    my $conf   = YAML::XS::LoadFile("$path/mysql.yml");
    my %config = %$conf;
    my $dbh;
    my $sth;
    my $sthCheck;
    my $host;
    my $sensor;

    $dbh = DBI->connect(
        "dbi:mysql::$config{'DB'}->{'host'}",
        $config{'DB'}->{'user'},
        $config{'DB'}->{'pass'}
    ) or die $dbh->errstr;

    sqlCreate( $dbh, $conf );
    sqlInsertHost( $dbh, $_[1], $_[2] );
    $host = sqlGetHost($dbh, $_[1], $_[2] );
    sqlInsertSensor($dbh, \%yml, $host);
    sqlInsertValues($dbh, \%yml, $host);

    $dbh->disconnect();
}

#** @function public sqlSync() 
# @brief sync database from local DB to remote DB
#*
sub sqlSync {
    my $path = join("/", dirname( abs_path($0) ), "../..");
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


