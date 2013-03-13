#!/usr/bin/perl

use strict;
use warnings "all";
use IO::Socket::INET;
use Storable;
use YAML::XS;
use File::Basename;
use FreezeThaw qw(freeze thaw cmpStr safeFreeze cmpStrHard);

my $sock;
my $path=join("/", dirname($0), "../..");
my $fh;
my @temp;

my $data = YAML::XS::LoadFile("$path/tmp/current.yml");
my %dataHash = %$data;
my $node = YAML::XS::LoadFile("$path/etc/node.yml");
my %nodeHash = %$node;

$sock = IO::Socket::INET->new(
    PeerPort => $nodeHash{port},
    PeerAddr => inet_ntoa(INADDR_BROADCAST),
    Proto => getprotobyname('udp'),
    LocalAddr => $nodeHash{ip},
    Broadcast => 1 )
or die "Can't bind : $@\n";

$sock->send( (freeze(%dataHash)) );
