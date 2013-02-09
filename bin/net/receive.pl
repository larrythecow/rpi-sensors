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
BEGIN { push @INC, join( "/", dirname($0), "../lib/" ) }
use sensors;

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

sub sql {
    my %yml    = %{ $_[0] };
    my $conf   = YAML::XS::LoadFile("config.yml");
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

    #** get current host
    $sthCheck = $dbh->prepare("select * from host where host.name like ? and host.ip=INET_ATON(?);");
    $sthCheck->execute( $_[1], $_[2] );
    $host = $sthCheck->fetchrow_hashref;
    $sthCheck->finish() or die $dbh->errstr;

    #** insert sensor if not in DB
    $sth = $dbh->prepare("INSERT INTO sensor(host_id, typ, name, uuid) VALUES (?,?,?,?);")
      or die $dbh->errstr;
    $sthCheck = $dbh->prepare(
"select * from host inner join sensor using (host_id) where host.host_id=? and typ like ? and sensor.name like ? and uuid like ?;"
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

    #** insert values
    $sthCheck = $dbh->prepare("select sensor.sensor_id from host inner join sensor using (host_id) where host.host_id=? and typ like ? and sensor.name like ? and uuid like ?;");
    $sth = $dbh->prepare("INSERT INTO data(sensor_id, temp, hydro, time ) VALUES (?,?,?, FROM_UNIXTIME(?));");
    foreach my $type ( keys %yml ) {
        print "\t$type\n";
            my $i = 0;
            foreach my $id ( @{ $yml{$type}->{id} } ) {
                if ( $type eq "dht11" ) {
                    $sthCheck->execute($host->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                    $sensor = $sthCheck->fetchrow_hashref;
                    $sth->execute($sensor->{sensor_id}, $yml{$type}->{'temperature'}->[$i], $yml{$type}->{'humidity'}->[$i], $yml{$type}->{'time'}->[$i]);
                }
                else {
                    $sthCheck->execute($host->{'host_id'}, $type, $yml{$type}->{name}->[$i], $id );
                    $sensor = $sthCheck->fetchrow_hashref;
                    $sth->execute($sensor->{sensor_id}, $yml{$type}->{'temperature'}->[$i], $yml{$type}->{'humidity'}->[$i], $yml{$type}->{'time'}->[$i]);
                }
                $i++;
            }
    }
    $sthCheck->finish();
    $sth->finish() or die $dbh->errstr;


    $dbh->disconnect();
}

sub server {

    my $sock;
    my $text;
    my $source;
    my $sourcePort;
    my $sourceIP;
    my $sourceHost;

    $sock = IO::Socket::INET->new(
        LocalPort => 9999,

        #PeerAddr => inet_ntoa(INADDR_BROADCAST),
        Proto => getprotobyname('udp'),

        #LocalHost => '192.168.240.10',
        #Broadcast => 1,
        #Listen => 5
    ) or die "Can't bind : $@\n";

    while ( my $source = $sock->recv( $text, 4096, 0 ) ) {
        ( $sourcePort, $sourceIP ) = sockaddr_in($source);
        $sourceHost = gethostbyaddr( $sourceIP, AF_INET );
        print "ip: ", inet_ntoa($sourceIP);
        print "host: $sourceHost port: $sourcePort\n";
        my %conf = thaw($text);

        #    print "DEBUG: ", inet_aton($sourceIP);
        sql( \%conf, $sourceHost, inet_ntoa($sourceIP) );
    }
}

server();
