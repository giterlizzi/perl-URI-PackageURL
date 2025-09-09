#!perl

use File::Spec;
use JSON::PP;
use Test::More;

require_ok('URI::VersionRange');

my $purl_tests_dir = File::Spec->catdir('t', 'vers');

BAIL_OUT('"vers" tests directory not found') if (!-d $purl_tests_dir);

foreach my $test_file (find($purl_tests_dir)) {
    execute_test($test_file);
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

        #note sprintf '[%s] %s', $test->{test_group}, $test->{description};

    TODO: {
            execute_containment_test($test) if $test->{test_type} eq 'containment';
            execute_roundtrip_test($test)   if $test->{test_type} eq 'roundtrip';
            execute_from_native_test($test) if $test->{test_type} eq 'from_native';
        }

    }

}

sub execute_containment_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $vers_string      = $test->{input}->{vers};
    my $version          = $test->{input}->{version};
    my $expected_output  = $test->{expected_output};

    my $vers = eval { URI::VersionRange->from_string($vers_string) };

    is $vers->contains($version), !!1, "$version version in range ($vers)" if $expected_output;
    is $vers->contains($version), !!0, "$version version not in range ($vers)" unless $expected_output;

}

sub execute_roundtrip_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $vers_string      = $test->{input}->{vers};
    my $expected         = $test->{expected_output};

    my $got = eval { URI::VersionRange->from_string($vers_string) };

    is "$got", $expected, "$test_description ($got)";

}

sub execute_from_native_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $native_range     = $test->{input}->{native_range};
    my $scheme           = $test->{input}->{scheme};
    my $expected         = $test->{expected_output};

    local $TODO = "SKIP vers:conan/" if $expected eq 'vers:conan/';

    my $got = eval { URI::VersionRange->from_native(scheme => $scheme, range => $native_range) };

    local $TODO = 'Skip because VERS require a range' if $expected_output eq 'vers:conan/';
    local $TODO = 'Skip include_prerelease=True'      if $native_range =~ 'include_prerelease=True';

    is "$got", $expected, "[$scheme] $test_description ($native_range --> $got)";

}

done_testing();
