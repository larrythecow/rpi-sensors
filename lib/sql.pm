#!/usr/bin/perl

package sql;

use strict;
use warnings;
use Data::Dumper;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.0.1';
@ISA         = qw(Exporter);
@EXPORT      = qw(sqlCreate sqlInsertHost);

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
    $sthCheck = $dbh->prepare("select * from host where host.name like ? and host.ip=INET_ATON(?);")
      or die $dbh->errstr;
    $sthCheck->execute( $_[1], $_[2] );
    $sth = $dbh->prepare("INSERT INTO host(name, ip) VALUES (?, INET_ATON(?));");
    if ( !( $sthCheck->rows ) ) {
        $sth->execute( $_[1], $_[2] ) or die $dbh->errstr;
        print "host insert into DB $_[1], $_[2] ";
    }
    $sth->finish()      or die $dbh->errstr;
    $sthCheck->finish() or die $dbh->errstr;

}

sub sqlGetHost{
    #** get current host
    $sthCheck = $dbh->prepare("select * from host where host.name like ? and host.ip=INET_ATON(?);");
    $sthCheck->execute( $_[1], $_[2] );
    $host = $sthCheck->fetchrow_hashref;
    $sthCheck->finish() or die $dbh->errstr;
    return $host;
    }

sub sqlInsertSensor{
    #** insert sensor if not in DB
    $sth = $dbh->prepare("INSERT INTO sensor(host_id, typ, name, uuid) VALUES (?,?,?,?);")
      or die $dbh->errstr;
    $sthCheck = $dbh->prepare(
"select * from host inner join sensor using (host_id) where host.host_id=? and typ like ? and sensor$
    );
    foreach my $type ( keys %yml ) {
            my $i = 0;
            foreach my $id ( @{ $yml{$type}->{id} } ) {
                $sthCheck->execute( $host->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                if ( my $hash_ref = $sthCheck->rows ) {
                }
                else {
                    $sth->execute( $host->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id )
                      or die $dbh->errstr;
                }
                $i++;
            }
    }
    $sthCheck->finish();
    $sth->finish() or die $dbh->errstr;
}
