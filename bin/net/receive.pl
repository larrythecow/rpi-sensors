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

my $path = join("/", dirname( abs_path($0) ), "../..");

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
    sqlInsertHost( $_[1], $_[2] );
    $host = sqlGetHost( $_[1], $_[2] );
    sqlInsertSensor();

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
    my $node = YAML::XS::LoadFile("$path/node.yml");
    my %nodeHash = %$node;

    my $sock;
    my $text;
    my $source;
    my $sourcePort;
    my $sourceIP;
    my $sourceHost;

    $sock = IO::Socket::INET->new(
        LocalPort => 9999,
        Proto => getprotobyname('udp'),
    ) or die "Can't bind : $@\n";

    print Dumper $sock;

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
