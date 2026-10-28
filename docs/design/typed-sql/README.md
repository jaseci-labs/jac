# Typed SQL module

`jaclang.sql` represents PostgreSQL queries as typed structural values.
`compile_sql(query_or_command)` plans and renders SQL plus named parameter bindings.
The portable module consists of [`sql.jac`](../../../jac/jaclang/sql.jac) and
[`impl/sql.impl.jac`](../../../jac/jaclang/impl/sql.impl.jac). Its imports are the
standard-library UUID and Decimal types. Forks can copy both files and the tests.

## Query categories

| Category | Meaning |
| --- | --- |
| `ScalarExpr[T]` | One SQL value |
| `Relation[R, C]` | Rows with a schema and cardinality proof |
| `Source` | A table, derived query, CTE or table-function binding |
| `Command` | INSERT, UPDATE, DELETE and schema-changing statements |

SELECT is a relational expression. Scalar-subquery conversion is explicit:
`scalar` accepts an at-most-one or exactly-one, single-column relation and returns
a nullable value; `scalar_one` preserves the type of a proven exactly-one result.
`limit_one` constructs the first proof while preserving the SELECT clauses,
including DISTINCT and DISTINCT ON; `aggregate` constructs the second.
The explicit diagnostic analyzer can verify these proofs against query structure.

Typed `Field[T]` keys identify columns. `source.col(key)` creates a column reference
directly from the key's name and SQL type without deriving or searching the source
schema. Callers supply keys matching their source; explicit diagnostics can check
that correspondence. Jac's static checker checks expression
categories and typed arguments. Builders retain local value constraints such as
integer bounds, nonempty operands, and supported operations. `compile_sql` plans
CTE definitions and generated names, renders SQL, and collects parameters. It
trusts the typed builder contract instead of running whole-query semantic analysis.
Dynamic SQL semantics such as grouping and visibility are checked by PostgreSQL.
Internal callers can explicitly run `QueryValidator().analyze(query)` for detailed
AST diagnostics. Direct AST edits and `Any` can bypass the static contract.

Sort builders accept only empty, FIRST or LAST null positioning. `aggregate`
requires a grouping aggregate in its SELECT expressions before assigning ExactlyOne;
subquery-only aggregates and plain windows do not establish that row-count contract.

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
scalar element contract and snapshot parameter sequences as tuples. Scalar-to-array
casts are rejected because SQL array text can contain NULL elements; use typed
array constructors or parameters. Physical table
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
Table functions receive the preceding-source scope implicitly. Explicit diagnostics check
JOIN visibility sequentially and propagates outer dependencies to enclosing
queries. GROUP BY coverage checks local columns while retaining those outer
references for the enclosing query's checks.

`ordered(query, [asc(output(key))])` orders a set result by its typed output columns.
Explicit diagnostics check DISTINCT ON leading ORDER BY keys, including permitted permutations.

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
A shared query can be used both inside a local WITH and through automatic CTE
binding elsewhere. The compiler preserves both binding scopes; duplicate explicit
bindings within one WITH are rejected by structural planning. Explicit diagnostics
also check nested binding visibility.

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

Recursive definitions use UNION or UNION ALL. The explicit diagnostic analyzer checks the anchor,
compatible output schemas and exactly one structural self-reference in the step.
That reference can occur through derived queries or a local CTE definition.
Windows and local deduplication/budget stages retain their own query regions.
Ordinary grouping aggregates may feed window arguments, partition keys and order
keys; their grouping and row-count facts propagate to the enclosing SELECT.
Direct recursive aggregation, scalar-subquery self-reference and references on
an outer join's nullable side are rejected by explicit diagnostics. Recursive termination follows the
query predicate. Parenthesized wrappers preserve arm-local ordering and limits.

### Runnable directory traversal

The complete [recursive directory example](recursive_directory.jac)
creates seven fixed directory/file nodes and runs the generated query in SQLite's
in-memory database. It needs no database server or extra dependencies. From the
repository root:

```sh
jac run docs/design/typed-sql/recursive_directory.jac
```

The selected root is bound through `slot('root_id', int64_type())`. The anchor
selects that root; the recursive step joins each directory to its children and
extends their path and depth. `define_cte(..., recursive=True)` connects both arms.

```text
project/
├── README.md
└── src/
    ├── lib/
    │   └── helper.jac
    └── main.jac
unrelated.txt
```

The program prints the SQL, bound parameters, expected rows and actual rows, then
asserts that both row lists match. The result contains six rows under `project`,
including depth 0 for the root and depth 3 for `project/src/lib/helper.jac`.
`unrelated.txt` belongs to a different root and is excluded.

## Compilation and AST lifetime

1. `QueryGraph` collects structural dependencies, parameter slots, source bindings
   and local WITH wrappers. Shared structural summaries are reused per compilation.
2. `QueryPlanner` orders CTE definitions and assigns generated names in a rendering plan.
3. `PostgresRenderer` emits SQL text and bound parameters. A compile-local schema
   dictionary supplies output column names where SQL rendering needs them.

`compile_sql` does not call `QueryValidator`, infer every expression's type, or
compute scope/grouping facts. The existing diagnostic analyzer remains available
for explicit checks and malformed-AST regression coverage.

AST values can be edited between compilations. Each compilation produces independent
SQL text, parameter values and slot metadata. No AST or schema cache is retained in
`CompiledSQL`. Compile again to use AST edits. All dependency and schema caches are
local to one compilation. Recursive CTE definitions use single-assignment binding.

## Verification

The suite contains 176 native Jac test entries: 58 SQLite cases, the same
58 PostgreSQL cases, 43 PostgreSQL feature cases, five static-check tests and
twelve builder/cache regression tests.
The static fixtures verify all 52 invalid calls at their expected source lines;
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
diagnostics and module portability under a different name.

PostgreSQL semantics references: [WITH queries](https://www.postgresql.org/docs/current/queries-with.html),
[table expressions](https://www.postgresql.org/docs/current/queries-table-expressions.html),
and [aggregate functions](https://www.postgresql.org/docs/current/functions-aggregate.html).

## Explicit diagnostics

`QueryValidator().analyze(query)` performs optional type, visibility, grouping and
recursive-placement analysis. Its scope-sensitive caches reset for each analysis.
Tests for intentionally malformed low-level ASTs invoke this diagnostic path
explicitly. Positive execution tests use the lightweight `compile_sql` path.

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

## Write statements and schema changes

`Command` is separate from a row-producing `Relation`. Compile statements with
`compile_command(command)` or `compile_sql(command)`. Both return `CompiledSQL`;
write predicates, values and RETURNING expressions use the same parameter collector,
named slots and `bind` implementation as queries. A command with RETURNING remains
an executable statement, rather than an implicit scalar or FROM source.

```jac
import from jaclang.sql {
    field, int64_type, text_type, table, slot, int64, named,
    insert_into, assign, update, delete_from, eq, compile_command
}
with entry {
    id = field("id", int64_type());
    name = field("name", text_type());
    people = table("people", [id, name]);
    new_name = slot("new_name", text_type());
    command = insert_into(
        people, [id, name], [[int64(1).ast, new_name.ast]],
        returning=[named("id", people.col(id))]
    );
    template = compile_command(command);
    print(template.sql);
    print(template.bind({"new_name": "Alice"}).params);

    change = update(
        people, [assign(name, new_name)],
        where=eq(people.col(id), int64(1))
    );
    print(compile_command(change).sql);
    print(compile_command(delete_from(people, where=eq(people.col(id), int64(1)))).sql);
}
```

| Operation | Builders |
| --- | --- |
| Insert | `insert_into` (one or more rows), `insert_select`, `insert_default` |
| Update/delete | `update`, `delete_from`; optional WHERE and RETURNING |
| Define table | `create_table`, `column_def`; field nullability, PRIMARY KEY, UNIQUE, IF NOT EXISTS |
| Define index | `create_index`; multi-column, UNIQUE, IF NOT EXISTS |
| Remove table/index | `drop_table`, `drop_index`; IF EXISTS, CASCADE |
| Change table | `add_column`, `drop_column`, `rename_column`, `rename_table` |
| Clear tables | `truncate_tables`; RESTART IDENTITY, CASCADE |

`assign(Field[T], ScalarExpr[T])` checks assignment types through the static API.
Heterogeneous INSERT rows contain expression AST nodes, like the existing VALUES
builder; callers match their declared columns and SQL types. Builders reject empty
row sets, mismatched row widths, duplicate columns and non-table write targets.
Omitting WHERE updates or deletes all rows, following SQL semantics.

INSERT SELECT and write-expression subqueries discover automatic CTE dependencies;
explicit `with_ctes` scopes on an input query remain local to that query. Identifiers
are quoted, and runtime values are bound parameters. Schema-changing statements
render their structural column/type definitions directly. Execute statements and
manage transactions through the database connection API.

Run statement tests, including execution against a disposable PostgreSQL cluster:

```sh
JAC_SQL_PG_SOCKET=/path/to/.s.PGSQL.PORT jac test jac/tests/sql/test_commands.jac -j 1
```
