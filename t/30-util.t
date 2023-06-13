#!perl -T

use strict;
use warnings;

use Test::More;

use URI::PackageURL::Util qw(purl_to_urls);

my @tests = (
    {
        purl           => 'pkg:cpan/GDT/URI-PackageURL@2.00',
        download_url   => 'http://www.cpan.org/authors/id/G/GD/GDT/URI-PackageURL-2.00.tar.gz',
        repository_url => 'https://metacpan.org/release/GDT/URI-PackageURL-2.00'
    },

    {
        purl         => 'pkg:github/package-url/purl-spec@40d01e26f9ae0af6b50a1309e6b089c14d6d2244',
        download_url => 'https://github.com/package-url/purl-spec/archive/40d01e26f9ae0af6b50a1309e6b089c14d6d2244.zip',
        repository_url => 'https://github.com/package-url/purl-spec'
    },

    {purl => 'pkg:pypi/django@1.11.1', repository_url => 'https://pypi.org/project/django/1.11.1'}
);

foreach my $test (@tests) {

    my $purl           = $test->{purl};
    my $download_url   = $test->{download_url};
    my $repository_url = $test->{repository_url};

    subtest "'$purl' URLs" => sub {

        my $urls = purl_to_urls($purl);

        is($urls->{download},   $download_url,   'Download URL')   if defined $urls->{download};
        is($urls->{repository}, $repository_url, 'Repository URL') if defined $urls->{repository};

    };

}

done_testing();
