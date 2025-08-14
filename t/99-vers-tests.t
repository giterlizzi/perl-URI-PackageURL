#!perl

use JSON::PP;
use Test::More;
use File::Spec;

require_ok('URI::VersionRange');

my $purl_tests_dir = File::Spec->catdir('t', 'vers');

BAIL_OUT('"vers" tests directory not found') if (!-d $purl_tests_dir);

foreach my $test_file (find($purl_tests_dir)) {

    next unless $test_file =~ /(containment|roundtrip)/;

    diag $test_file;

    subtest $test_file => sub {
        execute_test($test_file);
    }

}

sub find {

    my $directory = shift;

    opendir my $dh, $directory or Carp::croak "Can't open directory: $!";

    return
        map { -f $_ ? $_ : () }
        map { $_, -d $_ ? find($_) : () } map { /\A\.\.?\z/ ? () : File::Spec->catfile($directory, $_) } readdir $dh;

}

sub execute_test {

    my $test_file = shift;

    open my $fh, '<', $test_file or Carp::croak "Can't open file: $!";

    my $test_content = do { local $/; <$fh> };
    my $test_data    = eval { JSON::PP::decode_json($test_content) };

    BAIL_OUT("$test_file - $@") if $@;

    foreach my $test (@{$test_data->{tests}}) {

        diag $test->{description};

        local $TODO = 'SKIP test because URI::VersionRange fail in sorting in "to_string"'
            if ($test->{test_type} eq 'roundtrip');

        execute_containment_test($test) if $test->{test_type} eq 'containment';
        execute_roundtrip_test($test)   if $test->{test_type} eq 'roundtrip';

    }

}

sub execute_containment_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $vers_string      = $test->{input}->{vers};
    my $version          = $test->{input}->{version};
    my $expected_output  = $test->{expected_output};

    diag "$vers_string ($version)";

    my $vers = eval { URI::VersionRange->from_string($vers_string) };

    is $vers->contains($version), !!1, "$version version in range ($vers)" if $expected_output;
    is $vers->contains($version), !!0, "$version version not in range ($vers)" unless $expected_output;

}

sub execute_roundtrip_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $vers_string      = $test->{input}->{vers};
    my $expected_output  = $test->{expected_output};

    diag $vers_string;

    my $vers = eval { URI::VersionRange->from_string($vers_string) };

    is "$vers", $expected_output;

}

done_testing();
