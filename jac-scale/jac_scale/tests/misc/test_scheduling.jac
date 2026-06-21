"""Compact scheduling tests: endpoint filtering, dynamic CRUD, and validation."""

import contextlib;
import datetime;
import gc;
import glob;
import shutil;
import socket;
import subprocess;
import sys;
import time;
import unittest.mock;
import requests;
import from pathlib { Path }
import from typing { Any }
import from jac_scale.scheduler.scheduler {
    JacScaleScheduler,
    MemoryJobStore,
    TriggerSpec
}
import from jac_scale._optdeps.pymongo { PyMongoError }
import from jac_scale.tests.auth_test_helpers {
    data as _data,
    register_and_login as _get_token
}

glob FIXTURES_DIR: Path = Path(__file__).parent.parent / "fixtures";

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        return s.getsockname()[1];
    }
}

def _err(resp: dict[str, Any]) -> dict[str, Any] | None {
    if isinstance(resp, dict) and not resp.get("ok") {
        return resp.get("error") or resp;
    }
    return None;
}

def _cleanup {
    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for f in glob.glob(str(FIXTURES_DIR / pattern)) {
            with contextlib.suppress(Exception) {
                Path(f).unlink();
            }
        }
    }
    jac_dir = FIXTURES_DIR / ".jac";
    if jac_dir.exists() {
        with contextlib.suppress(Exception) {
            shutil.rmtree(jac_dir);
        }
    }
}

def _start_server(port: int) -> subprocess.Popen {
    base_url = f"http://localhost:{port}";
    jac_exe = Path(sys.executable).parent / "jac";
    proc = subprocess.Popen(
        [str(jac_exe), "start", "test_api.jac", "--port", str(port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(FIXTURES_DIR)
    );
    for _ in range(60) {
        if proc.poll() is not None {
            (out, err) = proc.communicate();
            raise RuntimeError(f"Server died.\nSTDOUT: {out}\nSTDERR: {err}");
        }
        try {
            r = requests.get(f"{base_url}/healthz", timeout=2);
            if r.status_code == 200 {
                return proc;
            }
        } except requests.RequestException {
            time.sleep(0.5);
        }
    }
    proc.terminate();
    proc.wait();
    raise RuntimeError("Server failed to start within 30s");
}

def _stop_server(proc: subprocess.Popen | None) {
    if proc {
        proc.terminate();
        with contextlib.suppress(subprocess.TimeoutExpired) {
            proc.wait(timeout=5);
        }
        with contextlib.suppress(Exception) {
            proc.kill();
            proc.wait();
        }
    }
    time.sleep(0.2);
    gc.collect();
}

def _post_job(base_url: str, headers: dict, payload: dict) -> dict[str, Any] {
    return requests.post(
        f"{base_url}/jobs", json=payload, headers=headers, timeout=5
    ).json();
}

test "endpoint filtering and startup" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        # Scheduled walkers should NOT be accessible via /walker/
        # Dynamic mode uses catch-all routes, so check for non-200 (not just 404)
        for name in [
            "StaticIntervalWalker",
            "StaticCronWalker",
            "StaticDateWalker",
            "DynamicScheduledWalker"
        ] {
            resp = requests.post(f"{base_url}/walker/{name}", json={}, timeout=5);
            assert resp.status_code != 200 , f"{name} must not be a /walker endpoint";
        }

        # Scheduled functions should NOT be accessible via /function/
        for name in [
            "static_interval_func",
            "static_cron_func",
            "static_date_func",
            "dynamic_scheduled_func"
        ] {
            resp = requests.post(f"{base_url}/function/{name}", json={}, timeout=5);
            assert resp.status_code != 200 , f"{name} must not be a /function endpoint";
        }

        # Regular walker and function should be accessible
        resp = requests.post(f"{base_url}/walker/NormalWalker", json={}, timeout=5);
        assert resp.status_code != 404 , "NormalWalker should be a /walker endpoint";
        resp = requests.post(f"{base_url}/function/normal_func", json={}, timeout=5);
        assert resp.status_code != 404 , "normal_func should be a /function endpoint";

        # /jobs endpoints should be accessible
        resp = requests.get(f"{base_url}/jobs", timeout=5);
        assert resp.status_code != 404 , "/jobs GET should be registered";
        resp = requests.post(f"{base_url}/jobs", json={}, timeout=5);
        assert resp.status_code != 404 , "/jobs POST should be registered";

        # __system__ user is created at startup but is NOT loginable over HTTP
        # (role='system' accounts have no credential record).
        resp = requests.post(
            f"{base_url}/user/login",
            json={
                "identity": {"type": "username", "value": "__system__"},
                "credential": {"type": "password", "password": "system_secret"}
            },
            timeout=5
        ).json();
        assert not resp.get("ok") , "__system__ user must not be loginable over HTTP";
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

test "dynamic jobs - all trigger types for walker and function" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        token = _get_token(base_url, "job_user", "pass123");
        h = {"Authorization": f"Bearer {token}"};
        # Scheduler default TZ is UTC — compute the run_date in UTC so the
        # "1 hour in the future" semantics are stable regardless of CI/dev TZ.
        run_date = (
            datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=1)
        ).strftime(
            "%Y-%m-%d %H:%M:%S"
        );

        cases = [
            # (name, trigger_payload)
            ("DynamicScheduledWalker", {"trigger": "interval", "interval": 3600}),
            ("DynamicScheduledWalker", {"trigger": "cron", "cron": "0 * * * *"}),
            ("DynamicScheduledWalker", {"trigger": "date", "date": run_date}),
            ("dynamic_scheduled_func", {"trigger": "interval", "interval": 3600}),
            ("dynamic_scheduled_func", {"trigger": "cron", "cron": "0 * * * *"}),
            ("dynamic_scheduled_func", {"trigger": "date", "date": run_date}),

        ];

        created_ids = [];
        for (name, tpayload) in cases {
            payload = {** {"walker_or_function": name}, ** tpayload};
            body = _post_job(base_url, h, payload);
            assert body.get("ok") , f"POST /jobs failed for {name}/{tpayload[
                'trigger'
            ]}: {body}";
            job = _data(body);
            assert job["name"] == name;
            assert job["trigger"] == tpayload["trigger"];
            assert "job_id" in job and job["status"] == "active";
            created_ids.append(job["job_id"]);
        }

        # GET /jobs lists all created jobs
        list_body = requests.get(f"{base_url}/jobs", headers=h, timeout=5).json();
        assert list_body.get("ok");
        result = _data(list_body);
        assert result["count"] >= len(cases);
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

test "jobs crud lifecycle" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        token = _get_token(base_url, "crud_user", "pass123");
        h = {"Authorization": f"Bearer {token}"};

        # Create
        body = _post_job(
            base_url,
            h,
            {
                "walker_or_function": "DynamicScheduledWalker",
                "trigger": "interval",
                "interval": 60
            }
        );
        assert body.get("ok") , f"Create failed: {body}";
        job = _data(body);
        job_id = job["job_id"];
        assert job["interval"] == 60 and job.get("created_by");

        # Get single
        body = requests.get(f"{base_url}/jobs/{job_id}", headers=h, timeout=5).json();
        assert body.get("ok") and _data(body)["job_id"] == job_id;

        # List
        body = requests.get(f"{base_url}/jobs", headers=h, timeout=5).json();
        assert body.get("ok") and _data(body)["count"] >= 1;

        # Update
        body = requests.put(
            f"{base_url}/jobs/{job_id}",
            json={"trigger": "interval", "interval": 120},
            headers=h,
            timeout=5
        ).json();
        assert body.get("ok") and _data(body)["interval"] == 120;

        # Delete
        body = requests.delete(
            f"{base_url}/jobs/{job_id}", headers=h, timeout=5
        ).json();
        assert body.get("ok") and _data(body).get("deleted") == True;

        # Verify gone
        body = requests.get(f"{base_url}/jobs/{job_id}", headers=h, timeout=5).json();
        assert not body.get("ok") and _err(body)["code"] == "NOT_FOUND";

        # Non-existent update and delete return 404
        for method in ["put", "delete"] {
            resp = getattr(requests, method)(
                f"{base_url}/jobs/nonexistent-id",
                json={"trigger": "interval", "interval": 60},
                headers=h,
                timeout=5
            ).json();
            assert not resp.get("ok") and _err(resp)["code"] == "NOT_FOUND";
        }
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

test "jobs validation and auth errors" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        token = _get_token(base_url, "val_user", "pass123");
        h = {"Authorization": f"Bearer {token}"};

        # Unauthenticated requests → ok=false / 401
        for req in [
            lambda : requests.get(f"{base_url}/jobs", timeout=5),
            lambda : requests.post(f"{base_url}/jobs", json={}, timeout=5),
            lambda : requests.put(f"{base_url}/jobs/x", json={}, timeout=5),
            lambda : requests.delete(f"{base_url}/jobs/x", timeout=5),

        ] {
            body = req().json();
            assert not body.get("ok") , "Unauthenticated request must fail";
        }

        invalid_request_cases = [
            # Non-existent walker → NOT_FOUND
            (
                {
                    "walker_or_function": "NoSuchWalker",
                    "trigger": "interval",
                    "interval": 60
                },
                "NOT_FOUND"
            ),
            # Walker without @schedule → INVALID_REQUEST
            (
                {
                    "walker_or_function": "NormalWalker",
                    "trigger": "interval",
                    "interval": 60
                },
                "INVALID_REQUEST"
            ),
            # Static walker via /jobs → INVALID_REQUEST
            (
                {
                    "walker_or_function": "StaticIntervalWalker",
                    "trigger": "interval",
                    "interval": 60
                },
                "INVALID_REQUEST"
            ),
            # Static function via /jobs → INVALID_REQUEST
            (
                {
                    "walker_or_function": "static_interval_func",
                    "trigger": "interval",
                    "interval": 60
                },
                "INVALID_REQUEST"
            ),
            # interval trigger, no interval value → INVALID_REQUEST
            (
                {"walker_or_function": "DynamicScheduledWalker", "trigger": "interval"},
                "INVALID_REQUEST"
            ),
            # cron trigger, no cron expression → INVALID_REQUEST
            (
                {"walker_or_function": "DynamicScheduledWalker", "trigger": "cron"},
                "INVALID_REQUEST"
            ),
            # date trigger, no date value → INVALID_REQUEST
            (
                {"walker_or_function": "DynamicScheduledWalker", "trigger": "date"},
                "INVALID_REQUEST"
            ),
            # Note: "missing trigger" and "unknown trigger" are rejected at the
            # Pydantic schema layer (CreateJobRequest) with FastAPI's default
            # 422 response, so they don't reach our custom handler and aren't
            # listed here.
        ];

        for (payload, expected_code) in invalid_request_cases {
            body = _post_job(base_url, h, payload);
            assert not body.get("ok") , f"Expected failure for payload {payload}";
            err = _err(body);
            assert err is not None and err.get("code") == expected_code , (
                f"Expected {expected_code}, got {err} for payload {payload}"
            );
        }

        # Pydantic schema validation (CreateJobRequest) rejects these two with
        # FastAPI's 422 format before our handler runs.
        schema_reject_payloads = [
            # Missing trigger
            {"walker_or_function": "DynamicScheduledWalker"},
            # Unknown trigger value (violates Literal['interval','cron','date'])
            {"walker_or_function": "DynamicScheduledWalker", "trigger": "weekly"}
        ];
        for payload in schema_reject_payloads {
            resp = requests.post(
                f"{base_url}/jobs", json=payload, headers=h, timeout=5
            );
            assert resp.status_code == 422 , (
                f"Expected 422 for payload {payload}, got {resp.status_code}"
            );
        }
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

test "ownership enforcement across users" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        token_a = _get_token(base_url, "alice", "pass_a");
        token_b = _get_token(base_url, "bob", "pass_b");
        ha = {"Authorization": f"Bearer {token_a}"};
        hb = {"Authorization": f"Bearer {token_b}"};

        # Alice creates a job
        body_a = _post_job(
            base_url,
            ha,
            {
                "walker_or_function": "DynamicScheduledWalker",
                "trigger": "interval",
                "interval": 3600
            }
        );
        assert body_a.get("ok") , f"Alice failed to create job: {body_a}";
        job_id = _data(body_a).get("job_id");
        assert job_id , "Expected job id on create";

        # Bob GET single → must not see it
        resp = requests.get(f"{base_url}/jobs/{job_id}", headers=hb, timeout=5).json();
        assert not resp.get("ok") , "Bob must not see Alice's job";
        err = _err(resp);
        assert err is not None and err.get("code") == "NOT_FOUND" , (
            f"Expected NOT_FOUND for cross-user GET, got {err}"
        );

        # Bob PUT → must not update it
        resp = requests.put(
            f"{base_url}/jobs/{job_id}",
            json={"trigger": "interval", "interval": 7200},
            headers=hb,
            timeout=5
        ).json();
        assert not resp.get("ok") , "Bob must not update Alice's job";
        err = _err(resp);
        assert err is not None and err.get("code") == "NOT_FOUND" , (
            f"Expected NOT_FOUND for cross-user PUT, got {err}"
        );

        # Bob DELETE → must not delete it
        resp = requests.delete(
            f"{base_url}/jobs/{job_id}", headers=hb, timeout=5
        ).json();
        assert not resp.get("ok") , "Bob must not delete Alice's job";
        err = _err(resp);
        assert err is not None and err.get("code") == "NOT_FOUND" , (
            f"Expected NOT_FOUND for cross-user DELETE, got {err}"
        );

        # Bob GET /jobs list → shouldn't contain Alice's job
        resp = requests.get(f"{base_url}/jobs", headers=hb, timeout=5).json();
        assert resp.get("ok") , f"Bob list call failed: {resp}";
        bob_jobs = _data(resp).get("jobs", []);
        assert all(j.get("job_id") != job_id for j in bob_jobs) , (
            "Bob's /jobs list leaked Alice's job"
        );

        # Alice can still access her own job
        resp = requests.get(f"{base_url}/jobs/{job_id}", headers=ha, timeout=5).json();
        assert resp.get("ok") , "Alice must see her own job";
        assert _data(resp).get("job_id") == job_id;

        # Alice can delete her own job
        resp = requests.delete(
            f"{base_url}/jobs/{job_id}", headers=ha, timeout=5
        ).json();
        assert resp.get("ok") , f"Alice failed to delete her own job: {resp}";
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

test "static walkers and functions actually execute" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        token = _get_token(base_url, "exec_user", "pass123");
        h = {"Authorization": f"Bearer {token}"};
        walker_count = 0;
        func_count = 0;
        log: list = [];
        deadline = time.monotonic() + 8.0;
        while time.monotonic() < deadline {
            resp = requests.post(
                f"{base_url}/function/get_execution_log", json={}, headers=h, timeout=5
            ).json();
            assert resp.get("ok") , f"get_execution_log call failed: {resp}";
            # Function endpoints wrap their return as data.result.<...>
            log = _data(resp).get("result", {}).get("log", []);
            assert isinstance(log, list) , f"Expected log list, got: {log}";
            walker_count = sum(
                1
                for e in log
                if e == "static-interval-walker"
            );
            func_count = sum(
                1
                for e in log
                if e == "static-interval-func"
            );
            if walker_count >= 3 and func_count >= 3 {
                break;
            }
            time.sleep(0.3);
        }

        # Both walker and function side-effects must be present — proves both
        # registration paths and execution paths are wired correctly.
        assert "static-interval-walker" in log , (
            f"static walker did not fire within 8s; log={log}"
        );
        assert "static-interval-func" in log , (
            f"static function did not fire within 8s; log={log}"
        );

        # Sanity check: at 0.3s interval, several fires should accumulate.
        # If we see only 1, something is gating execution.
        assert walker_count >= 3 , f"Expected >=3 walker fires, got {walker_count}";
        assert func_count >= 3 , f"Expected >=3 function fires, got {func_count}";
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

def _make_sched(user_exists_map: dict[str, bool] | None = None) -> JacScaleScheduler {
    # postinit runs automatically on construction (allocates _user_exists_cache).
    sched = JacScaleScheduler();
    sched._store = MemoryJobStore();
    sched._apscheduler = unittest.mock.MagicMock();
    mock_user_manager = unittest.mock.MagicMock();
    if user_exists_map is None {
        mock_user_manager.user_exists.return_value = True;
    } else {
        mock_user_manager.user_exists.side_effect = user_exists_map.get;
    }
    mock_server = unittest.mock.MagicMock();
    mock_server.user_manager = mock_user_manager;
    sched._server = mock_server;
    return sched;
}

test "TriggerSpec.validate rejects malformed cron expressions" {
    bad_crons = ['99 99 99 99 99', 'not a cron', '* * *', '60 * * * *', '* 24 * * *'];
    for bad in bad_crons {
        raised = False;
        try {
            TriggerSpec.validate(trigger='cron', cron=bad);
        } except ValueError as e {
            raised = True;
            msg = str(e).lower();
            assert 'cron' in msg or 'invalid' in msg , (
                f"ValueError for cron={bad!r} should mention cron/invalid, got: {e}"
            );
        }
        assert raised , f"Expected ValueError for malformed cron={bad!r}";
    }
}

test "TriggerSpec.validate accepts well-formed cron expressions" {
    good_crons = ['* * * * *', '0 0 * * *', '*/5 * * * *', '0 9-17 * * 1-5'];
    for good in good_crons {
        spec = TriggerSpec.validate(trigger='cron', cron=good);
        assert spec.trigger == 'cron';
        assert spec.cron == good;
    }
}

test "scheduler list_jobs propagates PyMongoError so endpoint can 503-map" {
    sched = _make_sched();
    sched._store = unittest.mock.MagicMock();
    sched._store.find_active.side_effect = PyMongoError('mongo down');

    raised_kind: str | None = None;
    try {
        sched.list_jobs();
    } except PyMongoError {
        raised_kind = 'pymongo';
    } except Exception as e {
        raised_kind = f'other:{type(e).__name__}';
    }
    assert raised_kind == 'pymongo' , (
        f"PyMongoError must propagate unwrapped so _err_response can map "
        f"it to STORAGE_UNAVAILABLE/503; got {raised_kind}"
    );
}

test "scheduler get_job propagates PyMongoError" {
    sched = _make_sched();
    sched._store = unittest.mock.MagicMock();
    sched._store.find_active_one.side_effect = PyMongoError('connection refused');

    raised_pymongo = False;
    try {
        sched.get_job('some-id');
    } except PyMongoError {
        raised_pymongo = True;
    }
    assert raised_pymongo , "PyMongoError from get_job must propagate";
}

test "user_is_live caches positive answer for ttl seconds" {
    # First call hits user_manager.user_exists; subsequent calls within TTL
    # are served from cache. After TTL expiry, user_manager is hit again.
    sched = _make_sched();
    sched._user_exists_ttl = 30.0;

    base_t = 1_000_000.0;
    with unittest.mock.patch('time.time') as mock_time {
        mock_time.return_value = base_t;
        assert sched._user_is_live('alice');
        assert sched._server.user_manager.user_exists.call_count == 1;
        # t=10 → within TTL, cache hit, user_manager not called again.
        mock_time.return_value = base_t + 10.0;
        assert sched._user_is_live('alice');
        assert sched._server.user_manager.user_exists.call_count == 1 , (
            f"Expected cache hit within TTL, but user_exists was called "
            f"{sched._server.user_manager.user_exists.call_count} times"
        );
        # t=29.9 → still within TTL.
        mock_time.return_value = base_t + 29.9;
        assert sched._user_is_live('alice');
        assert sched._server.user_manager.user_exists.call_count == 1;
        # t=31 → past TTL, cache miss, user_manager called again.
        mock_time.return_value = base_t + 31.0;
        assert sched._user_is_live('alice');
        assert sched._server.user_manager.user_exists.call_count == 2 , (
            "Expected user_manager to be re-consulted after TTL expiry"
        );
    }
}

test "user_is_live negative result is not cached" {
    sched = _make_sched(user_exists_map={'ghost': False});
    sched._user_exists_ttl = 30.0;

    with unittest.mock.patch('time.time') as mock_time {
        mock_time.return_value = 1_000_000.0;
        assert not sched._user_is_live('ghost');
        # Next call within TTL — must still hit the user_manager.
        mock_time.return_value = 1_000_001.0;
        assert not sched._user_is_live('ghost');
        assert sched._server.user_manager.user_exists.call_count == 2 , (
            "Negative results must not be cached"
        );
    }
}

test "user_is_live evicts positive cache when user later disappears" {
    sched = JacScaleScheduler();
    sched._user_exists_ttl = 30.0;
    sched._store = MemoryJobStore();
    sched._apscheduler = unittest.mock.MagicMock();

    state = {'alive': True};
    mock_um = unittest.mock.MagicMock();
    def _check_alive(_uid: str) -> bool {
        return state['alive'];
    }
    mock_um.user_exists.side_effect = _check_alive;
    mock_server = unittest.mock.MagicMock();
    mock_server.user_manager = mock_um;
    sched._server = mock_server;

    base_t = 2_000_000.0;
    with unittest.mock.patch('time.time') as mock_time {
        mock_time.return_value = base_t;
        assert sched._user_is_live('bob');
        # User gets deleted while still cached.
        state['alive'] = False;
        # Within TTL → still served from positive cache.
        mock_time.return_value = base_t + 10.0;
        assert sched._user_is_live('bob');
        # After TTL → cache expires, re-check, returns False, entry evicted.
        mock_time.return_value = base_t + 35.0;
        assert not sched._user_is_live('bob');
        assert 'bob' not in sched._user_exists_cache , (
            "Evicted negative entry should not linger in the cache"
        );
    }
}

test "register_dynamic_tasks_from_db marks jobs orphaned when creator gone" {
    sched = _make_sched(user_exists_map={'alice': True, 'ghost': False});
    alive_job = {
        'job_id': 'job-alive',
        'name': 'AliceWalker',
        'created_by': 'alice',
        'is_walker': True,
        'status': 'active',
        'trigger': 'interval',
        'interval': 60.0
    };
    ghost_job = {
        'job_id': 'job-ghost',
        'name': 'GhostWalker',
        'created_by': 'ghost',
        'is_walker': True,
        'status': 'active',
        'trigger': 'interval',
        'interval': 60.0
    };
    sched._store.insert(alive_job);
    sched._store.insert(ghost_job);

    # Patch _schedule_apscheduler_job so we can assert which jobs were
    # actually handed off to APScheduler.
    scheduled_ids: list[str] = [];

    def _capture_schedule(
        job_id: str, name: str, spec: any, user_id: str, is_walker: bool = True
    ) {
        scheduled_ids.append(job_id);
    }

    with unittest.mock.patch.object(
        sched, '_schedule_apscheduler_job', side_effect=_capture_schedule
    ) {
        sched.register_dynamic_tasks_from_db();
    }

    assert 'job-alive' in scheduled_ids , "Live job must be restored to APScheduler";
    assert 'job-ghost' not in scheduled_ids , (
        "Orphaned job (deleted creator) must NOT be re-added to APScheduler"
    );

    # Ghost job's status flipped from 'active' to 'orphaned' with a
    # timestamp; find_active_one should no longer return it.
    assert sched._store.find_active_one('job-ghost') is None , (
        "Orphaned job must not surface as an active job anymore"
    );
    raw_ghost = sched._store._jobs.get('job-ghost') or {};
    assert raw_ghost.get('status') == 'orphaned' , (
        f"Expected status='orphaned', got {raw_ghost.get('status')!r}"
    );
    assert raw_ghost.get('orphaned_at') , "orphaned_at timestamp must be set";

    raw_alive = sched._store._jobs.get('job-alive') or {};
    assert raw_alive.get('status') == 'active';
}

test "register_dynamic_tasks_from_db restores system-owned jobs without user_exists check" {
    sched = _make_sched(user_exists_map={'__system__': False});

    sys_job = {
        'job_id': 'job-sys',
        'name': 'SystemWalker',
        'created_by': '__system__',
        'is_walker': True,
        'status': 'active',
        'trigger': 'interval',
        'interval': 60.0
    };
    sched._store.insert(sys_job);

    scheduled_ids: list[str] = [];

    def _capture(
        job_id: str, name: str, spec: any, user_id: str, is_walker: bool = True
    ) {
        scheduled_ids.append(job_id);
    }

    with unittest.mock.patch.object(
        sched, '_schedule_apscheduler_job', side_effect=_capture
    ) {
        sched.register_dynamic_tasks_from_db();
    }

    assert 'job-sys' in scheduled_ids , (
        "System-owned job must be restored regardless of user_exists()"
    );
    raw = sched._store._jobs.get('job-sys') or {};
    assert raw.get('status') == 'active';
}

test "update_job with acting_as=None updates jobs created by any user (admin path)" {
    sched = _make_sched();

    job = {
        'job_id': 'job-x',
        'name': 'DynamicScheduledWalker',
        'created_by': 'alice',
        'is_walker': True,
        'status': 'active',
        'trigger': 'interval',
        'interval': 60.0
    };
    sched._store.insert(job);

    new_spec = TriggerSpec.validate(trigger='interval', interval=3600.0);

    # Non-admin (bob) → must NOT update Alice's job.
    with unittest.mock.patch.object(
        sched, '_schedule_apscheduler_job'
    ) as patched_schedule {
        result = sched.update_job(job_id='job-x', spec=new_spec, acting_as='bob');
        assert result is None , (
            "Non-owner (acting_as='bob') must return None when Alice owns the job"
        );
        assert patched_schedule.call_count == 0 , (
            "APScheduler must not be touched for unauthorized updates"
        );
    }

    # Admin path (acting_as=None) → MUST update.
    with unittest.mock.patch.object(
        sched, '_schedule_apscheduler_job'
    ) as patched_schedule {
        result = sched.update_job(job_id='job-x', spec=new_spec, acting_as=None);
        assert result is not None , (
            "Admin override (acting_as=None) must succeed regardless of created_by"
        );
        assert result.get('interval') == 3600.0;
        assert patched_schedule.call_count == 1 , (
            "Admin update must re-schedule the job in APScheduler"
        );
    }

    # Owner path (acting_as='alice') → also updates.
    with unittest.mock.patch.object(sched, '_schedule_apscheduler_job') {
        result = sched.update_job(job_id='job-x', spec=new_spec, acting_as='alice');
        assert result is not None , "Owner must be able to update her own job";
    }
}

test "delete_job with acting_as=None deletes jobs created by any user (admin path)" {
    sched = _make_sched();

    job = {
        'job_id': 'job-del',
        'name': 'DynamicScheduledWalker',
        'created_by': 'alice',
        'is_walker': True,
        'status': 'active',
        'trigger': 'interval',
        'interval': 60.0
    };
    sched._store.insert(job);

    # Non-admin (bob) → MUST NOT delete.
    deleted = sched.delete_job(job_id='job-del', acting_as='bob');
    assert deleted == False , "Non-owner must not be able to delete Alice's job";
    assert sched._store.find_active_one('job-del') is not None;

    # Admin (acting_as=None) → MUST delete.
    deleted = sched.delete_job(job_id='job-del', acting_as=None);
    assert deleted == True , "Admin override (acting_as=None) must delete the job";
    assert sched._store.find_active_one('job-del') is None , (
        "Job must be gone from the store after admin delete"
    );
}
