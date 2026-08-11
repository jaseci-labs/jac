import logging;
import os;
import threading;
import from typing { Any }

glob logger = logging.getLogger(__name__),
     _lock = threading.Lock(),
     _holder: dict[str, Any] = {},
     _DOCS_DDL = (
         'CREATE TABLE IF NOT EXISTS jac_docs ('
         'collection text NOT NULL, '
         'id text NOT NULL, '
         'doc jsonb NOT NULL, '
         'PRIMARY KEY (collection, id))'
     ),
     __all__ = ['scale_db_url', 'shared_store', 'open_docs_store'];


def open_docs_store -> (Any | None) {
    store = shared_store();
    if store is None {
        return None;
    }
    store.rows(_DOCS_DDL, {});
    return store;
}


def scale_db_url -> (str | None) {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        return url;
    }
    try {
        import from jaclang.scale.config.plugin_config { get_scale_config }
        cfg = get_scale_config().get_database_config();
        got = cfg.get('url') or cfg.get('postgres_url');
        return str(got) if got else None;
    } except Exception {
        return None;
    }
}


def shared_store -> (Any | None) {
    with _lock {
        import from jaclang.jac0core.runtime { JacRuntime }
        url = scale_db_url();
        key = url
            or (
                f"{JacRuntime.get_base_path_dir() or ''}"
                f"::{JacRuntime.get_full_target_path() or ''}"
            );
        if _holder.get('key') == key and 'store' in _holder {
            return _holder['store'];
        }
        old_store: Any = _holder.pop('store', None);
        if old_store is not None {
            try {
                old_store.close();
            } except Exception { }
        }
        store: (Any | None) = None;
        try {
            import from jaclang.runtimelib.session { conninfo_from_url }
            import from jaclang.runtimelib.store { PgStore }
            if url {
                store = PgStore(conninfo=conninfo_from_url(url));
            } else {
                import from jaclang.runtimelib.pgembed { PgRuntime }
                import from jaclang.runtimelib.session {
                    project_db_name,
                    shared_pg_data_dir
                }
                base = JacRuntime.get_base_path_dir();
                if base {
                    rt = PgRuntime(
                        data_dir=shared_pg_data_dir(),
                        database=project_db_name(
                            base, JacRuntime.get_full_target_path()
                        )
                    );
                    store = PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
                }
            }
            if store is not None {
                store.ensure_schema({});
            }
        } except Exception as e {
            logger.warning(f"scale shared store unavailable: {e}");
            _holder['key'] = key;
            _holder['store'] = None;
            return None;
        }
        _holder['key'] = key;
        _holder['store'] = store;
        return store;
    }
}
