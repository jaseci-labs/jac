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


test "a project database is owned by its project root, not a service directory" {
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.server.session { runtime_for_base }
    project_only = {
        k: v
        for (k, v) in os.environ.items()
        if k not in ('JAC_DB_SCRATCH', 'JAC_DB_SCRATCH_OWNER')
    };
    with patch.dict(os.environ, project_only, clear=True), TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text('[project]\nname="one-application"\n');
        (base / 'writer').mkdir();
        writer = str(base / 'writer' / 'main.jac');
        Path(writer).write_text('with entry {}');
        runtime = runtime_for_base(str(base / 'writer'), writer).runtime;
        assert runtime.owner_path == os.path.realpath(td);
        assert runtime.sole_owner_database;
        assert runtime.database == project_db_name(td, writer);
    }
    with patch.dict(os.environ, project_only, clear=True), TemporaryDirectory() as td {
        standalone = str(Path(td) / 'main.jac');
        Path(standalone).write_text('with entry {}');
        assert not runtime_for_base(td, standalone).runtime.sole_owner_database;
    }
}

test "creating a database for a renamed project names the database it replaces" {
    import logging;
    import from unittest.mock { patch }
    import from jaclang.data { dbcatalog }
    import from jaclang.data.dbcatalog { DbRecord }
    runtime = PgRuntime(
        data_dir='/unused',
        database='jac_renamed_665bae49',
        owner_path='/srv/app',
        sole_owner_database=True
    );
    records = [
        DbRecord(
            database='jac_renamed_665bae49', kind='project', owner_path='/srv/app'
        ),
        DbRecord(
            database='jac_original_665bae49', kind='project', owner_path='/srv/app'
        ),
        DbRecord(database='jac_scratch_1', kind='scratch', owner_path='/srv/app'),
        DbRecord(database='jac_elsewhere_1', kind='project', owner_path='/srv/other')
    ];
    captured: list[str] = [];
    class Capture(logging.Handler) {
        def emit(self: Capture, record: logging.LogRecord) {
            captured.append(record.getMessage());
        }
    }
    handler = Capture();
    logger = logging.getLogger('jaclang.data.pgembed');
    logger.addHandler(handler);
    try {
        with patch.object(dbcatalog, 'list_databases', return_value=records) {
            runtime._warn_superseded(None);
        }
    } finally {
        logger.removeHandler(handler);
    }
    assert len(captured) == 1 , captured;
    assert 'jac_original_665bae49' in captured[0];
    assert 'jac_scratch_1' not in captured[0];
    assert 'jac_elsewhere_1' not in captured[0];
    assert '[persistence] namespace' in captured[0];
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
