#!/usr/bin/perl

use strict;
use warnings "all";
use IO::Socket::INET;
use Storable;
use YAML::XS;
use FreezeThaw qw(freeze thaw cmpStr safeFreeze cmpStrHard);

my $sock;
my $path="/opt/tmp";
my $fh;
my @temp;

my $data = YAML::XS::LoadFile("$path/test.yml");
my %dataHash = %$data;
my $node = YAML::XS::LoadFile("$path/../rpi-sensors/node.yml");
my %nodeHash = %$node;

$sock = IO::Socket::INET->new(
    PeerPort => $nodeHash{port},
    PeerAddr => inet_ntoa(INADDR_BROADCAST),
    Proto => getprotobyname('udp'),
    LocalAddr => $nodeHash{ip},
    Broadcast => 1 )
or die "Can't bind : $@\n";

$sock->send( (freeze(%dataHash)) );
