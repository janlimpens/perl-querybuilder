use v5.40;
use Test2::V0;
use lib 'lib';
use Query::Builder;

# Test PostgreSQL Dialect
subtest 'PostgreSQL Dialect' => sub {
    my $qb = Query::Builder->new(dialect => 'pg');

    # Test compare
    my $equals = $qb->compare(name => 'Hansi');
    is $equals->to_string(), 'name = ?';
    is $equals->params(), 'Hansi';

    # Test multi-value compare (PostgreSQL uses ANY)
    my $multi = $qb->compare(name => [qw(Hansi Franz)]);
    is $multi->to_string(), 'name = ANY(?)';
    is $multi->params(), [qw(Hansi Franz)];

    # Test negated compare (single value)
    my $negated = $qb->compare(name => 'Hansi', negated => 1);
    is $negated->to_string(), 'NOT ( name = ? )';
    is $negated->params(), 'Hansi';

    # Test negated compare (multiple values - uses ALL)
    my $negated_multi = $qb->compare(name => [qw(Hansi Franz)], negated => 1);
    is $negated_multi->to_string(), 'NOT ( name = ALL(?) )';
    is $negated_multi->params(), [qw(Hansi Franz)];

    # Test combine_and
    my $and_expr = $qb->combine_and(
        $qb->compare(name => 'Hansi'),
        $qb->compare(age => '30', comparator => '>'));
    is $and_expr->to_string(), 'name = ? AND age > ?';
    is $and_expr->params(), ['Hansi', '30'];

    # Test combine_or
    my $or_expr = $qb->combine_or(
        $qb->compare(name => 'Hansi'),
        $qb->compare(name => 'Franz'));
    is $or_expr->to_string(), 'name = ? OR name = ?';
    is $or_expr->params(), ['Hansi', 'Franz'];

    # Test is_true - PostgreSQL uses TRUE (no column)
    my $true_expr = $qb->is_true();
    is $true_expr->to_string(), 'TRUE';
    is $true_expr->params(), [];

    # Test is_false - PostgreSQL uses FALSE (no column)
    my $false_expr = $qb->is_false();
    is $false_expr->to_string(), 'FALSE';
    is $false_expr->params(), [];

    # Test is_true with column
    my $true_col = $qb->is_true('is_active');
    is $true_col->to_string(), 'is_active';
    is $true_col->params(), [];

    # Test is_false with column (negates)
    my $false_col = $qb->is_false('is_active');
    is $false_col->to_string(), 'NOT ( is_active )';
    is $false_col->params(), [];

    # Test ILIKE (case-insensitive, default)
    my $like = $qb->like(name => '%Hans%');
    is $like->to_string(), 'name ILIKE ?';
    is $like->params(), '%Hans%';

    # Test LIKE (case-sensitive)
    my $like_cs = $qb->like(name => '%Hans%', case_sensitive => 1);
    is $like_cs->to_string(), 'name LIKE ?';
    is $like_cs->params(), '%Hans%';

    # Test negated LIKE
    my $not_like = $qb->like(name => '%Hans%', negated => 1);
    is $not_like->to_string(), 'NOT ( name ILIKE ? )';
    is $not_like->params(), '%Hans%';

    # Test complex combination
    my $complex = $qb->combine_and(
        $qb->combine_or(
            $qb->compare(name => 'Hansi'),
            $qb->like(name => '%Franz%')),
        $qb->compare(age => '18', comparator => '>='));
    is $complex->to_string(), '( name = ? OR name ILIKE ? ) AND age >= ?';
    is $complex->params(), ['Hansi', '%Franz%', '18'];

    # Test PostgreSQL-specific ANY/ALL
    my $any_compare = $qb->compare(status => ['active', 'pending', 'verified']);
    is $any_compare->to_string(), 'status = ANY(?)';
    is $any_compare->params(), ['active', 'pending', 'verified'];

    my $all_negated = $qb->compare(status => ['deleted', 'banned'], negated => 1);
    is $all_negated->to_string(), 'NOT ( status = ALL(?) )';
    is $all_negated->params(), ['deleted', 'banned'];
};

# Test MySQL Dialect
subtest 'MySQL Dialect' => sub {
    my $qb = Query::Builder->new(dialect => 'mysql');

    # Test compare
    my $equals = $qb->compare(name => 'Hansi');
    is $equals->to_string(), 'name = ?';
    is $equals->params(), 'Hansi';

    # Test is_true - MySQL uses 1 (no column)
    my $true_expr = $qb->is_true();
    is $true_expr->to_string(), '1';
    is $true_expr->params(), [];

    # Test is_false - MySQL uses 0 (no column)
    my $false_expr = $qb->is_false();
    is $false_expr->to_string(), '0';
    is $false_expr->params(), [];

    # Test is_true with column
    my $true_col = $qb->is_true('is_active');
    is $true_col->to_string(), 'is_active';
    is $true_col->params(), [];

    # Test is_false with column (negates)
    my $false_col = $qb->is_false('is_active');
    is $false_col->to_string(), 'NOT ( is_active )';
    is $false_col->params(), [];

    # Test LIKE (case-insensitive by default in MySQL)
    my $like = $qb->like(name => '%Hans%');
    is $like->to_string(), 'name LIKE ?';
    is $like->params(), '%Hans%';

    # Test BINARY LIKE (case-sensitive)
    my $like_cs = $qb->like(name => '%Hans%', case_sensitive => 1);
    is $like_cs->to_string(), 'BINARY name LIKE ?';
    is $like_cs->params(), '%Hans%';

    # Test negated LIKE
    my $not_like = $qb->like(name => '%Hans%', negated => 1);
    is $not_like->to_string(), 'NOT ( name LIKE ? )';
    is $not_like->params(), '%Hans%';

    # Test complex combination
    my $complex = $qb->combine_and(
        $qb->combine_or(
            $qb->compare(name => 'Hansi'),
            $qb->like(name => '%Franz%')),
        $qb->compare(age => '18', comparator => '>='));
    is $complex->to_string(), '( name = ? OR name LIKE ? ) AND age >= ?';
    is $complex->params(), ['Hansi', '%Franz%', '18'];
};

# Test SQLite Dialect
subtest 'SQLite Dialect' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');

    # Test compare
    my $equals = $qb->compare(name => 'Hansi');
    is $equals->to_string(), 'name = ?';
    is $equals->params(), 'Hansi';

    # Test is_true - SQLite uses 1 (no column)
    my $true_expr = $qb->is_true();
    is $true_expr->to_string(), '1';
    is $true_expr->params(), [];

    # Test is_false - SQLite uses 0 (no column)
    my $false_expr = $qb->is_false();
    is $false_expr->to_string(), '0';
    is $false_expr->params(), [];

    # Test is_true with column
    my $true_col = $qb->is_true('is_active');
    is $true_col->to_string(), 'is_active';
    is $true_col->params(), [];

    # Test is_false with column (negates)
    my $false_col = $qb->is_false('is_active');
    is $false_col->to_string(), 'NOT ( is_active )';
    is $false_col->params(), [];

    # Test LIKE (case-insensitive for ASCII by default)
    my $like = $qb->like(name => '%Hans%');
    is $like->to_string(), 'name LIKE ?';
    is $like->params(), '%Hans%';

    # Test GLOB (case-sensitive)
    my $like_cs = $qb->like(name => '*Hans*', case_sensitive => 1);
    is $like_cs->to_string(), 'name GLOB ?';
    is $like_cs->params(), '*Hans*';

    # Test negated LIKE
    my $not_like = $qb->like(name => '%Hans%', negated => 1);
    is $not_like->to_string(), 'NOT ( name LIKE ? )';
    is $not_like->params(), '%Hans%';

    # Test complex combination
    my $complex = $qb->combine_and(
        $qb->combine_or(
            $qb->compare(name => 'Hansi'),
            $qb->like(name => '%Franz%')),
        $qb->compare(age => '18', comparator => '>='));
    is $complex->to_string(), '( name = ? OR name LIKE ? ) AND age >= ?';
    is $complex->params(), ['Hansi', '%Franz%', '18'];
};

# Test dialect aliases
subtest 'Dialect Aliases' => sub {
    my $pg1 = Query::Builder->new(dialect => 'pg');
    my $pg2 = Query::Builder->new(dialect => 'postgresql');

    is $pg1->is_true()->to_string(), 'TRUE';
    is $pg2->is_true()->to_string(), 'TRUE';
};

# Test unknown dialect
subtest 'Unknown Dialect' => sub {
    like(
        dies { Query::Builder->new(dialect => 'oracle') },
        qr/Unknown dialect: oracle/,
        'Unknown dialect throws error'
    );
};

done_testing();
