"""Guards #8000 follow-up 2 (A/B/F): multi-pod scheduler correctness.

#7947 made the deploy story multi-pod Postgres, but the scheduler kept
single-pod semantics: every pod restored and fired every job, and job CRUD
mutated only the local APScheduler. These tests stand up two in-process
"pods" over one embedded Postgres and prove each tick is claimed by one
pod, jobs-changed NOTIFY reaches the other pod, and (with
APScheduler installed) a due job fires exactly once while DELETE stops it
on every pod without a restart.
"""

import time;
import datetime;
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
import from jaclang.server.task_scheduler { tick_of }

glob _holder: dict[str, any] = {};


def _store -> (PgStore | None) {
    try {
        if 'rt' not in _holder {
            _holder['rt'] = PgRuntime(data_dir=mkdtemp(prefix='jacsched_') + '/data');
        }
        store = PgStore(conninfo=_holder['rt'].ensure());
        store.ensure_schema({});
        return store;
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


def _pod(store: PgStore, collection: str, service: str = "") -> JacScaleScheduler {
    sched = JacScaleScheduler();
    sched._service = service;
    sched._store = PgJobStore(store=store, _collection=collection, _service=service);
    return sched;
}


def _on_grid(when: datetime.datetime, seconds: int) -> datetime.datetime {
    epoch = datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc);
    step = datetime.timedelta(seconds=seconds);
    return epoch + step * ((when - epoch) // step);
}


obj _Introspector {
    has _walkers: dict[str, any] = {},
        _functions: dict[str, any] = {};
}


obj _Server {
    has introspector: _Introspector,
        module_name: str = "billing";
}


obj _UnreachableStore {
    def kv_claim_tick(key: str, tick: int) -> bool {
        raise ConnectionError("the database is restarting");
    }
}


def _job(job_id: str, interval: float) -> dict[str, any] {
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


test "each tick of a job is claimed by exactly one pod" {
    sa = _store();
    if sa is None {
        return;
    }
    sb = _store();
    if sb is None {
        return;
    }
    pod_a = _pod(sa, 'mp_claim');
    pod_b = _pod(sb, 'mp_claim');
    spec = TriggerSpec(trigger='interval', interval=610.0);
    tick = _on_grid(
        datetime.datetime(2026, 9, 15, 12, 0, tzinfo=datetime.timezone.utc), 610
    );
    ms = datetime.timedelta(milliseconds=1);

    first = [
        pod_a._claim_fire('claim-job', spec, tick + 200 * ms),
        pod_b._claim_fire('claim-job', spec, tick + 900 * ms)
    ];
    assert sorted(first) == [False, True] , f"one pod per tick, got {first}";

    # #9027: 303 s later, past the old 300 s lease, a respawned worker still
    # inside the same tick used to fire it a second time.
    stale = pod_a._claim_fire(
        'claim-job', spec, tick + datetime.timedelta(seconds=303)
    );
    assert stale is False , "a tick that already ran must not run again";

    nxt = tick + datetime.timedelta(seconds=610);
    second = [
        pod_b._claim_fire('claim-job', spec, nxt + 50 * ms),
        pod_a._claim_fire('claim-job', spec, nxt + 400 * ms)
    ];
    assert sorted(second) == [False, True] , f"the next tick is claimable once, got {second}";
}


test "interval jobs scheduled apart share one phase" {
    require_module("apscheduler");
    import from apscheduler.triggers.interval { IntervalTrigger }
    utc = datetime.timezone.utc;
    spec = TriggerSpec(trigger='interval', interval=610.0);
    boot_a = datetime.datetime(2026, 9, 15, 11, 33, 13, 500000, tzinfo=utc);
    boot_b = boot_a + datetime.timedelta(seconds=305);
    first_a = IntervalTrigger(
        timezone=utc, **spec.apscheduler_kwargs()
    ).get_next_fire_time(
        None, boot_a
    );
    first_b = IntervalTrigger(
        timezone=utc, **spec.apscheduler_kwargs()
    ).get_next_fire_time(
        None, boot_b
    );
    for fire in [first_a, first_b] {
        assert tick_of(fire) % (610 * 1000000) == 0 , f"{fire} is off the shared grid";
        assert spec.due_tick(fire) == tick_of(fire) , "a fire must claim its own tick";
    }
}


test "a job whose tick cannot be claimed is skipped" {
    # #9030: a failed lease check used to answer True, so a database outage
    # ran the job on every worker of every pod at once.
    pod = JacScaleScheduler();
    pod._store = PgJobStore(store=_UnreachableStore(), _collection='mp_down');
    spec = TriggerSpec(trigger='interval', interval=60.0);
    now = datetime.datetime(2026, 9, 15, 12, 0, 5, tzinfo=datetime.timezone.utc);
    assert pod._claim_fire('down-job', spec, now) is False;
    assert pod._claim_fire('down-job', spec, now + datetime.timedelta(seconds=60))
        is False;
}


test "services sharing a collection see only their own jobs" {
    sa = _store();
    if sa is None {
        return;
    }
    orders = PgJobStore(store=sa, _collection='mp_scope', _service='orders');
    billing = PgJobStore(store=sa, _collection='mp_scope', _service='billing');
    mine = _job('scope-orders', 60.0);
    mine['service'] = 'orders';
    theirs = _job('scope-billing', 60.0);
    theirs['service'] = 'billing';
    orders.insert(mine);
    billing.insert(theirs);
    orders.insert(_job('scope-legacy', 60.0));

    (seen, total) = orders.find_active();
    ids = sorted([str(j['job_id']) for j in seen]);
    assert ids == ['scope-legacy', 'scope-orders'] and total == 2 , (ids, total);
    assert orders.find_active_one('scope-billing') is None;
    assert orders.update('scope-billing', {'interval': 1.0}) is False;
    assert orders.delete('scope-billing') is False;
    assert billing.find_active_one('scope-billing') is not None;
}


test "restore leaves a job to the service that serves its target" {
    require_module("apscheduler");
    import from apscheduler.schedulers.background { BackgroundScheduler }
    sa = _store();
    if sa is None {
        return;
    }
    pod = _pod(sa, 'mp_restore', 'billing');
    engine = BackgroundScheduler(timezone=datetime.timezone.utc);
    pod._apscheduler = engine;
    pod._server = _Server(
        introspector=_Introspector(_functions={'beat': lambda { None; }})
    );
    store = pod._store;
    assert store is not None;

    # #9028: this row's target lives in another service. It used to be
    # restored here, win ticks, and record a failed run on each.
    ghost = _job('ghost-1', 2.0);
    ghost['name'] = 'GhostWalker';
    ghost['is_walker'] = True;
    legacy = _job('legacy-beat', 2.0);
    legacy['name'] = 'beat';
    foreign = _job('orders-beat', 2.0);
    foreign['name'] = 'beat';
    foreign['service'] = 'orders';
    stamped = _job('billing-beat', 2.0);
    stamped['name'] = 'beat';
    stamped['service'] = 'billing';
    for row in [ghost, legacy, foreign, stamped] {
        store.insert(row);
    }

    pod.register_dynamic_tasks_from_db();
    scheduled = sorted([str(j.id) for j in engine.get_jobs()]);
    assert scheduled == ['billing-beat', 'legacy-beat'] , scheduled;

    # An update to an unstamped row reaches every pod as a NOTIFY; only the
    # service that serves its target may pick it up.
    pod._on_jobs_changed('ghost-1');
    after = sorted([str(j.id) for j in engine.get_jobs()]);
    assert after == ['billing-beat', 'legacy-beat'] , after;
    assert pod.update_job('ghost-1', TriggerSpec(trigger='interval', interval=4.0))
        is not None;
    assert 'ghost-1' not in [str(j.id) for j in engine.get_jobs()];
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
