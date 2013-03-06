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

sqlSync();
