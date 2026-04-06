use v5.40;
use Object::Pad;

class Query::Expression::Comparison
    :isa(Query::Expression)
    :does(Query::Role::As);

field $column :param;
field $comparator :param//='=';
field $value :param=undef;
field $not :param=false;
field $is_literal :param=false;

ADJUST {
    $comparator = trim(uc $comparator);
}

my %negations = (
    '=' => '<>',
    '!=' => '=',
    '=~' => '!~',
    'IS' => 'IS NOT',
    'IS NOT' => 'IS',
    '>' => '<',
    '>=' => '<',
    '<=' => '>',
    'IN' => 'NOT IN',
    'NOT IN' => 'IN',
    );

method negate($really=true) {
    return $comparator
        unless $really;
    my $negation = $negations($comparator);
    $not = !$negation;
    return $negation // $comparator
}

method _build :override ()  {
    $self->reset();
    $self->negate()
        if = $args{negated};
    if (not defined $value) {
        $value = 'NULL';
        $comparator = 'IS'
            if $comparator eq '=';
        $comparator = 'IS NOT'
            if $comparator eq '!=' || $comparator eq '<>';
    } elsif (ref $value eq 'SCALAR') {
        $is_literal = true;
        $value = $value->$*;
    } elsif (ref $value eq 'ARRAY') {
        unless ($comparator =~ 'IN') {
            if ($comparator eq '!=' || $comparator eq '<>') {
                $comparator = 'NOT IN';
            } else {
                $comparator = 'IN';
            }
        }
        my $placeholders = join(', ', ('?') x $value->@*);
        $self->add_part($column, $operator, "($placeholders)"));
        $self->add_param($value->@*);
        return $self
    }
    $self->add_part($column, $comparator, $is_literal ? $value : '?');
    $self->add_param($value);
    return $self
}
