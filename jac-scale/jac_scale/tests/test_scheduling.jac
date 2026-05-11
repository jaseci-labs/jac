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
import requests;
import from pathlib { Path }
import from typing { Any }

glob FIXTURES_DIR: Path = Path(__file__).parent / "fixtures";

# =============================================================================
# Helpers
# =============================================================================
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        return s.getsockname()[1];
    }
}

def _data(resp: dict[str, Any]) -> Any {
    if isinstance(resp, dict) and "data" in resp {
        return resp["data"];
    }
    return resp;
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

def _get_token(base_url: str, user: str = "testuser", pwd: str = "pass123") -> str {
    requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": user}],
            "credential": {"type": "password", "password": pwd}
        },
        timeout=5
    );
    resp = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": user},
            "credential": {"type": "password", "password": pwd}
        },
        timeout=5
    ).json();
    return _data(resp)["token"];
}

def _post_job(base_url: str, headers: dict, payload: dict) -> dict[str, Any] {
    return requests.post(
        f"{base_url}/jobs", json=payload, headers=headers, timeout=5
    ).json();
}

# =============================================================================
# Test 1: Endpoint filtering, /jobs routes, and system user
# =============================================================================
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

        # __system__ user created at startup
        resp = requests.post(
            f"{base_url}/user/login",
            json={
                "identity": {"type": "username", "value": "__system__"},
                "credential": {"type": "password", "password": "system_secret"}
            },
            timeout=5
        ).json();
        assert resp.get("ok") , "__system__ user must exist and authenticate";
        assert _data(resp).get("token");
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}

# =============================================================================
# Test 2: Dynamic jobs with all trigger types (interval / cron / date)
# =============================================================================
test "dynamic jobs - all trigger types for walker and function" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    _cleanup();
    sp = _start_server(port);
    try {
        token = _get_token(base_url, "job_user", "pass123");
        h = {"Authorization": f"Bearer {token}"};
        run_date = (datetime.datetime.now() + datetime.timedelta(hours=1)).strftime(
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
            assert "_id" in job and job["status"] == "active";
            created_ids.append(job["_id"]);
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

# =============================================================================
# Test 3: Full CRUD lifecycle
# =============================================================================
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
        job_id = job["_id"];
        assert job["interval"] == 60 and job.get("created_by");

        # Get single
        body = requests.get(f"{base_url}/jobs/{job_id}", headers=h, timeout=5).json();
        assert body.get("ok") and _data(body)["_id"] == job_id;

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

# =============================================================================
# Test 4: Validation and authentication errors
# =============================================================================
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
            # Missing trigger → INVALID_REQUEST
            ({"walker_or_function": "DynamicScheduledWalker"}, "INVALID_REQUEST"),
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
            # Unknown trigger type → INVALID_REQUEST
            (
                {"walker_or_function": "DynamicScheduledWalker", "trigger": "weekly"},
                "INVALID_REQUEST"
            ),

        ];

        for (payload, expected_code) in invalid_request_cases {
            body = _post_job(base_url, h, payload);
            assert not body.get("ok") , f"Expected failure for payload {payload}";
            err = _err(body);
            assert err is not None and err.get("code") == expected_code , (
                f"Expected {expected_code}, got {err} for payload {payload}"
            );
        }
    } finally {
        _stop_server(sp);
        _cleanup();
    }
}
