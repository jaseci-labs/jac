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
    lease_s: float = 60.0
) -> JobRunner {
    return JobRunner(
        store=JobQueueStore(store=pg.new_session()),
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
    lock = threading.Lock();
    def _record(job: JobInfo) {
        with lock {
            runs.append(job.id);
        }
        time.sleep(0.005);
    }
    runners = [_runner(pg, queue, _record, concurrency=4) for _ in range(2)];
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
}


test "a killed runner's job runs again once its lease expires" {
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
}


test "a failing job backs off between attempts and is dead after max_attempts" {
    pg = _pg();
    if pg is None {
        return;
    }
    cases: list[tuple[str, Exception, int]] = [
        ("an error is retried", RuntimeError("provider timed out"), 3),
        ("a missing target is not", JobTargetMissing("'Gone' is not served"), 1)
    ];
    for (label, error, runs_until_dead) in cases {
        queue = _queue();
        jobs = JobQueueStore(store=pg);
        job_id = jobs.insert(queue, "Work", {}, max_attempts=3);
        def _fail(job: JobInfo) {
            raise error;
        }
        runner = _runner(pg, queue, _fail);
        for attempt in range(1, runs_until_dead + 1) {
            assert runner.run_once(queue) , f"{label}: attempt {attempt} not claimed";
            info = _job(jobs.get(job_id));
            if attempt == runs_until_dead {
                assert info.status == STATUS_DEAD , f"{label}: {info.status}";
                assert str(error) in info.last_error , f"{label}: {info.last_error}";
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
        assert by_ref.target == f"{_queue.__module__}:_queue" , by_ref.target;

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
