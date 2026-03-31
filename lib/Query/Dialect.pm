package Query::Dialect;
use v5.40;
use Object::Pad;

class Query::Dialect :abstract;

use builtin ':5.40';
use Query::Expression;

field %negations = do {
    my %cmps = (
        '=' => '!=',
        '>' => '<',
        '>=' => '<=');
    %cmps = ( %cmps, reverse %cmps );
    %cmps
};

method negate(@expressions) {
    return
        unless @expressions;
    return $self->combine(OR => map { $_->negate() } @expressions)
}

method combine($link, @expressions) {
    return ()
        unless @expressions;
    return $expressions[0]
        if @expressions == 1;
    $link = trim($link);
    # Wrap expressions that contain AND/OR operators
    my @parts = map {
        ($_ isa Query::Expression && $_->as_sql() =~ / (AND|OR) /)
            ? $_->wrap()
            : $_
    } @expressions;
    return Query::Expression->new(
        joined_by => " $link ",
        parts => \@parts,
        params => [])
}

method combine_and(@expressions) {
    return $self->combine(AND => @expressions)
}

method combine_or(@expressions) {
    return $self->combine(OR => @expressions)
}

method compare($column, $value, %args) {
    my $comparator = $args{comparator} // '=';
    $comparator = trim($comparator);
    my $negated = $args{negated};
    my @expressions =
        map {
            my $exp = Query::Expression->new(
                parts => [$column, $comparator, '?'],
                params => [$_] );
            $negated ? $self->negate($exp) : $exp
        }
        ref $value eq 'ARRAY' ? $value->@* : $value;
    return $self->combine($negated ? 'AND' : 'OR' => @expressions);
}

method is_true($column);
method is_false($column);
method like($column, $pattern, %args);

1;
