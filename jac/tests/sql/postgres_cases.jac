"""Run the same behavioral cases on an explicitly supplied disposable PostgreSQL.

JAC_SQL_PG_SOCKET=/path/to/.s.PGSQL.PORT jac test jac/tests/sql/test_postgres.jac
"""
import os;
import unittest;
import jaclang.sql as sql;
glob s: any = sql;
import from .sql_cases { SQLTests, run_case }
class Rows {
    def init(self: Rows, values: any) -> object {
        self.values = values;
    }

    def fetchall(self: Rows) -> object {
        return self.values;
    }

    def fetchone(self: Rows) -> object {
        return self.values[0] if self.values else None;
    }
}

class Database {
    def init(self: Database) -> object {
        import from jaclang.data.pgwire { PgWireConnection }
        self.connection = PgWireConnection(
            user='sql_test',
            unix_sock=os.environ['JAC_SQL_PG_SOCKET'],
            database='postgres'
        );
        self.connection.run('BEGIN');
    }

    def execute(self: Database, sql: any, params: any = None) -> object {
        return Rows(self.connection.run(sql, **(params or {})));
    }

    def executescript(self: Database, script: any) -> object {
        for statement in script.split(';') {
            if statement.strip() {
                self.connection.run(statement);
            }
        }
    }

    def close(self: Database) -> object {
        try {
            self.connection.run('ROLLBACK');
        } finally {
            self.connection.close();
        }
    }
}

@unittest.skipUnless(
    os.environ.get('JAC_SQL_PG_SOCKET'), 'Set socket of a disposable SQL test cluster'
)
class PostgresTests(SQLTests) {
    def setUp(self: PostgresTests) -> object {
        self.id = s.field('id', s.int64_type());
        self.age = s.field('age', s.int64_type());
        self.name = s.field('name', s.text_type());
        self.people = s.table('people', [self.id, self.age, self.name], 'p');
        self.db = Database();
        self.addCleanup(self.db.close);
        self.db.executescript(
            'CREATE TEMP TABLE people(id BIGINT, age BIGINT, name TEXT);'
            "INSERT INTO people VALUES(1,20,'Ann'),(2,40,'Bob'),(3,40,'Cora');"
        );
    }
}
