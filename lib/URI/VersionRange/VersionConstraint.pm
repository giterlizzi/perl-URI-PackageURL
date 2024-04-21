package URI::VersionRange::VersionConstraint;

use feature ':5.10';
use strict;
use utf8;
use warnings;
use version ();

use Carp;
use Exporter qw(import);

use overload '""' => 'to_string', fallback => 1;

use constant TRUE  => !!1;
use constant FALSE => !!0;

our $VERSION = '2.11_02';

sub new {

    my ($class, %params) = @_;

    my $comparator = delete $params{comparator} // '=';
    my $version    = delete $params{version};

    my $self = {comparator => $comparator, version => $version};

    return bless $self, $class;
}

sub vers       { shift->{version} }      # TODO version conflict with "version" module
sub comparator { shift->{comparator} }

sub from_string {

    my ($class, $string) = @_;

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

    if ($string =~ /^(>=|<=|!=|<|>)(.*)/) {
        my ($comparator, $version) = ($1, $2);
        return $class->new(comparator => $comparator, version => $version);
    }

    return $class->new(comparator => '*') if ($string eq '*');

    return $class->new(comparator => '=', version => $string);
}

sub to_string {

    my $self = shift;

    return '*'         if $self->comparator eq '*';
    return $self->vers if $self->comparator eq '=';

    return $self->comparator . $self->vers;


}

sub contains {

    my ($self, $version) = @_;

    return TRUE if $self->comparator eq '*';

    return version->parse($version) == version->parse($self->{version}) if ($self->comparator eq '=');
    return version->parse($version) != version->parse($self->{version}) if ($self->comparator eq '!=');
    return version->parse($version) <= version->parse($self->{version}) if ($self->comparator eq '<=');
    return version->parse($version) < version->parse($self->{version})  if ($self->comparator eq '<');
    return version->parse($version) >= version->parse($self->{version}) if ($self->comparator eq '>=');
    return version->parse($version) > version->parse($self->{version})  if ($self->comparator eq '>');

    return FALSE;

}

sub TO_JSON {
    return {version => $_[0]->vers, comparator => $_[0]->comparator};

}

1;
