#!/usr/bin/perl
use strict;
use warnings;

use File::Basename;
use IO::Socket::INET;
use FreezeThaw qw(freeze thaw);
use YAML::XS;
use Cwd 'abs_path';
BEGIN { push @INC, join( "/", dirname( abs_path($0) ), "../../lib/" ) }
use sql;

#** @function public server() 
# @brief listen for incomming UDP packages and forward them to sqlInsertUDP()
#*
sub server {
    my $path = join("/", dirname( abs_path($0) ), "../..");
    my $node = YAML::XS::LoadFile("$path/etc/node.yml");
    my %nodeHash = %$node;

    my $sock;
    my $payload;
    my $sourceRAW;
    my $sourcePort;
    my $sourceIP;
    my $sourceHost;

    $sock = IO::Socket::INET->new(
        LocalPort => 9999,
        Proto => getprotobyname('udp'),
    ) or die "Can't bind : $@\n";

    print "LocalIP: $nodeHash{ip}\n";

    while ( my $sourceRAW = $sock->recv( $payload, 4096, 0 ) ) {
        ( $sourcePort, $sourceIP ) = sockaddr_in($sourceRAW);
        $sourceHost = gethostbyaddr( $sourceIP, AF_INET );
        my %conf = thaw($payload);
	if( (defined $sourceHost) ){
		print "\n", inet_ntoa($sourceIP), ":$sourcePort $sourceHost\n";
		sqlInsertYML( \%conf, $sourceHost, inet_ntoa($sourceIP) );
	}
	else{
		print "Unable to resolve ", inet_ntoa($sourceIP), "\n";
	}
    }
}

server();
