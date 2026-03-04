"""Tests for standalone-file DB naming fix (bug #4401).

Verifies that:
  1. running simple_persistent.jac creates simple_persistent.db (not main.db)
  2. running simple_node_connection.jac creates simple_node_connection.db
  3. running simple_persistent.jac a second time does NOT error
     (previously crashed with "pop from empty list" due to DB state mismatch)
"""

import os;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "different standalone files get separate db files" {
    db_dir = Path(FIXTURES) / ".jac" / "data";
    db_persistent = db_dir / "simple_persistent.db";
    db_connection = db_dir / "simple_node_connection.db";

    _orig_base = Jac.base_path_dir;
    try {
        Jac.set_base_path(FIXTURES);

        # Run first file
        execution.run(filename=os.path.join(FIXTURES, "simple_persistent.jac"));
        assert db_persistent.exists() , f"Expected {db_persistent} to exist";

        # Run second file
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        assert db_connection.exists() , f"Expected {db_connection} to exist";

        rc = execution.run(filename=os.path.join(FIXTURES, "simple_persistent.jac"));
        assert rc == 0 , (
            f"Second run of simple_persistent.jac file failed with return code {rc} - bug #4401 regression"
        );

        # Both should be separate files
        assert db_persistent != db_connection;
        assert db_persistent.exists() and db_connection.exists() , (
            "Both DB files should exist independently"
        );
        assert not (db_dir / "main.db").exists() , (
            "main.db should not exist for a standalone named file"
        );
    } finally {
        Jac.set_base_path(_orig_base);
        for f in [db_persistent, db_connection] {
            if f.exists() {
                f.unlink();
            }
        }
    }
}

test "running file with same name as project uses project DB name" {
    db_dir = Path(FIXTURES) / ".jac" / "data";
    db_project = db_dir / "test_db_naming.db";
    file_path = Path(FIXTURES) / "test_project";

    _orig_base = Jac.base_path_dir;
    try {
        Jac.set_base_path(FIXTURES);

        # Run the file in a subdirectory with a jac.toml that has the same name as the file (test_project)
        execution.run(filename=os.path.join(file_path, "main.jac"));
        assert db_project.exists() , f"Expected {db_project} to exist";
    } finally {
        Jac.set_base_path(_orig_base);
        if db_project.exists() {
            db_project.unlink();
        }
    }
}
