# Typed SQL module

`jaclang.sql` represents PostgreSQL queries as immutable, typed structural values.
`compile_sql(query)` analyzes a query and returns SQL plus named parameter bindings.
The portable module consists of [`sql.jac`](../../../jac/jaclang/sql.jac) and
[`impl/sql.impl.jac`](../../../jac/jaclang/impl/sql.impl.jac). Its imports are the
standard-library UUID and Decimal types. Forks can copy both files and the tests.

## Query categories

| Category | Meaning |
| --- | --- |
| `ScalarExpr[T]` | One SQL value |
| `Relation[R, C]` | Rows with a schema and cardinality proof |
| `Source` | A table, derived query, CTE or table-function binding |
| `Command` | Category reserved for data-changing statements |

SELECT is a relational expression. Scalar-subquery conversion is explicit:
`scalar` accepts an at-most-one or exactly-one, single-column relation and returns
a nullable value; `scalar_one` preserves the type of a proven exactly-one result.
`limit_one` constructs the first proof and `aggregate` constructs the second.
The analyzer verifies these proofs against query structure.

Typed `Field[T]` keys identify columns. Row shape is a checked `Schema` value;
column lookup checks names, SQL types and nullability. Jac checks expression
categories and typed arguments; query analysis checks dynamic row shape and scope.

## Construction example

```jac
import from jaclang.sql {
    field, int64_type, text_type, table, named, select, gt, int64, compile_sql
}
with entry {
    name = field("name", text_type());
    age = field("age", int64_type());
    people = table("people", [name, age]);
    query = select(
        [named("name", people.col(name))],
        source=people,
        where=gt(people.col(age), int64(30))
    );
    compiled = compile_sql(query);
    print(compiled.sql);
    print(compiled.params);
}
```

Representative output:

```sql
SELECT "_t0"."name" AS "name"
FROM "people" AS "_t0"
WHERE ("_t0"."age" > CAST(:p0 AS bigint))
```

Parameters: `{"p0": 30}`. Identifiers are quoted and values have separate bindings.
Reusing a parameter expression reuses its binding. Casts retain declared SQL types
in standalone values, VALUES rows and recursive anchors.

## Supported structures

| Area | Constructors and behavior |
| --- | --- |
| Types | Bool, Int32, Int64, Numeric, Float64, Text, UUID, `Nullable[T]`, one-dimensional `SqlArray[T]` |
| Predicates | Equality/order comparisons, IN, AND/OR/NOT, null tests and explicitly nullable boolean operations |
| Arithmetic | Int32/Int64 addition/subtraction; Numeric addition/subtraction; typed casts |
| Conditional/string expressions | `case_`, `case_nullable`, `concat`, `text_concat`, `lpad`, `coalesce` |
| Arrays | Typed literals, validated array parameters, concatenation, append and `any_eq` |
| Sources | Tables, derived queries, VALUES, `unnest` with optional ordinality |
| Joins | INNER, LEFT, CROSS; LATERAL derived sources and implicitly lateral table functions |
| Selection | Projection, column GROUP BY, HAVING, ordering, NULLS FIRST/LAST and limits |
| Sets | DISTINCT, DISTINCT ON, UNION/UNION ALL, EXCEPT/EXCEPT ALL, INTERSECT/INTERSECT ALL |
| Aggregates | COUNT(*), SUM for supported numeric types, BOOL_AND, BOOL_OR and distinct/non-distinct STRING_AGG |
| Windows | ROW_NUMBER, DENSE_RANK, aggregate OVER, PARTITION BY, ORDER BY and ROWS BETWEEN frames |
| CTEs | Automatic dependency collection, explicit lexical scopes, MATERIALIZED/NOT MATERIALIZED and recursion |

Numeric values use Decimal or integers. SUM follows PostgreSQL result types:
`sum_int32` returns nullable Int64; `sum_int64` and `sum_numeric` return nullable
Numeric; `sum_` returns nullable Float64. Array constructors validate a non-null
scalar element contract and snapshot parameter sequences as tuples. Physical table
schemas are contracts supplied by the integrating application.

`case_` requires identical branch types; `case_nullable` joins nullable and
non-null branches of one SQL type. Set outputs derive names from the left arm:
UNION combines nullability, EXCEPT retains the left contract, and INTERSECT
can produce NULL only when both inputs permit it. VALUES accepts a non-null
expression in a declared nullable column.

## Joins and source bindings

`source.ref()` creates an independent binding for self-joins. `project_all(source)`
constructs explicit typed projections for all fields in that binding.

A LEFT JOIN uses `optional_source(source)`. Its schema marks every output column
nullable, so callers read it using nullable field keys:

```jac
pets = optional_source(pets_table);
maybe_owner = field("owner_id", nullable(int64_type()));
joined = select(
    [named("owner", pets.col(maybe_owner))],
    source=people,
    joins=[left_join(pets, compare_nullable(people.col(person_id), pets.col(maybe_owner)))]
);
```

`query.as_source(lateral=True)` can reference preceding sources in its enclosing
FROM/JOIN sequence. An ordinary derived source can refer to ancestor query scopes.
Table functions receive the preceding-source scope implicitly. Analysis checks
JOIN visibility sequentially and propagates outer dependencies to enclosing
queries. GROUP BY coverage checks local columns while retaining those outer
references for the enclosing query's checks.

`ordered(query, [asc(output(key))])` orders a set result by its typed output columns.
DISTINCT ON checks leading ORDER BY keys, including permitted permutations.

An empty `in_(term, [])` renders membership in a typed empty subquery, retaining
`term` in the SQL. Aggregates and windows inside that term preserve the SELECT's
row-count and grouping semantics. Correlated VALUES rows use their supplied outer
scope and propagate dependencies for enclosing GROUP BY checks.

## CTE scopes and recursion

`cte(query)` creates a reusable reference. Compilation collects reachable definitions,
orders dependencies and assigns SQL names. Generated names avoid physical table
names and explicit table aliases throughout the query. Sources read the schema
of their defining query or CTE target.

Use `with_ctes(body, [references...])` to bind definitions at a specific query scope.
This retains local CTEs inside a recursive step or correlated subquery. Local
bindings can reference enclosing CTEs and visible outer columns. `cte(query,
materialized=True)` and `materialized=False` select PostgreSQL materialization
attributes. Consecutive local WITH wrappers are normalized at rendering.

Recursion has an explicit single-assignment forward reference:

```jac
walk = cte_ref([key]);
frontier = cte(
    select([named("n", walk.col(key))], source=walk,
        where=lt(walk.col(key), int64(4))),
    materialized=True
);
step = with_ctes(
    select([named("n", add(frontier.col(key), int64(1)))], source=frontier),
    [frontier]
);
define_cte(walk, union_all(anchor, step), recursive=True);
```

Recursive definitions use UNION or UNION ALL. The analyzer checks the anchor,
compatible output schemas and exactly one structural self-reference in the step.
That reference can occur through derived queries or a local CTE definition.
Windows and local deduplication/budget stages retain their own query regions.
Ordinary grouping aggregates may feed window arguments, partition keys and order
keys; their grouping and row-count facts propagate to the enclosing SELECT.
Direct recursive aggregation, scalar-subquery self-reference and references on
an outer join's nullable side are rejected. Recursive termination follows the
query predicate. Parenthesized wrappers preserve arm-local ordering and limits.

## Compilation and immutability

1. `QueryGraph` traverses structural containment and queues automatic CTE references.
   Explicit local bindings stay inside their lexical query scope.
2. `QueryValidator` checks expression signatures, types, scope, grouping, windows,
   cardinality and recursive-reference placement. It resolves generated names and
   returns a `ValidatedQuery` plan.
3. `PostgresRenderer` serializes that plan and assigns parameter bindings.

Query values, expressions, schemas and field definitions reject reassignment and
deletion. Nested sequence inputs are copied into tuples. Rebuild a query to change
it. SELECT schema derives from projections; set schemas derive from their arms;
source bindings read their targets. Recursive CTEs close through one-time binding.
Low-level AST construction receives the same semantic analysis as public builders.

## Verification

The suite contains 160 native Jac test entries: 56 SQLite cases, the same
56 PostgreSQL cases, 39 PostgreSQL feature cases, four static-check tests and
five cache regression tests.
The static fixtures verify all 31 invalid calls at their expected source lines;
positive checking covers the module and a valid-call fixture.

```sh
jac test jac/tests/sql/test_sql.jac jac/tests/sql/test_types.jac jac/tests/sql/test_cache.jac -j 1 -v
JAC_SQL_PG_SOCKET=/path/to/.s.PGSQL.PORT \
  jac test jac/tests/sql/test_postgres.jac jac/tests/sql/test_postgres_features.jac -j 1 -v
jac fmt --check --lintfix jac/jaclang/sql.jac \
  jac/jaclang/impl/sql.impl.jac jac/tests/sql/*.jac
```

PostgreSQL fixtures use a disposable cluster, account `sql_test`, database
`postgres`, and transaction-local tables rolled back after each test. Coverage
includes combined recursive frontier/dedup/window queries, nullable parent columns,
multiple recursive CTEs, standalone step reuse, parameter quoting, scope/type
rejections and module portability under a different name.

PostgreSQL semantics references: [WITH queries](https://www.postgresql.org/docs/current/queries-with.html),
[table expressions](https://www.postgresql.org/docs/current/queries-table-expressions.html),
and [aggregate functions](https://www.postgresql.org/docs/current/functions-aggregate.html).

## Validation reuse

Immutable SELECT and set-operation nodes retain their derived schemas. Within
one compilation, validation results are reused only for the same ordered source
and CTE scopes. Caches reset for each compilation; scope, projection, recursive
union and parameter checks remain enforced.

## Compile once and bind values

Use `slot(name, dtype)` for a named parameter without an initial value:

```jac
min_age = slot('min_age', int64_type());
compiled = compile_sql(select(
    [named('name', people.col(name))], source=people,
    where=gt(people.col(age), min_age)
));
first = compiled.bind({'min_age': 18});
second = compiled.bind({'min_age': 30});
```

Pass `first.sql` and `first.params` to the database driver. `CompiledSQL` keeps
SQL text, fixed parameter values and a tuple of slot names/types. It retains no
AST. `bind` checks exact parameter names and value types, copies the fixed
parameters and returns a new `CompiledSQL`; the original remains reusable.
Repeated names share a parameter and must have identical types. Names use ASCII
letters, digits and underscores, starting with a letter or underscore.
`sql` and `self` are reserved by the PostgreSQL driver calling convention. Generated
literal parameter names avoid collisions with slots. Text values are bound by
the driver, including strings containing SQL syntax.
