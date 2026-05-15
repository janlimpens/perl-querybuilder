# Perl Query Builder

A flexible, dialect-aware SQL query builder for Perl — build parameterized queries with an OO chainable API.

Supports PostgreSQL, MySQL, and SQLite.

## Quick Start

```perl
use Query::Builder;

my $qb = Query::Builder->new(dialect => 'sqlite');

# A simple select
my $query = $qb->select('id', 'name', 'email')
    ->from('users')
    ->where($qb->is_true('active'))
    ->order_by($qb->order_by('name'))
    ->limit(10);

say $query;           # SELECT id, name, email FROM users WHERE active ORDER BY name LIMIT ?
say $query->params(); # (1, 10)
```

## The SELECT API

Every SELECT query is built by chaining methods on the object returned by `$qb->select(...)`. All methods return `$self` so you can keep chaining.

### Basic structure

```perl
my $query = $qb->select(@columns)     # required
    ->from(@tables)                   # required
    ->distinct()                      # optional — DISTINCT or DISTINCT ON (...)
    ->with(@ctes)                     # optional — WITH (CTE), ...
    ->joins(@joins)                   # optional — JOIN ...
    ->where($condition)               # optional — WHERE ...
    ->group_by(@columns)              # optional — GROUP BY ...
    ->having($condition)              # optional — HAVING ...
    ->order_by(@order_clauses)        # optional — ORDER BY ...
    ->limit($n)                       # optional
    ->offset($n);                     # optional
```

### FROM

```perl
$qb->select('id', 'name')->from('users');
# SELECT id, name FROM users

$qb->select('a.id', 'r.title')
    ->from('actors a', 'roles r');
# SELECT a.id, r.title FROM actors a, roles r
```

### DISTINCT

```perl
$qb->select('department')->distinct()->from('employees');
# SELECT DISTINCT department FROM employees

$qb->select('department', 'name')
    ->distinct('department')
    ->from('employees');
# SELECT DISTINCT ON (department) department, name FROM employees   (PostgreSQL)
```

### WHERE — building conditions

The `where()` method takes a single condition expression. You build conditions with the clause-building methods described in the **Condition Reference** below.

```perl
$qb->select('id', 'name')
    ->from('users')
    ->where($qb->is_true('active'));
# SELECT id, name FROM users WHERE active

$qb->select('id', 'name')
    ->from('users')
    ->where(
        $qb->combine_and(
            $qb->is_true('active'),
            $qb->compare('age', 18, comparator => '>=')
        )
    );
# SELECT id, name FROM users WHERE active AND age >= ?
```

### JOIN

Joins are built with `$qb->join($table)` and passed to `joins()`:

```perl
my $j1 = $qb->join('roles')
    ->as('r')
    ->on($qb->compare('r.actor_id', \'a.id'));

my $j2 = $qb->join('theaters')
    ->as('t')
    ->using('theater_id');

$qb->select('a.name', 'r.title', 't.name')
    ->from('actors a')
    ->joins($j1, $j2);
```

Join types: pass `->type('LEFT')`, `->type('RIGHT')`, `->type('FULL')`, `->type('CROSS')`.

### WITH (CTEs)

CTEs are full SELECT statements with an alias:

```perl
my $cte = $qb->select('id', 'name', 'city')
    ->from('venues')
    ->where($qb->compare('type', 'theater'))
    ->as('theaters');

$qb->select('a.name', 't.name')
    ->from('actors a')
    ->with($cte)
    ->joins(
        $qb->join('theaters')->as('t')->using('theater_id')
    );
```

### GROUP BY

```perl
# Explicit grouping
$qb->select('department', 'COUNT(*) AS cnt')
    ->from('employees')
    ->group_by('department');

# Auto group_by — non-aggregate columns get positional references
$qb->select('department', $qb->aggr('COUNT(*)')->as('cnt'))
    ->from('employees')
    ->group_by();
# SELECT department, COUNT(*) AS cnt FROM employees GROUP BY 1
```

### HAVING

Filter grouped rows with `having()`. It accepts the same condition expressions as `where()`:

```perl
$qb->select('department', $qb->aggr('COUNT(*)')->as('cnt'))
    ->from('employees')
    ->group_by('department')
    ->having($qb->compare('cnt', 5, comparator => '>'));
# SELECT department, COUNT(*) AS cnt FROM employees
# GROUP BY department HAVING cnt > ?
```

### Aggregate expressions

```perl
$qb->aggr('COUNT(*)')                         # COUNT(*)
$qb->aggr('COUNT(*)')->as('cnt')               # COUNT(*) AS cnt
$qb->aggr('SUM(amount)')->as('total')          # SUM(amount) AS total
$qb->aggr("SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END)")->as('paid_total')
```

### ORDER BY

```perl
$qb->select('name', 'created')
    ->from('users')
    ->order_by(
        $qb->order_by('created', 'DESC'),
        $qb->order_by('name')
    );
# ORDER BY created DESC, name
```

### LIMIT / OFFSET

```perl
$qb->select('id')->from('users')->limit(100)->offset(200);
# LIMIT ? OFFSET ?   params: (100, 200)
```

### Alias via `as()`

Any SELECT expression can be aliased with `as()`:

```perl
$qb->select('id')->from('users')->as('u');
# ( SELECT id FROM users ) AS u

$qb->relation('id')->as('user_id');
# id AS user_id
```

### Clone

Clone a SELECT and override parts — useful for building a COUNT query from an existing one:

```perl
my $base = $qb->select('id', 'name', 'email')
    ->from('users')
    ->where($qb->is_true('active'));

my $count = $base->clone(columns => ['COUNT(*)']);
# SELECT COUNT(*) FROM users WHERE active
```

## Set Operations

```perl
my $a = $qb->select('id', 'name')->from('users');
my $b = $qb->select('id', 'name')->from('archived_users');

$qb->union($a, $b);         # ( … ) UNION ( … )
$qb->union_all($a, $b);     # ( … ) UNION ALL ( … )
$qb->intersect($a, $b);     # ( … ) INTERSECT ( … )
$qb->except($a, $b);        # ( … ) EXCEPT ( … )

# Use as a FROM source
$qb->select('*')->from($qb->union($a, $b));
```

## INSERT

### INSERT … VALUES

```perl
my $into = $qb->into('films', ['title', 'type', 'created'], [['Timbuktu', 'movie', \'NOW()']]);
# INTO films (title, type, created) VALUES ( ?, ?, NOW() )

# Pass raw SQL expressions as scalar refs: \'NOW()'
```

### INSERT … SELECT

```perl
my $insert = Query::Expression->new(parts => [
    INSERT => $qb->into(
        'archive',
        ['id', 'amount'],
        Query::Expression->new(parts => [
            'SELECT id, amount FROM invoices WHERE',
            $qb->compare('created_at', '2024-01-01', comparator => '<')
        ])
    )
]);
```

## UPDATE

```perl
my $set = $qb->set(
    title   => 'Timbuktu',
    type    => 'movie',
    updated => \'NOW()'
);
# SET title = ?, type = ?, updated = NOW()
# params: ('Timbuktu', 'movie')
```

## Condition Reference

These methods build individual condition expressions. Use them inside `where()`, `having()`, `on()`, or nest them with `combine_and()` / `combine_or()`.

### `compare($column, $value, %args)`

```perl
$qb->compare('name', 'Alice');
# name = ?

$qb->compare('age', 18, comparator => '>=');
# age >= ?

# IN with an array
$qb->compare('status', ['active', 'pending']);
# status IN (?, ?)

# Subquery as value
$qb->compare('role_id', $subquery, comparator => 'IN');
# role_id IN ( SELECT id FROM roles WHERE … )

# Scalar ref for raw column reference
$qb->compare('orders.user_id', \'users.id');
# orders.user_id = users.id

# Negate
$qb->compare('name', 'Agnaldo')->negate();
# NOT ( name = ? )
```

### `like($column, $pattern, %args)`

```perl
$qb->like('name', '%Alice%');
# name LIKE ?

$qb->like('name', '%Alice%')->negate();
# NOT ( name LIKE ? )

# PostgreSQL: case-insensitive by default (ILIKE)
$pg->like('name', '%Alice%', case_sensitive => 1);
# name LIKE ?           (forces LIKE instead of ILIKE)
```

### Boolean helpers

```perl
$qb->is_true();           # TRUE  (literal)
$qb->is_true('active');   # active
$qb->is_false();          # FALSE
$qb->is_false('deleted'); # NOT ( deleted )
```

### `is_null($column, $really)`

```perl
$qb->is_null('deleted_at');          # deleted_at IS NULL
$qb->is_null('email', 0);            # email IS NOT NULL
```

### `between($column, $low, $high, $really)`

```perl
$qb->between('age', 18, 65);         # age BETWEEN ? AND ?
$qb->between('score', 0, 50, 0);     # score NOT BETWEEN ? AND ?
```

### `negate(@expressions)`

Negates one or more expressions by switching their operators and combining with OR:

```perl
$qb->negate(
    $qb->compare('name', 'test'),
    $qb->compare('name', 'foo')
);
# NOT ( name = ? OR name = ? )
# Becomes: name != ? AND name != ?
```

### `combine($link, @expressions)` / `combine_and` / `combine_or`

Combine multiple conditions with AND or OR:

```perl
$qb->combine_and(
    $qb->is_true('active'),
    $qb->compare('age', 18, comparator => '>=')
);
# active AND age >= ?

$qb->combine_or(
    $qb->compare('role', 'admin'),
    $qb->compare('role', 'moderator')
);
# role = ? OR role = ?
```

Nesting works as expected:

```perl
$qb->combine_and(
    $qb->combine_or(
        $qb->compare('role', 'admin'),
        $qb->compare('role', 'moderator')
    ),
    $qb->is_true('active'),
    $qb->compare('age', 18, comparator => '>=')
);
# ( role = ? OR role = ? ) AND active AND age >= ?
```

### Subqueries and `exists()`

```perl
my $sub = $qb->select('1')
    ->from('orders')
    ->where($qb->compare('orders.user_id', \'users.id'));

$qb->exists($sub);           # EXISTS ( SELECT 1 FROM orders WHERE … )
$qb->exists($sub, 0);        # NOT EXISTS ( … )

# Use in WHERE
$qb->select('id', 'name')
    ->from('users')
    ->where($qb->exists($sub));
```

## Complex Example

```perl
my $qb = Query::Builder->new(dialect => 'sqlite');

my $theaters_cte = $qb->select(
        $qb->relation('id')->as('theater_id'),
        'name',
        'city'
    )
    ->from('venues')
    ->where($qb->compare('type', 'theater'))
    ->as('theaters');

my $query = $qb->select(
        'id', 'first_name', 'last_name', 'gender', 'birthday',
        'r.title', 'r.date',
        't.name', 't.city'
    )
    ->from('actors a')
    ->with($theaters_cte)
    ->joins(
        $qb->join('roles')
            ->as('r')
            ->on($qb->compare('r.actor_id', \'a.id')),
        $qb->join('theaters')
            ->as('t')
            ->using('theater_id')
    )
    ->where(
        $qb->combine_and(
            $qb->is_true('a.active'),
            $qb->compare('a.age', 30, comparator => '>')
        )
    )
    ->order_by(
        $qb->order_by('a.birthday', 'DESC'),
        $qb->order_by('a.last_name')
    )
    ->limit(100)
    ->offset(100);

say $query;
# WITH ( SELECT id AS theater_id, name, city FROM venues
#   WHERE type = ? ) AS theaters
# SELECT id, first_name, last_name, gender, birthday, r.title,
#   r.date, t.name, t.city
# FROM actors a
# JOIN roles AS r ON r.actor_id = a.id
# JOIN theaters AS t USING ( theater_id )
# WHERE a.active AND a.age > ?
# ORDER BY a.birthday DESC, a.last_name
# LIMIT ? OFFSET ?
```

## Dialects

Create a builder for your database:

```perl
my $postgresql = Query::Builder->new(dialect => 'pg');
my $mysql = Query::Builder->new(dialect => 'mysql');
my $sqlite = Query::Builder->new(dialect => 'sqlite');
```

Dialect-aware behaviour:

- `compare()` with array values: `IN (?, ?)` on SQLite/MySQL, `= ANY(?)` on PostgreSQL
- `like()`: ILIKE by default on PostgreSQL, LIKE on others
- `is_true()` / `is_false()`: native TRUE/FALSE on PostgreSQL, `1`/`0` on MySQL/SQLite

All queries are parameterized — values are not interpolated into the SQL string. Use `$query->params()` to retrieve the parameter list.
