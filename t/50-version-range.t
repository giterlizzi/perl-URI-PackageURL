#!perl -T

use strict;
use warnings;

use Test::More;

use URI::VersionRange;

my $vers = 'vers:golang/>v1.2.3|!=v2.1.3|<=v3.2.1';

my $v1 = URI::VersionRange->from_string($vers);
is $v1, $vers, $v1;

done_testing();
