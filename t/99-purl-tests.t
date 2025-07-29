#!perl

use JSON::PP;
use Test::More;
use File::Spec;

require_ok('URI::PackageURL');

my $purl_tests_dir = File::Spec->catdir('t', 'tests');

BAIL_OUT('"tests" directory not found') if (!-d $purl_tests_dir);


foreach my $test_file (find($purl_tests_dir)) {

    next unless ($test_file =~ /(specification|cpan)/);

    subtest $test_file => sub {
        execute_test($test_file);
    }

}

sub find {
    my $directory = shift;
    opendir my $dh, $directory or Carp::croak "Cant'open directory: $!";
    return map { $_, -d $_ ? find($_) : () } map { /\A\.\.?\z/ ? () : File::Spec->catfile($directory, $_) } readdir $dh;
}

sub execute_test {

    my $test_file = shift;

    open my $fh, '<', $test_file or Carp::croak "Can't open file: $!";

    my $test_content = do { local $/; <$fh> };
    my $test_data    = JSON::PP::decode_json($test_content);

    foreach my $test (@{$test_data->{tests}}) {

        diag $test->{description};

    TODO: {
            execute_parse_test($test)     if $test->{test_type} eq 'parse';
            execute_build_test($test)     if $test->{test_type} eq 'build';
            execute_roundtrip_test($test) if $test->{test_type} eq 'roundtrip';
        }

    }

}

sub execute_build_test {

    my $test = shift;

    my $test_description = $test->{description};

    my $purl = eval { URI::PackageURL->new(%{$test->{input}}); };

    local $TODO = 'DUBIOUS MAVEN TEST' if $test_description =~ /invalid encoded colon : between scheme and type/i;
    local $TODO = 'DUBIOUS CONAN TEST' if $@ =~ /Conan 'channel' qualifier does not exist for namespace/i;

    if ($test->{expected_failure}) {
        like($@, qr/Invalid Package URL/i, "ENCODE: $test_description");
        return;
    }

    if (!$test->{expected_failure} && $@) {
        fail("DECODE: $test_description ($@)");
        return;
    }

    is($purl->to_string, $test->{expected_output}, "ENCODE: $test_description");

}

sub execute_parse_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $purl_string      = $test->{input};

    diag $purl_string;

    my $purl = eval { URI::PackageURL->from_string($purl_string) };

    local $TODO = 'DUBIOUS NPM TEST'   if $purl_string =~ /pkg\:npm\/@/;
    local $TODO = 'DUBIOUS CONAN TEST' if $@           =~ /Conan 'channel' qualifier does not exist for namespace/i;

    if ($test->{expected_failure}) {
        like($@, qr/(Invalid|Malformed) Package URL/i, "DECODE $purl_string: $test_description");
        return;
    }

    if (!$test->{expected_failure} && $@) {
        fail("DECODE: $test_description ($@)");
        return;
    }

    my @components = qw(type namespace name version subpath);

    foreach my $component (@components) {
        is(
            $purl->$component,
            $test->{expected_output}->{$component},
            "DECODE: Compare '$test_description' $component component"
        );
    }

}

sub execute_roundtrip_test {

    my $test = shift;

    my $test_description = $test->{description};
    my $purl_string      = $test->{input};

    diag $purl_string;

    my $purl = eval { URI::PackageURL->from_string($purl_string) };

    if ($@) {
        fail("DECODE: $test_description ($@)");
        return;
    }

    is($purl->to_string, $test->{expected_output}, "ENCODE: $test_description");

}

done_testing();
