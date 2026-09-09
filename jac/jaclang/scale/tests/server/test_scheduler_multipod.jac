"""Guards #8000 follow-up 2 (A/B/F): multi-pod scheduler correctness.

#7947 made the deploy story multi-pod Postgres, but the scheduler kept
single-pod semantics: every pod restored and fired every job, and job CRUD
mutated only the local APScheduler. These tests stand up two in-process
"pods" over one embedded Postgres and prove the per-fire lease admits one
pod per tick, jobs-changed NOTIFY reaches the other pod, and (with
APScheduler installed) a due job fires exactly once while DELETE stops it
on every pod without a restart.
"""

import time;
import from tempfile { mkdtemp }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.data.store { PgStore }
import from jaclang.testing.requires { require_module }
import from jaclang.scale.scheduler.scheduler {
    JOBS_CHANGED_CHANNEL,
    JacScaleScheduler,
    PgJobStore,
    TriggerSpec
}

glob _holder: dict = {},
     _DOCS_DDL = (
         'CREATE TABLE IF NOT EXISTS jac_docs ('
         'collection text NOT NULL, id text NOT NULL, doc jsonb NOT NULL, '
         'PRIMARY KEY (collection, id))'
     );


def _store -> (PgStore | None) {
    try {
        if 'rt' not in _holder {
            _holder['rt'] = PgRuntime(data_dir=mkdtemp(prefix='jacsched_') + '/data');
        }
        store = PgStore(conninfo=_holder['rt'].ensure());
        store.ensure_schema({});
        store.rows(_DOCS_DDL, {});
        return store;
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


def _pod(store: PgStore, collection: str) -> JacScaleScheduler {
    sched = JacScaleScheduler();
    sched._store = PgJobStore(store=store, _collection=collection);
    return sched;
}


def _job(job_id: str, interval: float) -> dict {
    return {
        'job_id': job_id,
        'name': 'tick',
        'created_by': '__system__',
        'is_walker': False,
        'created_at': '2026-01-01T00:00:00+00:00',
        'status': 'active',
        'trigger': 'interval',
        'interval': interval,
        'cron': None,
        'date': None
    };
}


test "job CRUD on one pod is visible to the other pod's store" {
    sa = _store();
    if sa is None {
        return;
    }
    sb = _store();
    a = PgJobStore(store=sa, _collection='mp_crud');
    b = PgJobStore(store=sb, _collection='mp_crud');

    a.insert(_job('mp1', 60.0));
    seen = b.find_active_one('mp1');
    assert seen is not None and seen['name'] == 'tick';

    assert a.delete('mp1') is True;
    assert b.find_active_one('mp1') is None;
}


test "per-fire lease admits exactly one pod per tick" {
    sa = _store();
    if sa is None {
        return;
    }
    sb = _store();
    if sb is None {
        return;
    }
    pod_a = _pod(sa, 'mp_lease');
    pod_b = _pod(sb, 'mp_lease');
    spec = TriggerSpec(trigger='interval', interval=2.0);

    admissions = [
        pod_a._acquire_fire_lease('lease-job', spec),
        pod_b._acquire_fire_lease('lease-job', spec)
    ];
    assert sorted(admissions) == [False, True] , f"exactly one pod may win a tick, got {admissions}";

    # After the lease TTL (interval * 0.8 -> 1s) the next tick is admittable.
    time.sleep(1.2);
    assert pod_b._acquire_fire_lease('lease-job', spec) is True;
}


test "jobs-changed NOTIFY from one pod reaches the other pod's listener" {
    sa = _store();
    if sa is None {
        return;
    }
    sb = _store();
    if sb is None {
        return;
    }
    pod_a = _pod(sa, 'mp_notify');
    got: list[str] = [];
    sb.listen(JOBS_CHANGED_CHANNEL, lambda (payload: str) { got.append(payload); });

    pod_a._notify_jobs_changed('job-xyz');
    deadline = time.time() + 10.0;
    while time.time() < deadline and not got {
        time.sleep(0.1);
    }
    assert got == ['job-xyz'] , f"expected push delivery of the job id, got {got}";

    # Push, not the old 1 Hz poll: delivery must be well under a second.
    got.clear();
    started = time.time();
    pod_a._notify_jobs_changed('job-fast');
    while time.time() - started < 10.0 and not got {
        time.sleep(0.01);
    }
    assert got and (time.time() - started) < 0.9 , f"cross-pod delivery took {time.time()
        - started:.2f}s; LISTEN must be push";
}


test "two live pods fire a due job exactly once and DELETE stops both" {
    require_module("apscheduler");
    import datetime as _dt;
    import from apscheduler.schedulers.background { BackgroundScheduler }
    sa = _store();
    if sa is None {
        return;
    }
    sb = _store();
    if sb is None {
        return;
    }
    pod_a = _pod(sa, 'mp_fire');
    pod_b = _pod(sb, 'mp_fire');
    sched_a = BackgroundScheduler(timezone=_dt.timezone.utc);
    sched_b = BackgroundScheduler(timezone=_dt.timezone.utc);
    pod_a._apscheduler = sched_a;
    pod_b._apscheduler = sched_b;
    pod_a._start_jobs_listener();
    pod_b._start_jobs_listener();
    sched_a.start();
    sched_b.start();

    try {
        job_id = 'fire-once';
        store_a = pod_a._store;
        assert store_a is not None , 'pod A must carry a job store';
        store_a.insert(_job(job_id, 2.0));
        spec = TriggerSpec(trigger='interval', interval=2.0);
        # Both pods restore the same job, as register_dynamic_tasks_from_db
        # does on boot. With no server attached, an admitted fire records a
        # failed run, so run_count counts lease admissions exactly.
        for pod in [pod_a, pod_b] {
            pod._schedule_apscheduler_job(
                job_id=job_id,
                name='tick',
                spec=spec,
                user_id='__system__',
                is_walker=False
            );
        }
        time.sleep(5.0);
        doc = store_a.find_active_one(job_id);
        assert doc is not None;
        runs = int(doc.get('run_count', 0));
        assert 1 <= runs <= 3 , f"~2 ticks in 5s must admit one pod each, got run_count={runs}";

        assert pod_a.delete_job(job_id) is True;
        deadline = time.time() + 10.0;
        while time.time() < deadline and sched_b.get_jobs() {
            time.sleep(0.1);
        }
        assert not sched_a.get_jobs();
        assert not sched_b.get_jobs() , 'DELETE on pod A must stop the schedule on pod B without a restart';
    } finally {
        sched_a.shutdown(`wait=False);
        sched_b.shutdown(`wait=False);
    }
}


test "events url scheme is validated with a clean error" {
    import from jaclang.scale.server.extensions {
        validate_events_url as _validate_events_url
    }
    _validate_events_url(None);
    _validate_events_url('postgresql://u:p@h:5432/db');
    _validate_events_url('postgres://u:p@h:5432/db');
    with testraises(ValueError) as exc {
        _validate_events_url('redis://localhost:6379/0');
    }
    assert '[scale.events].url' in str(exc.value);
    assert 'postgresql://' in str(exc.value);
}
