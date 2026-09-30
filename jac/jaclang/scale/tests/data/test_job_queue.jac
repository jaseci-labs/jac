"""Durable job queue on Postgres (issue #9620).

Every test drives a real embedded Postgres: runners claim with FOR UPDATE SKIP
LOCKED, hold jobs under a lease, retry with the outbox's backoff and give up
after max_attempts. Each test works in its own queue name so runs never see
each other's rows."""

import threading;
import time;
import uuid;
import from collections { Counter }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.data.store { JOBS_SCHEMA_SQL, PgStore }
import from jaclang.data.type_identity { type_module }
import from jaclang.server.outbox { backoff_seconds }
import from jaclang.server.session { shared_pg_data_dir }
import from jaclang.scale.jobs.queue {
    DEFAULT_QUEUE,
    JobInfo,
    JobQueueStore,
    STATUS_CANCELLED,
    STATUS_DEAD,
    STATUS_DONE,
    STATUS_FAILED,
    STATUS_QUEUED,
    STATUS_RUNNING,
    cancel,
    enqueue,
    job_info,
    use_store
}
import from jaclang.scale.jobs.runner { JobRunner, JobTargetMissing, QueueSpec }

glob _holder: dict[str, any] = {};


"""A fresh connection to the shared embedded cluster, or None when it is unavailable."""
def _pg -> (PgStore | None) {
    try {
        if "rt" not in _holder {
            _holder["rt"] = PgRuntime(
                data_dir=shared_pg_data_dir(), database="jac_job_queue"
            );
        }
        store = PgStore(conninfo=_holder["rt"].ensure());
        for stmt in JOBS_SCHEMA_SQL {
            store.rows(stmt, {});
        }
        return store;
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


def _job(found: (JobInfo | None)) -> JobInfo {
    if found is None {
        raise AssertionError("job row missing");
    }
    return found;
}


def _queue -> str {
    return f"q_{uuid.uuid4().hex[:12]}";
}


def _runner(
    pg: PgStore,
    queue: str,
    execute: Callable[[JobInfo], None],
    concurrency: int = 1,
    lease_s: float = 60.0,
    service: str = ""
) -> JobRunner {
    return JobRunner(
        store=JobQueueStore(store=pg.new_session(), service=service),
        queues=[QueueSpec(name=queue, concurrency=concurrency, lease_s=lease_s)],
        execute=execute,
        poll_s=0.05,
        retention_s=0.0
    );
}


def _status_count(pg: PgStore, queue: str, status: str) -> int {
    rows = pg.rows(
        "SELECT count(*) FROM jac_jobs WHERE queue = :q AND status = :s",
        {'q': queue, 's': status}
    );
    return int(rows[0][0]);
}


test "two runners never run the same job" {
    pg = _pg();
    if pg is None {
        return;
    }
    queue = _queue();
    jobs = JobQueueStore(store=pg);
    ids = [jobs.insert(queue, "Work", {"n": n}) for n in range(40)];
    runs: list[str] = [];
    foreign: list[str] = [];
    lock = threading.Lock();
    def _record(job: JobInfo) {
        with lock {
            runs.append(job.id);
        }
        time.sleep(0.005);
    }
    def _trespass(job: JobInfo) {
        foreign.append(job.id);
    }
    runners = [_runner(pg, queue, _record, concurrency=4) for _ in range(2)];
    runners.append(_runner(pg, queue, _trespass, concurrency=4, service="billing"));
    for r in runners {
        r.start();
    }
    try {
        deadline = time.monotonic() + 30.0;
        while _status_count(pg, queue, STATUS_DONE) < len(ids)
            and time.monotonic() < deadline {
            time.sleep(0.05);
        }
    } finally {
        for r in runners {
            r.stop();
        }
    }
    repeats = {
        i: n
        for (i, n) in Counter(runs).items()
        if n > 1
    };
    assert repeats == {} , f"jobs ran more than once: {repeats}";
    assert sorted(runs) == sorted(ids) , f"ran {len(runs)} of {len(ids)} jobs";
    assert foreign == [] , f"another service's runner took {len(foreign)} job(s)";
}


test "a stopped or killed runner's job runs again once its lease expires" {
    pg = _pg();
    if pg is None {
        return;
    }
    queue = _queue();
    jobs = JobQueueStore(store=pg);
    job_id = jobs.insert(queue, "Work", {});
    held = jobs.claim(queue, "runner-that-was-killed", 60.0);
    assert _job(held).id == job_id , held;
    runs: list[str] = [];
    def _record(job: JobInfo) {
        runs.append(job.id);
    }
    survivor = _runner(pg, queue, _record);

    survivor.maintain();
    assert not survivor.run_once(queue) , "a job under a live lease was taken";

    pg.rows(
        "UPDATE jac_jobs SET lease_until = now() - interval '1 second' WHERE id = :id",
        {'id': job_id}
    );
    survivor.maintain();
    assert survivor.run_once(queue) , "the expired job was not re-queued";
    info = _job(jobs.get(job_id));
    assert runs == [job_id] , runs;
    assert info.status == STATUS_DONE , info.status;
    assert info.attempts == 2 , f"expected the retry to be attempt 2, got {info.attempts}";

    slow_id = jobs.insert(queue, "Work", {});
    release = threading.Event();
    def _hang(job: JobInfo) {
        release.`wait(10.0);
    }
    draining = _runner(pg, queue, _hang, lease_s=2.0);
    draining.start();
    try {
        deadline = time.monotonic() + 10.0;
        while not draining.attending() and time.monotonic() < deadline {
            time.sleep(0.02);
        }
        assert draining.attending() == [slow_id] , draining.attending();
        started = time.monotonic();
        draining.stop(0.3);
        waited = time.monotonic() - started;
        assert waited < 1.5 , f"stop ignored its deadline and waited {waited:.1f}s";
        before = pg.rows(
            "SELECT lease_until FROM jac_jobs WHERE id = :id", {'id': slow_id}
        );
        time.sleep(0.8);
        after = pg.rows(
            "SELECT lease_until FROM jac_jobs WHERE id = :id", {'id': slow_id}
        );
        assert before == after , "a stopped runner kept renewing an abandoned lease";
    } finally {
        release.set();
    }
}


test "a failing job backs off between attempts and is dead after max_attempts" {
    pg = _pg();
    if pg is None {
        return;
    }
    release = threading.Event();
    def _hang(job: JobInfo) {
        release.`wait(10.0);
    }
    cases: list[tuple[str, (Exception | None), float, int, str]] = [
        (
            "an error is retried",
            RuntimeError("provider timed out"),
            0.0,
            3,
            "provider timed out"
        ),
        (
            "a missing target is not",
            JobTargetMissing("'Gone' is not served"),
            0.0,
            1,
            "is not served"
        ),
        ("a hung attempt times out", None, 0.3, 3, "ran past timeout_s=0.3")
    ];
    try {
        for (label, error, timeout_s, runs_until_dead, message) in cases {
            queue = _queue();
            jobs = JobQueueStore(store=pg);
            job_id = jobs.insert(
                queue, "Work", {}, max_attempts=3, timeout_s=timeout_s
            );
            def _fail(job: JobInfo) {
                raise error;
            }
            runner = _runner(pg, queue, _fail if error is not None else _hang);
            for attempt in range(1, runs_until_dead + 1) {
                started = time.monotonic();
                assert runner.run_once(queue) , f"{label}: attempt {attempt} not claimed";
                waited = time.monotonic() - started;
                assert waited < 2.0 , f"{label}: attempt {attempt} held for {waited:.1f}s";
                assert runner.attending() == [] , f"{label}: still heartbeating {runner.attending()}";
                info = _job(jobs.get(job_id));
                if attempt == runs_until_dead {
                    assert info.status == STATUS_DEAD , f"{label}: {info.status}";
                    assert message in info.last_error , f"{label}: {info.last_error}";
                    break;
                }
                assert info.status == STATUS_FAILED , f"{label}: {info.status}";
                gap = pg.rows(
                    "SELECT EXTRACT(EPOCH FROM run_at - updated_at) FROM jac_jobs WHERE id = :id",
                    {'id': job_id}
                );
                wanted = backoff_seconds(attempt);
                assert abs(float(gap[0][0]) - wanted) < 0.5 , (
                    f"{label}: attempt {attempt} waits {gap[0][0]}s, expected {wanted}s"
                );
                assert not runner.run_once(queue) , f"{label}: retried before its backoff";
                pg.rows(
                    "UPDATE jac_jobs SET run_at = now() WHERE id = :id", {'id': job_id}
                );
            }
            assert not runner.run_once(queue) , f"{label}: a dead job was claimed";
        }
    } finally {
        release.set();
    }
}


test "a second enqueue with the same key is a no-op" {
    pg = _pg();
    if pg is None {
        return;
    }
    use_store(JobQueueStore(store=pg));
    key = f"review:{uuid.uuid4().hex}";
    try {
        first = enqueue("RunAgent", {"run_id": 1}, key=key);
        second = enqueue("RunAgent", {"run_id": 2}, key=key);
        assert first == second , f"{first} != {second}";
        rows = pg.rows("SELECT count(*) FROM jac_jobs WHERE key = :k", {'k': key});
        assert int(rows[0][0]) == 1 , rows;
        info = _job(job_info(first));
        assert info.queue == DEFAULT_QUEUE and info.args == {"run_id": 1} , info;
        by_ref = _job(job_info(enqueue(_queue, key=key + ":ref")));
        assert by_ref.target == f"{type_module(_queue)}:_queue" , by_ref.target;

        rejected: list[tuple[dict[str, any], str]] = [
            ({"target": ""}, "walker, a function, or its name"),
            ({"queue": "nowhere"}, "not declared in [scale.jobs] queues"),
            ({"max_attempts": 0}, "max_attempts must be at least 1"),
            ({"timeout_s": -1}, "timeout_s must be 0"),
            ({"args": {"when": object()}}, "JSON-serializable")
        ];
        for (overrides, message) in rejected {
            call: dict[str, any] = {"target": "RunAgent", "args": {}};
            call.update(overrides);
            try {
                enqueue(**call);
                assert False , f"{overrides} was accepted";
            } except ValueError as e {
                assert message in str(e) , f"{overrides}: {e}";
            }
        }
    } finally {
        pg.rows("DELETE FROM jac_jobs WHERE key LIKE :k", {'k': key + "%"});
        use_store(None);
    }
}


test "cancel stops only a job that has not started" {
    pg = _pg();
    if pg is None {
        return;
    }
    queue = _queue();
    jobs = JobQueueStore(store=pg);
    use_store(jobs);
    try {
        waiting = jobs.insert(queue, "Work", {});
        running = jobs.insert(queue, "Work", {}, run_at=None);
        pg.rows(
            "UPDATE jac_jobs SET run_at = now() + interval '1 hour' WHERE id = :id",
            {'id': waiting}
        );
        assert _job(jobs.claim(queue, "busy-runner", 60.0)).id == running;
        cases: list[tuple[str, bool, str]] = [
            (waiting, True, STATUS_CANCELLED),
            (running, False, STATUS_RUNNING),
            (waiting, False, STATUS_CANCELLED)
        ];
        for (job_id, stopped, status) in cases {
            assert cancel(job_id) == stopped , f"cancel({job_id}) != {stopped}";
            assert _job(job_info(job_id)).status == status , _job(
                job_info(job_id)
            ).status;
        }
        assert _status_count(pg, queue, STATUS_QUEUED) == 0;
    } finally {
        use_store(None);
    }
}


test "a served job runs as the root that queued it, commits with it, and dies with it" {
    import shutil;
    import tempfile;
    import from pathlib { Path }
    import from jaclang.server.shared_store { shared_store }
    import from jaclang.scale.config.config_loader {
        get_scale_config,
        reset_scale_config
    }
    import from jaclang.scale.server.job_queue_ext { JobQueueExtension }
    import from jaclang.scale.tests.scale_test_client { ScaleTestClient, extract_data }
    fixture = Path(__file__).parent.parent / "fixtures" / "job_queue";
    tmp = tempfile.mkdtemp();
    shutil.copytree(str(fixture), tmp, dirs_exist_ok=True);
    reset_scale_config();
    get_scale_config(Path(tmp));
    client: (ScaleTestClient | None) = None;
    try {
        client = ScaleTestClient.from_file(str(Path(tmp) / "app.jac"), base_path=tmp);
        server = client.server;
        ext: any = None;
        for candidate in server.extensions {
            candidate.on_worker_start(server);
            if isinstance(candidate, JobQueueExtension) {
                ext = candidate;
            }
        }
        users = server.user_manager;
        def _login(name: str) -> tuple[dict[str, str], str] {
            token = client.register_and_login(name, "Passw0rd!long");
            user = users.find_user_by_identity(name);
            user_root = str(users.get_root_id(str(user.get("user_id")))).replace(
                "-", ""
            );
            return ({"Authorization": f"Bearer {token}"}, user_root);
        }
        (auth_a, root_a) = _login("jobs_tenant_a");
        (auth_b, root_b) = _login("jobs_tenant_b");
        def _post(path: str, body: dict[str, any]) -> dict[str, any] {
            return extract_data(client.post(path, json=body, headers=auth_a).json());
        }
        def _settle(job_id: str, status: str, budget: float) -> dict[str, any] {
            started = time.monotonic();
            seen: dict[str, any] = {};
            while time.monotonic() - started < budget {
                status_reply = _post("/walker/ReviewStatus", {"job_id": job_id});
                assert "reports" in status_reply , f"status {job_id}: {status_reply}";
                seen = status_reply["reports"][0];
                if seen["status"] == status {
                    break;
                }
                time.sleep(0.1);
            }
            return seen;
        }
        cases: list[tuple[str, dict[str, any], dict[str, any]]] = [
            (
                "omitted as_root runs as the caller's root",
                {"run_id": "own"},
                {"status": "done", "as_root": root_a, "enqueued_by": root_a}
            ),
            (
                "the caller's own root is accepted",
                {"run_id": "explicit", "as_root": root_a},
                {"status": "done", "as_root": root_a}
            ),
            (
                "another tenant's root is refused",
                {"run_id": "foreign", "as_root": root_b},
                {"error": "cannot queue a job for root"}
            ),
            (
                "a system target runs as the system user",
                {"run_id": "system", "housekeeping": True},
                {"status": "done", "as_root": "", "enqueued_by": root_a}
            ),
            (
                "a hung attempt is dead at timeout_s",
                {"run_id": "hung", "hang": True},
                {"status": "dead", "last_error": "ran past timeout_s=0.5"}
            ),
            (
                "a walker that raises after enqueue leaves no job",
                {
                    "run_id": "rolled",
                    "key": f"rollback:{uuid.uuid4().hex}",
                    "fail_after": True
                },
                {"error": "", "no_job": True}
            )
        ];
        review_target = "";
        for (label, body, want) in cases {
            reply = _post("/walker/QueueReview", body);
            if "error" in want {
                assert "error" in reply , f"{label}: accepted {reply}";
                assert want["error"] in str(reply["error"]) , f"{label}: {reply}";
                if want.get("no_job") {
                    pg_shared: any = shared_store();
                    rows = pg_shared.rows(
                        "SELECT count(*) FROM jac_jobs WHERE key = :k",
                        {'k': body["key"]}
                    );
                    assert int(rows[0][0]) == 0 , f"{label}: the job outlived its walker";
                }
                continue;
            }
            assert "reports" in reply , f"{label}: {reply}";
            seen = _settle(
                reply["reports"][0]["job_id"],
                want["status"],
                2.5 if body.get("hang") else 10.0
            );
            for (field, value) in want.items() {
                if field == "last_error" {
                    assert value in seen[field] , f"{label}: {seen}";
                } else {
                    assert seen.get(field) == value , f"{label}: {field} {seen}";
                }
            }
            if body["run_id"] == "own" {
                review_target = seen["target"];
            }
        }
        gone = JobQueueStore(store=shared_store(), service=ext.service);
        orphan = gone.insert(
            "agents", review_target, {"run_id": "orphan"}, as_root=uuid.uuid4().hex
        );
        seen = _settle(orphan, "dead", 10.0);
        assert seen["status"] == "dead" and seen["attempts"] == 1 , seen;
        assert "no longer exists" in seen["last_error"] , seen;
    } finally {
        if client is not None {
            for candidate in client.server.extensions {
                if isinstance(candidate, JobQueueExtension)
                    and candidate.runner is not None {
                    candidate.runner.stop(1.0);
                }
            }
            client.close();
        }
        reset_scale_config();
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
