package URI::VersionRange;

use feature ':5.10';
use strict;
use utf8;
use warnings;
use version ();

use Carp;
use List::Util qw(pairs first);
use Exporter   qw(import);

use URI::VersionRange::VersionConstraint;

use constant DEBUG => $ENV{VERS_DEBUG};
use constant TRUE  => !!1;
use constant FALSE => !!0;

use overload '""' => 'to_string', fallback => 1;

our $VERSION = '2.11_01';
our @EXPORT  = qw(encode_vers decode_vers);

my $VERS_REGEXP = qr{^vers:[a-z\\.\\-\\+][a-z0-9\\.\\-\\+]*/.+};

sub new {

    my ($class, %params) = @_;

    my $scheme = delete $params{scheme} // 'vers';

    my $versioning_scheme = delete $params{versioning_scheme}
        or Carp::croak "Invalid Version Range: 'versioning_scheme' is required";

    my $version_constraints = delete $params{version_constraints}
        or Carp::croak "Invalid Version Range: 'version_constraints' is required";

    my @version_constraints = ();

    foreach (@{$version_constraints}) {
        if (ref($_) ne 'URI::VersionRange::VersionConstraint') {
            push @version_constraints, URI::VersionRange::VersionConstraint->from_string($_);
        }
        else {
            push @version_constraints, $_;
        }
    }

    my $self
        = {scheme => $scheme, versioning_scheme => $versioning_scheme, version_constraints => \@version_constraints};

    return bless $self, $class;

}

sub scheme              { shift->{scheme} }
sub versioning_scheme   { shift->{versioning_scheme} }
sub version_constraints { shift->{version_constraints} }

sub encode_vers { __PACKAGE__->new(@_)->to_string }
sub decode_vers { __PACKAGE__->from_string(shift) }

sub from_string {

    my ($class, $string) = @_;

    if ($string !~ /$VERS_REGEXP/) {
        Carp::croak 'Malformed Version Range string';
    }

    my %components = ();

    # - Remove all spaces and tabs.
    # - Start from left, and split once on colon ":".
    # - The left hand side is the URI-scheme that must be lowercase.
    #       Tools must validate that the URI-scheme value is vers.
    # - The right hand side is the specifier.

    $string =~ s/(\s|\t)+//g;

    my @s1 = split(':', $string);
    $components{scheme} = lc $s1[0];

    # - Split the specifier from left once on a slash "/".
    # - The left hand side is the <versioning-scheme> that must be lowercase. Tools
    #   should validate that the <versioning-scheme> is a known scheme.
    # - The right hand side is a list of one or more constraints. Tools must validate
    #   that this constraints string is not empty ignoring spaces.

    my @s2 = split('/', $s1[1]);
    $components{versioning_scheme} = lc $s2[0];

    # - If the constraints string is equal to "", the ``<version-constraint>``
    #   is "". Parsing is done and no further processing is needed for this vers.
    #   A tool should report an error if there are extra characters beyond "*".
    # - Strip leading and trailing pipes "|" from the constraints string.
    # - Split the constraints on pipe "|". The result is a list of <version-constraint>.
    #   Consecutive pipes must be treated as one and leading and trailing pipes ignored.

    $s2[1] =~ s{(^\|)|(\|$)}{}g;

    my @s3 = split(/\|/, $s2[1]);
    $components{version_constraint} = [];

    # - For each <version-constraint>:
    #   - Determine if the <version-constraint> starts with one of the two comparators:
    #     - If it starts with ">=", then the comparator is ">=".
    #     - If it starts with "<=", then the comparator is "<=".
    #     - If it starts with "!=", then the comparator is "!=".
    #     - If it starts with "<", then the comparator is "<".
    #     - If it starts with ">", then the comparator is ">".
    #     - Remove the comparator from <version-constraint> string start. The remaining string is the version.
    #   - Otherwise the version is the full <version-constraint> string (which implies an equality comparator of "=")
    #   - Tools should validate and report an error if the version is empty.
    #   - If the version contains a percent "%" character, apply URL quoting rules to unquote this string.
    #   - Append the parsed (comparator, version) to the constraints list.

    foreach (@s3) {
        push @{$components{version_constraints}}, URI::VersionRange::VersionConstraint->from_string($_);
    }

    if (DEBUG) {
        say STDERR "-- S1: @s1";
        say STDERR "-- S2: @s2";
        say STDERR "-- S3: @s3";
    }

    return $class->new(%components);

}

sub to_string {

    my $self = shift;

    my @version_constraints = ();

    foreach (@{$self->version_constraints}) {
        push @version_constraints, $_;
    }

    return join '', 'vers:', $self->versioning_scheme, '/', join('|', @version_constraints);


}

sub contains {

    my ($self, $version) = @_;

    my @first  = ();
    my @second = ();

    if (scalar @{$self->version_constraints} == 1) {
        return $self->version_constraints->[0]->contains($version);
    }

    foreach my $constraint (@{$self->version_constraints}) {

        # If the "tested version" is equal to the any of the constraint version
        # where the constraint comparator is for equality (any of "=", "<=", or ">=")
        # then the "tested version" is in the range. Check is finished.
        return TRUE
            if ((first { $constraint->comparator eq $_ } ('=', '<=', '>='))
            && (version->parse($version) == version->parse($constraint->vers)));

        # If the "tested version" is equal to the any of the constraint version
        # where the constraint comparator is "=!" then the "tested version" is NOT
        # in the range. Check is finished.
        return FALSE
            if ($constraint->comparator eq '!=' && (version->parse($version) == version->parse($constraint->vers)));

        # Split the constraint list in two sub lists:
        #    a first list where the comparator is "=" or "!="
        #    a second list where the comparator is neither "=" nor "!="

        push @first, $constraint if ((first { $constraint->comparator eq $_ } ('=', '!=')));
        push @second, $constraint if ((first { $constraint->comparator ne $_ } ('=', '!=')));

        return FALSE unless @second;

    }

    if (scalar @second == 1) {
        return $second[0]->contain_version($version);
    }

    # Iterate over the current and next contiguous constraints pairs (aka. pairwise)
    # in the second list.

    # For each current and next constraint:

    my $is_first_iteration = TRUE;

    my $current_constraint = undef;
    my $next_constraint    = undef;

    foreach (pairs @second) {

        $current_constraint = $_->[0];
        $next_constraint    = $_->[1] || URI::VersionRange::VersionConstraint->new;

        # If this is the first iteration and current comparator is "<" or <=" and
        # the "tested version" is less than the current version then the "tested
        # version" is IN the range. Check is finished.

        if ($is_first_iteration) {

            return TRUE
                if ((first { $current_constraint->comparator eq $_ } ('<=', '<'))
                && version->parse($version) < version->parse($current_constraint->vers));

            $is_first_iteration = FALSE;

        }

        # If current comparator is ">" or >=" and next comparator is "<" or <="
        # and the "tested version" is greater than the current version and the
        # "tested version" is less than the next version then the "tested version"
        # is IN the range. Check is finished.

        if (   (first { $current_constraint->comparator eq $_ } ('>', '>='))
            && (first { $next_constraint->comparator eq $_ } ('<', '<='))
            && (version->parse($version) > version->parse($next_constraint->vers))
            && (version->parse($version) < version->parse($current_constraint->vers)))
        {
            return TRUE;
        }

        # If current comparator is "<" or <=" and next comparator is ">" or >="
        # then these versions are out the range. Continue to the next iteration.

        elsif ((first { $current_constraint->comparator eq $_ } ('<', '<='))
            && (first { $next_constraint->comparator } ('>', '>=')))
        {
            next;
        }

        else {
            Carp::croak 'Constraints are in an invalid order';
        }

    }

    # If this is the last iteration and next comparator is ">" or >=" and the
    # "tested version" is greater than the next version then the "tested version"
    # is IN the range. Check is finished.

    return TRUE
        if ((first { $next_constraint->comparator eq $_ } ('>', '>='))
        && (version->parse($version) > version->parse($next_constraint->vers)));

    return FALSE;

}

sub TO_JSON {

    my $self = shift;

    return {versioning_scheme => $self->versioning_scheme, version_constraints => $self->version_constraints,};

}

1;

__END__
=head1 NAME

URI::VersionRange - Perl extension for Version Range Specification

=head1 SYNOPSIS

  use URI::VersionRange;

  # OO-interface

  $vers = URI::VersionRange->new(
    versioning_scheme  => cpan,
    version_constraint => ['>2.00']
  );
  
  say $vers; # vers:cpan/>2.00

  # Parse "vers" string
  $vers = URI::VersionRange->from_string('vers:cpan/>2.00|<2.11');

  # exported functions

  $vers = decode_vers('vers:cpan/>2.00|<2.11');
  say $vers->versioning_scheme;  # cpan

  $vers_string = encode_vers(versioning_scheme => cpan, version_constraint => ['>2.00']);
  say $vers_string; # vers:cpan/>2.00

  foreach my $version_constraint (@{$vers->version_constraint}) {
    if ($version_constraint->contain_version('2.10')) {
        say "2.10 version is OK";
    }
  }

=head1 DESCRIPTION

A version range specifier (aka. "vers") is a URI string using the C<vers> URI-scheme with this syntax:

    vers:<versioning-scheme>/<version-constraint>|<version-constraint>|...

C<vers> is the URI-scheme and is an acronym for "VErsion Range Specifier".

The pipe "|" is used as a simple separator between C<version-constraint>.
Each C<version-constraint> in this pipe-separated list contains a comparator and a version:

    <comparator:version>

This list of C<version-constraint> are signposts in the version timeline of a package
that specify version intervals.

A C<version> satisfies a version range specifier if it is contained within any
of the intervals defined by these C<version-constraint>.

L<https://github.com/package-url/purl-spec>


=head2 FUNCTIONAL INTERFACE

They are exported by default:

=over

=item $vers_string = encode_vers(%vers_components);

Converts the given C<vers> components to "vers" string. Croaks on error.

This function call is functionally identical to:

   $vers_string = URI::VersionRange->new(%vers_components)->to_string;

=item $vers = decode_vers($vers_string);

Converts the given "vers" string to L<URI::VersionRange> object. Croaks on error.

This function call is functionally identical to:

   $vers = URI::VersionRange->from_string($vers_string);

=back

=head2 OBJECT-ORIENTED INTERFACE

=over

=item $vers = URI::VersionRange->new(%components)

Create new B<URI::Version> instance using provided C<vers> components
(scheme, versioning_scheme, version_constraints).

=item $vers->scheme

Always C<vers>

=item $vers->versioning_scheme

By convention the versioning scheme should be the same as the L<URI::PackageURL>
package C<type> for a given package ecosystem.

=item $vers->version_constraints

C<version_constraints> is ARRAY of L<URI::VersionRange::VersionConstraint> object.

=item $vers->to_string

Stringify C<vers> components.

=item $vers->TO_JSON

Helper method for JSON modules (L<JSON>, L<JSON::PP>, L<JSON::XS>, L<Mojo::JSON>, etc).

    use Mojo::JSON qw(encode_json);

    say encode_json($vers);  # {"version_constraints":[{"comparator":">","version":"2.00"},{"comparator":"<","version":"2.11"}],"versioning_scheme":"cpan"}

=item $vers = URI::VersionRange->from_string($vers_string);

Converts the given "vers" string to L<URI::VersionRange> object. Croaks on error.

=back


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

This software is copyright (c) 2022-2024 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
