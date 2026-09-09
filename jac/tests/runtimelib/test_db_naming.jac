"""Tests for standalone-file DB naming (bug #4401, ported to Postgres).

Verifies that:
  1. running simple_persistent.jac and simple_node_connection.jac lands
     each file in its own database on the shared embedded server
  2. running simple_persistent.jac a second time does NOT error
     (previously crashed with "pop from empty list" due to DB state mismatch)
  3. a file inside a project directory uses the project name from jac.toml
"""

import os;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { project_db_name, shared_pg_data_dir }
import from jaclang.data.store { PgStore, TxnIsolation }

glob FIXTURES = str(Path(__file__).parent / "fixtures");


def _database_names -> list[str] {
    rt = PgRuntime(data_dir=shared_pg_data_dir(), database="postgres");
    st = PgStore(conninfo=rt.ensure());
    st.begin(TxnIsolation.READ_COMMITTED);
    names = [str(r[0]) for r in st.rows("SELECT datname FROM pg_database", {})];
    st.commit();
    st.close();
    return names;
}


test "different standalone files get separate databases" {
    db_persistent = project_db_name(
        FIXTURES, os.path.join(FIXTURES, "simple_persistent.jac")
    );
    db_connection = project_db_name(
        FIXTURES, os.path.join(FIXTURES, "simple_node_connection.jac")
    );
    assert db_persistent != db_connection , (
        "Standalone files must map to distinct databases"
    );
    assert db_persistent.startswith("jac_simple_persistent_");
    assert db_connection.startswith("jac_simple_node_connection_");

    _orig_base = Jac.get_base_path_dir();
    try {
        Jac.set_base_path(FIXTURES);

        # The database is provisioned by the first access to persistent state,
        # so these files have to actually touch the graph: simple_persistent
        # declares walkers only, hence the explicit spawn.
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"), entry_name="create"
        );
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));

        rc = execution.run(target=os.path.join(FIXTURES, "simple_persistent.jac"));
        assert rc == 0 , (
            f"Second run of simple_persistent.jac file failed with return code {rc} - bug #4401 regression"
        );

        names = _database_names();
        assert db_persistent in names , (
            f"Expected database {db_persistent} on the shared server"
        );
        assert db_connection in names , (
            f"Expected database {db_connection} on the shared server"
        );
    } finally {
        Jac.set_base_path(_orig_base);
    }
}


test "running file with same name as project uses project DB name" {
    file_path = Path(FIXTURES) / "test_project";

    _orig_base = Jac.get_base_path_dir();
    try {
        Jac.set_base_path(FIXTURES);

        execution.run(target=os.path.join(file_path, "main.jac"), entry_name="create");

        # jac.toml names the project test_db_naming; the database carries
        # that name (suffixed with the base-path digest), not "main".
        matches = [
            n
            for n in _database_names()
            if n.startswith("jac_test_db_naming_")
        ];
        assert matches , "Expected a jac_test_db_naming_* database on the shared server";
    } finally {
        Jac.set_base_path(_orig_base);
    }
}
