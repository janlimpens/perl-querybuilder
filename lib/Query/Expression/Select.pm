use v5.40;
use Object::Pad ':experimental(inherit_field)';

class Query::Expression::Select;
inherit Query::Expression '$parts';
use builtin ':5.40';

field $as :param=undef;
field $columns :param=[];
field $ctes :param=[];
field $group_by :param=[];
field $joins :param=[];
field $limit :inheritable :param=undef;
field $offset :inheritable :param=undef;
field $order_by :param=[];
field $table :param=[];
field $where :param=undef;

method _comma(@parts) {
    return
        unless @parts;
    return Query::Expression->new(
        joined_by => ', ',
        parts => \@parts )
}

method _build :override ()  {
    $self->reset();
    $self->add_part('(')
        if $as;
    $self->add_part(Query::Expression->new(parts => [WITH => $self->_comma($ctes->@*)]))
        if $ctes->@*;
    $self->add_part('SELECT');
    $columns = ['*']
        unless $columns;
    $columns = [$columns]
        unless ref $columns eq 'ARRAY';
    $self->add_part($self->_comma($columns->@*));
    $table = [$table]
        unless ref $table eq 'ARRAY';
    $self->add_part(FROM => $self->_comma($table->@*))
        if $table->@*;
    $self->add_part(Query::Expression->new(parts => [WHERE => $where]))
        if $where;
    $self->add_part(Query::Expression->new(parts => ['ORDER BY' => $self->_comma($order_by->@*)]))
        if $order_by->@*;
    $self->add_part(Query::Expression->new(parts => ['GROUP BY' => $self->_comma($group_by->@*)]))
        if $group_by->@*;
    $self->add_part(Query::Expression->new(parts => [LIMIT => '?'], params => [$limit]))
        if defined $limit;
    $self->add_part(Query::Expression->new(parts => [OFFSET => '?'], params => [$offset]))
        if defined $offset;
    $self->add_part(')', 'AS', $as)
        if $as;
    return
}

method columns(@cols) {
    push $columns->@*, @cols;
    return $self
}

method from($t) {
    $table = $t;
    return $self
}

method where($clause) {
    $where = $clause;
    return $self
}

method limit($l) {
    $limit = $l;
    return $self
}

method offset($off) {
    $offset = $off;
    return $self
}

method group_by(@g) {
    push $group_by->@*, @g;
    return $self
}

method with(@cte) {
    push $ctes->@*, @cte;
    return $self
}

method as($alias=undef) {
    return $as
        unless $alias;
    $as = $alias;
    return $self
}

method joins(@expressipns) {
    push $joins->@*, @expressipns;
    return $self
}

method order_by(@expressions) {
    push $order_by->@*, @expressions;
    return $self
}
