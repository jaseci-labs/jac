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
    billing = JobQueueStore(store=pg, service="billing");
    foreign_id = billing.insert(queue, "Work", {}, max_attempts=1);
    assert _job(billing.claim(queue, "billing-runner", 60.0)).id == foreign_id;
    runs: list[str] = [];
    def _record(job: JobInfo) {
        runs.append(job.id);
    }
    survivor = _runner(pg, queue, _record);

    survivor.maintain();
    assert not survivor.run_once(queue) , "a job under a live lease was taken";

    pg.rows(
        "UPDATE jac_jobs SET lease_until = now() - interval '1 second' WHERE id IN (:a, :b)",
        {'a': job_id, 'b': foreign_id}
    );
    survivor.maintain();
    assert survivor.run_once(queue) , "the expired job was not re-queued";
    info = _job(jobs.get(job_id));
    assert runs == [job_id] , runs;
    assert info.status == STATUS_DONE , info.status;
    assert info.attempts == 2 , f"expected the retry to be attempt 2, got {info.attempts}";
    foreign = _job(jobs.get(foreign_id));
    assert foreign.lease_owner == "billing-runner" , "another service's runner reaped its lease";
    assert billing.reap() == [foreign_id] , "the owning service did not reap its job";
    assert _job(jobs.get(foreign_id)).status == STATUS_DEAD;
    pg.rows(
        "UPDATE jac_jobs SET status = :done, updated_at = now() - interval '1 hour' WHERE id IN (:a, :b)",
        {'done': STATUS_DONE, 'a': job_id, 'b': foreign_id}
    );
    jobs.prune(60.0);
    assert jobs.get(job_id) is None , "prune kept its own finished job";
    assert jobs.get(foreign_id) is not None , "prune deleted another service's job";
    billing.prune(60.0);

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
        billing = JobQueueStore(store=pg, service="billing");
        theirs = billing.insert(DEFAULT_QUEUE, "RunAgent", {"run_id": 3}, key=key);
        assert theirs != first , "another service's key deduplicated this job";
        assert billing.insert(DEFAULT_QUEUE, "RunAgent", {}, key=key) == theirs;
        assert _job(job_info(theirs)).service == "billing";
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


test "a served app runs a private walker from a sibling module and times out a hung one" {
    import shutil;
    import tempfile;
    import from pathlib { Path }
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
        for ext in server.extensions {
            ext.on_worker_start(server);
        }
        auth = {
            "Authorization": f"Bearer {client.register_and_login(
                'jobs_user', 'Passw0rd!long'
            )}"
        };
        cases: list[tuple[bool, str, str, float]] = [
            (False, "done", "", 10.0),
            (True, "dead", "ran past timeout_s=0.5", 2.5)
        ];
        for (hang, status, error, budget) in cases {
            queued = extract_data(
                client.post(
                    "/walker/QueueReview",
                    json={"run_id": f"r-{hang}", "hang": hang},
                    headers=auth
                ).json()
            );
            job_id = queued["reports"][0]["job_id"];
            started = time.monotonic();
            seen: dict[str, any] = {};
            while time.monotonic() - started < budget {
                seen = extract_data(
                    client.post(
                        "/walker/ReviewStatus", json={"job_id": job_id}, headers=auth
                    ).json()
                )["reports"][0];
                if seen["status"] == status {
                    break;
                }
                time.sleep(0.1);
            }
            assert seen.get("status") == status , f"hang={hang}: {seen} after {budget}s";
            assert error in seen["last_error"] , f"hang={hang}: {seen['last_error']}";
        }
    } finally {
        if client is not None {
            for ext in client.server.extensions {
                if isinstance(ext, JobQueueExtension) and ext.runner is not None {
                    ext.runner.stop(1.0);
                }
            }
            client.close();
        }
        reset_scale_config();
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
