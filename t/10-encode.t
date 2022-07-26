#!perl -T

use strict;
use warnings;

use Test::More;

use URI::PackageURL qw(encode_purl);

is(
    encode_purl(type => 'cpan', name => 'URI::PackageURL', version => '1.00'),
    'pkg:cpan/URI/PackageURL@1.00',
    'encode_purl()'
);

done_testing();
