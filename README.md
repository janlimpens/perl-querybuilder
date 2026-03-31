# Perl Query Builder

A flexible SQL query builder for Perl with dialect support for PostgreSQL, MySQL, and SQLite.

## Features

- Automatically generates SQL clauses optimized for your database
- Generates parameterized queries to prevent SQL injection
- Build complex queries from simple building blocks

## Supported Dialects

- **PostgreSQL**
- **MySQL**
- **SQLite**
- easy to support others

## Quick Start

```perl
use Query::Builder;

my $qb = Query::Builder->new(dialect => 'sqlite');

# Build a clause
my $clause = $qb->combine(AND => 
    $qb->compare(name => 'Fatima',
    $qb->is_true('can_sing'));

my @result = $dbh->selectall_array('SELECT * FROM table WHERE '. $clause->as_sql(), { Slice => {} }, $clause->params());

# SELECT * FROM table WHERE name = ? AND can_sing
# with params ('Fatima')
```

## API Reference

### Basic Comparisons

#### `compare($column, $value, %args)`

Compare a column to one or more values.

```perl
$qb->compare(name => 'John');
$qb->compare(age => 18, comparator => '>=');
$pg->compare(status => ['active', 'pending']);
$pg->compare(status => ['deleted', 'banned'], negated => true);
$pg->compare(score => [80, 90, 100], comparator => '>');
```

### Pattern Matching

#### `like($column, $pattern, %args)`

Pattern matching with LIKE.

```perl
# PostgreSQL: Uses ILIKE for case-insensitive by default
my $pg = Query::Builder->new(dialect => 'pg');

$pg->like(name => '%John%', case_sensitive => true);
$qb->like(email => '%@spam.com', negated => true);
```
### Logical Operators

#### `combine_and(@expressions)`

Combine expressions with AND.

```perl
my $query = $qb->combine_and(
    $qb->compare(age => 18, comparator => '>='),
    $qb->compare(country => 'Cuba')
);
# SQL: age >= ? AND country = ?
```

#### `combine_or(@expressions)`

Works the same, shorthand for

```perl
my $query = $qb->combine(OR =>
    $qb->compare(role => 'admin'),
    $qb->compare(role => 'moderator')
);
# SQL: role = ? OR role = ?
```

### Boolean Values

#### `is_true($column = undef)`

Returns a TRUE expression or a column reference.

```perl
# Literal TRUE (no column parameter)
# PostgreSQL
$qb->is_true();  # SQL: TRUE

# With column parameter - returns the column as-is
$qb->is_true('is_active');  # SQL: is_active
$qb->is_true('verified');   # SQL: verified

# Use case: boolean column checks
```

#### `is_false($column = undef)`

Returns a FALSE expression or a negated column reference.

### Advanced Operations

#### `negate(@expressions)`

Negate one or more expressions.

```perl
my $expr = $qb->compare(name => 'test');
my $negated = $qb->negate($expr);
# SQL: NOT ( name = ? )
```

#### `combine($link, @expressions)`

combine expressions with a custom operator.

```perl
my $query = $qb->combine('OR', @expressions);
```

## Complex Examples

### Nested Conditions

```perl
my $query = $qb->combine_and(
    $qb->combine_or(
        $qb->compare(role => 'admin'),
        $qb->compare(role => 'moderator')
    ),
    $qb->compare(active => true),
    $qb->compare(age => 18, comparator => '>=')
);
# SQL: ( role = ? OR role = ? ) AND active = ? AND age >= ?
# Params: ['admin', 'moderator', 1, 18]
```
