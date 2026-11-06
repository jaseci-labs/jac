"""Drops its own database on the first schema stamp read, so the reconnect inside
ensure_schema recreates the database while the schema gate is held."""

import os;
import sys;
import from pathlib { Path }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { shared_pg_data_dir, project_db_name }
import from jaclang.data.store { PgStore }

obj DropMidSchemaStore(PgStore) {
    has rt: (PgRuntime | None) = None,
        dropped: bool = False;

    def _schema_stamp -> (str | None) {
        if not self.dropped and self.rt is not None {
            self.dropped = True;
            self.rt.drop_database(self.conninfo.database, force=True);
        }
        return super._schema_stamp();
    }
}

glob td = os.environ["JAC_SCHEMA_TEST_DIR"];

with entry {
    rt = PgRuntime(
        data_dir=shared_pg_data_dir(),
        database=project_db_name(td, str(Path(td) / "app.jac")),
        owner_path=td
    );
    info = rt.ensure();
    store = DropMidSchemaStore(conninfo=info, ensure_cb=rt.ensure, rt=rt);
    try {
        store.ensure_schema_once({});
        anchors = bool(
            store.rows("SELECT to_regclass('anchors') IS NOT NULL", {})[0][0]
        );
        sys.stdout.write(f"dropped={store.dropped} anchors={anchors}\n");
    } finally {
        store.close();
        rt.drop_database(info.database, force=True);
    }
}
