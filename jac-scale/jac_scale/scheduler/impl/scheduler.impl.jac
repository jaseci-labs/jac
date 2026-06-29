def _utc_now_iso -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}

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

impl TriggerSpec.from_dict(d: dict) -> TriggerSpec {
    return TriggerSpec(
        trigger=d.get('trigger', 'interval'),
        interval=d.get('interval'),
        cron=d.get('cron'),
        date=d.get('date')
    );
}

impl TriggerSpec.to_dict -> dict {
    return {
        'trigger': self.trigger,
        'interval': self.interval,
        'cron': self.cron,
        'date': self.date
    };
}

impl TriggerSpec.apscheduler_kwargs -> dict {
    if self.trigger == 'interval' {
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

impl JacScaleScheduler.postinit -> None {
    logging.getLogger('apscheduler').setLevel(logging.ERROR);
    self._user_exists_cache = {};
}

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

    self._user_exists_cache.pop(user_id, None);
    return False;
}

impl JacScaleScheduler._require_store -> JobStore {
    if self._store is None {
        raise RuntimeError(
            "JacScaleScheduler not initialized — call setup() before using the store"
        );
    }
    return self._store;
}

impl JacScaleScheduler.instance -> JacScaleScheduler {
    global _jac_scale_scheduler;
    if _jac_scale_scheduler is not None {
        return _jac_scale_scheduler;
    }
    _jac_scale_scheduler = JacScaleScheduler();
    return _jac_scale_scheduler;
}

impl JacScaleScheduler.setup(system_user_id: str, server: Any | None = None) -> None {
    self._system_user_id = system_user_id;
    self._server = server;

    def _dynamic_handler(task: Any) {
        self._execute_task(task.name, self._system_user_id, task.is_walker);
    }
    Scheduler.instance().dynamic_handler = _dynamic_handler;

    scheduler_cfg = get_scale_config().get_scheduler_config();
    collection = scheduler_cfg.get('collection', 'scheduled_jobs');
    db_cfg = get_scale_config().get_database_config();
    if db_cfg.get('mongodb_uri') {
        try {
            mongo_db = MongoDb(client=get_mongo_client());
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

    if HAS_APSCHEDULER {
        pool_size = int(scheduler_cfg.get('thread_pool_size', 10));
        misfire = int(scheduler_cfg.get('misfire_grace_time', 60));
        executors = {'default': ThreadPoolExecutor(pool_size)};
        job_defaults = {
            'coalesce': False,
            'max_instances': 1,
            'misfire_grace_time': misfire
        };

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

    store = self._require_store();
    persisted_id = store.insert(job_data);
    job_data['job_id'] = persisted_id;

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

impl JacScaleScheduler.get_job(job_id: str) -> (dict | None) {
    return self._require_store().find_active_one(job_id);
}

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

impl JacScaleScheduler.delete_job(job_id: str, acting_as: str | None = None) -> bool {
    where = {'created_by': acting_as} if acting_as is not None else None;

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
            import from jac_scale.memory.context { JScaleExecutionContext }
            import from jaclang { JacRuntime as Jac }

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

        asyncio.run(_run());
    } except Exception as e {
        logger.error(f"Error executing {label} '{name}': {e}");
        self._mark_failed(job_id, str(e));
    }
}

impl JacScaleScheduler._record_run(
    job_id: str, status: str, error: str | None = None
) -> None {
    try {
        self._require_store().record_run(job_id, status, error);
    } except Exception as e {
        logger.warning(f"Could not record run for job {job_id}: {e}");
    }
}

impl JacScaleScheduler._mark_failed(job_id: str | None, reason: str) -> None {
    if job_id {
        self._record_run(job_id, 'failed', reason);
    }
}

impl JacScaleScheduler._schedule_apscheduler_job(
    job_id: str, name: str, spec: TriggerSpec, user_id: str, is_walker: bool = True
) -> None {
    if self._apscheduler is None {
        raise RuntimeError("APScheduler is not initialized");
    }

    def job_func {
        if user_id != self._system_user_id and self._server is not None {
            if not self._user_is_live(user_id) {
                logger.warning(
                    f"Job '{name}' (id={job_id}) creator '{user_id}' no longer exists — marking orphaned"
                );

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
