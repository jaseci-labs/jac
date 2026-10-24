import os;
import unittest;
import from decimal { Decimal }
import from uuid { UUID }
import jaclang.sql as sql;
import from .postgres_cases { PostgresTests }
import from .sql_cases { run_case }
glob s: any = sql;

class FeatureTests(PostgresTests) {
    def test_boolean_comparison_and_case(self: FeatureTests) -> object {
        expr = s.or_(
            [
                s.and_([s.lt(s.int64(1), s.int64(2)), s.le(s.int64(2), s.int64(2))]),
                s.not_(s.boolean(True))
            ]
        );
        choice = s.case_([(expr, s.int64(7))], s.int64(9));
        self.assertEqual(
            self.execute(
                s.select(
                    [
                        s.named('n', s.sub(choice, s.int64(2))),
                        s.named('ge', s.ge(s.int64(2), s.int64(1))),
                        s.named('ne', s.ne(s.int64(1), s.int64(2)))
                    ]
                )
            ),
            [(5, True, True)]
        );
        with self.assertRaises(s.SqlError) {
            s.case_([(s.int64(1), s.int64(2))], s.int64(3));
        }
        with self.assertRaises(s.SqlError) {
            s.case_([(s.boolean(True), s.text('bad'))], s.int64(3));
        }
    }

    def test_nullable_boolean_semantics(self: FeatureTests) -> object {
        missing = s.param(s.nullable(s.int64_type()), None);
        unknown = s.compare_nullable(missing, s.int64(1));
        query = s.select(
            [
                s.named('unknown', s.not_nullable(unknown)),
                s.named('yes', s.or_nullable([unknown, s.boolean(True)])),
                s.named('no', s.and_nullable([unknown, s.boolean(False)])),
                s.named('null', s.is_null(missing)),
                s.named('present', s.is_not_null(missing))
            ]
        );
        self.assertEqual(self.execute(query), [(None, True, False, True, False)]);
        with self.assertRaises(s.SqlError) {
            s.compare_nullable(s.text('x'), s.int64(1));
        }
    }

    def test_including_empty_membership(self: FeatureTests) -> object {
        self.assertEqual(
            self.execute(
                s.select(
                    [
                        s.named('yes', s.in_(s.int64(2), [s.int64(1), s.int64(2)])),
                        s.named('empty', s.in_(s.int64(2), []))
                    ]
                )
            ),
            [(True, False)]
        );
        with self.assertRaises(s.SqlError) {
            s.in_(s.int64(1), [s.text('x')]);
        }
    }

    def test_strings_and_numeric_types(self: FeatureTests) -> object {
        absent = s.param(s.nullable(s.text_type()), None);
        query = s.select(
            [
                s.named(
                    'key',
                    s.text_concat(
                        s.lpad(s.text('7'), s.int32(4), s.text('0')),
                        s.concat([s.text(':'), absent, s.text('id')])
                    )
                ),
                s.named(
                    'n',
                    s.numeric_sub(
                        s.numeric_add(s.numeric(Decimal('1.25')), s.numeric(2)),
                        s.numeric(1)
                    )
                )
            ]
        );
        rows = self.execute(query);
        self.assertEqual(rows[0][0], '0007:id');
        self.assertEqual(Decimal(str(rows[0][1])), Decimal('2.25'));
        for v in [2147483648, True] {
            with self.assertRaises(s.SqlError) {
                s.int32(v);
            }
        }
        with self.assertRaises(s.SqlError) {
            s.numeric(1.5);
        }
        arithmetic = s.sub_int32(s.add_int32(s.int32(3), s.int32(4)), s.int32(1));
        self.assertEqual(self.execute(s.select([s.named('n', arithmetic)])), [(6, )]);
    }

    def test_array_parameters_and_operations(self: FeatureTests) -> object {
        items = s.array_concat(
            s.array_param(s.int64_type(), [1, 2]), s.array(s.int64_type(), [s.int64(3)])
        );
        items = s.array_append(items, s.int64(4));
        key = s.field('n', s.int64_type());
        ord = s.field('ord', s.int64_type());
        src = s.unnest(items, key, ord);
        query = s.select(
            [s.named('n', src.col(key)), s.named('ord', src.col(ord))],
            source=src,
            order_by=[s.asc(src.col(ord))]
        );
        self.assertEqual(self.execute(query), [(1, 1), (2, 2), (3, 3), (4, 4)]);
        self.assertEqual(
            self.execute(s.select([s.named('member', s.any_eq(s.int64(3), items))])),
            [(True, )]
        );
        empty = s.unnest(s.array(s.uuid_type(), []), s.field('id', s.uuid_type()));
        self.assertEqual(
            self.execute(
                s.select(
                    [s.named('id', empty.col(s.field('id', s.uuid_type())))],
                    source=empty
                )
            ),
            []
        );
    }

    def test_array_parameter_quoting_and_validation(self: FeatureTests) -> object {
        value = 'x"},NULL,\\ SQL';
        key = s.field('v', s.text_type());
        source = s.unnest(s.array_param(s.text_type(), [value, 'normal']), key);
        self.assertEqual(
            self.execute(s.select([s.named('v', source.col(key))], source=source)),
            [(value, ), ('normal', )]
        );
        with self.assertRaises(s.SqlError) {
            s.array_param(s.int64_type(), ['1']);
        }
        with self.assertRaises(s.SqlError) {
            s.array(s.int64_type(), [s.text('1')]);
        }
        with self.assertRaises(s.SqlError) {
            s.any_eq(s.int64(1), s.array_param(s.text_type(), ['1']));
        }
        with self.assertRaises(s.SqlError) {
            s.unnest(s.array_param(s.int64_type(), [1]), s.field('x', s.text_type()));
        }
    }

    def test_values_relation_and_row_validation(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        relation = s.values([key], [[s.int64(2)], [s.int64(1)]]);
        source = relation.as_source();
        self.assertEqual(
            self.execute(
                s.select(
                    [s.named('n', source.col(key))],
                    source=source,
                    order_by=[s.asc(source.col(key))]
                )
            ),
            [(1, ), (2, )]
        );
        for rows in [[], [[s.text('x')]], [[s.int64(1), s.int64(2)]]] {
            with self.assertRaises(s.SqlError) {
                s.compile_sql(s.values([key], rows));
            }
        }
        maybe = s.field('n', s.nullable(s.int64_type()));
        widened = s.values([maybe], [[s.int64(1)], [s.null(s.int64_type())]]);
        self.assertEqual(self.execute(widened), [(1, ), (None, )]);
    }

    def test_lateral_correlations_and_visibility(self: FeatureTests) -> object {
        other = self.people.ref();
        inner = s.select(
            [s.named('other', other.col(self.id))],
            source=other,
            where=s.gt(other.col(self.age), self.people.col(self.age))
        );
        source = inner.as_source(lateral=True);
        key = s.field('other', s.int64_type());
        body = s.select(
            [
                s.named('id', self.people.col(self.id)),
                s.named('other', source.col(key))
            ],
            source=self.people,
            joins=[s.cross_join(source)],
            order_by=[s.asc(self.people.col(self.id)), s.asc(source.col(key))]
        );
        self.assertEqual(self.execute(body), [(1, 2), (1, 3)]);
        nonlateral = inner.as_source();
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select(
                    [s.named('id', self.people.col(self.id))],
                    source=self.people,
                    joins=[s.cross_join(nonlateral)]
                )
            );
        }
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.select([s.named('n', source.col(key))], source=source));
        }
    }

    def test_left_join_null_extension(self: FeatureTests) -> object {
        owner = s.field('owner', s.int64_type());
        pets = s.optional_source(s.values([owner], [[s.int64(1)]]).as_source());
        nullable_owner = s.field('owner', s.nullable(s.int64_type()));
        query = s.select(
            [
                s.named('id', self.people.col(self.id)),
                s.named('owner', pets.col(nullable_owner))
            ],
            source=self.people,
            joins=[
                s.left_join(
                    pets,
                    s.compare_nullable(
                        self.people.col(self.id), pets.col(nullable_owner)
                    )
                )
            ],
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(self.execute(query), [(1, 1), (2, None), (3, None)]);
        with self.assertRaises(s.SqlError) {
            pets.col(owner);
        }
        raw = s.Join(
            source=self.people.ref(), condition=s.boolean(True).ast, kind='LEFT'
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select([s.named('n', s.int64(1))], source=self.people, joins=[raw])
            );
        }
    }

    def test_left_lateral_join(self: FeatureTests) -> object {
        other = self.people.ref();
        key = s.field('other', s.nullable(s.int64_type()));
        inner = s.select(
            [s.named('other', other.col(self.id))],
            source=other,
            where=s.gt(other.col(self.age), self.people.col(self.age))
        );
        source = s.optional_source(inner.as_source(lateral=True));
        query = s.select(
            [
                s.named('id', self.people.col(self.id)),
                s.named('other', source.col(key))
            ],
            source=self.people,
            joins=[s.left_join(source, s.boolean(True))],
            order_by=[s.asc(self.people.col(self.id)), s.asc(source.col(key))]
        );
        self.assertEqual(self.execute(query), [(1, 2), (1, 3), (2, None), (3, None)]);
    }

    def test_correlated_unnest_with_ordinality(self: FeatureTests) -> object {
        projected = s.named(
            'items',
            s.array(
                s.int64_type(),
                [self.people.col(self.id), s.add(self.people.col(self.id), s.int64(10))]
            )
        );
        base = s.select([projected], source=self.people).as_source();
        key = s.field('item', s.int64_type());
        order = s.field('ord', s.int64_type());
        source = s.unnest(base.col(projected.key()), key, order);
        query = s.select(
            [s.named('item', source.col(key)), s.named('ord', source.col(order))],
            source=base,
            joins=[s.cross_join(source)],
            order_by=[s.asc(source.col(key))]
        );
        self.assertEqual(
            self.execute(query), [(1, 1), (2, 1), (3, 1), (11, 2), (12, 2), (13, 2)]
        );
    }

    def test_distinct_and_distinct_on(self: FeatureTests) -> object {
        self.assertEqual(
            self.execute(
                s.select(
                    [s.named('age', self.people.col(self.age))],
                    source=self.people,
                    distinct=True,
                    order_by=[s.asc(self.people.col(self.age))]
                )
            ),
            [(20, ), (40, )]
        );
        query = s.select(
            [
                s.named('age', self.people.col(self.age)),
                s.named('id', self.people.col(self.id))
            ],
            source=self.people,
            distinct_on=[self.people.col(self.age).ast],
            order_by=[
                s.asc(self.people.col(self.age)),
                s.desc(self.people.col(self.id))
            ]
        );
        self.assertEqual(self.execute(query), [(20, 1), (40, 3)]);
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select(
                    [s.named('age', self.people.col(self.age))],
                    source=self.people,
                    distinct_on=[self.people.col(self.age).ast],
                    order_by=[s.asc(self.people.col(self.id))]
                )
            );
        }
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select(
                    [s.named('age', self.people.col(self.age))],
                    source=self.people,
                    distinct=True,
                    order_by=[s.asc(self.people.col(self.id))]
                )
            );
        }
    }

    def test_set_operations_and_result_ordering(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        a = s.values([key], [[s.int64(1)], [s.int64(1)], [s.int64(2)]]);
        b = s.values([key], [[s.int64(1)], [s.int64(3)]]);
        for (query, expected) in [
            (s.union(a, b), [(1, ), (2, ), (3, )]),
            (s.except_(a, b), [(2, )]),
            (s.except_(a, b, all_=True), [(1, ), (2, )]),
            (s.intersect(a, b), [(1, )])
        ] {
            self.assertEqual(
                self.execute(s.ordered(query, [s.asc(s.output(key))])), expected
            );
        }
        self.assertEqual(
            self.execute(s.ordered(s.union(a, b), [s.desc(s.output(key))], limit=1)),
            [(3, )]
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.ordered(a, [s.asc(s.int64(1))]));
        }
    }

    def test_null_ordering(self: FeatureTests) -> object {
        key = s.field('n', s.nullable(s.int64_type()));
        q = s.values(
            [key],
            [
                [s.param(s.nullable(s.int64_type()), None)],
                [s.param(s.nullable(s.int64_type()), 1)]
            ]
        );
        source = q.as_source();
        query = s.select(
            [s.named('n', source.col(key))],
            source=source,
            order_by=[s.asc(source.col(key), nulls='LAST')]
        );
        self.assertEqual(self.execute(query), [(1, ), (None, )]);
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select(
                    [s.named('n', s.int64(1))],
                    order_by=[s.asc(s.int64(1), nulls='LAST; SELECT 1')]
                )
            );
        }
    }

    def test_integer_aggregates_and_result_types(self: FeatureTests) -> object {
        summed = s.sum_int64(self.people.col(self.id));
        self.assertEqual(summed.ast.dtype.name, 'numeric');
        rows = self.execute(
            s.aggregate([s.named('total', summed)], source=self.people)
        );
        self.assertEqual(Decimal(str(rows[0][0])), Decimal(6));
        term = s.cast(self.people.col(self.id), s.int32_type());
        small = s.sum_int32(term);
        self.assertEqual(small.ast.dtype.name, 'bigint');
        self.assertEqual(
            self.execute(s.aggregate([s.named('total', small)], source=self.people)),
            [(6, )]
        );
        self.assertEqual(
            self.execute(
                s.aggregate(
                    [s.named('total', summed)],
                    source=self.people,
                    where=s.boolean(False)
                )
            ),
            [(None, )]
        );
    }

    def test_boolean_and_string_aggregates(self: FeatureTests) -> object {
        query = s.aggregate(
            [
                s.named('all', s.bool_and(s.gt(self.people.col(self.id), s.int64(0)))),
                s.named(
                    'names',
                    s.string_agg(self.people.col(self.name), s.text(','), distinct=True)
                )
            ],
            source=self.people
        );
        rows = self.execute(query);
        self.assertTrue(rows[0][0]);
        self.assertEqual(sorted(str(rows[0][1]).split(',')), ['Ann', 'Bob', 'Cora']);
        self.assertEqual(
            self.execute(
                s.aggregate(
                    [s.named('all', s.bool_and(s.boolean(True)))],
                    source=self.people,
                    where=s.boolean(False)
                )
            ),
            [(None, )]
        );
    }

    def test_window_ranking_partition_and_count(self: FeatureTests) -> object {
        query = s.select(
            [
                s.named('id', self.people.col(self.id)),
                s.named(
                    'row', s.row_number(order_by=[s.asc(self.people.col(self.id))])
                ),
                s.named(
                    'rank', s.dense_rank(order_by=[s.asc(self.people.col(self.age))])
                ),
                s.named(
                    'count',
                    s.over(s.count(), partition_by=[self.people.col(self.age).ast])
                )
            ],
            source=self.people,
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(
            self.execute(query), [(1, 1, 1, 1), (2, 2, 2, 2), (3, 3, 2, 2)]
        );
    }

    def test_window_budget_frames(self: FeatureTests) -> object {
        frame = s.rows_between(s.unbounded_preceding(), s.preceding(1));
        sum = s.over(
            s.sum_int64(self.people.col(self.id)),
            order_by=[s.asc(self.people.col(self.id))],
            frame=frame
        );
        query = s.select(
            [s.named('prior', s.coalesce(sum, s.numeric(0)))],
            source=self.people,
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(
            [Decimal(str(r[0])) for r in self.execute(query)],
            [Decimal(0), Decimal(1), Decimal(3)]
        );
        cumulative = s.over(
            s.sum_int64(self.people.col(self.id)),
            order_by=[s.asc(self.people.col(self.id))],
            frame=s.rows_between(s.unbounded_preceding(), s.current_row())
        );
        self.assertEqual(
            [
                Decimal(str(r[0]))
                for r in self.execute(
                    s.select(
                        [s.named('sum', cumulative)],
                        source=self.people,
                        order_by=[s.asc(self.people.col(self.id))]
                    )
                )
            ],
            [Decimal(1), Decimal(3), Decimal(6)]
        );
    }

    def test_window_validation(self: FeatureTests) -> object {
        rank = s.row_number(order_by=[s.asc(self.people.col(self.id))]);
        for query in [
            s.select(
                [s.named('n', s.int64(1))],
                source=self.people,
                where=s.gt(rank, s.int64(1))
            ),
            s.select([s.named('n', s.sum_int64(rank))], source=self.people),
            s.select(
                [s.named('n', s.row_number(order_by=[s.asc(rank)]))], source=self.people
            )
        ] {
            with self.assertRaises(s.SqlError) {
                s.compile_sql(query);
            }
        }
        with self.assertRaises(s.SqlError) {
            s.rows_between(s.following(1), s.preceding(1));
        }
        with self.assertRaises(s.SqlError) {
            s.rows_between(s.preceding(-1), s.current_row());
        }
        with self.assertRaises(s.SqlError) {
            s.over(s.int64(1));
        }
    }

    def test_local_cte_dependencies_and_materialization(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        a = s.cte(s.select([s.named('n', s.int64(1))]), materialized=True);
        b = s.cte(
            s.select([s.named('n', s.add(a.col(key), s.int64(1)))], source=a),
            materialized=False
        );
        body = s.with_ctes(s.select([s.named('n', b.col(key))], source=b), [b, a]);
        self.assertEqual(self.execute(body), [(2, )]);
        text = s.compile_sql(body).sql;
        self.assertIn('AS MATERIALIZED', text);
        self.assertIn('AS NOT MATERIALIZED', text);
    }

    def test_local_cte_inside_correlated_lateral(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        local = s.cte(s.select([s.named('n', self.people.col(self.id))]));
        inner = s.with_ctes(
            s.select([s.named('n', local.col(key))], source=local), [local]
        ).as_source(
            lateral=True
        );
        query = s.select(
            [s.named('n', inner.col(key))],
            source=self.people,
            joins=[s.cross_join(inner)],
            order_by=[s.asc(inner.col(key))]
        );
        self.assertEqual(self.execute(query), [(1, ), (2, ), (3, )]);
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.select([s.named('n', local.col(key))], source=local));
        }
    }

    def test_local_cte_scope_rejections(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        local = s.cte(s.select([s.named('n', s.int64(1))]));
        body = s.select([s.named('n', local.col(key))], source=local);
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.with_ctes(body, [local, local]));
        }
        nested = s.with_ctes(body, [local]);
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.with_ctes(nested, [local]));
        }
    }

    def test_recursive_local_materialized_frontier(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        frontier = s.cte(
            s.select(
                [s.named('n', walk.col(key))],
                source=walk,
                where=s.lt(walk.col(key), s.int64(4))
            ),
            materialized=True
        );
        step = s.with_ctes(
            s.select(
                [s.named('n', s.add(frontier.col(key), s.int64(1)))], source=frontier
            ),
            [frontier]
        );
        s.define_cte(
            walk,
            s.union_all(s.select([s.named('n', s.int64(1))]), step),
            recursive=True
        );
        query = s.select(
            [s.named('n', walk.col(key))], source=walk, order_by=[s.asc(walk.col(key))]
        );
        self.assertEqual(self.execute(query), [(1, ), (2, ), (3, ), (4, )]);
        self.assertEqual(self.execute(step), [(2, ), (3, ), (4, )]);
    }

    def test_recursive_union_distinct_and_values_anchor(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        anchor = s.values([key], [[s.int64(1)]]);
        step = s.select([s.named('n', walk.col(key))], source=walk);
        s.define_cte(walk, s.union(anchor, step), recursive=True);
        self.assertEqual(
            self.execute(s.select([s.named('n', walk.col(key))], source=walk)), [(1, )]
        );
    }

    def test_recursive_nested_derived_and_window(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        next = s.select(
            [s.named('n', s.add(walk.col(key), s.int64(1)))],
            source=walk,
            where=s.lt(walk.col(key), s.int64(3))
        ).as_source();
        step = s.select([s.named('n', next.col(key))], source=next);
        s.define_cte(
            walk,
            s.union_all(s.select([s.named('n', s.int64(1))]), step),
            recursive=True
        );
        self.assertEqual(
            self.execute(
                s.select(
                    [s.named('n', walk.col(key))],
                    source=walk,
                    order_by=[s.asc(walk.col(key))]
                )
            ),
            [(1, ), (2, ), (3, )]
        );
    }

    def test_recursive_invalid_reference_placement(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        another = walk.ref();
        step = s.select(
            [s.named('n', walk.col(key))], source=walk, joins=[s.cross_join(another)]
        );
        s.define_cte(
            walk,
            s.union_all(s.select([s.named('n', s.int64(1))]), step),
            recursive=True
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.select([s.named('n', walk.col(key))], source=walk));
        }
    }

    def test_recursive_frontier_dedup_and_windows(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        frontier = s.cte(
            s.select(
                [s.named('n', walk.col(key))],
                source=walk,
                where=s.lt(walk.col(key), s.int64(4))
            ),
            materialized=True
        );
        first = s.select(
            [s.named('n', s.add(frontier.col(key), s.int64(1)))], source=frontier
        );
        second = s.select(
            [s.named('n', s.add(frontier.col(key), s.int64(2)))], source=frontier
        );
        raw = s.cte(s.union_all(first, second));
        dedup = s.cte(
            s.select(
                [s.named('n', raw.col(key))],
                source=raw,
                distinct_on=[raw.col(key).ast],
                order_by=[s.asc(raw.col(key))]
            )
        );
        counted = s.cte(
            s.select(
                [
                    s.named('n', dedup.col(key)),
                    s.named('layer_count', s.over(s.count())),
                    s.named('rank', s.row_number(order_by=[s.asc(dedup.col(key))]))
                ],
                source=dedup
            )
        );
        layer_count = s.field('layer_count', s.int64_type());
        step = s.with_ctes(
            s.select(
                [s.named('n', counted.col(key))],
                source=counted,
                where=s.lt(counted.col(layer_count), s.int64(4))
            ),
            [counted, raw, dedup, frontier]
        );
        s.define_cte(
            walk, s.union(s.select([s.named('n', s.int64(1))]), step), recursive=True
        );
        self.assertEqual(
            self.execute(
                s.select(
                    [s.named('n', walk.col(key))],
                    source=walk,
                    order_by=[s.asc(walk.col(key))]
                )
            ),
            [(1, ), (2, ), (3, ), (4, ), (5, )]
        );
    }

    def test_nullable_case_and_set_schemas(self: FeatureTests) -> object {
        chosen = s.case_nullable(
            [(s.boolean(False), s.int64(7))], s.null(s.int64_type())
        );
        self.assertEqual(self.execute(s.select([s.named('n', chosen)])), [(None, )]);
        first = s.select([s.named('n', s.int64(1))]);
        missing = s.select([s.named('n', s.null(s.int64_type()))]);
        combined = s.union_all(first, missing);
        self.assertTrue(combined.ast.schema.fields[0].dtype.nullable);
        source = combined.as_source();
        key = s.field('n', s.nullable(s.int64_type()));
        self.assertEqual(
            self.execute(
                s.select(
                    s.project_all(source),
                    source=source,
                    order_by=[s.asc(source.col(key), nulls='LAST')]
                )
            ),
            [(1, ), (None, )]
        );
        self.assertFalse(s.except_(first, missing).ast.schema.fields[0].dtype.nullable);
        self.assertFalse(
            s.intersect(first, missing).ast.schema.fields[0].dtype.nullable
        );
    }

    def test_recursive_nullable_parent_column(self: FeatureTests) -> object {
        n = s.field('n', s.int64_type());
        parent = s.field('parent', s.nullable(s.int64_type()));
        walk = s.cte_ref([n, parent]);
        anchor = s.select(
            [s.named('n', s.int64(1)), s.named('parent', s.null(s.int64_type()))]
        );
        step = s.select(
            [
                s.named('n', s.add(walk.col(n), s.int64(1))),
                s.named('parent', walk.col(n))
            ],
            source=walk,
            where=s.lt(walk.col(n), s.int64(3))
        );
        s.define_cte(walk, s.union_all(anchor, step), recursive=True);
        self.assertEqual(
            self.execute(
                s.select(
                    s.project_all(walk), source=walk, order_by=[s.asc(walk.col(n))]
                )
            ),
            [(1, None), (2, 1), (3, 2)]
        );
    }

    def test_raw_wrapper_cardinality_is_checked(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        body = s.select([s.named('n', s.int64(1))]);
        for ast in [
            s.WithNode(cardinality='exactly_one_aggregate', body=body.ast, bindings=()),
            s.OrderedNode(
                cardinality='exactly_one_aggregate',
                body=body.ast,
                ordering=(),
                limit=None
            ),
            s.ValuesNode(
                cardinality='exactly_one_aggregate',
                declared_schema=s.Schema((key, )),
                rows=((s.int64(1).ast, ), )
            )
        ] {
            with self.assertRaises(s.SqlError) {
                s.compile_sql(s.Relation(ast));
            }
        }
    }

    def test_ancestor_correlations_and_forward_scope(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        ancestor_read = s.select([s.named('n', self.people.col(self.id))]).as_source();
        inner = s.limit_one(
            s.select([s.named('n', ancestor_read.col(key))], source=ancestor_read)
        );
        body = s.select(
            [s.named('n', s.scalar(inner, key))],
            source=self.people,
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(self.execute(body), [(1, ), (2, ), (3, )]);
        later = self.people.ref();
        premature = s.select([s.named('n', later.col(self.id))]).as_source(
            lateral=True
        );
        invalid = s.select(
            [s.named('n', premature.col(key))],
            source=self.people,
            joins=[s.cross_join(premature), s.cross_join(later)]
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(invalid);
        }
    }

    def test_two_recursive_ctes_and_window_steps(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        next = s.add(walk.col(key), s.int64(1));
        step = s.select(
            [s.named('n', s.case_([(s.le(s.row_number(), s.int64(10)), next)], next))],
            source=walk,
            where=s.lt(walk.col(key), s.int64(3))
        );
        s.define_cte(
            walk,
            s.union_all(s.select([s.named('n', s.int64(1))]), step),
            recursive=True
        );
        chosen = s.cte_ref([key]);
        anchor = s.select(
            [s.named('n', walk.col(key))],
            source=walk,
            where=s.eq(walk.col(key), s.int64(3))
        );
        descend = s.select(
            [s.named('n', s.sub(chosen.col(key), s.int64(1)))],
            source=chosen,
            where=s.gt(chosen.col(key), s.int64(1))
        );
        s.define_cte(chosen, s.union(anchor, descend), recursive=True);
        self.assertEqual(
            self.execute(
                s.select(
                    s.project_all(chosen),
                    source=chosen,
                    order_by=[s.asc(chosen.col(key))]
                )
            ),
            [(1, ), (2, ), (3, )]
        );
    }

    def test_distinct_order_variants_and_empty_frames(self: FeatureTests) -> object {
        query = s.select(
            [
                s.named('id', self.people.col(self.id)),
                s.named('age', self.people.col(self.age))
            ],
            source=self.people,
            distinct_on=[self.people.col(self.age).ast, self.people.col(self.id).ast],
            order_by=[s.asc(self.people.col(self.id)), s.asc(self.people.col(self.age))]
        );
        self.assertEqual(self.execute(query), [(1, 20), (2, 40), (3, 40)]);
        unordered = s.select(
            [s.named('age', self.people.col(self.age))],
            source=self.people,
            distinct_on=[self.people.col(self.age).ast]
        );
        self.assertEqual(
            sorted([int(r[0]) for r in self.execute(unordered)]), [20, 40]
        );
        empty = s.over(
            s.sum_int64(self.people.col(self.id)),
            order_by=[s.asc(self.people.col(self.id))],
            frame=s.rows_between(s.preceding(1), s.preceding(2))
        );
        self.assertEqual(
            self.execute(s.select([s.named('n', empty)], source=self.people)),
            [(None, ), (None, ), (None, )]
        );
    }

    def test_typed_ast_rejections(self: FeatureTests) -> object {
        with self.assertRaises(s.SqlError) {
            s.cast(s.boolean(True), s.uuid_type());
        }
        raw = s.ScalarExpr(
            s.CallNode(
                dtype=s.DataType('bigint'), op='PG_SLEEP', args=(s.int64(1).ast, )
            )
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.select([s.named('n', raw)]));
        }
        bad = s.Join(
            source=self.people.ref(), condition=s.boolean(False).ast, kind='CROSS'
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select([s.named('n', s.int64(1))], source=self.people, joins=[bad])
            );
        }
        with self.assertRaises(s.SqlError) {
            s.DataType('bigint', 'invalid');
        }
        source = s.cte(s.select([s.named('n', s.int64(1))]), materialized='invalid');
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select(
                    [s.named('n', source.col(s.field('n', s.int64_type())))],
                    source=source
                )
            );
        }
    }

    def test_lateral_values_reads_preceding_columns(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        relation = s.values(
            [key],
            [[self.people.col(self.id)], [s.add(self.people.col(self.id), s.int64(10))]]
        );
        src = relation.as_source(lateral=True);
        query = s.select(
            [s.named('id', self.people.col(self.id)), s.named('n', src.col(key))],
            source=self.people,
            joins=[s.cross_join(src)],
            order_by=[s.asc(self.people.col(self.id)), s.asc(src.col(key))]
        );
        self.assertEqual(
            self.execute(query), [(1, 1), (1, 11), (2, 2), (2, 12), (3, 3), (3, 13)]
        );
        ordinary = relation.as_source();
        with self.assertRaises(s.SqlError) {
            s.compile_sql(
                s.select(
                    [s.named('n', ordinary.col(key))],
                    source=self.people,
                    joins=[s.cross_join(ordinary)]
                )
            );
        }
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.select(s.project_all(src), source=src));
        }
    }

    def test_values_retains_outer_group_dependencies(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        source = s.values([key], [[self.people.col(self.id)]]).as_source(lateral=True);
        inner = s.limit_one(s.select([s.named('n', source.col(key))], source=source));
        result = s.scalar(inner, key);
        grouped = s.select(
            [
                s.named('id', self.people.col(self.id)),
                s.named('n', result),
                s.named('count', s.count())
            ],
            source=self.people,
            group_by=[self.people.col(self.id).ast],
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(self.execute(grouped), [(1, 1, 1), (2, 2, 1), (3, 3, 1)]);
        invalid = s.aggregate(
            [s.named('n', result), s.named('count', s.count())], source=self.people
        );
        with self.assertRaisesRegex(s.SqlError, 'GROUP BY') {
            s.compile_sql(invalid);
        }
        nested_source = s.values([key], [[self.people.col(self.id)]]).as_source();
        nested = s.limit_one(
            s.select([s.named('n', nested_source.col(key))], source=nested_source)
        );
        outer = s.select(
            [s.named('n', s.scalar(nested, key))],
            source=self.people,
            order_by=[s.asc(self.people.col(self.id))]
        );
        self.assertEqual(self.execute(outer), [(1, ), (2, ), (3, )]);
    }

    def test_recursive_window_group_aggregate_rejected(self: FeatureTests) -> object {
        key = s.field('n', s.int64_type());
        walk = s.cte_ref([key]);
        rank = s.row_number(order_by=[s.desc(s.count())]);
        step = s.select([s.named('n', rank)], source=walk);
        s.define_cte(
            walk,
            s.union_all(s.select([s.named('n', s.int64(1))]), step),
            recursive=True
        );
        with self.assertRaises(s.SqlError) {
            s.compile_sql(s.select(s.project_all(walk), source=walk));
        }
    }

    def test_boolean_or_aggregate(self: FeatureTests) -> object {
        query = s.aggregate(
            [s.named('any', s.bool_or(s.gt(self.people.col(self.id), s.int64(2))))],
            source=self.people
        );
        self.assertEqual(self.execute(query), [(True, )]);
        self.db.execute('DELETE FROM people');
        self.assertEqual(self.execute(query), [(None, )]);
        with self.assertRaises(s.SqlError) {
            s.bool_or(s.int64(1));
        }
    }

    def test_named_slot_array_bind(self: FeatureTests) -> object {
        ids = s.slot('ids', s.array_type(s.int64_type()));
        compiled = s.compile_sql(
            s.select(
                [s.named('id', self.people.col(self.id))],
                source=self.people,
                where=s.any_eq(self.people.col(self.id), ids),
                order_by=[s.asc(self.people.col(self.id))]
            )
        );
        first = compiled.bind({'ids': (1, 3)});
        first_rows: any = self.db.execute(first.sql, first.params);
        self.assertEqual(first_rows.fetchall(), [(1, ), (3, )]);
        second = compiled.bind({'ids': ()});
        second_rows: any = self.db.execute(second.sql, second.params);
        self.assertEqual(second_rows.fetchall(), []);
        self.assertEqual(first.params, {'ids': (1, 3)});
        with self.assertRaises(s.SqlError) {
            compiled.bind({'ids': (1, 'wrong')});
        }
    }
}

test "PostgreSQL features: boolean comparison and case" {
    run_case(FeatureTests("test_boolean_comparison_and_case"));
}

test "PostgreSQL features: nullable boolean semantics" {
    run_case(FeatureTests("test_nullable_boolean_semantics"));
}

test "PostgreSQL features: including empty membership" {
    run_case(FeatureTests("test_including_empty_membership"));
}

test "PostgreSQL features: strings and numeric types" {
    run_case(FeatureTests("test_strings_and_numeric_types"));
}

test "PostgreSQL features: array parameters and operations" {
    run_case(FeatureTests("test_array_parameters_and_operations"));
}

test "PostgreSQL features: array parameter quoting and validation" {
    run_case(FeatureTests("test_array_parameter_quoting_and_validation"));
}

test "PostgreSQL features: values relation and row validation" {
    run_case(FeatureTests("test_values_relation_and_row_validation"));
}

test "PostgreSQL features: lateral correlations and visibility" {
    run_case(FeatureTests("test_lateral_correlations_and_visibility"));
}

test "PostgreSQL features: left join null extension" {
    run_case(FeatureTests("test_left_join_null_extension"));
}

test "PostgreSQL features: left lateral join" {
    run_case(FeatureTests("test_left_lateral_join"));
}

test "PostgreSQL features: correlated unnest with ordinality" {
    run_case(FeatureTests("test_correlated_unnest_with_ordinality"));
}

test "PostgreSQL features: distinct and distinct on" {
    run_case(FeatureTests("test_distinct_and_distinct_on"));
}

test "PostgreSQL features: set operations and result ordering" {
    run_case(FeatureTests("test_set_operations_and_result_ordering"));
}

test "PostgreSQL features: null ordering" {
    run_case(FeatureTests("test_null_ordering"));
}

test "PostgreSQL features: integer aggregates and result types" {
    run_case(FeatureTests("test_integer_aggregates_and_result_types"));
}

test "PostgreSQL features: boolean and string aggregates" {
    run_case(FeatureTests("test_boolean_and_string_aggregates"));
}

test "PostgreSQL features: window ranking partition and count" {
    run_case(FeatureTests("test_window_ranking_partition_and_count"));
}

test "PostgreSQL features: window budget frames" {
    run_case(FeatureTests("test_window_budget_frames"));
}

test "PostgreSQL features: window validation" {
    run_case(FeatureTests("test_window_validation"));
}

test "PostgreSQL features: local cte dependencies and materialization" {
    run_case(FeatureTests("test_local_cte_dependencies_and_materialization"));
}

test "PostgreSQL features: local cte inside correlated lateral" {
    run_case(FeatureTests("test_local_cte_inside_correlated_lateral"));
}

test "PostgreSQL features: local cte scope rejections" {
    run_case(FeatureTests("test_local_cte_scope_rejections"));
}

test "PostgreSQL features: recursive local materialized frontier" {
    run_case(FeatureTests("test_recursive_local_materialized_frontier"));
}

test "PostgreSQL features: recursive union distinct and values anchor" {
    run_case(FeatureTests("test_recursive_union_distinct_and_values_anchor"));
}

test "PostgreSQL features: recursive nested derived and window" {
    run_case(FeatureTests("test_recursive_nested_derived_and_window"));
}

test "PostgreSQL features: recursive invalid reference placement" {
    run_case(FeatureTests("test_recursive_invalid_reference_placement"));
}

test "PostgreSQL features: recursive frontier dedup and windows" {
    run_case(FeatureTests("test_recursive_frontier_dedup_and_windows"));
}

test "PostgreSQL features: nullable case and set schemas" {
    run_case(FeatureTests("test_nullable_case_and_set_schemas"));
}

test "PostgreSQL features: recursive nullable parent column" {
    run_case(FeatureTests("test_recursive_nullable_parent_column"));
}

test "PostgreSQL features: raw wrapper cardinality is checked" {
    run_case(FeatureTests("test_raw_wrapper_cardinality_is_checked"));
}

test "PostgreSQL features: ancestor correlations and forward scope" {
    run_case(FeatureTests("test_ancestor_correlations_and_forward_scope"));
}

test "PostgreSQL features: two recursive ctes and window steps" {
    run_case(FeatureTests("test_two_recursive_ctes_and_window_steps"));
}

test "PostgreSQL features: distinct order variants and empty frames" {
    run_case(FeatureTests("test_distinct_order_variants_and_empty_frames"));
}

test "PostgreSQL features: typed ast rejections" {
    run_case(FeatureTests("test_typed_ast_rejections"));
}

test "PostgreSQL features: lateral values reads preceding columns" {
    run_case(FeatureTests("test_lateral_values_reads_preceding_columns"));
}

test "PostgreSQL features: values retains outer group dependencies" {
    run_case(FeatureTests("test_values_retains_outer_group_dependencies"));
}

test "PostgreSQL features: recursive window group aggregate rejected" {
    run_case(FeatureTests("test_recursive_window_group_aggregate_rejected"));
}

test "PostgreSQL features: boolean or aggregate" {
    run_case(FeatureTests("test_boolean_or_aggregate"));
}

test "PostgreSQL features: named slot array bind" {
    run_case(FeatureTests("test_named_slot_array_bind"));
}
