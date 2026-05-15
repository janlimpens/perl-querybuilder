use v5.40;
use Test2::V0;
use lib 'lib';
use Query::Builder;

subtest 'having' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');
    my $sql = $qb->select('department', 'COUNT(*) AS cnt')
        ->from('employees')
        ->group_by('department')
        ->having($qb->compare('cnt', 5, comparator => '>'));
    is $sql, 'SELECT department, COUNT(*) AS cnt FROM employees GROUP BY department HAVING cnt > ?', 'having with aggregation';
    is [$sql->params()], [5], 'having params';
};

subtest 'aggr and auto group_by' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');

    # aggr with alias
    my $aggr = $qb->aggr('COUNT(*)')->as('cnt');
    is $aggr, 'COUNT(*) AS cnt', 'aggr with alias produces AS SQL';

    # aggr without alias
    my $aggr_no_alias = $qb->aggr('SUM(amount)');
    is $aggr_no_alias, 'SUM(amount)', 'aggr without alias omits AS';

    # auto group_by with mixed columns and aggregates
    my $sql = $qb->select('department', $qb->aggr('COUNT(*)')->as('cnt'))
        ->from('employees')
        ->group_by();
    is $sql, 'SELECT department, COUNT(*) AS cnt FROM employees GROUP BY 1',
        'auto group_by produces positional references';

    # explicit group_by still works alongside aggregates
    my $sql2 = $qb->select('department', 'city', $qb->aggr('SUM(salary)')->as('total'))
        ->from('employees')
        ->group_by('department', 'city');
    is $sql2, 'SELECT department, city, SUM(salary) AS total FROM employees GROUP BY department, city',
        'explicit group_by with aggregates';

    # auto group_by with only aggregate columns (no GROUP BY)
    my $sql3 = $qb->select($qb->aggr('COUNT(*)')->as('cnt'))
        ->from('employees')
        ->group_by();
    is $sql3, 'SELECT COUNT(*) AS cnt FROM employees',
        'auto group_by with only aggregates omits GROUP BY';

    # * excluded from auto group_by
    my $sql5 = $qb->select('*')
        ->from('t')
        ->group_by();
    is $sql5, 'SELECT * FROM t',
        '* excluded from auto group_by';

    # having with aggregate and auto group_by
    my $sql6 = $qb->select('department', $qb->aggr('COUNT(*)')->as('cnt'))
        ->from('employees')
        ->group_by()
        ->having($qb->compare('cnt', 5, comparator => '>'));
    is $sql6, 'SELECT department, COUNT(*) AS cnt FROM employees GROUP BY 1 HAVING cnt > ?',
        'having with auto group_by';
    is [$sql6->params()], [5], 'having params with auto group_by';

    # relation objects included in auto group_by
    my $sql7 = $qb->select($qb->relation('id')->as('emp_id'), 'name', $qb->aggr('COUNT(*)')->as('cnt'))
        ->from('employees')
        ->group_by();
    is $sql7, 'SELECT id AS emp_id, name, COUNT(*) AS cnt FROM employees GROUP BY 1, 2',
        'relation objects included in auto group_by positions';
};

subtest 'is null' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');

    my $is_null = $qb->is_null('deleted_at');
    is $is_null, 'deleted_at IS NULL', 'is null';

    my $is_not_null = $qb->is_null('email', false);
    is $is_not_null, 'email IS NOT NULL', 'is not null';

    my $sql = $qb->select('id', 'name')
        ->from('users')
        ->where($qb->is_null('deleted_at'));
    is $sql, 'SELECT id, name FROM users WHERE deleted_at IS NULL', 'is null in where';

    my $sql2 = $qb->select('id')
        ->from('users')
        ->where(
            $qb->combine_and(
                $qb->is_null('deleted_at'),
                $qb->is_null('email', false)));
    is $sql2, 'SELECT id FROM users WHERE deleted_at IS NULL AND email IS NOT NULL', 'is null combined';
};

subtest 'distinct' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');

    my $sql = $qb->select('department')
        ->distinct()
        ->from('employees');
    is $sql, 'SELECT DISTINCT department FROM employees', 'plain distinct';

    my $sql2 = $qb->select('department', 'name')
        ->distinct('department')
        ->from('employees');
    is $sql2, 'SELECT DISTINCT ON (department) department, name FROM employees', 'distinct on';

    my $sql3 = $qb->select('department', $qb->aggr('COUNT(*)')->as('cnt'))
        ->distinct()
        ->from('employees')
        ->group_by();
    is $sql3, 'SELECT DISTINCT department, COUNT(*) AS cnt FROM employees GROUP BY 1', 'distinct with group by';
};

subtest 'from readme' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');
    my $cte = $qb->select($qb->relation('id')->as('theater_id'), 'name', 'city')
        ->from('venues')
        ->as('theaters')
        ->where($qb->compare(type => 'theater'));
    my $join_1 = $qb->join('roles')
        ->type('LEFT')
        ->as('r')
        ->on( $qb->compare('r.actor_id', \'a.id') );
    my $join_2 = $qb->join('theaters')
        ->as('t')
        ->using('theater_id');
    my $sql = $qb->select(qw(id first_name last_name gender birthday r.title r.date t.name t.city))
        ->from('actors a')
        ->with($cte)
        ->joins($join_1, $join_2)
        ->where(
            $qb->combine(AND =>
                $qb->is_true('a.active'),
                $qb->compare('a.age', 30, comparator => '>')))
        ->order_by(
            $qb->order_by('a.birthday', 'DESC'),
            $qb->order_by('a.last_name'))
        ->limit(100)
        ->offset(100);
    is $sql, 'WITH ( SELECT id AS theater_id, name, city FROM venues WHERE type = ? ) AS theaters SELECT id, first_name, last_name, gender, birthday, r.title, r.date, t.name, t.city FROM actors a LEFT JOIN roles AS r ON r.actor_id = a.id JOIN theaters AS t USING ( theater_id ) WHERE a.active AND a.age > ? ORDER BY a.birthday DESC, a.last_name LIMIT ? OFFSET ?', 'got good sql';
};

subtest clone => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');
    my $q = $qb->select($qb->relation('id')->as('theater_id'), 'name', 'city')
        ->from('venues')
        ->where($qb->compare(type => 'theater'));
    my $count = $q->clone(columns => ['COUNT(*)']);
    is $count, 'SELECT COUNT(*) FROM venues WHERE type = ?', 'cloned successfully';
    is [$count->params()], ['theater'], 'params cloned successfully';
};

subtest 'GROUP BY comes before ORDER BY' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');
    my $sql = $qb->select('word', 'COUNT(*) AS c')
        ->from('matrix')
        ->group_by('word')
        ->order_by($qb->order_by('c', 'DESC'));
    like "$sql", qr/GROUP BY word ORDER BY c DESC/, 'GROUP BY precedes ORDER BY';
};

done_testing();
