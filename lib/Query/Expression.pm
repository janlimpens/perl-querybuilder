package Query::Expression;
use v5.40;
use Object::Pad ':experimental(inherit_field)';
use overload '""' => \&as_sql;
class Query::Expression;

use builtin ':5.40';

field $parts :inheritable :param = [];
field $params :inheritable :param = undef;
field $joined_by :param //= ' ';
field $brackets :inheritable :param = undef;

ADJUST {
    die 'parts are required'
        unless defined $parts;
    $parts = [ $parts ]
        unless ref $parts eq 'ARRAY';
}

method as_sql {
    # no () because "" overload comes with 3 args
    my $sql = join $joined_by,
        map { $_ isa Query::Expression ? $_->as_sql() : trim($_) }
        $parts->@*;
    if ($brackets) {
        my ($open, $close) = split //, $brackets;
        $sql = "$open $sql $close";
    }
    return $sql
}

method params() {
    my @params = $params && ref $params eq 'ARRAY' ? $params->@* : ();
    push @params, $params
        if $params && ref $params ne 'ARRAY';
    for my $part ($parts->@*) {
        next
            unless $part isa Query::Expression;
        push @params, $part->params();
    }
    return @params
}

method add_param($param) {
    push $params->@*, $param;
    return $self
}

method wrap($new_brackets//='()') {
    return Query::Expression->new(
        parts => $parts,
        params => $params,
        joined_by => $joined_by,
        brackets => $new_brackets)
}

# a bit too specific, maybe a prepend('NOT')?
method negate($really=true) {
    return $self
        unless $really;
    return Query::Expression->new(
        parts => ['NOT', $self->wrap()],
        joined_by => ' ',
        params => [])
}

1;
