package Query::Expression;
use v5.40;
use Object::Pad;

class Query::Expression {
    use builtin qw(trim);
    
    field $parts :param;
    field $params :param = undef;
    field $joined_by :param = ' ';

    method to_string() {
        $parts = [$parts]
            unless ref $parts eq 'ARRAY';
        return join $joined_by, map { ref $_ ? $_->to_string() : trim($_) } $parts->@*
    }

    method params() {
        $parts = [$parts]
            unless ref $parts eq 'ARRAY';
        if ($params) {
            return $params
        } else {
            my @p;
            for my $part ($parts->@*) {
                if (ref $part && $part->can('params')) {
                    my $sub_params = $part->params();
                    if (ref $sub_params eq 'ARRAY') {
                        push @p, $sub_params->@*;
                    } else {
                        push @p, $sub_params;
                    }
                }
            }
            return @p == 0 ? [] : (@p == 1 ? $p[0] : \@p);
        }
    }
}

1;