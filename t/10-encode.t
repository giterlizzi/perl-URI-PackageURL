#!perl -T

use strict;
use warnings;

use Test::More;

use URI::PackageURL qw(encode_purl);


my @TESTS = (
    {purl => 'pkg:cpan/Perl::Version@1.013', type => 'cpan', name => 'Perl::Version', version => '1.013'},
    {
        purl      => 'pkg:cpan/DROLSKY/DateTime@1.55',
        type      => 'cpan',
        namespace => 'DROLSKY',
        name      => 'DateTime',
        version   => '1.55'
    },
    {purl => 'pkg:cpan/DateTime@1.55',      type => 'cpan', name      => 'DateTime', version => '1.55'},
    {purl => 'pkg:cpan/GDT/URI-PackageURL', type => 'cpan', namespace => 'GDT',      name    => 'URI-PackageURL',},
    {purl => 'pkg:cpan/LWP::UserAgent',     type => 'cpan', name      => 'LWP::UserAgent'},
    {
        purl      => 'pkg:cpan/OALDERS/libwww-perl@6.76',
        type      => 'cpan',
        namespace => 'OALDERS',
        name      => 'libwww-perl',
        version   => '6.76'
    },
    {purl => 'pkg:cpan/URI', type => 'cpan', name => 'URI'}
);


foreach my $test (@TESTS) {

    my $expected_purl = $test->{purl};

    subtest "$expected_purl" => sub {

        my $got_purl_1 = encode_purl(
            type      => $test->{type},
            namespace => $test->{namespace},
            name      => $test->{name},
            version   => $test->{version}
        );

        my $got_purl_2 = URI::PackageURL->new(
            type      => $test->{type},
            namespace => $test->{namespace},
            name      => $test->{name},
            version   => $test->{version}
        );

        is($got_purl_1, $expected_purl, "encode_purl --> $got_purl_1");
        is($got_purl_2, $expected_purl, "URI::PackageURL --> $got_purl_2");

    };

}

done_testing();
