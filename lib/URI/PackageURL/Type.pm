package URI::PackageURL::Type;

use feature ':5.10';
use strict;
use utf8;
use warnings;

use Carp ();
use File::Spec;
use JSON::PP;
use List::Util            qw(first);
use URI::PackageURL::Util qw(resources_path);

use constant DEBUG => $ENV{PURL_DEBUG};

our $VERSION = '2.23_5';


my %ALGO_LENGTH = ('md5' => 32, 'sha1' => 40, 'sha256' => 64, 'sha384' => 96, 'sha512' => 128,);

sub new {

    my ($class, $type) = @_;

    Carp::croak 'Missing PURL type' unless $type;

    $type = lc $type;

    my $definition = _load_definition($type);

    my $self = {type => $type, definition => $definition};

    return bless $self, $class;

}

sub _load_definition {

    my $purl_type = shift;

    my $def_file = File::Spec->catfile(resources_path(), 'types', "$purl_type-definition.json");

    return unless -e $def_file;

    open my $fh, '<', $def_file or Carp::croak "Can't open '$purl_type' definition schema file: $!";
    my $def_content = do { local $/; <$fh> };

    DEBUG and say STDERR "-- Loaded '$purl_type-definition.json' schema";

    my $def_data = eval { decode_json($def_content) };
    Carp::croak "Failed to decode PURL type definition: $@" if $@;

    return $def_data;

}

sub definition { shift->{definition} }

sub normalize {

    my $self = shift;

    my %components = (
        type       => undef,
        namespace  => undef,
        name       => undef,
        version    => undef,
        version    => undef,
        qualifiers => {},
        subpath    => undef,
        @_
    );

    # Common normalizations
    $components{type} = lc $components{type};

    if (grep { $_ eq $components{type} } qw(alpm apk bitbucket composer deb github gitlab hex npm oci pypi)) {
        $components{name} = lc $components{name};
    }

    if (defined $components{namespace}) {

        if (grep { $_ eq $components{type} } qw(alpm apk bitbucket composer deb github gitlab golang hex rpm)) {
            $components{namespace} = lc $components{namespace};
        }

        if (grep { $_ eq $components{type} } qw(cpan)) {
            $components{namespace} = uc $components{namespace};
        }

    }

    # Force checksum into ARRAY
    if (defined $components{qualifiers}->{checksum} and ref $components{qualifiers}->{checksum} ne 'ARRAY') {
        $components{qualifiers}->{checksum} = [$components{qualifiers}->{checksum}];
    }

    # PURL type specific normalization
TYPE: for ($components{type}) {

        if (/huggingface/) {

            # The version is the model revision Git commit hash. It is case insensitive and
            # must be lowercased in the package URL.

            $components{version} = lc $components{version};
            last TYPE;
        }

        if (/mlflow/) {

            # The "name" case sensitivity depends on the server implementation:
            #   - Azure ML: it is case sensitive and must be kept as-is in the package URL.
            #   - Databricks: it is case insensitive and must be lowercased in the package URL.

            last TYPE unless $components{qualifiers}->{repository_url};

            if ($components{qualifiers}->{repository_url} =~ /azuredatabricks/) {
                $components{name} = lc $components{name};
            }
            last TYPE;
        }

        if (/pypi/) {

            # A PyPI package name must be lowercased and underscore "_" replaced with a dash "-".
            $components{name} =~ s/_/-/g;
            last TYPE;
        }

    }

    return wantarray ? %components : \%components;

}

sub validate {

    my $self = shift;

    my %components = (
        type       => undef,
        namespace  => undef,
        name       => undef,
        version    => undef,
        version    => undef,
        qualifiers => {},
        subpath    => undef,
        @_
    );

    # Check PURL components requirements

    Carp::croak "Invalid PURL: '$components{scheme}' is not a valid scheme" unless ($components{scheme} eq 'pkg');

    foreach my $qualifier (keys %{$components{qualifiers}}) {
        Carp::croak "Invalid PURL: '$qualifier' is not a valid qualifier" if ($qualifier =~ /(\s|\%)/);
    }

    # Check checksum qualifier
    if (defined $components{qualifiers}->{checksum} and ref $components{qualifiers}->{checksum} eq 'ARRAY') {

        foreach (@{$components{qualifiers}->{checksum}}) {

            my ($algo, $checksum) = split ':', $_;

            if (defined $ALGO_LENGTH{$algo}) {

                if (length($checksum) != $ALGO_LENGTH{$algo}) {
                    DEBUG and say STDERR "PURL: Malformed '$algo' checksum qualifier (invalid length)";
                }

                if ($checksum !~ m/^[0-9a-f]+$/) {
                    DEBUG and say STDERR "PURL: Malformed '$algo' checksum qualifier (invalid characters)";
                }

            }

            # Fallback
            elsif ($checksum !~ /^[0-9a-f]{32,}$/) {
                DEBUG and say STDERR "PURL: Malformed '$algo' checksum qualifier (invalid characters or length)";
            }

        }

    }

    # PURL type definition validation
    if (my $definition = $self->definition) {

        $definition->{qualifiers_definition} //= [];

        my $purl_type = $components{type};

        # Check components using PURL type definition

        for my $component (qw[namespace name version]) {

            my $def_type = sprintf '%s_definition', $component;
            my $def_rule = $definition->{$def_type};

            next unless $def_rule;

            my $requirement = $def_rule->{requirement};
            next unless $requirement;

            DEBUG and say STDERR "-- Validation - Evaluate rule for $component -- is $requirement";

            if (defined $components{$component} and $requirement eq 'prohibited') {
                Carp::croak sprintf("Invalid PURL: Prohibited '%s' for %s PURL type", $component, $purl_type);
            }

            if (not defined $components{$component} and $requirement eq 'required') {
                Carp::croak sprintf("Invalid PURL: Required '%s' for %s PURL type", $component, $purl_type);
            }

        }

        # Default known qualifiers
        my @known_qualifiers = (qw[
            vers
            repository_url
            download_url
            vcs_url
            file_name
            checksum
            checksums
        ]);

        foreach my $rule (@{$definition->{qualifiers_definition}}) {

            my $key = $rule->{key};
            push @known_qualifiers, $key;

            my $requirement = $rule->{requirement};
            next unless $requirement;

            DEBUG and say STDERR "-- Validation - Evaluate rule for '$key' qualifier -- is $requirement";

            if (defined $components{qualifiers}->{$key} and $requirement eq 'prohibited') {
                Carp::croak sprintf("Invalid PURL: Prohibited '%s' qualifier for %s PURL type", $key, $purl_type);
            }

            if (not defined $components{qualifiers}->{$key} and $requirement eq 'required') {
                Carp::croak sprintf("Invalid PURL: Required '%s' qualifier for %s PURL type", $key, $purl_type);
            }

        }

        # Check unknown qualifiers
        foreach my $key (keys %{$components{qualifiers}}) {
            DEBUG and say STDERR "PURL: '$key' is known qualifier for '$purl_type' PURL type"
                unless (first { $key eq $_ } @known_qualifiers);
        }


        # PURL type specific validation

    TYPE: for ($purl_type) {

            if (/conan/) {
                if ($components{namespace} && !defined $components{qualifiers}->{channel}) {
                    Carp::croak "Invalid PURL: Conan without 'channel' qualifier";
                }

                if (!$components{namespace} && defined $components{qualifiers}->{channel}) {
                    Carp::croak "Invalid PURL: Conan 'channel' qualifier without 'namespace'";
                }
                last TYPE;
            }

            if (/cpan/) {

                # Use legacy CPAN PURL type SPEC
                if ($ENV{PURL_LEGACY_CPAN_TYPE}) {

                    if ((defined $components{namespace} && defined $components{name}) && $components{namespace} =~ /\:/)
                    {
                        Carp::croak "Invalid PURL: CPAN 'namespace' component must have the distribution author";
                    }

                    if ((defined $components{namespace} && defined $components{name}) && $components{name} =~ /\:/) {
                        Carp::croak "Invalid PURL: CPAN 'name' component must have the distribution name";
                    }

                    if (!defined $components{namespace} && $components{name} =~ /\-/) {
                        Carp::croak "Invalid PURL: CPAN 'name' component must have the module name";
                    }

                    last TYPE;

                }

                # TODO: Remove when the new CPAN PURL type is merged
                # The namespace is the CPAN id of the author/publisher. It MUST be written uppercase and is required.

                unless (defined($components{namespace})) {
                    Carp::croak
                        "Invalid PURL: The CPAN 'namespace' is required and must contain the CPAN ID of the author/publisher";
                }

                if ($components{name} =~ /\:/) {
                    Carp::croak "Invalid PURL: The CPAN 'name' component must have the distribution name";
                }

                last TYPE;

            }

            if (/cran/) {
                Carp::croak "Invalid PURL: Cran 'version' is required" unless defined $components{version};
                last TYPE;
            }

            if (/swift/) {

                # TODO remove after spec FIX
                Carp::croak "Invalid PURL: Swift 'version' is required" unless defined $components{version};

                if (defined $components{namespace}) {
                    my ($source, $user_org) = split '/', $components{namespace};
                    Carp::croak "Invalid PURL: Swift user/organization is required in 'namespace'" unless $user_org;
                }

                last TYPE;

            }

        }

    }

    return 1;

}

1;

__END__
=head1 NAME

URI::PackageURL::Type - PURL type base class for URI::PackageURL

=head1 SYNOPSIS

  use URI::PackageURL::Type;

  # Load 'cpan' PURL type definition
  $type = URI::PackageURL::Type->new('cpan');

  say $type->definition->{description};


=head1 DESCRIPTION

URL::PackageURL::Type is the PURL type helper for URL::PackageURL.

=over

=item $purl_type->normalize

Perform PURL components normalization and validation:

    %components = $purl_type->normalize(
        type      => 'CPAN',
        namespace => 'gdt',
        name      => 'URI-PackageURL'
    );

    say Dumper(\%components);

    # {
    #   type => 'cpan',
    #   namespace => 'GDT',
    #   name => 'URI-PackageURL'
    # }


=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/giterlizzi/perl-URI-PackageURL/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/giterlizzi/perl-URI-PackageURL>

    git clone https://github.com/giterlizzi/perl-URI-PackageURL.git


=head1 AUTHOR

=over 4

=item * Giuseppe Di Terlizzi <gdt@cpan.org>

=back


=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2022-2025 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
