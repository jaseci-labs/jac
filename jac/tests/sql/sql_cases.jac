"""Behavioral contracts for the portable Jac SQL package (stdlib unittest/sqlite3)."""
import sqlite3;
import importlib;
import from pathlib { Path }
import sys;
import from tempfile { TemporaryDirectory }
import unittest;
import from uuid { UUID }
import jaclang.sql as sql;
glob s: any = sql;
# Explicit diagnostic coverage for malformed low-level ASTs and dynamic misuse.
# Normal execution tests use compile_sql directly.
def _checked_sql(query: any) -> any {
    s.QueryValidator().analyze(query);
    return s.compile_sql(query);
}

class SQLTests(unittest.TestCase) {
    def setUp(self: SQLTests) -> object {
        self.id = s.field('id', s.int64_type());
        self.age = s.field('age', s.int64_type());
        self.name = s.field('name', s.text_type());
        self.people = s.table('people', [self.id, self.age, self.name], 'p');
        self.db = sqlite3.connect(':memory:');
        self.db.executescript(
            'CREATE TABLE people(id INTEGER, age INTEGER, name TEXT);'
            "INSERT INTO people VALUES(1,20,'Ann'),(2,40,'Bob'),(3,40,'Cora');"
        );
        self.addCleanup(self.db.close);
    }

    def execute(self: SQLTests, query: any) -> object {
        c = s.compile_sql(query);
        return self.db.execute(c.sql, c.params).fetchall();
    }

    def test_module_is_portable_with_implementation(self: SQLTests) -> object {
        with TemporaryDirectory(prefix='jac-sql-portable-') as folder {
            module = Path(folder) / 'portable_sql.jac';
            original = Path(s.__file__);
            module.write_text(original.read_text());
            implementation = Path(folder) / 'impl';
            implementation.mkdir();
            (implementation / 'portable_sql.impl.jac').write_text(
                (original.parent / 'impl' / 'sql.impl.jac').read_text()
            );
            sys.path.insert(0, folder);
            try {
                independent = importlib.import_module('portable_sql');
                query = independent.select(
                    [independent.named('n', independent.int64(7))]
                );
                compiled = independent.compile_sql(query);
                self.assertEqual(
                    self.db.execute(compiled.sql, compiled.params).fetchone(), (7, )
                );
            } finally {
                sys.path.remove(folder);
                sys.modules.pop('portable_sql', None);
            }
        }
    }

    def test_sort_options_are_closed(self: SQLTests) -> object {
        for make_order in [s.asc, s.desc] {
            for invalid in [
                'LAST, (SELECT 1)',
                'FIRST; SELECT 1',
                'last',
                'NULLS LAST'
            ] {
                with self.subTest(invalid=invalid), self.assertRaises(s.SqlError) {
                    make_order(s.int64(1), nulls=invalid);
                }
            }
            for valid in ['', 'FIRST', 'LAST'] {
                query = s.select(
                    [s.named('n', s.int64(1))],
                    order_by=[make_order(s.int64(1), nulls=valid)]
                );
                compiled = s.compile_sql(query);
                self.assertIn(
                    (' NULLS ' + valid) if valid else 'ORDER BY', compiled.sql
                );
                self.assertEqual(self.execute(query), [(1, )]);
            }
        }
    }

    def test_exactly_one_is_checked_at_construction(self: SQLTests) -> object {
        inner = s.aggregate([s.named('n', s.count())], source=self.people);
        nested = s.scalar_one(inner, s.field('n', s.int64_type()));
        window = s.row_number(order_by=[s.asc(s.int64(1))]);
        for empty in [False, True] {
            if empty {
                self.db.execute('DELETE FROM people');
            }
            for term in [
                s.int64(1),
                self.people.col(self.age),
                nested,
                s.exists(inner),
                window
            ] {
                with self.subTest(empty=empty), self.assertRaises(s.SqlError) {
                    s.aggregate([s.named('n', term)], source=self.people);
                }
            }
            expression = s.add(s.count(), s.int64(1));
            query = s.aggregate(
                [s.named('n', expression)], source=self.people, where=s.boolean(False)
            );
            scalar = s.scalar_one(query, s.field('n', s.int64_type()));
            self.assertEqual(self.execute(s.select([s.named('n', scalar)])), [(1, )]);
            count = s.scalar_one(inner, s.field('n', s.int64_type()));
            self.assertEqual(
                self.execute(s.select([s.named('n', count)])), [(0 if empty else 3, )]
            );
        }
    }

    def test_select_parameters_and_order(self: SQLTests) -> object {
        q = s.select(
            [s.named('name', self.people.col(self.name))],
            source=self.people,
            where=s.gt(self.people.col(self.age), s.int64(30)),
            order_by=[s.desc(self.people.col(self.name))]
        );
        self.assertEqual(self.execute(q), [('Cora', ), ('Bob', )]);
        c = s.compile_sql(q);
        self.assertEqual(c.params, {'p0': 30});
        self.assertIn(':p0', c.sql);
    }

    def test_join_and_shared_parameter(self: SQLTests) -> object {
        age = self.people.col(self.age);
        p = s.int64(30);
        q = s.select(
            [s.named('plus', s.add(age, p))], source=self.people, where=s.gt(age, p)
        );
        self.assertEqual(self.execute(q), [(70, ), (70, )]);
        self.assertEqual(s.compile_sql(q).params, {'p0': 30});
        owner = s.field('owner', s.int64_type());
        pets = s.table('pets', [owner], 'pet');
        self.db.executescript(
            'CREATE TABLE pets(owner INTEGER); INSERT INTO pets VALUES(2),(2);'
        );
        join = s.inner_join(pets, s.eq(self.people.col(self.id), pets.col(owner)));
        q = s.select(
            [s.named('name', self.people.col(self.name))],
            source=self.people,
            joins=[join]
        );
        self.assertEqual(self.execute(q), [('Bob', ), ('Bob', )]);
    }

    def test_group_by_count(self: SQLTests) -> object {
        key = self.people.col(self.age);
        q = s.select(
            [s.named('age', key), s.named('n', s.count())],
            source=self.people,
            group_by=[key.ast],
            order_by=[s.asc(key)]
        );
        self.assertEqual(self.execute(q), [(20, 1), (40, 2)]);
    }

    def test_aggregate_empty_is_one_row(self: SQLTests) -> object {
        result = s.named('n', s.count());
        q = s.aggregate(
            [result],
            source=self.people,
            where=s.gt(self.people.col(self.age), s.int64(100))
        );
        value = s.scalar_one(q, result.key());
        self.assertEqual(self.execute(s.select([s.named('n', value)])), [(0, )]);
    }

    def test_scalar_optional_empty_yields_null(self: SQLTests) -> object {
        result = s.named('age', self.people.col(self.age));
        q = s.limit_one(
            s.select(
                [result],
                source=self.people,
                where=s.gt(self.people.col(self.age), s.int64(100))
            )
        );
        value = s.scalar(q, result.key());
        self.assertEqual(self.execute(s.select([s.named('age', value)])), [(None, )]);
    }

    def test_scalar_requires_proof_and_one_column(self: SQLTests) -> object {
        result = s.named('age', self.people.col(self.age));
        q = s.select([result], source=self.people);
        with self.assertRaisesRegex(s.SqlError, 'at-most-one') {
            s.scalar(q, result.key());
        }
        q = s.limit_one(
            s.select(
                [result, s.named('name', self.people.col(self.name))],
                source=self.people
            )
        );
        with self.assertRaises(s.SqlError) {
            s.scalar(q, result.key());
        }
    }

    def test_correlated_exists(self: SQLTests) -> object {
        other = s.table('people', [self.id, self.age, self.name], 'other');
        sub = s.select(
            [s.named('id', other.col(self.id))],
            source=other,
            where=s.and_(
                [
                    s.eq(other.col(self.id), self.people.col(self.id)),
                    s.gt(other.col(self.age), s.int64(30))
                ]
            )
        );
        q = s.select(
            [s.named('name', self.people.col(self.name))],
            source=self.people,
            where=s.exists(sub)
        );
        self.assertEqual(self.execute(q), [('Bob', ), ('Cora', )]);
    }

    def test_derived_schema_and_scope(self: SQLTests) -> object {
        out = s.named('label', self.people.col(self.name));
        source = s.select([out], source=self.people).as_source();
        self.assertEqual(
            self.execute(
                s.select([s.named('label', source.col(out.key()))], source=source)
            ),
            [('Ann', ), ('Bob', ), ('Cora', )]
        );
        with self.assertRaisesRegex(s.SqlError, 'Unknown column') {
            _checked_sql(
                s.select([s.named('age', source.col(self.age))], source=source)
            );
        }
        with self.assertRaisesRegex(s.SqlError, 'outside scope') {
            _checked_sql(s.select([s.named('name', self.people.col(self.name))]));
        }
    }

    def test_union_schema_and_arm_limits(self: SQLTests) -> object {
        first = s.select([s.named('n', s.int64(1))], limit=1);
        second = s.select([s.named('m', s.int64(2))], limit=1);
        self.assertEqual(self.execute(s.union_all(first, second)), [(1, ), (2, )]);
        with self.assertRaisesRegex(s.SqlError, 'UNION') {
            s.union_all(first, s.select([s.named('n', s.text('bad'))]));
        }
    }

    def test_cte(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        ref = s.cte(s.select([s.named('n', s.int64(7))]));
        body = s.select([s.named('n', ref.col(key))], source=ref);
        self.assertEqual(self.execute(body), [(7, )]);
        missing = s.cte_ref([key]);
        with self.assertRaisesRegex(s.SqlError, 'no definition') {
            _checked_sql(s.select([s.named('n', missing.col(key))], source=missing));
        }
    }

    def test_recursive_cte(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        ref = s.cte_ref([key]);
        first = s.select([s.named('n', s.int64(1))]);
        step = s.select(
            [s.named('n', s.add(ref.col(key), s.int64(1)))],
            source=ref,
            where=s.gt(s.int64(4), ref.col(key))
        );
        s.define_cte(ref, s.union_all(first, step), recursive=True);
        body = s.select(
            [s.named('n', ref.col(key))], source=ref, order_by=[s.asc(ref.col(key))]
        );
        self.assertEqual(self.execute(body), [(1, ), (2, ), (3, ), (4, )]);
    }

    def test_edited_recursive_union_is_checked(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        ref = s.cte_ref([key]);
        anchor = s.select([s.named('n', s.int64(1))]);
        step = s.select(
            [s.named('n', s.add(ref.col(key), s.int64(1)))],
            source=ref,
            where=s.gt(s.int64(3), ref.col(key))
        );
        combined = s.union_all(anchor, step);
        s.define_cte(ref, combined, recursive=True);
        replacement = s.select([s.named('n', s.text('abc'))], source=ref);
        combined.ast.right = replacement.ast;
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('n', ref.col(key))], source=ref));
        }
        combined.ast.right = step.ast;
        body = s.select(
            [s.named('n', ref.col(key))], source=ref, order_by=[s.asc(ref.col(key))]
        );
        self.assertEqual(self.execute(body), [(1, ), (2, ), (3, )]);
        invalid = s.Relation(
            s.UnionNode(
                cardinality='many',
                left=anchor.ast,
                right=replacement.ast,
                keep_duplicates=True
            )
        );
        bad = s.cte_ref([key]);
        with self.assertRaisesRegex(s.SqlError, 'UNION schema/cardinality mismatch') {
            s.define_cte(bad, invalid, recursive=True);
            _checked_sql(s.select([s.named('n', bad.col(key))], source=bad));
        }
    }

    def _assert_recursive_anchor(self: SQLTests, first: any, expected: any) -> object {
        key = s.field('n', s.int64_type());
        ref = s.cte_ref([key]);
        step = s.select(
            [s.named('n', s.add(ref.col(key), s.int64(1)))],
            source=ref,
            where=s.gt(s.int64(4), ref.col(key))
        );
        s.define_cte(ref, s.union_all(first, step), recursive=True);
        body = s.select(
            [s.named('n', ref.col(key))], source=ref, order_by=[s.asc(ref.col(key))]
        );
        self.assertEqual(self.execute(body), expected);
    }

    def test_recursive_anchor_limit(self: SQLTests) -> object {
        first = s.select([s.named('n', s.int64(1))], limit=1);
        self._assert_recursive_anchor(first, [(1, ), (2, ), (3, ), (4, )]);
    }

    def test_recursive_anchor_order(self: SQLTests) -> object {
        first = s.select(
            [s.named('n', self.people.col(self.id))],
            source=self.people,
            order_by=[s.desc(self.people.col(self.id))]
        );
        self._assert_recursive_anchor(
            first, [(1, ), (2, ), (2, ), (3, ), (3, ), (3, ), (4, ), (4, ), (4, )]
        );
    }

    def test_recursive_anchor_order_limit(self: SQLTests) -> object {
        first = s.select(
            [s.named('n', self.people.col(self.id))],
            source=self.people,
            order_by=[s.desc(self.people.col(self.id))],
            limit=1
        );
        self._assert_recursive_anchor(first, [(3, ), (4, )]);
    }

    def test_cte_dependencies_and_recursive_anchor_validation(
        self: SQLTests
    ) -> object {
        key = s.field('n', s.int64_type());
        a = s.cte_ref([key]);
        b = s.cte_ref([key]);
        s.define_cte(a, s.select([s.named('n', b.col(key))], source=b));
        s.define_cte(b, s.select([s.named('n', s.int64(1))]));
        body = s.select([s.named('n', a.col(key))], source=a);
        self.assertEqual(self.execute(body), [(1, )]);
        bad = s.cte_ref([key]);
        bad_body = s.select([s.named('n', bad.col(key))], source=bad);
        s.define_cte(bad, s.union_all(bad_body, bad_body), recursive=True);
        with self.assertRaises(s.SqlError) {
            _checked_sql(bad_body);
        }
    }

    def test_recursive_step_eligibility(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        for mode in [0, 1] {
            ref = s.cte_ref([key]);
            anchor = s.select([s.named('n', s.int64(1))]);
            if mode == 0 {
                step = s.select([s.named('n', s.int64(2))]);
            } else {
                step = s.select([s.named('n', s.count())], source=ref);
            }
            s.define_cte(ref, s.union_all(anchor, step), recursive=True);
            body = s.select([s.named('n', ref.col(key))], source=ref);
            with self.subTest(mode=mode), self.assertRaises(s.SqlError) {
                _checked_sql(body);
            }
        }
    }

    def test_nullable_three_valued_predicate(self: SQLTests) -> object {
        value = s.param(s.nullable(s.int64_type()), None);
        comparison = s.eq_nullable(value, s.param(s.nullable(s.int64_type()), 3));
        self.assertEqual(
            self.execute(s.select([s.named('n', s.int64(1))], where=comparison)), []
        );
        self.assertEqual(
            self.execute(s.select([s.named('n', s.coalesce(value, s.int64(5)))])),
            [(5, )]
        );
        self.assertEqual(
            self.execute(s.select([s.named('missing', s.is_null(value))])), [(1, )]
        );
        with self.assertRaises(s.SqlError) {
            s.eq(value, value);
        }
    }

    def test_parameter_value_type_and_bounds(self: SQLTests) -> object {
        for (dtype, value) in [
            (s.int64_type(), True),
            (s.int64_type(), '1'),
            (s.bool_type(), 1),
            (s.text_type(), 4),
            (s.int64_type(), (2 ** 63)),
            (s.int64_type(), (-(2 ** 63) - 1)),
            (s.uuid_type(), 'bad'),
            (s.int64_type(), None)
        ] {
            with self.subTest(value=value), self.assertRaises(s.SqlError) {
                s.param(dtype, value);
            }
        }
        c = s.compile_sql(s.select([s.named('id', s.uuid(UUID(int=1)))]));
        self.assertEqual(c.params['p0'], UUID(int=1));
        s.int64(-(2 ** 63));
        s.int64(((2 ** 63) - 1));
    }

    def test_injection_is_bound_and_identifiers_are_quoted(self: SQLTests) -> object {
        evil = "x'); DROP TABLE people; --";
        c = s.compile_sql(s.select([s.named('weird"name', s.text(evil))]));
        self.assertNotIn(evil, c.sql);
        self.assertEqual(c.params, {'p0': evil});
        self.assertIn('"weird""name"', c.sql);
        self.assertEqual(self.db.execute(c.sql, c.params).fetchone(), (evil, ));
        with self.assertRaises(s.SqlError) {
            s.quote_identifier('bad\x00name');
        }
    }

    def test_wrong_expression_categories_and_types(self: SQLTests) -> object {
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('bad', s.eq(s.int64(1), s.text('a')))]));
        }
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('bad', s.add(s.text('a'), s.text('b')))]));
        }
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('bad', s.and_([s.int64(1)]))]));
        }
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('n', s.int64(1))], where=s.int64(1)));
        }
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.int64(1));
        }
    }

    def test_alias_and_join_scopes(self: SQLTests) -> object {
        other = s.table('people', [self.id, self.age, self.name], 'p');
        join = s.inner_join(other, s.eq(self.people.col(self.id), other.col(self.id)));
        q = s.select(
            [s.named('n', self.people.col(self.id))], source=self.people, joins=[join]
        );
        with self.assertRaisesRegex(s.SqlError, 'Duplicate') {
            _checked_sql(q);
        }
        future = s.table('people', [self.id], 'future');
        other = s.table('people', [self.id], 'o');
        bad = s.inner_join(other, s.eq(other.col(self.id), future.col(self.id)));
        q = s.select(
            [s.named('n', self.people.col(self.id))], source=self.people, joins=[bad]
        );
        with self.assertRaisesRegex(s.SqlError, 'outside scope') {
            _checked_sql(q);
        }
    }

    def test_aggregate_validation(self: SQLTests) -> object {
        for q in [
            s.select(
                [s.named('age', self.people.col(self.age)), s.named('n', s.count())],
                source=self.people
            ),
            s.select(
                [s.named('age', self.people.col(self.age))],
                source=self.people,
                where=s.gt(s.count(), s.int64(1))
            )
        ] {
            with self.subTest(q=q), self.assertRaises(s.SqlError) {
                _checked_sql(q);
            }
        }
        with self.assertRaises(s.SqlError) {
            s.aggregate(
                [s.named('age', self.people.col(self.age))], source=self.people
            );
        }
    }

    def test_compiled_query_survives_ast_edits(self: SQLTests) -> object {
        q = s.select([s.named('n', s.int64(1))], limit=1);
        compiled = s.compile_sql(q);
        q.ast.limit = 2;
        updated = s.compile_sql(q);
        self.assertIn('LIMIT 1', compiled.sql);
        self.assertIn('LIMIT 2', updated.sql);
        self.assertEqual(self.execute(q), [(1, )]);
    }

    def test_edited_projection_type_is_checked(self: SQLTests) -> object {
        q = s.select([s.named('n', s.int64(1))]);
        compiled = s.compile_sql(q);
        original_params = dict(compiled.params);
        q.ast.projections[0].expr = s.text('abc').ast;
        with self.assertRaises(s.SqlError) {
            _checked_sql(q);
        }
        self.assertEqual(compiled.params, original_params);
    }

    def test_derived_schema_comes_from_query(self: SQLTests) -> object {
        output = s.named('n', s.int64(1));
        q = s.select([output]);
        derived = q.as_source();
        self.assertNotIn('schema', derived.__dict__);
        self.assertNotIn('schema', q.ast.__dict__);
        outer = s.select(
            [s.named('n', s.add(derived.col(output.key()), s.int64(1)))], source=derived
        );
        self.assertEqual(self.execute(outer), [(2, )]);
    }

    def test_edited_projection_nullability_is_checked(self: SQLTests) -> object {
        q = s.select([s.named('n', s.int64(1))]);
        s.compile_sql(q);
        q.ast.projections[0].expr = s.param(s.nullable(s.int64_type()), None).ast;
        with self.assertRaises(s.SqlError) {
            _checked_sql(q);
        }
        q.ast.projections[0].field.dtype.nullable = True;
        self.execute(q);
    }

    def test_query_rebuild_preserves_original(self: SQLTests) -> object {
        first = s.select([s.named('n', s.int64(1))]);
        second = s.select([s.named('n', s.int64(2))]);
        self.assertEqual(self.execute(first), [(1, )]);
        self.assertEqual(self.execute(second), [(2, )]);
    }

    def test_recursive_step_can_be_reused(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        ref = s.cte_ref([key]);
        anchor = s.select([s.named('n', s.int64(1))]);
        step = s.select(
            [s.named('n', s.add(ref.col(key), s.int64(1)))],
            source=ref,
            where=s.gt(s.int64(3), ref.col(key)),
            order_by=[]
        );
        s.define_cte(ref, s.union_all(anchor, step), recursive=True);
        self.assertEqual(self.execute(step), [(2, ), (3, )]);
        derived = step.as_source();
        self.assertEqual(
            self.execute(s.select([s.named('n', derived.col(key))], source=derived)),
            [(2, ), (3, )]
        );
    }

    def test_cte_bindings_share_target_schema(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        reference = s.cte(s.select([s.named('n', s.int64(1))]));
        use = reference.ref();
        self.assertNotIn('schema', use.__dict__);
        with self.assertRaises((s.SqlError, AttributeError)) {
            reference.schema = s.Schema((s.field('m', s.int64_type()), ));
        }
        self.assertEqual(
            self.execute(s.select([s.named('n', use.col(key))], source=use)), [(1, )]
        );
        forward = s.cte_ref([key]);
        binding = forward.ref();
        self.assertIs(binding.schema, forward.schema);
        s.define_cte(forward, s.select([s.named('n', s.int64(7))]));
        self.assertEqual(
            self.execute(s.select([s.named('n', binding.col(key))], source=binding)),
            [(7, )]
        );
    }

    def test_correlated_aggregate_local_grouping(self: SQLTests) -> object {
        other = self.people.ref();
        inner = s.aggregate(
            [s.named('n', s.add(s.count(), self.people.col(self.id)))], source=other
        );
        body = s.select(
            [s.named('n', s.scalar_one(inner, s.field('n', s.int64_type())))],
            source=self.people,
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(self.execute(body), [(4, ), (5, ), (6, )]);
        invalid = s.aggregate(
            [s.named('n', s.add(s.count(), other.col(self.id)))], source=other
        );
        with self.assertRaisesRegex(s.SqlError, 'GROUP BY') {
            _checked_sql(invalid);
        }
        invalid_outer = s.aggregate(
            [
                s.named('n', s.scalar_one(inner, s.field('n', s.int64_type()))),
                s.named('total', s.count())
            ],
            source=self.people
        );
        with self.assertRaisesRegex(s.SqlError, 'GROUP BY') {
            _checked_sql(invalid_outer);
        }
    }

    def test_constructor_inputs_are_snapshotted(self: SQLTests) -> object {
        fields = [s.field('n', s.int64_type())];
        src = s.table('people', fields);
        fields.clear();
        self.assertEqual(len(src.schema.fields), 1);
        projections = [s.named('n', s.int64(1))];
        query = s.select(projections);
        projections.clear();
        self.assertIsInstance(query.ast.projections, tuple);
        self.assertIsInstance(src.schema.fields, tuple);
        self.assertEqual(self.execute(query), [(1, )]);
    }

    def test_invalid_raw_nodes_are_rejected(self: SQLTests) -> object {
        field = s.field('n', s.int64_type());
        projection = s.ProjectionDef(field=field, expr=s.text('abc').ast);
        bad = s.select([projection]);
        with self.assertRaisesRegex(s.SqlError, 'projection n') {
            _checked_sql(bad);
        }
        derived = bad.as_source();
        outer = s.select(
            [s.named('n', s.add(derived.col(field), s.int64(1)))], source=derived
        );
        with self.assertRaisesRegex(s.SqlError, 'projection n') {
            _checked_sql(outer);
        }
        nullable = s.ProjectionDef(
            field=field, expr=s.param(s.nullable(s.int64_type()), None).ast
        );
        with self.assertRaisesRegex(s.SqlError, 'projection n') {
            _checked_sql(s.select([nullable]));
        }
        cte = s.cte(s.select([s.named('n', s.int64(1))]));
        with self.assertRaisesRegex(s.SqlError, 'already defined') {
            cte.binding.bind(s.select([s.named('n', s.int64(2))]).ast, False);
        }
        with self.assertRaisesRegex(s.SqlError, 'already defined') {
            cte.binding._definition = s.select([s.named('n', s.int64(2))]).ast;
        }
    }

    def test_validation_precedes_rendering(self: SQLTests) -> object {
        query = s.select([s.named('n', s.int64(1))]);
        plan = s.QueryValidator().analyze(query);
        self.assertIs(plan.query, query.ast);
        compiled = s.PostgresRenderer().render(plan);
        self.assertEqual(
            self.db.execute(compiled.sql, compiled.params).fetchall(), [(1, )]
        );
        invalid = s.select([s.named('n', self.people.col(self.id))]);
        with self.assertRaisesRegex(s.SqlError, 'outside scope') {
            s.QueryValidator().analyze(invalid);
        }
    }

    def test_cte_names_do_not_capture_physical_tables(self: SQLTests) -> object {
        kids = s.cte(
            s.select(
                [s.named('id', self.people.col(self.id))],
                source=self.people,
                where=s.gt(s.int64(30), self.people.col(self.age))
            )
        );
        probe = s.select([s.named('id', kids.col(self.id))], source=kids);
        query = s.select(
            [s.named('name', self.people.col(self.name))],
            source=self.people,
            where=s.exists(probe),
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(self.execute(query), [('Ann', ), ('Bob', ), ('Cora', )]);
    }

    def test_generated_names_avoid_physical_prefixes(self: SQLTests) -> object {
        self.db.executescript(
            'CREATE TABLE "_cte0" (n BIGINT); INSERT INTO "_cte0" VALUES (7); CREATE TABLE "_t0" (n BIGINT); INSERT INTO "_t0" VALUES (7);'
        );
        key = s.field('n', s.int64_type());
        physical = s.table('_cte0', [key]);
        other = s.table('_t0', [key]);
        temp = s.cte(s.select([s.named('n', s.int64(1))]));
        query = s.select(
            [
                s.named('physical', physical.col(key)),
                s.named('temporary', temp.col(key))
            ],
            source=physical,
            joins=[
                s.inner_join(other, s.eq(physical.col(key), other.col(key))),
                s.inner_join(temp, s.gt(physical.col(key), temp.col(key)))
            ]
        );
        self.assertEqual(self.execute(query), [(7, 1)]);
    }

    def test_cte_reuse_and_independent_bindings(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        temp = s.cte(s.select([s.named('n', s.int64(3))]));
        left = temp.ref();
        right = temp.ref();
        query = s.select(
            [s.named('left', left.col(key)), s.named('right', right.col(key))],
            source=left,
            joins=[s.inner_join(right, s.eq(left.col(key), right.col(key)))]
        );
        self.assertEqual(self.execute(query), [(3, 3)]);
        self.assertEqual(s.compile_sql(query).sql.count(' AS ('), 1);
    }

    def test_distinct_cte_objects_have_distinct_names(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        left = s.cte(s.select([s.named('n', s.int64(1))]));
        right = s.cte(s.select([s.named('n', s.int64(2))]));
        query = s.select(
            [s.named('a', left.col(key)), s.named('b', right.col(key))],
            source=left,
            joins=[s.inner_join(right, s.gt(right.col(key), left.col(key)))]
        );
        self.assertEqual(self.execute(query), [(1, 2)]);
    }

    def test_cte_dependencies_in_subqueries(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        first = s.cte(s.select([s.named('n', s.int64(3))]));
        second = s.cte(
            s.select([s.named('n', s.add(first.col(key), s.int64(1)))], source=first)
        );
        inner = s.limit_one(s.select([s.named('n', second.col(key))], source=second));
        query = s.select([s.named('n', s.scalar(inner, key))]);
        self.assertEqual(self.execute(query), [(4, )]);
    }

    def test_cte_missing_definition_cycles_and_redefinition(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        missing = s.cte_ref([key]);
        with self.assertRaisesRegex(s.SqlError, 'no definition') {
            _checked_sql(s.select([s.named('n', missing.col(key))], source=missing));
        }
        a = s.cte_ref([key]);
        b = s.cte_ref([key]);
        s.define_cte(a, s.select([s.named('n', b.col(key))], source=b));
        s.define_cte(b, s.select([s.named('n', a.col(key))], source=a));
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('n', a.col(key))], source=a));
        }
        with self.assertRaisesRegex(s.SqlError, 'already defined') {
            s.define_cte(a, s.select([s.named('n', s.int64(1))]));
        }
    }

    def test_cte_cannot_capture_outer_columns(self: SQLTests) -> object {
        captured = s.cte(s.select([s.named('id', self.people.col(self.id))]));
        body = s.select([s.named('id', captured.col(self.id))], source=captured);
        with self.assertRaisesRegex(s.SqlError, 'outside scope') {
            _checked_sql(body);
        }
    }

    def test_generated_names_are_deterministic(self: SQLTests) -> object {
        key = s.field('n', s.int64_type());
        temp = s.cte(s.select([s.named('n', s.int64(7))]));
        query = s.select([s.named('n', temp.col(key))], source=temp);
        before = s.compile_sql(query);
        after = s.compile_sql(query);
        self.assertEqual(before.sql, after.sql);
        self.assertEqual(before.params, after.params);
        self.assertEqual(temp.alias, '');
        self.assertEqual(self.execute(query), [(7, )]);
    }

    def test_auto_source_aliases_for_self_join(self: SQLTests) -> object {
        left = self.people.ref();
        right = self.people.ref();
        query = s.select(
            [s.named('name', left.col(self.name))],
            source=left,
            joins=[s.inner_join(right, s.eq(left.col(self.id), right.col(self.id)))],
            order_by=[s.asc(left.col(self.id))]
        );
        self.assertEqual(self.execute(query), [('Ann', ), ('Bob', ), ('Cora', )]);
    }

    def test_source_field_schema_validation(self: SQLTests) -> object {
        with self.assertRaises(s.SqlError) {
            _checked_sql(
                s.select(
                    [s.named('age', self.people.col(s.field('age', s.text_type())))],
                    source=self.people
                )
            );
        }
        with self.assertRaises(s.SqlError) {
            s.table('bad', [self.id, self.id], 'b');
        }
        for limit in [True, -1, '3'] {
            with self.assertRaises(s.SqlError) {
                s.select([s.named('n', s.int64(1))], limit=limit);
            }
        }
    }

    def test_empty_membership_preserves_aggregate_rows(self: SQLTests) -> object {
        for empty in [False, True] {
            if empty {
                self.db.execute('DELETE FROM people');
            }
            with self.subTest(empty=empty) {
                query = s.aggregate(
                    [s.named('empty', s.in_(s.count(), []))], source=self.people
                );
                self.assertEqual(self.execute(query), [(False, )]);
                scalar = s.scalar_one(query, s.field('empty', s.bool_type()));
                self.assertEqual(
                    self.execute(s.select([s.named('empty', scalar)])), [(False, )]
                );
                grouped = s.select(
                    [
                        s.named('age', self.people.col(self.age)),
                        s.named('empty', s.in_(s.count(), []))
                    ],
                    source=self.people,
                    group_by=[self.people.col(self.age).ast],
                    order_by=[s.asc(self.people.col(self.age))]
                );
                self.assertEqual(
                    self.execute(grouped), [] if empty else [(20, False), (40, False)]
                );
            }
        }
    }

    def test_windows_over_grouped_counts(self: SQLTests) -> object {
        total = s.over(s.sum_int64(s.count()));
        rank = s.row_number(order_by=[s.desc(s.count())]);
        query = s.select(
            [
                s.named('age', self.people.col(self.age)),
                s.named('rank', rank),
                s.named('total', total)
            ],
            source=self.people,
            group_by=[self.people.col(self.age).ast],
            order_by=[s.asc(self.people.col(self.age))]
        );
        self.assertEqual(
            [(r[0], r[1], int(r[2])) for r in self.execute(query)],
            [(20, 2, 3), (40, 1, 3)]
        );
        partitioned = s.row_number(
            partition_by=[s.count().ast], order_by=[s.asc(self.people.col(self.age))]
        );
        partitioned_query = s.select(
            [s.named('age', self.people.col(self.age)), s.named('rank', partitioned)],
            source=self.people,
            group_by=[self.people.col(self.age).ast],
            order_by=[s.asc(self.people.col(self.age))]
        );
        self.assertEqual(self.execute(partitioned_query), [(20, 1), (40, 1)]);
        self.db.execute('DELETE FROM people');
        self.assertEqual(self.execute(query), []);
    }

    def test_windows_preserve_implicit_group_proof(self: SQLTests) -> object {
        for empty in [False, True] {
            if empty {
                self.db.execute('DELETE FROM people');
            }
            with self.subTest(empty=empty) {
                total = s.over(s.sum_int64(s.count()));
                query = s.aggregate([s.named('n', total)], source=self.people);
                self.assertEqual(
                    [int(r[0]) for r in self.execute(query)], [0 if empty else 3]
                );
                value = s.scalar_one(query, s.field('n', s.nullable(s.numeric_type())));
                self.assertEqual(
                    [int(r[0]) for r in self.execute(s.select([s.named('n', value)]))],
                    [0 if empty else 3]
                );
                ranked = s.aggregate(
                    [s.named('n', s.row_number(order_by=[s.desc(s.count())]))],
                    source=self.people
                );
                self.assertEqual(self.execute(ranked), [(1, )]);
            }
        }
    }

    def test_grouped_windows_keep_stage_checks(self: SQLTests) -> object {
        bad_key = s.row_number(
            order_by=[s.desc(s.add(s.count(), self.people.col(self.id)))]
        );
        invalid = s.select(
            [s.named('n', bad_key)],
            source=self.people,
            group_by=[self.people.col(self.age).ast]
        );
        with self.assertRaisesRegex(s.SqlError, 'GROUP BY') {
            _checked_sql(invalid);
        }
        bad_arg = s.over(
            s.sum_int64(self.people.col(self.id)), order_by=[s.desc(s.count())]
        );
        with self.assertRaisesRegex(s.SqlError, 'GROUP BY') {
            _checked_sql(s.select([s.named('n', bad_arg)], source=self.people));
        }
        valid_key = s.row_number(
            order_by=[s.desc(s.add(s.count(), self.people.col(self.age)))]
        );
        valid = s.select(
            [s.named('n', valid_key)],
            source=self.people,
            group_by=[self.people.col(self.age).ast],
            order_by=[s.asc(self.people.col(self.age))]
        );
        self.assertEqual(self.execute(valid), [(2, ), (1, )]);
        nested = s.row_number(
            order_by=[s.asc(s.row_number(order_by=[s.desc(s.count())]))]
        );
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('n', nested)], source=self.people));
        }
        argument = s.over(s.sum_int64(s.row_number()));
        with self.assertRaises(s.SqlError) {
            _checked_sql(s.select([s.named('n', argument)], source=self.people));
        }
    }

    def test_named_slot_rebind(self: SQLTests) -> object {
        age = s.slot('min_age', s.int64_type());
        query = s.select(
            [s.named('name', self.people.col(self.name))],
            source=self.people,
            where=s.gt(self.people.col(self.age), age),
            order_by=[s.asc(self.people.col(self.id))]
        );
        compiled = s.compile_sql(query);
        first = compiled.bind({'min_age': 18});
        second = compiled.bind({'min_age': 30});
        self.assertIs(first.sql, compiled.sql);
        self.assertEqual(
            self.db.execute(first.sql, first.params).fetchall(),
            [('Ann', ), ('Bob', ), ('Cora', )]
        );
        self.assertEqual(
            self.db.execute(second.sql, second.params).fetchall(),
            [('Bob', ), ('Cora', )]
        );
        self.assertEqual(first.params, {'min_age': 18});
        self.assertEqual(compiled.params, {});
        self.assertEqual(second.slots, ());
    }

    def test_named_slot_literal_collision(self: SQLTests) -> object {
        query = s.select(
            [
                s.named(
                    'n',
                    s.add(
                        s.int64(5),
                        s.add(
                            s.slot('p0', s.int64_type()), s.slot('p0', s.int64_type())
                        )
                    )
                )
            ]
        );
        compiled = s.compile_sql(query);
        self.assertEqual(len(compiled.slots), 1);
        bound = compiled.bind({'p0': 3});
        self.assertEqual(self.db.execute(bound.sql, bound.params).fetchall(), [(11, )]);
        self.assertEqual(compiled.params, {'p1': 5});
    }

    def test_named_slot_names_are_validated(self: SQLTests) -> object {
        for name in [
            '',
            'sql',
            'self',
            '1age',
            'x); DROP TABLE people; --',
            'x:y',
            'two words',
            'x\x00y',
            'é'
        ] {
            with self.assertRaises(s.SqlError) {
                s.slot(name, s.int64_type());
            }
        }
    }

    def test_named_slot_conflicting_types(self: SQLTests) -> object {
        query = s.select(
            [
                s.named('n', s.slot('value', s.int64_type())),
                s.named('t', s.slot('value', s.text_type()))
            ]
        );
        with self.assertRaises(s.SqlError) {
            _checked_sql(query);
        }
    }

    def test_named_slot_bind_checks(self: SQLTests) -> object {
        compiled = s.compile_sql(s.select([s.named('n', s.slot('n', s.int64_type()))]));
        for values in [
            {},
            {'n': 1, 'extra': 2},
            {'n': 'oops'},
            {'n': True},
            {'n': None},
            {'n': 2 ** 63}
        ] {
            with self.assertRaises(s.SqlError) {
                compiled.bind(values);
            }
        }
        nullable = s.compile_sql(
            s.select([s.named('n', s.slot('n', s.nullable(s.int64_type())))])
        );
        bound = nullable.bind({'n': None});
        self.assertEqual(
            self.db.execute(bound.sql, bound.params).fetchall(), [(None, )]
        );
        fixed = s.compile_sql(s.select([s.named('n', s.int64(7))]));
        bound = fixed.bind({});
        self.assertEqual(self.db.execute(bound.sql, bound.params).fetchall(), [(7, )]);
    }

    def test_named_slot_does_not_retain_ast(self: SQLTests) -> object {
        import weakref;
        import gc;
        query = s.select([s.named('n', s.slot('n', s.int64_type()))]);
        reference = weakref.ref(query.ast);
        compiled = s.compile_sql(query);
        del query;
        gc.collect();
        self.assertIsNone(reference());
        bound = compiled.bind({'n': 42});
        self.assertEqual(self.db.execute(bound.sql, bound.params).fetchall(), [(42, )]);
    }

    def test_named_slot_injection_is_bound(self: SQLTests) -> object {
        compiled = s.compile_sql(
            s.select([s.named('value', s.slot('value', s.text_type()))])
        );
        evil = "x'); DROP TABLE people; --";
        bound = compiled.bind({'value': evil});
        self.assertNotIn(evil, bound.sql);
        self.assertEqual(
            self.db.execute(bound.sql, bound.params).fetchall(), [(evil, )]
        );
        self.assertEqual(
            self.db.execute('SELECT COUNT(*) FROM people').fetchone(), (3, )
        );
    }
}


def run_case(check: unittest.TestCase) {
    result = unittest.TestResult();
    check.run(result);
    if result.skipped {
        raise unittest.SkipTest(str(result.skipped));
    }
    assert result.testsRun == 1;
    assert not result.errors , str(result.errors);
    assert not result.failures , str(result.failures);
}
