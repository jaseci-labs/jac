"""Guards #8000 Part 2 / follow-up 2C: PgJobStore talks direct SQL.

The deleted Mongo-shaped shim loaded the whole active-job set twice per page
and paginated in Python, injected a Mongo `_id` into every document (which
leaked into GET /jobs payloads), and did SELECT -> mutate -> whole-doc upsert
so concurrent record_run calls lost counts and CAS-guarded updates could win
on two pods at once. These tests drive the rewritten store against a real
embedded Postgres: pagination and counting happen in SQL, no `_id` is ever
fabricated, updates are single-statement atomic, and the webhook api-key
user_id index actually exists in the catalog (issue 1.4).
"""

import json;
import threading;
import from tempfile { mkdtemp }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.store { PgStore }
import from jaclang.scale.scheduler.scheduler { PgJobStore }
import from jaclang.scale.webhook.webhook { ApiKeyManager }

glob _holder: dict = {},
     _DOCS_DDL = (
         'CREATE TABLE IF NOT EXISTS jac_docs ('
         'collection text NOT NULL, id text NOT NULL, doc jsonb NOT NULL, '
         'PRIMARY KEY (collection, id))'
     );


def _store -> (PgStore | None) {
    try {
        if 'rt' not in _holder {
            _holder['rt'] = PgRuntime(data_dir=mkdtemp(prefix='jacjs_') + '/data');
        }
        store = PgStore(conninfo=_holder['rt'].ensure());
        store.rows(_DOCS_DDL, {});
        return store;
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


def _job(job_id: str, **over: any) -> dict {
    base = {
        'job_id': job_id,
        'name': 'tick',
        'created_by': 'user-a',
        'is_walker': True,
        'created_at': '2026-01-01T00:00:00+00:00',
        'status': 'active',
        'trigger': 'interval',
        'interval': 60.0,
        'cron': None,
        'date': None
    };
    base.update(over);
    return base;
}


test "pagination and counting happen in SQL and no _id is fabricated" {
    store = _store();
    if store is None {
        return;
    }
    js = PgJobStore(store=store, _collection='jobs_page');
    for n in range(5) {
        js.insert(_job(f"j{n}"));
    }
    js.insert(_job('j5', status='orphaned'));

    (page, total) = js.find_active(limit=2, offset=2);
    assert total == 5;
    assert [j['job_id'] for j in page] == ['j2', 'j3'];
    for j in page {
        assert '_id' not in j , 'the Mongo _id leak is back';
    }

    (filtered, ftotal) = js.find_active(created_by='user-a', trigger='interval');
    assert ftotal == 5;
    (none_page, ntotal) = js.find_active(created_by='nobody');
    assert (none_page, ntotal) == ([], 0);

    one = js.find_active_one('j1');
    assert one is not None and one['job_id'] == 'j1' and '_id' not in one;
    assert js.find_active_one('j5') is None , 'non-active jobs must not resolve';
}


test "CAS-guarded update wins exactly once and preserves untouched fields" {
    store = _store();
    if store is None {
        return;
    }
    js = PgJobStore(store=store, _collection='jobs_cas');
    js.insert(_job('cas1', interval=15.0));

    first = js.update(
        'cas1',
        {'status': 'orphaned', 'orphaned_at': 'sometime'},
        where={'status': 'active'}
    );
    second = js.update('cas1', {'status': 'orphaned'}, where={'status': 'active'});
    assert first is True;
    assert second is False , 'CAS filter must be evaluated in the same statement';

    raw = store.rows(
        "SELECT doc FROM jac_docs WHERE collection = 'jobs_cas' AND id = 'cas1'", {}
    )[0][0];
    doc = raw if isinstance(raw, dict) else json.loads(str(raw));
    assert doc['interval'] == 15.0 , 'partial update must not clobber other fields';
    assert doc['status'] == 'orphaned';

    assert js.update('cas1', {'x': 1}, where={'created_by': 'someone-else'}) is False;
    assert js.delete('cas1', where={'created_by': 'someone-else'}) is False;
    assert js.delete('cas1', where={'created_by': 'user-a'}) is True;
    assert js.delete('cas1') is False;
}


test "concurrent record_run from two connections never loses a count" {
    store_a = _store();
    if store_a is None {
        return;
    }
    store_b = _store();
    a = PgJobStore(store=store_a, _collection='jobs_inc');
    b = PgJobStore(store=store_b, _collection='jobs_inc');
    a.insert(_job('inc1'));

    def hammer(js: PgJobStore) {
        for _ in range(10) {
            js.record_run('inc1', 'succeeded');
        }
    }
    ta = threading.Thread(target=hammer, args=(a, ));
    tb = threading.Thread(target=hammer, args=(b, ));
    ta.start();
    tb.start();
    ta.join();
    tb.join();

    doc = a.find_active_one('inc1');
    assert doc is not None;
    assert doc['run_count'] == 20 , f"lost updates: run_count={doc['run_count']}";
    assert doc['last_status'] == 'succeeded';
}


test "webhook api-key user_id index exists in the catalog (#8000 1.4)" {
    store = _store();
    if store is None {
        return;
    }
    mgr = ApiKeyManager(_db=store);
    idx = store.rows(
        "SELECT indexname FROM pg_indexes WHERE tablename = 'jac_docs' "
        "AND indexname = 'jac_docs_user_id_idx'",
        {}
    );
    assert idx , 'user_id lookups must be indexed, not collection scans';
}


test "api key create, list, resolve shape, and revoke over SQL" {
    store = _store();
    if store is None {
        return;
    }
    mgr = ApiKeyManager(_db=store, _collection='wh_keys_t');
    created = mgr.create_api_key('user-w', 'ci-key');
    assert created.ok;
    key_id = created.data['api_key_id'];

    listed = mgr.list_api_keys('user-w');
    assert [k['api_key_id'] for k in listed.data['api_keys']] == [key_id];

    doc = mgr._get_key_doc(key_id);
    assert doc is not None;
    assert doc['api_key_id'] == key_id , 'consumers key rate limiting off api_key_id';
    assert '_id' not in doc;

    revoked = mgr.revoke_api_key('user-w', key_id);
    assert revoked.ok;
    assert mgr.list_api_keys('user-w').data['api_keys'] == [];
    refused = mgr.revoke_api_key('someone-else', key_id);
    assert refused.error.code == 'FORBIDDEN';
}
