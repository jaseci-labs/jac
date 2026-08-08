import json;
import logging;
import from typing { Any }
import from jaclang.scale.persistence.pg { shared_store }

glob logger = logging.getLogger(__name__),
     _DOCS_SCHEMA = """
     CREATE TABLE IF NOT EXISTS jac_docs (
         collection text NOT NULL,
         id         text NOT NULL,
         doc        jsonb NOT NULL,
         PRIMARY KEY (collection, id)
     )
     """;


def _jsonable(o: any) -> str {
    return str(o);
}


obj _OpResult {
    has modified_count: int = 0,
        deleted_count: int = 0;
}


obj _Cursor {
    has docs: list = [];

    def skip(n: int) -> _Cursor {
        return _Cursor(docs=self.docs[n:]);
    }

    def limit(n: int) -> _Cursor {
        return _Cursor(docs=self.docs[:n]);
    }

    def __iter__ -> Any {
        return iter(self.docs);
    }
}


obj _ColShim {
    def create_index(*args: Any, **kwargs: Any) { }
}


obj PgDocDb {
    has store: Any;

    def postinit {
        self.store.rows(_DOCS_SCHEMA, {});
    }

    def _get_mongo_collection(collection: str) -> _ColShim {
        return _ColShim();
    }

    def create_index(*args: Any, **kwargs: Any) { }
    def _match_sql(filter: dict, params: dict) -> str {
        conds: list[str] = [];
        n = 0;
        for (k, v) in (filter or {}).items() {
            key = f"f{n}";
            n += 1;
            if k == '_id' {
                params[key] = str(v);
                conds.append(f"id = :{key}");
            } else {
                params[key] = json.dumps(v, default=_jsonable);
                conds.append(f"doc->'{k}' = CAST(:{key} AS jsonb)");
            }
        }
        return (' AND ' + ' AND '.join(conds)) if conds else '';
    }

    def insert_one(collection: str, doc: dict) {
        d = dict(doc);
        id = str(d.get('_id') or d.get('job_id') or d.get('id') or '');
        assert id , 'PgDocDb.insert_one needs an _id/job_id/id field';
        self.store.rows(
            """
            INSERT INTO jac_docs (collection, id, doc)
            VALUES (:c, :i, CAST(:d AS jsonb))
            ON CONFLICT (collection, id) DO UPDATE SET doc = EXCLUDED.doc
            """,
            {'c': collection, 'i': id, 'd': json.dumps(d, default=_jsonable)}
        );
    }

    def _load(
        collection: str, filter: dict, params_extra: (str | None) = None
    ) -> list {
        params: dict = {'c': collection};
        cond = self._match_sql(filter, params);
        rows = self.store.rows(
            f"SELECT id, doc FROM jac_docs WHERE collection = :c{cond} ORDER BY id",
            params
        );
        out: list = [];
        for (rid, doc) in rows {
            d = doc if isinstance(doc, dict) else json.loads(str(doc));
            d['_id'] = d.get('_id') or str(rid);
            out.append(d);
        }
        return out;
    }

    def find(
        collection: str, filter: dict = {}, projection: (dict | None) = None
    ) -> _Cursor {
        return _Cursor(docs=self._load(collection, filter));
    }

    def find_one(
        collection: str, filter: dict = {}, projection: (dict | None) = None
    ) -> (dict | None) {
        got = self._load(collection, filter);
        return got[0] if got else None;
    }

    def count_documents(collection: str, filter: dict = {}) -> int {
        return len(self._load(collection, filter));
    }

    def update_one(collection: str, filter: dict, update: dict) -> _OpResult {
        docs = self._load(collection, filter);
        if not docs {
            return _OpResult();
        }
        d = docs[0];
        for (k, v) in (update.get('$set') or {}).items() {
            d[k] = v;
        }
        for (k, v) in (update.get('$inc') or {}).items() {
            cur: Any = d.get(k) or 0;
            inc: Any = v;
            d[k] = cur + inc;
        }
        self.insert_one(collection, d);
        return _OpResult(modified_count=1);
    }

    def delete_one(collection: str, filter: dict) -> _OpResult {
        docs = self._load(collection, filter);
        if not docs {
            return _OpResult();
        }
        self.store.rows(
            'DELETE FROM jac_docs WHERE collection = :c AND id = :i',
            {'c': collection, 'i': str(docs[0]['_id'])}
        );
        return _OpResult(deleted_count=1);
    }

    def delete_many(collection: str, filter: dict) -> _OpResult {
        docs = self._load(collection, filter);
        for d in docs {
            self.store.rows(
                'DELETE FROM jac_docs WHERE collection = :c AND id = :i',
                {'c': collection, 'i': str(d['_id'])}
            );
        }
        return _OpResult(deleted_count=len(docs));
    }
}


def open_doc_db -> (PgDocDb | None) {
    try {
        store = shared_store();
        return PgDocDb(store=store) if store is not None else None;
    } except Exception as e {
        logger.warning(f"document db unavailable: {e}");
        return None;
    }
}
