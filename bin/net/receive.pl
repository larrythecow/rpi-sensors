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

sub sql {
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

    print "IP: $nodeHash{ip}\n";

    while ( my $source = $sock->recv( $text, 4096, 0 ) ) {
        ( $sourcePort, $sourceIP ) = sockaddr_in($source);
        $sourceHost = gethostbyaddr( $sourceIP, AF_INET );
        my %conf = thaw($text);
	if( (defined $sourceHost) ){
		print "ip: ", inet_ntoa($sourceIP);
		print "host: $sourceHost port: $sourcePort\n";
		sql( \%conf, $sourceHost, inet_ntoa($sourceIP) );
	}
	else{
		print "Unable to resolve ", inet_ntoa($sourceIP), "\n";
	}
    }
}

server();
