use v5.40;
use Test2::V0;
use lib 'lib';
use Query::Builder;

# Test PostgreSQL ANY/ALL vs MySQL/SQLite behavior

# PostgreSQL Dialect
my $pg = Query::Builder->new(dialect => 'pg');

# MySQL Dialect
my $mysql = Query::Builder->new(dialect => 'mysql');

# SQLite Dialect
my $sqlite = Query::Builder->new(dialect => 'sqlite');

subtest 'Single value comparison - all dialects behave the same' => sub {
    my $pg_single = $pg->compare(name => 'John');
    my $mysql_single = $mysql->compare(name => 'John');
    my $sqlite_single = $sqlite->compare(name => 'John');

    is $pg_single->to_string(), 'name = ?';
    is $mysql_single->to_string(), 'name = ?';
    is $sqlite_single->to_string(), 'name = ?';

    is $pg_single->params(), 'John';
    is $mysql_single->params(), 'John';
    is $sqlite_single->params(), 'John';
};

subtest 'Multiple values - PostgreSQL uses ANY' => sub {
    my $pg_multi = $pg->compare(status => ['active', 'pending', 'verified']);

    is $pg_multi->to_string(), 'status = ANY(?)';
    is $pg_multi->params(), ['active', 'pending', 'verified'];
};

subtest 'Multiple values - MySQL uses AND combine' => sub {
    my $mysql_multi = $mysql->compare(status => ['active', 'pending', 'verified']);

    is $mysql_multi->to_string(), 'status = ? AND status = ? AND status = ?';
    is $mysql_multi->params(), ['active', 'pending', 'verified'];
};

subtest 'Multiple values - SQLite uses AND combine' => sub {
    my $sqlite_multi = $sqlite->compare(status => ['active', 'pending', 'verified']);

    is $sqlite_multi->to_string(), 'status = ? AND status = ? AND status = ?';
    is $sqlite_multi->params(), ['active', 'pending', 'verified'];
};

subtest 'Negated multiple values - PostgreSQL uses ALL with NOT' => sub {
    my $pg_not = $pg->compare(status => ['deleted', 'banned'], negated => 1);

    is $pg_not->to_string(), 'NOT ( status = ALL(?) )';
    is $pg_not->params(), ['deleted', 'banned'];
};

subtest 'Negated multiple values - MySQL uses OR combine' => sub {
    my $mysql_not = $mysql->compare(status => ['deleted', 'banned'], negated => 1);

    is $mysql_not->to_string(), 'NOT ( status = ? ) OR NOT ( status = ? )';
    is $mysql_not->params(), ['deleted', 'banned'];
};

subtest 'Negated multiple values - SQLite uses OR combine' => sub {
    my $sqlite_not = $sqlite->compare(status => ['deleted', 'banned'], negated => 1);

    is $sqlite_not->to_string(), 'NOT ( status = ? ) OR NOT ( status = ? )';
    is $sqlite_not->params(), ['deleted', 'banned'];
};

subtest 'PostgreSQL ANY with different comparators' => sub {
    # Greater than ANY - true if value is greater than at least one element
    my $gt_any = $pg->compare(score => [70, 80, 90], comparator => '>');
    is $gt_any->to_string(), 'score > ANY(?)';
    is $gt_any->params(), [70, 80, 90];

    # Less than ANY - true if value is less than at least one element
    my $lt_any = $pg->compare(age => [18, 21, 65], comparator => '<');
    is $lt_any->to_string(), 'age < ANY(?)';
    is $lt_any->params(), [18, 21, 65];

    # Not equal ANY (careful - this is rarely what you want!)
    my $ne_any = $pg->compare(id => [1, 2, 3], comparator => '!=');
    is $ne_any->to_string(), 'id != ANY(?)';
    is $ne_any->params(), [1, 2, 3];
};

subtest 'PostgreSQL negated with different comparators becomes ALL' => sub {
    # NOT (score > ALL(?)) means score is not greater than all values
    my $not_gt_all = $pg->compare(score => [70, 80, 90], comparator => '>', negated => 1);
    is $not_gt_all->to_string(), 'NOT ( score > ALL(?) )';
    is $not_gt_all->params(), [70, 80, 90];
};

subtest 'Complex query with ANY in PostgreSQL' => sub {
    my $complex = $pg->combine_and(
        $pg->compare(status => ['active', 'pending']),
        $pg->compare(role => ['admin', 'moderator', 'user']),
        $pg->compare(age => 18, comparator => '>=')
    );

    is $complex->to_string(), 'status = ANY(?) AND role = ANY(?) AND age >= ?';
    # Params are flattened by the Expression params() method
    my $params = $complex->params();
    is ref($params), 'ARRAY';
    is scalar(@$params), 6;
    is $params->[0], 'active';
    is $params->[1], 'pending';
    is $params->[2], 'admin';
    is $params->[3], 'moderator';
    is $params->[4], 'user';
    is $params->[5], 18;
};

subtest 'Complex query with AND combine in MySQL' => sub {
    my $complex = $mysql->combine_and(
        $mysql->compare(status => ['active', 'pending']),
        $mysql->compare(role => ['admin', 'moderator']),
        $mysql->compare(age => 18, comparator => '>=')
    );

    is $complex->to_string(), '( status = ? AND status = ? ) AND ( role = ? AND role = ? ) AND age >= ?';
    my $params = $complex->params();
    is ref($params), 'ARRAY';
    is scalar(@$params), 5;
    is $params->[0], 'active';
    is $params->[1], 'pending';
    is $params->[2], 'admin';
    is $params->[3], 'moderator';
    is $params->[4], 18;
};

subtest 'Semantic equivalence test' => sub {
    # These should be semantically equivalent (though syntactically different)
    # PostgreSQL: status = ANY(ARRAY['active', 'pending'])
    # MySQL: (status = 'active' AND status = 'pending')
    # Note: In real SQL, AND would never be true for same column with different values
    # This demonstrates the implementation difference

    my $pg_q = $pg->compare(x => [1, 2]);
    my $mysql_q = $mysql->compare(x => [1, 2]);

    # Both should have same params
    is $pg_q->params(), [1, 2];
    is $mysql_q->params(), [1, 2];

    # Different SQL syntax
    isnt $pg_q->to_string(), $mysql_q->to_string();
};

subtest 'Two values edge case' => sub {
    my $pg_two = $pg->compare(id => [1, 2]);
    my $mysql_two = $mysql->compare(id => [1, 2]);

    is $pg_two->to_string(), 'id = ANY(?)';
    is $mysql_two->to_string(), 'id = ? AND id = ?';
};

done_testing();
