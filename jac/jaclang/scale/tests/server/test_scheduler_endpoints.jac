"""Guards #8000 (1.3): the /jobs endpoints must map Postgres/store failures to
503 STORAGE_UNAVAILABLE. The old branch tested PyMongoError, which nothing can
raise since #7947 removed Mongo, so every storage failure fell through to the
generic 500 SCHEDULER_ERROR and the 503 path was unreachable.
"""

import from jaclang.data.pgwire { PgWireError }
import from jaclang.scale.server.jobs_ext { _err_response }
import from jaclang.scale.scheduler.scheduler { TriggerSpec }


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


test "an interval below the floor is refused, not scheduled" {
    # #9032: the only interval rule was "> 0", so any authenticated user could
    # ask for a millisecond job. The floor lives with the rest of the interval
    # rule, the one place POST and PUT both reach through _build_spec.
    caught = "";
    try {
        TriggerSpec.validate(trigger="interval", interval=0.001);
    } except ValueError as e {
        caught = str(e);
    }
    assert "at least" in caught , f"expected a floor message, got {caught!r}";
    assert "min_interval" in caught , "the message must name the key that raises it";
}


test "an interval at the floor is accepted" {
    spec = TriggerSpec.validate(trigger="interval", interval=1.0);
    assert spec.trigger == "interval";
    assert spec.interval == 1.0;
}


test "a zero interval is still refused" {
    caught = "";
    try {
        TriggerSpec.validate(trigger="interval", interval=0);
    } except ValueError as e {
        caught = str(e);
    }
    assert "> 0" in caught , f"expected the positive-interval message, got {caught!r}";
}
