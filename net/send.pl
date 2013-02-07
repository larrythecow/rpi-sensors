#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use Storable;
use YAML::XS;
use FreezeThaw qw(freeze thaw cmpStr safeFreeze cmpStrHard);

my $sock;
my $path="/opt/tmp";
my $fh;
my @temp;

my $conf = YAML::XS::LoadFile("$path/test.yml");
my %yml = %$conf;

$sock = IO::Socket::INET->new(
    PeerPort => 9999,
    PeerAddr => inet_ntoa(INADDR_BROADCAST),
    Proto => getprotobyname('udp'),
    LocalAddr => '192.168.240.50',
    Broadcast => 1 )
or die "Can't bind : $@\n";

$sock->send( (freeze(%yml)) );
#Storable::nstore_fd( \%yml, $sock );
