"""Guards #8000 (1.3): the /jobs endpoints must map Postgres/store failures to
503 STORAGE_UNAVAILABLE. The old branch tested PyMongoError, which nothing can
raise since #7947 removed Mongo, so every storage failure fell through to the
generic 500 SCHEDULER_ERROR and the 503 path was unreachable.
"""

import from jaclang.data.pgwire { PgWireError }
import from jaclang.scale.server.jobs_ext { _err_response }
import from jaclang.scale.scheduler.scheduler { MemoryJobStore, TriggerSpec }


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


test "the quota is decided where the row is written" {
    # #9032 again: the cap used to be a count read before a separate insert,
    # so two concurrent creates could both see room and both take it. The
    # store decides now, so the check and the write cannot be separated.
    store = MemoryJobStore();
    for i in range(3) {
        placed = store.insert_within_quota(
            {"job_id": f"j{i}", "created_by": "ana", "status": "active"}, "ana", 3
        );
        assert placed , f"job {i} should fit under a cap of 3";
    }
    refused = store.insert_within_quota(
        {"job_id": "j3", "created_by": "ana", "status": "active"}, "ana", 3
    );
    assert not refused , "the fourth job must be refused at a cap of 3";
    (rows, total) = store.find_active(created_by="ana");
    assert total == 3 , f"the refused job must not have been written, got {total}";
}


test "another account's jobs do not count against mine" {
    store = MemoryJobStore();
    store.insert_within_quota(
        {"job_id": "a1", "created_by": "ana", "status": "active"}, "ana", 1
    );
    placed = store.insert_within_quota(
        {"job_id": "b1", "created_by": "ben", "status": "active"}, "ben", 1
    );
    assert placed , "ben's first job must fit under his own cap";
}


test "a cap of zero means unlimited" {
    store = MemoryJobStore();
    for i in range(5) {
        assert store.insert_within_quota(
            {"job_id": f"u{i}", "created_by": "ana", "status": "active"}, "ana", 0
        );
    }
    (rows, total) = store.find_active(created_by="ana");
    assert total == 5 , total;
}
