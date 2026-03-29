use v5.40;
use Test2::V0;
use lib 'lib';
use Query::Builder;

# Create a PostgreSQL query builder (default)
my $qb = Query::Builder->new();

# Test basic compare
my $equals = $qb->compare(name => 'Hansi');
is $equals->to_string(), 'name = ?';
is $equals->params(), 'Hansi';

# Test multi-value compare (PostgreSQL uses ANY)
my $multi_value_equals = $qb->compare(name => [qw(Hansi Hansi2)]);
is $multi_value_equals->to_string(), 'name = ANY(?)';
is $multi_value_equals->params(), [qw(Hansi Hansi2)];

# Test negated compare
my $negated_equals = $qb->compare(name => 'Hansi', negated => 1);
is $negated_equals->to_string(), 'NOT ( name = ? )';
is $negated_equals->params(), 'Hansi';

# Test multiple negated values (PostgreSQL uses ALL with negation)
my $multiple_negated_equals = $qb->compare(name => [qw(Hansi Hansi2)], negated => 1);
is $multiple_negated_equals->to_string(), 'NOT ( name = ALL(?) )';
is $multiple_negated_equals->params(), [qw(Hansi Hansi2)];

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

# Test is_true - no column (literal TRUE)
my $true_expr = $qb->is_true();
is $true_expr->to_string(), 'TRUE';
is $true_expr->params(), [];

# Test is_false - no column (literal FALSE)
my $false_expr = $qb->is_false();
is $false_expr->to_string(), 'FALSE';
is $false_expr->params(), [];

# Test is_true with column
my $true_column = $qb->is_true('is_active');
is $true_column->to_string(), 'is_active';
is $true_column->params(), [];

# Test is_false with column (negates the column)
my $false_column = $qb->is_false('is_active');
is $false_column->to_string(), 'NOT ( is_active )';
is $false_column->params(), [];

# Test like with ILIKE (case-insensitive, default for PostgreSQL)
my $like_expr = $qb->like(name => '%Hans%');
is $like_expr->to_string(), 'name ILIKE ?';
is $like_expr->params(), '%Hans%';

# Test like with % at start
my $like_start = $qb->like(name => '%Hans');
is $like_start->to_string(), 'name ILIKE ?';
is $like_start->params(), '%Hans';

# Test like with % at end
my $like_end = $qb->like(name => 'Hans%');
is $like_end->to_string(), 'name ILIKE ?';
is $like_end->params(), 'Hans%';

# Test like with % at both ends
my $like_both = $qb->like(name => '%Hans%');
is $like_both->to_string(), 'name ILIKE ?';
is $like_both->params(), '%Hans%';

# Test negated like
my $not_like = $qb->like(name => '%Hans%', negated => 1);
is $not_like->to_string(), 'NOT ( name ILIKE ? )';
is $not_like->params(), '%Hans%';

# Test case-sensitive LIKE
my $like_case_sensitive = $qb->like(name => '%Hans%', case_sensitive => 1);
is $like_case_sensitive->to_string(), 'name LIKE ?';
is $like_case_sensitive->params(), '%Hans%';

# Test complex combination
my $complex = $qb->combine_and(
    $qb->combine_or(
        $qb->compare(name => 'Hansi'),
        $qb->like(name => '%Franz%')),
    $qb->compare(age => '18', comparator => '>='));
is $complex->to_string(), '( name = ? OR name ILIKE ? ) AND age >= ?';
is $complex->params(), ['Hansi', '%Franz%', '18'];

# Test ANY with different comparators
my $any_greater = $qb->compare(score => [80, 90, 100], comparator => '>');
is $any_greater->to_string(), 'score > ANY(?)';
is $any_greater->params(), [80, 90, 100];

# Test negated ANY becomes ALL
my $not_any = $qb->compare(status => ['deleted', 'banned', 'suspended'], negated => 1);
is $not_any->to_string(), 'NOT ( status = ALL(?) )';
is $not_any->params(), ['deleted', 'banned', 'suspended'];

done_testing();
