use v5.40;
use Object::Pad;

class Query::Expression::Aggregate
    :isa(Query::Expression)
    :does(Query::Role::As);

field $expression :param;

method _build :override () {
    $self->reset();
    $self->add_part($expression);
    return $self
}

method _post_sql :override ($sql) {
    return $self->as_as_sql($sql)
}

1;
