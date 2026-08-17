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
     _SECRET_KEYWORDS = ('password', 'sslpassword'),
     __all__ = [
         'scale_db_url',
         'mask_db_url',
         'masked_db_url',
         'shared_store',
         'shared_store_error',
         'open_docs_store'
     ];


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


def mask_db_url(url: str) -> str {
    if not url {
        return '';
    }
    import from urllib.parse { parse_qsl, urlencode, urlsplit, urlunsplit }
    try {
        parts = urlsplit(url);
    } except Exception {
        return '***';
    }
    if not parts.scheme and not parts.netloc {
        return _mask_keyword_dsn(url);
    }
    netloc = parts.netloc;
    if '@' in netloc {
        netloc = f"***@{netloc.rsplit('@', 1)[1]}";
    }
    query = parts.query;
    if query {
        try {
            query = urlencode(
                [
                    (k, ('***' if k.strip().lower() in _SECRET_KEYWORDS else v))
                    for (k, v) in parse_qsl(query, keep_blank_values=True)
                ],
                safe='*'
            );
        } except Exception {
            query = '***';
        }
    }
    body = urlunsplit(('', '', parts.path, query, parts.fragment));
    if netloc or '://' in url {
        return f"{parts.scheme}://{netloc}{body}";
    }
    return f"{parts.scheme}:{body}";
}


def _mask_keyword_dsn(dsn: str) -> str {
    import re;
    keys = '|'.join(_SECRET_KEYWORDS);
    return re.sub(rf"(?i)\b({keys})\s*=\s*('(?:[^'\\]|\\.)*'|\S*)", r"\1=***", dsn);
}


def masked_db_url -> str {
    return mask_db_url(scale_db_url() or '');
}


def shared_store_error -> (Exception | None) {
    err = _holder.get('error');
    return err if isinstance(err, Exception) else None;
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
        reset = False;
        try {
            import from jaclang.runtimelib.session { conninfo_from_url, promotions_for }
            import from jaclang.runtimelib.store { PgStore }
            promotions = promotions_for(JacRuntime.get_base_path_dir());
            if url {
                store = PgStore(conninfo=conninfo_from_url(url), promotions=promotions);
            } else {
                import from jaclang.runtimelib.session { runtime_for_base }
                base = JacRuntime.get_base_path_dir();
                if base {
                    lease = runtime_for_base(base, JacRuntime.get_full_target_path());
                    rt = lease.runtime;
                    store = PgStore(
                        conninfo=rt.ensure(), ensure_cb=rt.ensure, promotions=promotions
                    );
                    reset = lease.reset;
                }
            }
            if store is not None {
                store.ensure_schema_once(promotions);
                if reset {
                    store.reset_data();
                }
            }
        } except Exception as e {
            target = masked_db_url() or 'the embedded server';
            logger.warning(f"scale shared store unavailable at {target}: {e!r}");
            _holder['key'] = key;
            _holder['store'] = None;
            _holder['error'] = e;
            return None;
        }
        _holder['key'] = key;
        _holder['store'] = store;
        _holder['error'] = None;
        return store;
    }
}
