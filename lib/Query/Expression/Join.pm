use v5.40;
use Object::Pad ':experimental(inherit_field)';

class Query::Expression::Join;
inherit Query::Expression '$parts';
use builtin ':5.40';

field $table :param=undef;
field $as :param=undef;
field $type :param='';
field $on :param=undef;
field $using :param=undef;

field %types = (
    '' => '',
    INNER => '',
    LEFT => 'LEFT',
    'LEFT OUTER' => 'LEFT',
    RIGHT => 'RIGHT',
    'RIGHT OUTER' => 'RIGHT',
    FULL => 'FULL',
    CROSS => 'CROSS' );

method _build() {
    my @parts;
    $type = $types{uc trim($type)} // die "type $type not recognized";
    die 'no table specified'
        unless $table;
    push @parts,  $type||(), 'JOIN', $table;
    push @parts, AS => $as
        if $as;
    if ($on && $using) { die 'both on and using specified'; }
    elsif ($on) { push @parts, ON => $on; }
    elsif ($using) { push @parts, USING => '(', $using, ')'; }
    else { die 'no join condition specified'; }
    $parts = \@parts;
}

method as_sql {
    $self->_build();
    return $self->SUPER::as_sql()
}
use overload '""' => \&as_sql;

method params() {
    $self->_build();
    return $self->SUPER::params()
}
