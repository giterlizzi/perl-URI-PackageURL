#!perl -T

use strict;
use warnings;

use Test::More;

use URI::VersionRange;

my $vers = 'vers:cpan/>v1.00|!=v2.10|<=v3.00';

my $v1 = URI::VersionRange->from_string($vers);

my $v2 = URI::VersionRange->new(
    scheme      => 'cpan',
    constraints => [
        URI::VersionRange::Constraint->new(comparator => '>',  version => 'v1.00'),
        URI::VersionRange::Constraint->new(comparator => '!=', version => 'v2.10'),
        URI::VersionRange::Constraint->new(comparator => '<=', version => 'v3.00')
    ]
);

my $v3 = URI::VersionRange->new(scheme => 'cpan', constraints => ['>v1.00', '!=v2.10', '<=v3.00']);

my $v4 = decode_vers($vers);

subtest "Version range (from string)" => sub {

    is $v1, $_, $v1 for (($vers, $v2, $v3, $v4));

    is $v1->contains('v2.11'), !!1, 'The version is in range';
    is $v1->contains('v2.10'), !!0, 'The version is not in range';
    is $v1->contains('v0.01'), !!0, 'The version is not in range';

};

subtest "Version range (Object-Oriented #1)" => sub {

    is $v2, $_, $v2 for (($vers, $v1, $v3, $v4));

    is $v2->contains('v2.11'), !!1, 'The version is in range';
    is $v2->contains('v2.10'), !!0, 'The version is not in range';
    is $v2->contains('v0.01'), !!0, 'The version is not in range';

};

subtest "Version range (Object-Oriented #2)" => sub {

    is $v3, $_, $v3 for (($vers, $v1, $v2, $v4));

    is $v3->contains('v2.11'), !!1, 'The version is in range';
    is $v3->contains('v2.10'), !!0, 'The version is not in range';
    is $v3->contains('v0.01'), !!0, 'The version is not in range';

};

subtest "Version range (decode_vers)" => sub {

    is $v4, $_, $v4 for (($vers, $v1, $v2, $v3));

    is $v4->contains('v2.11'), !!1, 'The version is in range';
    is $v4->contains('v2.10'), !!0, 'The version is not in range';
    is $v4->contains('v0.01'), !!0, 'The version is not in range';

};

done_testing();
