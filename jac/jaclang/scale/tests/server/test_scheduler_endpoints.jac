"""Guards #8000 (1.3): the /jobs endpoints must map Postgres/store failures to
503 STORAGE_UNAVAILABLE. The old branch tested PyMongoError, which nothing can
raise since #7947 removed Mongo, so every storage failure fell through to the
generic 500 SCHEDULER_ERROR and the 503 path was unreachable.
"""

import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.data.pgwire { PgWireError }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.server.jobs_ext { _err_response }
import from jaclang.scale.scheduler.scheduler { MemoryJobStore, TriggerSpec }
import from jaclang.scale.tests.scale_test_client { ScaleTestClient }
import from jaclang.testing.requires { require_module }


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


test "another service's jobs do not count against this service's cap" {
    store = MemoryJobStore();
    store.insert_within_quota(
        {"job_id": "o1", "created_by": "ana", "status": "active", "service": "orders"},
        "ana",
        1
    );
    placed = store.insert_within_quota(
        {"job_id": "b1", "created_by": "ana", "status": "active", "service": "billing"},
        "ana",
        1
    );
    assert placed , "ana's job in orders must not use her cap in billing";
    refused = store.insert_within_quota(
        {"job_id": "b2", "created_by": "ana", "status": "active", "service": "billing"},
        "ana",
        1
    );
    assert not refused;
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


test "POST /jobs schedules a DYNAMIC target, then refuses the account past its cap" {
    # #9025 was a 404 for every DYNAMIC target, and nothing drove the handler:
    # restoring the old get_walkers lookup kept every test green. This goes
    # through the served route, on the job store the app really uses.
    require_module("apscheduler");
    fixtures = Path(__file__).parent.parent / "fixtures";
    base = tempfile.mkdtemp(prefix="jac-jobs-cap-");
    for f in fixtures.iterdir() {
        if f.is_file() {
            shutil.copy2(f, Path(base) / f.name);
        }
    }
    toml = Path(base) / "jac.toml";
    toml.write_text(toml.read_text() + "\n[scale.scheduler]\nmax_jobs_per_user = 1\n");
    reset_scale_config();
    get_scale_config(project_dir=Path(base));
    client = ScaleTestClient.from_file(str(fixtures / "test_api.jac"), base_path=base);
    try {
        token = client.register_and_login("jobs-cap-user", "password123");
        headers = {"Authorization": f"Bearer {token}"};
        body = {
            "walker_or_function": "DynamicScheduledWalker",
            "trigger": "interval",
            "interval": 60
        };
        first = client.post("/jobs", json=body, headers=headers);
        assert first.status_code == 201 , first.text;
        assert first.json()["data"]["name"] == "DynamicScheduledWalker" , first.text;

        second = client.post("/jobs", json=body, headers=headers);
        assert second.status_code == 429 , second.text;
        assert second.json()["error"]["code"] == "QUOTA_EXCEEDED" , second.text;
    } finally {
        client.close();
        reset_scale_config();
        shutil.rmtree(base, ignore_errors=True);
    }
}
