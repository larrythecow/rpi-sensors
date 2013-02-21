#!/usr/bin/perl

package sql;

use strict;
use warnings;
use Data::Dumper;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.0.1';
@ISA         = qw(Exporter);
@EXPORT      = qw(sqlCreate sqlInsertHost sqlGetHost sqlInsertSensor sqlInsertValues);

#** @var $debug debug flag
my $debug=0;
#** @var $LogPath debug log path
my $LogPath="/opt/tmp/sensor-debug";

sub sqlCreate {
    my %config = %{ $_[1] };

    $_[0]->do("CREATE DATABASE IF NOT EXISTS $config{'DB'}->{'database'}")
      or die $_[0]->errstr;

    $_[0]->do("use $config{'DB'}->{'database'}") or die $_[0]->errstr;

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

sub sqlGetHost{
    #** get current host
    my $sthCheck = $_[0]->prepare("select * from host where host.name like ? and host.ip=INET_ATON(?);");
    $sthCheck->execute( $_[1], $_[2] );
    my $host = $sthCheck->fetchrow_hashref;
    $sthCheck->finish() or die $_[0]->errstr;
    return $host;
    }

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

sub sqlInsertValues{
    my %yml    = %{ $_[1] };
    my $sensor;
    
    my $sthCheck = $_[0]->prepare("select sensor.sensor_id from host inner join sensor using (host_id) where host.host_id=? and typ like ? and sensor.name like ? and uuid like ?;");
    my $sth = $_[0]->prepare("INSERT INTO data(sensor_id, temp, hydro, time ) VALUES (?,?,?, FROM_UNIXTIME(?));");
    foreach my $type ( keys %yml ) {
        print "\t$type\n";
            my $i = 0;
            foreach my $id ( @{ $yml{$type}->{id} } ) {
                if ( $type eq "dht11" ) {
                    $sthCheck->execute($_[2]->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                    $sensor = $sthCheck->fetchrow_hashref;
                    $sth->execute($sensor->{sensor_id}, $yml{$type}->{'temperature'}->[$i], $yml{$type}->{'humidity'}->[$i], $yml{$type}->{'time'}->[$i]);
                }
                else {
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
