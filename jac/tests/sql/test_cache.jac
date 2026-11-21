"""Regression coverage for scope-sensitive validation memoization."""
import jaclang.sql as s;
import from unittest { TestCase }

test "SQL cache: schemas reflect AST edits between compilations" {
    a = s.select([s.named('n', s.int64(1))]);
    b = s.select([s.named('n', s.int64(2))]);
    union = s.union_all(a, b);
    s.compile_sql(union);
    replacement = s.select([s.named('renamed', s.int64(3))]);
    ast: any = a.ast;
    replacement_ast: any = replacement.ast;
    ast.projections = replacement_ast.projections;
    assert a.ast.schema.fields[0].name == 'renamed';
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


test "SQL cache: replay free CTE dependencies without rescanning structure" {
    import from unittest.mock { patch }
    c = s.cte(s.select([s.named('n', s.int64(1))]));
    body = s.select(s.project_all(c), source=c);
    local = s.with_ctes(body, [c]);
    scan = s.QueryGraph();
    with patch.object(scan, 'scan_query', wraps=scan.scan_query) as scanner {
        scan.visit_query(local.ast);
        assert not scan.ctes;
        scans = scanner.call_count;
        scan.visit_query(body.ast);
        assert scanner.call_count == scans;
        assert len(scan.ctes) == 1 and scan.ctes[0] is c;
    }
}

test "SQL constructors: typed operations skip duplicate signature analysis" {
    import from unittest.mock { patch }
    integer = s.int64(1);
    small = s.int32(1);
    numeric = s.numeric(1);
    floating = s.param(s.float64_type(), 1.0);
    truth = s.boolean(True);
    text = s.text('x');
    optional = s.param(s.nullable(s.int64_type()), None);
    maybe_bool = s.param(s.nullable(s.bool_type()), None);
    source = s.table('people', [s.field('n', s.int64_type())]);
    with patch.object(
        s, 'same_type', side_effect=AssertionError('constructor repeated type analysis')
    ), patch.object(
        s,
        '_aggregate_type',
        side_effect=AssertionError('constructor repeated aggregate analysis')
    ) {
        expression = s.add(integer, s.sub(integer, integer));
        s.eq_nullable(optional, optional);
        s.coalesce(optional, integer);
        s.is_null(optional);
        s.and_([truth, s.not_(truth)]);
        s.or_([truth]);
        s.and_nullable([truth, maybe_bool]);
        s.or_nullable([truth, maybe_bool]);
        s.not_nullable(maybe_bool);
        s.sum_(floating);
        s.sum_int32(small);
        s.sum_int64(integer);
        s.sum_numeric(numeric);
        s.bool_and(truth);
        s.bool_or(maybe_bool);
        s.string_agg(text, text);
        s.inner_join(source, truth);
        query = s.select([s.named('n', expression)], where=truth);
    }
    s.compile_sql(query);
}


test "SQL compilation: slot metadata and array parameters are snapshots" {
    check = TestCase();
    dtype = s.int64_type();
    variable = s.slot('n', dtype);
    query = s.select([s.named('n', variable)]);
    compiled = s.compile_sql(query);
    dtype.data.name = 'text';
    assert compiled.bind({'n': 3}).params['n'] == 3;
    with check.assertRaises(s.SqlError) {
        compiled.bind({'n': 'wrong'});
    }
    values: any = [1, 2];
    parameter = s.param(s.array_type(s.int64_type()), values);
    array_query = s.select([s.named('values', parameter)]);
    snapshot = s.compile_sql(array_query);
    values.append(3);
    assert list(snapshot.params.values())[0] == (1, 2);
    assert list(s.compile_sql(array_query).params.values())[0] == (1, 2, 3);
}


test "SQL diagnostics: schemas are reused only within one analysis" {
    import from unittest.mock { patch }
    check = TestCase();
    left = s.select([s.named('n', s.int64(1))]);
    right = s.select([s.named('n', s.int64(2))]);
    union = s.union_all(left, right);
    original_keys = set(union.ast.__dict__);
    with patch.object(s, '_merge_set_schema', wraps=s._merge_set_schema) as merge {
        s.QueryValidator().analyze(union);
        assert merge.call_count == 1;
        s.QueryValidator().analyze(union);
        assert merge.call_count == 2;
    }
    assert set(union.ast.__dict__) == original_keys;
    replacement = s.select([s.named('n', s.text('wrong'))]);
    ast: any = union.ast;
    setattr(ast, 'right', replacement.ast);
    with check.assertRaises(s.SqlError) {
        s.QueryValidator().analyze(union);
    }
}


test "SQL compilation: typed builders render without semantic analysis" {
    import from unittest.mock { patch }
    query = s.select(
        [s.named('n', s.add(s.int64(1), s.slot('increment', s.int64_type())))]
    );
    with patch.object(
        s.QueryValidator, 'analyze', side_effect=AssertionError('unexpected analysis')
    ), patch.object(
        s.QueryValidator,
        'expr_uncached',
        side_effect=AssertionError('unexpected expression checking')
    ) {
        compiled = s.compile_sql(query);
    }
    assert compiled.bind({'increment': 2}).params['increment'] == 2;
    assert ' + ' in compiled.sql;
}


test "SQL compilation: low-level AST typing is the caller contract" {
    query = s.select([s.named('n', s.int64(1))]);
    ast: any = query.ast;
    ast.projections[0].expr = s.text('abc').ast;
    compiled = s.compile_sql(query);
    assert 'text' in compiled.sql;
    assert list(compiled.params.values()) == ['abc'];
}


test "SQL columns: typed field access does not derive or search schemas" {
    import from unittest.mock { patch }
    key = s.field('n', s.int64_type());
    a = s.select([s.named('n', s.int64(1))]);
    b = s.select([s.named('n', s.int64(2))]);
    source = s.union_all(a, b).as_source();
    with patch.object(
        s.Schema, 'find', side_effect=AssertionError('unexpected field lookup')
    ), patch.object(
        s, '_set_schema', side_effect=AssertionError('unexpected schema derivation')
    ) {
        column = source.col(key);
    }
    assert column.ast.dtype is key.dtype;
    column_ast: any = column.ast;
    assert column_ast.name == 'n';
    assert column_ast.source is source;
    s.compile_sql(s.select([s.named('n', column)], source=source));
}
