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
import socket;
import threading;
import from tempfile { mkdtemp }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.data.store { PgStore }
import from jaclang.testing.requires { require_module }
import from jaclang.scale.scheduler.scheduler {
    JOBS_CHANGED_CHANNEL,
    JacScaleScheduler,
    PgJobStore,
    TriggerSpec,
    new_engine
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


def _unreachable_store -> PgStore {
    import from jaclang.server.session { conninfo_from_url }
    probe = socket.socket();
    probe.bind(('127.0.0.1', 0));
    port = probe.getsockname()[1];
    probe.close();
    return PgStore(
        conninfo=conninfo_from_url(f"postgresql://jac:jac@127.0.0.1:{port}/jac")
    );
}


def _wait_for_runs(engine: any, job_id: str, count: int) -> bool {
    import from apscheduler.events { EVENT_JOB_ERROR, EVENT_JOB_EXECUTED }
    seen: list[str] = [];
    done = threading.Event();
    def on_run(event: any) {
        if event.job_id == job_id {
            seen.append(job_id);
            if len(seen) >= count {
                done.set();
            }
        }
    }
    engine.add_listener(on_run, EVENT_JOB_EXECUTED | EVENT_JOB_ERROR);
    return done.`wait(15.0);
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

    # A row this service owns stays reachable for DELETE whatever its status.
    # find_active_one hides an orphaned row, which would strand it in the
    # collection with no way to remove it through the API.
    retired = _job('mp2', 60.0);
    retired['status'] = 'orphaned';
    a.insert(retired);
    assert a.find_active_one('mp2') is None;
    assert a.find_one('mp2') is not None;
    pod = JacScaleScheduler();
    pod._store = a;
    assert pod.delete_job('mp2') is True;
    assert b.find_one('mp2') is None;
}


test "each scheduled occurrence of a job is claimed by exactly one pod" {
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
    tick = _on_grid(
        datetime.datetime(2026, 9, 15, 12, 0, tzinfo=datetime.timezone.utc), 610
    );
    first = [
        pod_a._claim_fire('claim-job', tick),
        pod_b._claim_fire('claim-job', tick)
    ];
    assert sorted(first) == [False, True] , f"one pod per occurrence, got {first}";

    # #9027: a respawned worker re-running an occurrence that already ran.
    assert pod_a._claim_fire('claim-job', tick) is False;

    nxt = tick + datetime.timedelta(seconds=610);
    second = [pod_b._claim_fire('claim-job', nxt), pod_a._claim_fire('claim-job', nxt)];
    assert sorted(second) == [False, True] , f"the next occurrence is claimable once, got {second}";
    assert pod_b._claim_fire('claim-job', tick) is False , "claims only move forward";
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
    }
}


test "a job whose occurrence cannot be claimed is skipped, until it can be again" {
    # #9030: a failed lease check used to answer True, so a database outage
    # ran the job on every worker of every pod at once. Nothing listens on
    # this port, so the real claim fails the way a restarting database does.
    pod = JacScaleScheduler();
    pod._store = PgJobStore(store=_unreachable_store(), _collection='mp_down');
    at = datetime.datetime(2026, 9, 15, 12, 0, tzinfo=datetime.timezone.utc);
    assert pod._claim_fire('down-job', at) is False;
    assert pod._claim_fire('down-job', at + datetime.timedelta(seconds=60)) is False;

    # Skipping is only right if it ends. A restart or failover drops the
    # connection the claim runs on while the server itself stays up; the
    # store has to redial rather than hand back the dead one forever.
    live = _store();
    if live is None {
        return;
    }
    back = JacScaleScheduler();
    back._store = PgJobStore(store=live, _collection='mp_back');
    assert back._claim_fire('back-job', at) is True;
    try {
        live._side().run("SELECT pg_terminate_backend(pg_backend_pid())");
    } except Exception {}
    assert back._claim_fire('back-job', at + datetime.timedelta(seconds=60)) is True;
    assert back._claim_fire('back-job', at + datetime.timedelta(seconds=60)) is False;
}


test "each run carries the time it was scheduled for" {
    # APScheduler hands a job no arguments, so a run could only guess its
    # occurrence from the clock. Catch-up runs make the difference visible:
    # four missed minutes arrive together and must stay four occurrences.
    require_module("apscheduler");
    utc = datetime.timezone.utc;
    engine = new_engine(2, 3600);
    seen: list[datetime.datetime] = [];
    def record(scheduled_at: datetime.datetime | None = None) {
        if scheduled_at is not None {
            seen.append(scheduled_at);
        }
    }
    now = datetime.datetime.now(utc);
    first = now.replace(second=0, microsecond=0) - datetime.timedelta(minutes=4);
    step = datetime.timedelta(minutes=1);
    engine.add_job(
        record,
        'interval',
        id='fire-times',
        minutes=1,
        start_date=first,
        next_run_time=first
    );
    engine.start();
    try {
        assert _wait_for_runs(engine, 'fire-times', 4) , seen;
        assert seen[:4]
            == [first, first + step, first + 2 * step, first + 3 * step] , seen;
    } finally {
        engine.shutdown(`wait=False);
    }
}


test "a late run claims the occurrence it was scheduled for, not the current one" {
    # A cron occurrence delivered late used to claim the minute it started in,
    # which is not an occurrence at all, so it ran even though another pod had
    # already run the real one.
    require_module("apscheduler");
    sa = _store();
    if sa is None {
        return;
    }
    sb = _store();
    if sb is None {
        return;
    }
    utc = datetime.timezone.utc;
    top = datetime.datetime.now(utc).replace(minute=0, second=0, microsecond=0);
    pod_a = _pod(sa, 'mp_late');
    pod_b = _pod(sb, 'mp_late');
    engine = new_engine(2, 7200);
    pod_b._apscheduler = engine;
    hourly = TriggerSpec(trigger='cron', cron='0 * * * *');
    for job_id in ['ran-on-a', 'ran-nowhere'] {
        row = _job(job_id, 0.0);
        row.update({'trigger': 'cron', 'interval': None, 'cron': '0 * * * *'});
        pod_b._require_store().insert(row);
        pod_b._schedule_apscheduler_job(
            job_id=job_id,
            name='tick',
            spec=hourly,
            user_id='__system__',
            is_walker=False
        );
        engine.modify_job(job_id, next_run_time=top);
    }
    assert pod_a._claim_fire('ran-on-a', top) is True;
    engine.start();
    try {
        assert _wait_for_runs(engine, 'ran-on-a', 1);
        assert _wait_for_runs(engine, 'ran-nowhere', 1);
    } finally {
        engine.shutdown(`wait=False);
    }
    store = pod_b._require_store();
    skipped = store.find_active_one('ran-on-a');
    ran = store.find_active_one('ran-nowhere');
    assert skipped is not None and ran is not None;
    assert int(skipped.get('run_count') or 0) == 0 , f"pod A already ran {top}: {skipped}";
    assert int(ran.get('run_count') or 0) == 1 , f"the unclaimed occurrence must run once: {ran}";
}


test "services sharing a collection list every job but reach only their own" {
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

    # GET /jobs is a discovery route on the fleet gateway, which returns the
    # first service's 200, so a listing has to cover every service.
    (everyone, total_all) = orders.find_active();
    listed = sorted([str(j['job_id']) for j in everyone]);
    assert listed == ['scope-billing', 'scope-legacy', 'scope-orders']
        and total_all == 3 , listed;

    (scoped, total) = orders.find_active(service='orders');
    ids = sorted([str(j['job_id']) for j in scoped]);
    assert ids == ['scope-legacy', 'scope-orders'] and total == 2 , (ids, total);
    assert orders.find_active_one('scope-billing') is None;
    assert orders.update('scope-billing', {'interval': 1.0}) is False;
    assert orders.delete('scope-billing') is False;
    assert billing.find_active_one('scope-billing') is not None;
}


test "restore leaves a job to the service that serves its target" {
    require_module("apscheduler");
    sa = _store();
    if sa is None {
        return;
    }
    pod = _pod(sa, 'mp_restore', 'billing');
    engine = new_engine(2, 60);
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
    # A service answers only for jobs it can run, before changing anything:
    # through the gateway, its 404 is what moves discovery on to the owner.
    assert pod.get_job('ghost-1') is None;
    assert pod.get_job('orders-beat') is None;
    assert pod.get_job('legacy-beat') is not None;
    assert pod.update_job('ghost-1', TriggerSpec(trigger='interval', interval=4.0))
        is None;
    untouched = store.find_active_one('ghost-1');
    assert untouched is not None and float(untouched['interval']) == 2.0 , untouched;
    assert pod.delete_job('ghost-1') is False;
    assert store.find_active_one('ghost-1') is not None;
    assert 'ghost-1' not in [str(j.id) for j in engine.get_jobs()];
    (listed, total) = pod.list_jobs();
    assert total == 4 , [j['job_id'] for j in listed];
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
    sched_a = new_engine(2, 60);
    sched_b = new_engine(2, 60);
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
