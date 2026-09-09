"""Guards #8000 (1.3): the /jobs endpoints must map Postgres/store failures to
503 STORAGE_UNAVAILABLE. The old branch tested PyMongoError, which nothing can
raise since #7947 removed Mongo, so every storage failure fell through to the
generic 500 SCHEDULER_ERROR and the 503 path was unreachable.
"""

import from jaclang.data.pgwire { PgWireError }
import from jaclang.scale.server.jobs_ext { _err_response }


test "pg wire failure maps to 503 storage unavailable" {
    resp = _err_response(PgWireError({"C": "08006", "M": "connection lost"}));
    assert resp.ok is False;
    err = resp.error;
    assert err is not None , "error envelope must be populated";
    assert err.code == "STORAGE_UNAVAILABLE";
    assert resp.meta.extra["http_status"] == 503;
}


test "connection refused maps to 503 storage unavailable" {
    resp = _err_response(ConnectionRefusedError("connection refused"));
    err = resp.error;
    assert err is not None , "error envelope must be populated";
    assert err.code == "STORAGE_UNAVAILABLE";
    assert resp.meta.extra["http_status"] == 503;
}


test "generic errors still map to 500 scheduler error" {
    resp = _err_response(RuntimeError("boom"));
    err = resp.error;
    assert err is not None , "error envelope must be populated";
    assert err.code == "SCHEDULER_ERROR";
    assert resp.meta.extra["http_status"] == 500;
}
