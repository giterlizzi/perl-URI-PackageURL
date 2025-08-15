#!perl

use JSON::PP;
use Test::More;
use File::Spec;

require_ok('URI::PackageURL');

my $purl_tests_dir = File::Spec->catdir('t', 'purl');

BAIL_OUT('"purl" tests directory not found') if (!-d $purl_tests_dir);

$ENV{PURL_LEGACY_CPAN_TYPE} = 1;

foreach my $test_file (find($purl_tests_dir)) {

    # (!) Skip some tests for PRs and issues in purl-spec that are still open

    #                      PURL TYPE          ISSUE
    next if ($test_file =~ /cocoapods/);    # percent encoding
    next if ($test_file =~ /conan/);        # qualifiers order
    next if ($test_file =~ /generic/);      # qualifiers order
    next if ($test_file =~ /maven/);        # qualifiers order
    next if ($test_file =~ /mlflow/);       # qualifiers order
    next if ($test_file =~ /npm/);          # percent encoding
    next if ($test_file =~ /oci/);          # percent encoding + qualifiers order
    next if ($test_file =~ /rpm/);          # qualifiers order
    next if ($test_file =~ /swid/);         # percent encoding

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

        diag sprintf '[%s] %s', $test->{test_group}, $test->{description};

    TODO: {

            local $TODO = 'SKIP test because in ENCODE always generate well format PURL string'
                if ($test->{description} eq 'invalid encoded colon : between scheme and type');

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

    if ($test->{expected_failure}) {
        like($@, qr/Invalid PURL/i, "ENCODE: $test_description");
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

    if ($test->{expected_failure}) {
        like($@, qr/(Invalid|Malformed) PURL/i, "DECODE $purl_string: $test_description");
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
