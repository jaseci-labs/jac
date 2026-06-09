"""Current UTC time as an ISO-8601 string. Used for timestamps persisted to the store."""
def _utc_now_iso -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}

"""Validate inputs and return a TriggerSpec. Raises ValueError on bad input."""
impl TriggerSpec.validate(
    trigger: str,
    interval: float | None = None,
    cron: str | None = None,
    date: str | None = None
) -> TriggerSpec {
    valid = ('interval', 'cron', 'date');
    if trigger not in valid {
        raise ValueError(f"trigger must be one of: {list(valid)}");
    }
    if trigger == 'interval' {
        if interval is None {
            raise ValueError("interval (seconds) required for trigger='interval'");
        }
        if float(interval) <= 0 {
            raise ValueError("interval must be > 0 seconds");
        }
    } elif trigger == 'cron' {
        if not cron {
            raise ValueError("cron expression required for trigger='cron'");
        }
        # Structural + range validation via APScheduler's parser. Catches things
        # like '99 99 99 99 99' that pass a naive 5-field check. If APScheduler
        # is not installed, cron triggers are unsupported — don't silently accept.
        _ct: Any = CronTrigger;
        if _ct is None {
            raise ValueError(
                "cron triggers require APScheduler. Install with: pip install jac-scale[scheduler]"
            );
        }
        try {
            _ct.from_crontab(cron);
        } except Exception as e {
            raise ValueError(f"invalid cron expression: {e}");
        }
    } elif trigger == 'date' {
        if not date {
            raise ValueError("date (ISO datetime string) required for trigger='date'");
        }
    }
    return TriggerSpec(trigger=trigger, interval=interval, cron=cron, date=date);
}

"""Rehydrate a TriggerSpec from a persisted job dict (no validation)."""
impl TriggerSpec.from_dict(d: dict) -> TriggerSpec {
    return TriggerSpec(
        trigger=d.get('trigger', 'interval'),
        interval=d.get('interval'),
        cron=d.get('cron'),
        date=d.get('date')
    );
}

"""Return the fields as a dict for job-data persistence."""
impl TriggerSpec.to_dict -> dict {
    return {
        'trigger': self.trigger,
        'interval': self.interval,
        'cron': self.cron,
        'date': self.date
    };
}

"""Build the kwargs for APScheduler.add_job(..., trigger=..., **kwargs).
Cron and date inputs are interpreted in the scheduler's default timezone (UTC).
"""
impl TriggerSpec.apscheduler_kwargs -> dict {
    if self.trigger == 'interval' {
        # validate() guarantees interval is not None and > 0 for trigger='interval'.
        return {'seconds': float(self.interval)};
    }
    if self.trigger == 'cron' {
        fields = (self.cron or '').strip().split();
        (f_min, f_hour, f_day, f_month, f_weekday) = fields;
        return {
            'minute': f_min,
            'hour': f_hour,
            'day': f_day,
            'month': f_month,
            'day_of_week': f_weekday
        };
    }
    return {'run_date': self.date};
}

"""MongoJobStore — DB-backed, authoritative when configured."""
impl MongoJobStore.postinit -> None {
    try {
        self._db.create_index(
            self._collection, {'job_id': 1}, unique=True, name='job_id_unique'
        );
    } except Exception as e {
        logger.warning(f"Could not ensure job_id index: {e}");
    }
}

impl MongoJobStore.insert(job: dict) -> str {
    self._db.insert_one(self._collection, dict(job));
    return str(job['job_id']);
}

impl MongoJobStore.find_active(
    limit: int | None = None,
    offset: int = 0,
    trigger: str | None = None,
    created_by: str | None = None
) -> tuple[list[dict], int] {
    query: dict[str, Any] = {'status': 'active'};
    if trigger {
        query['trigger'] = trigger;
    }
    if created_by {
        query['created_by'] = created_by;
    }
    # Count matching docs first so callers can paginate without rerunning the filter set.
    total = self._db.count_documents(self._collection, query);
    cursor: Any = self._db.find(self._collection, query, {'_id': 0});
    if offset > 0 {
        cursor = cursor.skip(offset);
    }
    if limit is not None {
        cursor = cursor.limit(limit);
    }
    return ([doc for doc in cursor], total);
}

impl MongoJobStore.find_active_one(job_id: str) -> dict | None {
    return self._db.find_one(
        self._collection, {'job_id': job_id, 'status': 'active'}, {'_id': 0}
    );
}

"""Build a single-job mongo filter, merging an optional `where` predicate.

Centralises the `{'job_id': ...} + where` pattern shared by update/delete so
ownership/state predicates are applied identically across the two paths.
"""
def _job_filter(job_id: str, where: dict | None) -> dict[str, Any] {
    f: dict[str, Any] = {'job_id': job_id};
    if where {
        f.update(where);
    }
    return f;
}

impl MongoJobStore.update(
    job_id: str, updates: dict, where: dict | None = None
) -> bool {
    result = self._db.update_one(
        self._collection, _job_filter(job_id, where), {'$set': updates}
    );
    return result.modified_count > 0;
}

impl MongoJobStore.delete(job_id: str, where: dict | None = None) -> bool {
    result = self._db.delete_one(self._collection, _job_filter(job_id, where));
    return result.deleted_count > 0;
}

impl MongoJobStore.record_run(
    job_id: str, status: str, error: str | None = None
) -> None {
    # One atomic round-trip: $inc on run_count, $set on the last_* fields.
    self._db.update_one(
        self._collection,
        {'job_id': job_id},
        {
            '$inc': {'run_count': 1},
            '$set': {
                'last_run_at': _utc_now_iso(),
                'last_status': status,
                'last_error': error
            }
        }
    );
}

"""MemoryJobStore — fallback when no DB is configured.

Lazy-init per-instance: the `_jobs` field defaults to None (class-level) and
the real dict is allocated here, so the class-level value can never be a
shared-across-instances mutable. Same pattern as `JacScaleScheduler._store`.
"""
impl MemoryJobStore.postinit -> None {
    self._jobs = {};
}

impl MemoryJobStore.insert(job: dict) -> str {
    job_id = str(job['job_id']);
    self._jobs[job_id] = dict(job);
    return job_id;
}

impl MemoryJobStore.find_active(
    limit: int | None = None,
    offset: int = 0,
    trigger: str | None = None,
    created_by: str | None = None
) -> tuple[list[dict], int] {
    # Single pass through the dict applying all active/trigger/creator filters.
    matches: list[dict] = [];
    for j in self._jobs.values() {
        if j.get('status') != 'active' {
            continue;
        }
        if trigger is not None and j.get('trigger') != trigger {
            continue;
        }
        if created_by is not None and j.get('created_by') != created_by {
            continue;
        }
        matches.append(j);
    }
    total = len(matches);
    end = (offset + limit) if limit is not None else total;
    return (matches[offset:end], total);
}

impl MemoryJobStore.find_active_one(job_id: str) -> dict | None {
    job = self._jobs.get(job_id);
    if job and job.get('status') == 'active' {
        return job;
    }
    return None;
}

impl MemoryJobStore.update(
    job_id: str, updates: dict, where: dict | None = None
) -> bool {
    job = self._jobs.get(job_id);
    if job is None {
        return False;
    }
    if where {
        for (k, v) in where.items() {
            if job.get(k) != v {
                return False;
            }
        }
    }
    job.update(updates);
    return True;
}

impl MemoryJobStore.delete(job_id: str, where: dict | None = None) -> bool {
    job = self._jobs.get(job_id);
    if job is None {
        return False;
    }
    if where {
        for (k, v) in where.items() {
            if job.get(k) != v {
                return False;
            }
        }
    }
    del self._jobs[job_id];
    return True;
}

impl MemoryJobStore.record_run(
    job_id: str, status: str, error: str | None = None
) -> None {
    job = self._jobs.get(job_id);
    if job is None {
        return;
    }
    job['last_run_at'] = _utc_now_iso();
    job['last_status'] = status;
    job['last_error'] = error;
    job['run_count'] = int(job.get('run_count', 0)) + 1;
}

"""Silence APScheduler's verbose logs on instantiation; lazy-init per-instance state."""
impl JacScaleScheduler.postinit -> None {
    logging.getLogger('apscheduler').setLevel(logging.ERROR);
    self._user_exists_cache = {};
}

"""Return True if `user_id` currently exists. Caches positive answers for
`_user_exists_ttl` seconds so a high-frequency scheduled job doesn't round-trip
to the DB on every tick. Negative answers are never cached: a deleted user
should transition to the orphaned path immediately.
"""
impl JacScaleScheduler._user_is_live(user_id: str) -> bool {
    import time;
    now = time.time();
    expires_at = self._user_exists_cache.get(user_id, 0.0);
    if expires_at > now {
        return True;
    }
    if self._server is None {
        return False;
    }
    if self._server.user_manager.user_exists(user_id) {
        self._user_exists_cache[user_id] = now + self._user_exists_ttl;
        return True;
    }
    # Negative: evict any stale positive entry.
    self._user_exists_cache.pop(user_id, None);
    return False;
}

"""Return the configured store. Raises if setup() was never called.

Use this everywhere instead of `self._store.X(...)` so the type narrows to
JobStore (non-Optional) and accidental pre-setup use fails loudly.
"""
impl JacScaleScheduler._require_store -> JobStore {
    if self._store is None {
        raise RuntimeError(
            "JacScaleScheduler not initialized — call setup() before using the store"
        );
    }
    return self._store;
}

"""Return or create the module-level singleton JacScaleScheduler."""
impl JacScaleScheduler.instance -> JacScaleScheduler {
    global _jac_scale_scheduler;
    if _jac_scale_scheduler is not None {
        return _jac_scale_scheduler;
    }
    _jac_scale_scheduler = JacScaleScheduler();
    return _jac_scale_scheduler;
}

"""Set up the scheduler with the system user's id and optional server reference."""
impl JacScaleScheduler.setup(system_user_id: str, server: Any | None = None) -> None {
    self._system_user_id = system_user_id;
    self._server = server;

    # Register the dynamic handler via the public API in jaclang's scheduler.
    def _dynamic_handler(task: Any) {
        self._execute_task(task.name, self._system_user_id, task.is_walker);
    }
    Scheduler.instance().dynamic_handler = _dynamic_handler;

    # Configure the JobStore: MongoJobStore when a URI is configured (authoritative),
    # otherwise MemoryJobStore as a fallback.
    scheduler_cfg = get_scale_config().get_scheduler_config();
    collection = scheduler_cfg.get('collection', 'scheduled_jobs');
    db_cfg = get_scale_config().get_database_config();
    if db_cfg.get('mongodb_uri') {
        try {
            mongo_db = Db(client=get_mongo_client());
            self._store = MongoJobStore(_db=mongo_db, _collection=collection);
            logger.debug("MongoDB configured — jobs will be persisted");
        } except Exception as e {
            logger.warning(f"MongoDB connection failed, using in-memory: {e}");
            self._store = MemoryJobStore();
        }
    } else {
        self._store = MemoryJobStore();
    }
    self._user_exists_ttl = float(scheduler_cfg.get('user_exists_ttl', 30.0));

    # APScheduler uses an in-memory job store — persistence goes through self._store,
    # avoiding serialisation issues with closures.
    if HAS_APSCHEDULER {
        pool_size = int(scheduler_cfg.get('thread_pool_size', 10));
        misfire = int(scheduler_cfg.get('misfire_grace_time', 60));
        executors = {'default': ThreadPoolExecutor(pool_size)};
        job_defaults = {
            'coalesce': False,
            'max_instances': 1,
            'misfire_grace_time': misfire
        };
        # Default timezone is UTC. Per-job overrides flow through TriggerSpec
        # and are applied when the job is added (see apscheduler_kwargs).
        self._apscheduler = BackgroundScheduler(
            executors=executors,
            job_defaults=job_defaults,
            timezone=datetime.timezone.utc
        );
        logger.debug(
            f"APScheduler initialized (pool_size={pool_size}, misfire_grace={misfire}s, tz=UTC)"
        );
    } else {
        self._apscheduler = None;
        logger.info(
            "APScheduler not installed — dynamic scheduling disabled. "
            "Install with: pip install jac-scale[scheduler]"
        );
    }
}

"""Start the APScheduler background scheduler."""
impl JacScaleScheduler.start -> None {
    if self._apscheduler is not None {
        try {
            self._apscheduler.start();
            logger.info("APScheduler started (timezone=UTC)");
        } except Exception as e {
            logger.error(f"Failed to start APScheduler: {e}");
        }
    }
}

"""Stop the APScheduler background scheduler.

If `drain=True`, wait for in-flight scheduled jobs to complete before returning.
Base Scheduler (static tasks) is stopped too.
"""
impl JacScaleScheduler.stop(drain: bool = False) -> None {
    if self._apscheduler is not None and self._apscheduler.running {
        try {
            self._apscheduler.shutdown(wait=drain);
            logger.info(f"Scheduler stopped (drain={drain})");
        } except Exception as e {
            logger.debug(f"Error stopping APScheduler: {e}");
        }
    }
    try {
        Scheduler.instance().stop();
    } except Exception as e {
        logger.debug(f"Error stopping base Scheduler: {e}");
    }
}

"""Register static tasks (STATIC trigger) with the base jaclang Scheduler."""
impl JacScaleScheduler.register_static_tasks(
    walkers: dict, functions: dict, server: Any
) -> None {
    self._server = server;
    base_scheduler = Scheduler.instance();

    def _make_target(_name: str, _is_walker: bool) -> Any {
        def target {
            self._execute_task(_name, self._system_user_id, _is_walker);
        }
        return target;
    }

    for (registry, is_walker) in [(walkers, True), (functions, False)] {
        label = 'walker' if is_walker else 'function';
        for item_name in registry {
            item = registry[item_name];
            spec = item.schedule_spec if item?.schedule_spec else None;
            if spec is None {
                continue;
            }
            if spec.trigger != ScheduleTrigger.STATIC {
                logger.debug(
                    f"'{item_name}' has DYNAMIC trigger — managed by APScheduler"
                );
                continue;
            }
            logger.debug(f"Registered static {label}: {item_name}");
            base_scheduler.register(
                name=item_name,
                target=_make_target(item_name, is_walker),
                spec=spec,
                is_walker=is_walker
            );
        }
    }

    if base_scheduler._tasks {
        base_scheduler.start();
        logger.info(
            f"Base Scheduler started with {len(base_scheduler._tasks)} static task(s)"
        );
    } else {
        logger.info("No static scheduled tasks registered");
    }
}

"""Load persisted dynamic jobs from DB and re-add them to APScheduler."""
impl JacScaleScheduler.register_dynamic_tasks_from_db -> None {
    if self._apscheduler is None {
        return;
    }
    (jobs, _total) = self._require_store().find_active();
    restored = 0;
    orphaned = 0;
    failed = 0;
    for job_data in jobs {
        job_id = str(job_data.get('job_id', str(uuid4())));
        name = job_data.get('name', '');
        user_id = job_data.get('created_by', self._system_user_id);
        is_walker = job_data.get('is_walker', True);
        if not name {
            continue;
        }
        if user_id != self._system_user_id and not self._user_is_live(user_id) {
            try {
                self._require_store().update(
                    job_id,
                    {'status': 'orphaned', 'orphaned_at': _utc_now_iso()},
                    where={'status': 'active'}
                );
            } except Exception as e {
                logger.debug(f"Could not mark job {job_id} orphaned: {e}");
            }
            logger.warning(
                f"Skipping restore of '{name}' (id={job_id}): creator '{user_id}' no longer exists"
            );
            orphaned += 1;
            continue;
        }
        try {
            spec = TriggerSpec.from_dict(job_data);
            self._schedule_apscheduler_job(
                job_id=job_id,
                name=name,
                spec=spec,
                user_id=user_id,
                is_walker=is_walker
            );
            logger.debug(f"Restored dynamic job: {name} (id={job_id})");
            restored += 1;
        } except Exception as e {
            logger.error(f"Failed to restore job '{name}': {e}");
            failed += 1;
        }
    }
    if restored or failed or orphaned {
        logger.info(
            f"Dynamic job restoration complete: {restored} restored, "
            f"{orphaned} orphaned, {failed} failed"
        );
    } else {
        logger.info("No persisted dynamic jobs to restore");
    }
}

"""Create a new dynamic scheduled job. Runs as the creating user (created_by)."""
impl JacScaleScheduler.create_job(
    name: str, spec: TriggerSpec, created_by: str
) -> dict {
    if self._apscheduler is None {
        raise RuntimeError(
            "APScheduler is not available. Install with: pip install jac-scale[scheduler]"
        );
    }

    job_id = str(uuid4());
    now_str = _utc_now_iso();

    # Resolve whether this is a walker or function once, persist it
    introspector = self._server.introspector if self._server else None;
    is_walker = name in (introspector._walkers or {}) if introspector else False;

    job_data: dict = {
        'job_id': job_id,
        'name': name,
        'created_by': created_by,
        'is_walker': is_walker,
        'created_at': now_str,
        'status': 'active'
    };
    job_data.update(spec.to_dict());

    # No per-process lock: insert is atomic via the unique job_id index, and
    # APScheduler.add_job handles its own thread safety.
    store = self._require_store();
    persisted_id = store.insert(job_data);
    job_data['job_id'] = persisted_id;
    # Schedule with APScheduler. Dynamic jobs execute as the creating user
    # (created_by), not the system user.
    #
    # The outer except catches the rare cases where add_job fails *after*
    # validation passed: APS shutdown race, internal APS errors, etc. (Cron
    # and date inputs are already parsed by TriggerSpec.validate, so format
    # errors don't reach here.) Rolling back the DB row prevents a retried
    # request from creating a duplicate record alongside the zombie one.
    #
    # The inner try/except guards the rollback itself: if mongo blips during
    # the delete, we log the leaked job_id (orphan-detection on next restart
    # will clean it up) and let the original scheduling error propagate to
    # the caller. Without this, the rollback exception would replace the
    # original one, hiding the real root cause from the user and from logs.
    try {
        self._schedule_apscheduler_job(
            job_id=persisted_id,
            name=name,
            spec=spec,
            user_id=created_by,
            is_walker=is_walker
        );
    } except Exception {
        try {
            store.delete(persisted_id);
        } except Exception as rollback_err {
            logger.error(
                f"Failed to roll back zombie job record {persisted_id} after "
                f"schedule failure: {type(rollback_err).__name__}: {rollback_err}"
            );
        }
        raise;
    }

    logger.debug(f"Created dynamic job: {name} (id={persisted_id})");
    return job_data;
}

"""List active dynamic jobs. Pagination + filters are pushed to the store."""
impl JacScaleScheduler.list_jobs(
    limit: int | None = None,
    offset: int = 0,
    trigger: str | None = None,
    created_by: str | None = None
) -> tuple[list[dict], int] {
    return self._require_store().find_active(
        limit=limit, offset=offset, trigger=trigger, created_by=created_by
    );
}

"""Get a single dynamic job by ID."""
impl JacScaleScheduler.get_job(job_id: str) -> (dict | None) {
    return self._require_store().find_active_one(job_id);
}

"""Update schedule for an existing dynamic job.

If `acting_as` is set, the write is conditional on the job belonging to that
user — the predicate is evaluated atomically by the store, so an unauthorized
or racing write returns 0 modified rows and surfaces as None to the caller.
APScheduler.add_job is internally thread-safe, so no per-process lock is taken.
"""
impl JacScaleScheduler.update_job(
    job_id: str, spec: TriggerSpec, acting_as: str | None = None
) -> (dict | None) {
    existing = self.get_job(job_id);
    if existing is None {
        return None;
    }

    name = existing.get('name', '');
    user_id = existing.get('created_by', self._system_user_id);
    is_walker = existing.get('is_walker', True);
    updates: dict[str, Any] = {'updated_at': _utc_now_iso()};
    updates.update(spec.to_dict());

    where = {'created_by': acting_as} if acting_as is not None else None;
    # DB is authoritative. If the predicate no longer holds (deleted, transferred,
    # auth bypass attempt) the write is a no-op and we return None.
    if not self._require_store().update(job_id, updates, where=where) {
        return None;
    }
    if self._apscheduler is not None {
        self._schedule_apscheduler_job(
            job_id=job_id, name=name, spec=spec, user_id=user_id, is_walker=is_walker
        );
    }

    updated = dict(existing);
    updated.update(updates);
    logger.debug(f"Updated dynamic job: {name} (id={job_id})");
    return updated;
}

"""Delete a dynamic scheduled job.

If `acting_as` is set, the delete only applies when the job belongs to that
user (single atomic mongo op). APScheduler.remove_job is internally thread-safe.
"""
impl JacScaleScheduler.delete_job(job_id: str, acting_as: str | None = None) -> bool {
    where = {'created_by': acting_as} if acting_as is not None else None;
    # DB first: if deletion fails, APScheduler still fires the job — safe.
    # If we removed APScheduler first and the DB delete failed, the job
    # would resurrect on next restart via register_dynamic_tasks_from_db.
    result = self._require_store().delete(job_id, where=where);
    if result and self._apscheduler is not None {
        try {
            self._apscheduler.remove_job(job_id);
        } except Exception as e {
            logger.warning(
                f"DB row for job {job_id} deleted but APScheduler.remove_job failed: {e}. "
                f"Job may keep firing until restart."
            );
        }
        logger.debug(f"Deleted dynamic job id={job_id}");
    }
    return result;
}

"""Execute a scheduled walker or function in the context of the given user.

If `job_id` is provided (dynamic jobs), records execution history into the store.
Static jobs pass job_id=None and skip history recording.
"""
impl JacScaleScheduler._execute_task(
    name: str, user_id: str, is_walker: bool, job_id: str | None = None
) -> None {
    import asyncio;
    label = 'walker' if is_walker else 'function';
    try {
        if self._server is None {
            logger.error(f"Cannot execute {label} '{name}': server reference not set");
            self._mark_failed(job_id, 'server reference not set');
            return;
        }
        introspector = self._server.introspector;
        registry: dict[str, Any] = (
            introspector._walkers if is_walker else introspector._functions
        )
        or {};
        target = registry.get(name);
        if target is None {
            logger.warning(
                f"Scheduled {label} '{name}' is no longer registered in the server"
            );
            self._mark_failed(job_id, 'target not registered');
            return;
        }

        async def _run {
            import from jac_scale.context { JScaleExecutionContext }
            import from jaclang { JacRuntime as Jac }
            # Each scheduled job runs in its own isolated root context so
            # concurrent jobs cannot share L1 state or interfere with
            # in-flight HTTP requests that may be using the global context.
            ctx = JScaleExecutionContext();
            ctx_token = Jac.push_request_context(ctx);
            try {
                if is_walker {
                    result = await self._server.execution_manager.spawn_walker(
                        target, {}, user_id
                    );
                } else {
                    result = await self._server.execution_manager.execute_function(
                        target, {}, user_id
                    );
                }
                if isinstance(result, dict) and 'error' in result {
                    err = str(result.get('error'));
                    logger.error(f"Scheduled {label} '{name}' error: {err}");
                    self._mark_failed(job_id, err);
                } elif job_id {
                    self._record_run(job_id, 'succeeded');
                }
            } finally {
                Jac.reset_request_context(ctx_token);
                try {
                    ctx.mem.close();
                } except Exception as ce {
                    logger.warning(f"Scheduled job context close failed: {ce}");
                }
            }
        }

        # APScheduler fires this in a worker thread with no event loop —
        # create an isolated loop per invocation to keep execution thread-safe.
        asyncio.run(_run());
    } except Exception as e {
        logger.error(f"Error executing {label} '{name}': {e}");
        self._mark_failed(job_id, str(e));
    }
}

"""Record the outcome of a scheduled execution on the job record.

Delegates to the store's atomic record_run (single round-trip for Mongo).
"""
impl JacScaleScheduler._record_run(
    job_id: str, status: str, error: str | None = None
) -> None {
    try {
        self._require_store().record_run(job_id, status, error);
    } except Exception as e {
        logger.warning(f"Could not record run for job {job_id}: {e}");
    }
}

"""Record a 'failed' run if job_id is provided. No-op for static jobs (job_id=None).

Collapses the `if job_id { self._record_run(job_id, 'failed', ...); }` guard
that every failure path in `_execute_task` would otherwise repeat.
"""
impl JacScaleScheduler._mark_failed(job_id: str | None, reason: str) -> None {
    if job_id {
        self._record_run(job_id, 'failed', reason);
    }
}

"""Add a job to APScheduler using a validated TriggerSpec."""
impl JacScaleScheduler._schedule_apscheduler_job(
    job_id: str, name: str, spec: TriggerSpec, user_id: str, is_walker: bool = True
) -> None {
    if self._apscheduler is None {
        raise RuntimeError("APScheduler is not initialized");
    }

    def job_func {
        # Dynamic jobs run as the creating user. If that user has been deleted,
        # mark the job orphaned and unregister so it stops firing.
        if user_id != self._system_user_id and self._server is not None {
            if not self._user_is_live(user_id) {
                logger.warning(
                    f"Job '{name}' (id={job_id}) creator '{user_id}' no longer exists — marking orphaned"
                );
                # Conditional update: only flip status if it's still active so
                # concurrent orphan-detection in another replica is idempotent.
                # APScheduler.remove_job is internally thread-safe.
                self._require_store().update(
                    job_id,
                    {'status': 'orphaned', 'orphaned_at': _utc_now_iso()},
                    where={'status': 'active'}
                );
                try {
                    self._apscheduler.remove_job(job_id);
                } except Exception as e {
                    logger.debug(
                        f"Could not remove orphaned APScheduler job {job_id}: {e}"
                    );
                }
                return;
            }
        }
        self._execute_task(name, user_id, is_walker, job_id=job_id);
    }

    self._apscheduler.add_job(
        job_func,
        spec.trigger,
        id=job_id,
        replace_existing=True,
        **spec.apscheduler_kwargs()
    );
}
