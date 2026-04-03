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
field $table :param=[];
field $where :param=undef;

method _comma(@parts) {
    return
        unless @parts;
    return Query::Expression->new(
        joined_by => ', ',
        parts => \@parts )
}

method _build() {
    my @parts;
    push @parts, '('
        if $as;
    push @parts, Query::Expression->new(parts => [WITH => $self->_comma($ctes->@*)])
        if $ctes->@*;
    push @parts, 'SELECT';
    $columns = ['*']
        unless $columns;
    $columns = [$columns]
        unless ref $columns eq 'ARRAY';
    push @parts, $self->_comma($columns->@*);
    $table = [$table]
        unless ref $table eq 'ARRAY';
    push @parts, (FROM => $self->_comma($table->@*))
        if $table->@*;
    push @parts, Query::Expression->new(parts => [WHERE => $where])
        if $where;
    push @parts, Query::Expression->new(parts => ['GROUP BY' => $self->_comma($group_by->@*)])
        if $group_by->@*;
    push @parts, Query::Expression->new(parts => [LIMIT => '?'], params => [$limit])
        if defined $limit;
    push @parts, Query::Expression->new(parts => [OFFSET => '?'], params => [$offset])
        if defined $offset;
    push @parts, ')', 'AS', $as
        if $as;
    $parts = \@parts;
}

method as_sql {
    $self->_build();
    my $sql = join ' ',
        map { $_ isa Query::Expression ? $_->as_sql() : trim($_) }
        $parts->@*;
    return $sql
}
use overload '""' => \&as_sql;

method params() {
    $self->_build();
    return $self->SUPER::params()
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
