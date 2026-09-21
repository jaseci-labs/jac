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


test "standalone files without a project remain separate applications" {
    import from tempfile { TemporaryDirectory }
    with TemporaryDirectory() as td {
        first = Path(td) / 'first.jac';
        second = Path(td) / 'second.jac';
        first.write_text('with entry {}');
        second.write_text('with entry {}');
        assert project_db_name(td, str(first)) != project_db_name(td, str(second));
    }
}

test "nested service entries select one application database" {
    import from tempfile { TemporaryDirectory }
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text('[project]\nname="one-application"\n');
        for service in ['writer', 'reader'] {
            (base / service).mkdir();
            (base / service / 'main.jac').write_text('with entry {}');
        }
        writer = str(base / 'writer' / 'main.jac');
        reader = str(base / 'reader' / 'main.jac');
        expected = project_db_name(td, writer);
        assert project_db_name(td, reader) == expected;
        assert project_db_name(str(base / 'writer'), writer) == expected;
        assert project_db_name(str(base / 'reader'), reader) == expected;
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
