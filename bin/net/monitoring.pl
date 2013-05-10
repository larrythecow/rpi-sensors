#!/usr/bin/perl

use Net::Jabber qw(Client);
use Data::Dumper;

my $server = "jabber.ccc.de";
my $port = "5222";
my $username = "monitoring";
my $password = "3zKCQMlg";
my $resource = "autosend";
my @hosts = ("192.168.240.1", "192.168.240.2", "192.168.240.3", "192.168.240.50", "192.168.240.51");


my $clnt = new Net::Jabber::Client;

my $status = $clnt->Connect(hostname=>$server, port=>$port);

if (!defined($status)) {
    die "Jabber connect error ($!)\n";
}

my @result = $clnt->AuthSend(username=>$username,
        password=>$password,
        resource=>$resource);

if ($result[0] ne "ok") {
    die "Jabber auth error: @result\n";
}

my $body = 'test';
chomp($body);

foreach my $sys (@hosts){
    my $retval = system(join(" ", "fping", $sys, "-c 3", "-q", "-t 5000"));
	if($retval != 0){
	    $clnt->MessageSend(to=>'sid_blub@jabber.ccc.de',
		subject=>"",
		body=>join(" ", $sys, $retval),
		type=>"chat",
		priority=>10);
	}
}
$clnt->Disconnect();

