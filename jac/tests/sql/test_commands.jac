"""Statement rendering and execution on an explicitly supplied disposable PostgreSQL."""
import os;
import unittest;
import jaclang.sql as s;
import from .sql_cases { run_case }
import from .postgres_cases { Database }

class CommandTests(unittest.TestCase) {
    def test_write_bindings(self: CommandTests) -> object {
        idf = s.field('id', s.int64_type());
        name = s.field('name', s.text_type());
        people = s.table('people', [idf, name]);
        value = s.slot('name', s.text_type());
        compiled = s.compile_command(
            s.insert_into(
                people,
                [idf, name],
                [[s.int64(1).ast, value.ast]],
                returning=[s.named('id', people.col(idf))]
            )
        );
        self.assertIn('INSERT INTO "people" AS "_t0"', compiled.sql);
        self.assertIn('RETURNING "_t0"."id" AS "id"', compiled.sql);
        self.assertIn('CAST(:name AS text)', compiled.sql);
        bound = compiled.bind({'name': "a'); DROP TABLE people; --"});
        self.assertNotIn('DROP TABLE', bound.sql);
        self.assertEqual(bound.params['name'], "a'); DROP TABLE people; --");
        self.assertEqual(compiled.params, {'p0': 1});
        self.assertFalse(hasattr(compiled, 'ast'));
        self.assertEqual(
            s.compile_sql(s.delete_from(people)).sql, 'DELETE FROM "people" AS "_t0"'
        );
    }

    def test_invalid_shapes(self: CommandTests) -> object {
        key = s.field('id', s.int64_type());
        target = s.table('people', [key]);
        with self.assertRaises(s.SqlError) {
            s.insert_into(target, [key], []);
        }
        with self.assertRaises(s.SqlError) {
            s.insert_into(target, [key], [[]]);
        }
        with self.assertRaises(s.SqlError) {
            s.insert_into(target, [key, key], [[s.int64(1).ast, s.int64(2).ast]]);
        }
        with self.assertRaises(s.SqlError) {
            s.update(target, []);
        }
        with self.assertRaises(s.SqlError) {
            s.create_table(target, []);
        }
        with self.assertRaises(s.SqlError) {
            s.create_index(target, 'idx', []);
        }
        with self.assertRaises(s.SqlError) {
            s.truncate_tables([]);
        }
        with self.assertRaises(s.SqlError) {
            s.delete_from(s.select([s.named('id', s.int64(1))]).as_source());
        }
        with self.assertRaises(s.SqlError) {
            s.insert_select(target, [key, key], s.select([s.named('id', s.int64(1))]));
        }
    }

    def test_ddl_quotes_names(self: CommandTests) -> object {
        key = s.field('a"b', s.int64_type());
        target = s.table('t"; DROP TABLE x; --', [key], namespace='odd"schema');
        sql = s.compile_command(
            s.create_table(
                target, [s.column_def(key, primary_key=True)], if_not_exists=True
            )
        ).sql;
        self.assertEqual(
            sql,
            'CREATE TABLE IF NOT EXISTS "odd""schema"."t""; DROP TABLE x; --" ("a""b" bigint NOT NULL PRIMARY KEY)'
        );
        self.assertIn(
            '"idx""name"',
            s.compile_command(
                s.create_index(target, 'idx"name', [key], unique=True)
            ).sql
        );
        self.assertEqual(
            s.compile_command(
                s.drop_index('ix', namespace='public', if_exists=True)
            ).sql,
            'DROP INDEX IF EXISTS "public"."ix"'
        );
    }

    def test_ctes_and_slot_collisions(self: CommandTests) -> object {
        key = s.field('id', s.int64_type());
        target = s.table('out', [key]);
        ref = s.cte(s.select([s.named('id', s.slot('p0', s.int64_type()))]));
        query = s.select(s.project_all(ref), source=ref);
        compiled = s.compile_command(
            s.insert_select(
                target, [key], query, returning=[s.named('extra', s.int64(9))]
            )
        );
        self.assertTrue(compiled.sql.startswith('WITH '));
        self.assertIn('INSERT INTO "out"', compiled.sql);
        self.assertNotIn('p0', compiled.params);
        self.assertEqual(compiled.bind({'p0': 7}).params, {'p1': 9, 'p0': 7});
        with self.assertRaises(s.SqlError) {
            s.compile_command(
                s.update(
                    target,
                    [s.assign(key, s.slot('x', s.int64_type()))],
                    returning=[s.named('bad', s.slot('x', s.text_type()))]
                )
            );
        }
    }
}

@unittest.skipUnless(
    os.environ.get('JAC_SQL_PG_SOCKET'), 'Set socket of a disposable SQL test cluster'
)
class CommandPostgresTests(unittest.TestCase) {
    def setUp(self: CommandPostgresTests) -> object {
        self.db: any = Database();
        self.idf = s.field('id', s.int64_type());
        self.name = s.field('name', s.text_type());
        self.target = s.table('sql_command_people', [self.idf, self.name]);
        self.execute(
            s.create_table(
                self.target,
                [s.column_def(self.idf, primary_key=True), s.column_def(self.name)]
            )
        );
    }

    def tearDown(self: CommandPostgresTests) -> object {
        self.db.close();
    }

    def execute(self: CommandPostgresTests, command: s.Command) -> any {
        compiled = s.compile_command(command);
        return self.db.execute(compiled.sql, compiled.params).fetchall();
    }

    def test_crud(self: CommandPostgresTests) -> object {
        t = self.target;
        returning = [s.named('id', t.col(self.idf)), s.named('name', t.col(self.name))];
        result = self.execute(
            s.insert_into(
                t,
                [self.idf, self.name],
                [
                    [s.int64(1).ast, s.text("O'Reilly").ast],
                    [s.int64(2).ast, s.text('other').ast]
                ],
                returning=returning
            )
        );
        self.assertEqual(result, [(1, "O'Reilly"), (2, 'other')]);
        self.assertEqual(
            self.execute(
                s.update(
                    t,
                    [s.assign(self.name, s.text('new'))],
                    where=s.eq(t.col(self.idf), s.int64(1)),
                    returning=returning
                )
            ),
            [(1, 'new')]
        );
        self.assertEqual(
            self.execute(
                s.delete_from(
                    t, where=s.eq(t.col(self.idf), s.int64(2)), returning=returning
                )
            ),
            [(2, 'other')]
        );
        self.assertEqual(
            self.db.execute('SELECT id,name FROM sql_command_people').fetchall(),
            [(1, 'new')]
        );
    }

    def test_insert_select_cte(self: CommandPostgresTests) -> object {
        ref = s.cte(
            s.select([s.named('id', s.int64(3)), s.named('name', s.text('cte'))])
        );
        query = s.with_ctes(s.select(s.project_all(ref), source=ref), [ref]);
        self.assertEqual(
            self.execute(
                s.insert_select(
                    self.target,
                    [self.idf, self.name],
                    query,
                    returning=[s.named('id', self.target.col(self.idf))]
                )
            ),
            [(3, )]
        );
        ref2 = s.cte(
            s.select([s.named('id', s.int64(4)), s.named('name', s.text('auto'))])
        );
        self.execute(
            s.insert_select(
                self.target,
                [self.idf, self.name],
                s.select(s.project_all(ref2), source=ref2)
            )
        );
        self.assertEqual(
            self.db.execute('SELECT id FROM sql_command_people ORDER BY id').fetchall(),
            [(3, ), (4, )]
        );
    }

    def test_schema_changes(self: CommandPostgresTests) -> object {
        t = self.target;
        extra = s.field('extra', s.nullable(s.text_type()));
        self.execute(s.create_table(t, [s.column_def(self.idf)], if_not_exists=True));
        self.execute(
            s.create_index(
                t, 'sql_command_people_ix', [self.name], unique=True, if_not_exists=True
            )
        );
        self.execute(s.add_column(t, s.column_def(extra)));
        self.execute(s.rename_column(t, 'extra', 'renamed'));
        self.execute(s.drop_column(t, 'renamed'));
        self.execute(s.truncate_tables([t], restart_identity=True));
        self.execute(s.drop_index('sql_command_people_ix', if_exists=True));
        self.execute(s.rename_table(t, 'sql_command_people_renamed'));
        renamed = s.table('sql_command_people_renamed', [self.idf, self.name]);
        self.execute(s.drop_table(renamed, if_exists=True, cascade=True));
        self.execute(s.drop_table(renamed, if_exists=True));
    }

    def test_default_and_subquery_update(self: CommandPostgresTests) -> object {
        nullable_key = s.field('n', s.nullable(s.int64_type()));
        defaults = s.table('sql_command_defaults', [nullable_key]);
        self.execute(s.create_table(defaults, [s.column_def(nullable_key)]));
        self.assertEqual(
            self.execute(
                s.insert_default(
                    defaults, returning=[s.named('n', defaults.col(nullable_key))]
                )
            ),
            [(None, )]
        );
        c = s.cte(s.select([s.named('name', s.text('from cte'))]));
        self.execute(
            s.insert_into(
                self.target,
                [self.idf, self.name],
                [[s.int64(1).ast, s.text('old').ast]]
            )
        );
        value = s.scalar_one(
            s.aggregate([s.named('name', s.count())]), s.field('name', s.int64_type())
        );
        self.assertEqual(
            self.execute(
                s.update(
                    self.target,
                    [s.assign(self.idf, value)],
                    returning=[s.named('id', self.target.col(self.idf))]
                )
            ),
            [(1, )]
        );
        query = s.limit_one(s.select(s.project_all(c), source=c));
        # Nullable scalar output uses an explicitly nullable destination field.
        nullable_name = s.field('name', s.nullable(s.text_type()));
        self.assertEqual(
            self.execute(
                s.update(
                    self.target,
                    [
                        s.assign(
                            nullable_name,
                            s.scalar(query, s.field('name', s.text_type()))
                        )
                    ],
                    returning=[s.named('name', self.target.col(self.name))]
                )
            ),
            [('from cte', )]
        );
    }
}

test "SQL commands: write bindings" {
    run_case(CommandTests('test_write_bindings'));
}

test "SQL commands: invalid shapes" {
    run_case(CommandTests('test_invalid_shapes'));
}

test "SQL commands: DDL quoting" {
    run_case(CommandTests('test_ddl_quotes_names'));
}

test "SQL commands: CTE planning and slots" {
    run_case(CommandTests('test_ctes_and_slot_collisions'));
}

test "PostgreSQL commands: CRUD" {
    run_case(CommandPostgresTests('test_crud'));
}

test "PostgreSQL commands: INSERT SELECT" {
    run_case(CommandPostgresTests('test_insert_select_cte'));
}

test "PostgreSQL commands: schema changes" {
    run_case(CommandPostgresTests('test_schema_changes'));
}

test "PostgreSQL commands: defaults and subqueries" {
    run_case(CommandPostgresTests('test_default_and_subquery_update'));
}
