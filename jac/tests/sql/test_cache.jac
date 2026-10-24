"""Regression coverage for scope-sensitive validation memoization."""
import jaclang.sql as s;
import from unittest { TestCase }

test "SQL cache: immutable schemas are reused" {
    check = TestCase();
    a = s.select([s.named('n', s.int64(1))]);
    b = s.select([s.named('n', s.int64(2))]);
    union = s.union_all(a, b);
    assert a.ast.schema is a.ast.schema;
    assert union.ast.schema is union.ast.schema;
    with check.assertRaises(s.SqlError) {
        ast: any = a.ast;
        ast._schema_cache = s.Schema((s.FieldDef('wrong', s.DataType('text')), ));
    }
    s.compile_sql(union);
}

test "SQL cache: expression visibility is scoped" {
    check = TestCase();
    key = s.field('n', s.int64_type());
    source = s.table('numbers', [key]);
    expr = source.col(key).ast;
    validator = s.QueryValidator();
    validator.expr(expr, [source], [source], []);
    assert len(validator.expression_cache) == 1;
    validator.expr(expr, [source], [source], []);
    assert len(validator.expression_cache) == 1;
    with check.assertRaises(s.SqlError) {
        validator.expr(expr, [], [], []);
    }
    assert len(validator.expression_cache) == 1;
}

test "SQL cache: correlated query needs its outer scope" {
    check = TestCase();
    key = s.field('n', s.int64_type());
    source = s.table('numbers', [key]);
    query = s.select([s.named('n', source.col(key))]);
    validator = s.QueryValidator();
    validator.query(query.ast, [source], []);
    validator.query(query.ast, [source], []);
    assert len(validator.query_cache) == 1;
    with check.assertRaises(s.SqlError) {
        validator.query(query.ast, [], []);
    }
}

test "SQL cache: CTE visibility is scoped" {
    check = TestCase();
    key = s.field('n', s.int64_type());
    reference = s.cte(s.select([s.named('n', s.int64(1))]));
    query = s.select([s.named('n', reference.col(key))], source=reference);
    validator = s.QueryValidator();
    validator.query(query.ast, [], [reference]);
    with check.assertRaises(s.SqlError) {
        validator.query(query.ast, [], []);
    }
}

test "SQL cache: analyze clears previous results" {
    query = s.select([s.named('n', s.int64(1))]);
    validator = s.QueryValidator();
    validator.analyze(query);
    old_keys = set(validator.query_cache);
    next_query = s.select([s.named('n', s.int64(2))]);
    validator.analyze(next_query);
    assert not (old_keys & set(validator.query_cache));
}
