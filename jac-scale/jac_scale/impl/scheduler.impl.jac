"""Silence APScheduler's verbose logs on instantiation."""
impl JacScaleScheduler.postinit -> None {
    logging.getLogger('apscheduler').setLevel(logging.ERROR);
    # Ensure each instance gets its own dict (avoid mutable default sharing)
    self._in_memory_jobs = {};
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

"""Set up the scheduler with a system token and optional server reference."""
impl JacScaleScheduler.setup(system_token: str, server: Any | None = None) -> None {
    self._system_token = system_token;
    self._server = server;

    # Register the dynamic handler via the public API in jaclang's scheduler.
    def _dynamic_handler(task: Any) {
        self._execute_task(task.name, self._system_username, task.is_walker);
    }
    Scheduler.instance().dynamic_handler = _dynamic_handler;

    # Configure scheduler settings and initialize DB connection once.
    scheduler_cfg = get_scale_config().get_scheduler_config();
    self._collection = scheduler_cfg.get('collection', 'scheduled_jobs');
    db_cfg = get_scale_config().get_database_config();
    if db_cfg.get('mongodb_uri') {
        try {
            self._db = Db(client=get_mongo_client(), db_name='jac_scale');
            logger.debug("MongoDB configured — jobs will be persisted");
        } except Exception as e {
            logger.warning(f"MongoDB connection failed, using in-memory: {e}");
            self._db = None;
        }
    }
    # APScheduler uses in-memory job store — MongoDB persistence is handled manually
    # via _persist_job / _load_jobs_from_db, avoiding serialisation issues with closures.
    if HAS_APSCHEDULER {
        executors = {'default': ThreadPoolExecutor(10)};
        job_defaults = {'coalesce': False, 'max_instances': 1};
        self._apscheduler = BackgroundScheduler(
            executors=executors, job_defaults=job_defaults
        );
        logger.debug("APScheduler initialized with in-memory job store");
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
            logger.debug("Scheduler started");
        } except Exception as e {
            logger.error(f"Failed to start APScheduler: {e}");
        }
    }
}

"""Stop the APScheduler background scheduler."""
impl JacScaleScheduler.stop -> None {
    if self._apscheduler is not None and self._apscheduler.running {
        try {
            self._apscheduler.shutdown(wait=False);
            logger.info("Scheduler stopped");
        } except Exception as e {
            logger.error(f"Error stopping APScheduler: {e}");
        }
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
            self._execute_task(_name, self._system_username, _is_walker);
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
            logger.debug(f"Registering static {label} task: {item_name}");
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
        logger.debug(
            f"Base Scheduler started with {len(base_scheduler._tasks)} static task(s)"
        );
    }
}

"""Load persisted dynamic jobs from DB and re-add them to APScheduler."""
impl JacScaleScheduler.register_dynamic_tasks_from_db -> None {
    if self._apscheduler is None {
        return;
    }
    jobs = self._load_jobs_from_db();
    for job_data in jobs {
        job_id = str(job_data.get('_id', str(uuid4())));
        name = job_data.get('name', '');
        trigger = job_data.get('trigger', 'interval');
        interval = job_data.get('interval');
        cron = job_data.get('cron');
        date = job_data.get('date');
        username = job_data.get('created_by', self._system_username);
        is_walker = job_data.get('is_walker', True);
        if name {
            try {
                self._schedule_apscheduler_job(
                    job_id=job_id,
                    name=name,
                    trigger=trigger,
                    interval=interval,
                    cron=cron,
                    date=date,
                    username=username,
                    is_walker=is_walker
                );
                logger.debug(f"Restored dynamic job: {name} (id={job_id})");
            } except Exception as e {
                logger.error(f"Failed to restore job '{name}': {e}");
            }
        }
    }
}

"""Create a new dynamic scheduled job."""
impl JacScaleScheduler.create_job(
    name: str,
    trigger: str,
    interval: (float | None) = None,
    cron: (str | None) = None,
    date: (str | None) = None,
    created_by: str = '__system__',
    root_id: (str | None) = None
) -> dict {
    if self._apscheduler is None {
        raise RuntimeError(
            "APScheduler is not available. Install with: pip install jac-scale[scheduler]"
        );
    }

    job_id = str(uuid4());
    now_str = datetime.datetime.now(datetime.timezone.utc).isoformat();

    # Resolve whether this is a walker or function once, persist it
    introspector = self._server.introspector if self._server else None;
    is_walker = name in (introspector._walkers or {}) if introspector else False;

    job_data: dict = {
        '_id': job_id,
        'name': name,
        'trigger': trigger,
        'interval': interval,
        'cron': cron,
        'date': date,
        'created_by': created_by,
        'root_id': root_id,
        'is_walker': is_walker,
        'created_at': now_str,
        'status': 'active'
    };

    # Schedule with APScheduler first (raises on invalid config)
    self._schedule_apscheduler_job(
        job_id=job_id,
        name=name,
        trigger=trigger,
        interval=interval,
        cron=cron,
        date=date,
        username=created_by,
        is_walker=is_walker
    );

    # Persist to DB (MongoDB or in-memory)
    persisted_id = self._persist_job(job_data);
    job_data['_id'] = persisted_id;

    logger.debug(f"Created dynamic job: {name} (id={persisted_id})");
    return job_data;
}

"""List all dynamic scheduled jobs."""
impl JacScaleScheduler.list_jobs -> list[dict] {
    return self._load_jobs_from_db();
}

"""Get a single dynamic job by ID."""
impl JacScaleScheduler.get_job(job_id: str) -> (dict | None) {
    if self._db is not None {
        try {
            doc = self._db.find_one(
                self._collection, {'_id': job_id, 'status': 'active'}
            );
            if doc {
                doc['_id'] = str(doc['_id']);
                return doc;
            }
            return None;
        } except Exception as e {
            logger.warning(f"MongoDB find_one failed, using in-memory: {e}");
        }
    }
    return self._in_memory_jobs.get(job_id);
}

"""Update schedule for an existing dynamic job."""
impl JacScaleScheduler.update_job(
    job_id: str,
    trigger: str,
    interval: (float | None) = None,
    cron: (str | None) = None,
    date: (str | None) = None
) -> (dict | None) {
    existing = self.get_job(job_id);
    if existing is None {
        return None;
    }

    name = existing.get('name', '');
    username = existing.get('created_by', self._system_username);
    is_walker = existing.get('is_walker', True);
    updates = {
        'trigger': trigger,
        'interval': interval,
        'cron': cron,
        'date': date,
        'updated_at': datetime.datetime.now(datetime.timezone.utc).isoformat()
    };

    # Remove old APScheduler job and re-add with new schedule
    if self._apscheduler is not None {
        try {
            self._apscheduler.remove_job(job_id);
        } except Exception as e {
            logger.debug(f"Could not remove old APScheduler job {job_id}: {e}");
        }
        self._schedule_apscheduler_job(
            job_id=job_id,
            name=name,
            trigger=trigger,
            interval=interval,
            cron=cron,
            date=date,
            username=username,
            is_walker=is_walker
        );
    }

    # Update DB record
    self._update_job_in_db(job_id, updates);

    updated = dict(existing);
    updated.update(updates);
    logger.debug(f"Updated dynamic job: {name} (id={job_id})");
    return updated;
}

"""Delete a dynamic scheduled job."""
impl JacScaleScheduler.delete_job(job_id: str) -> bool {
    if self._apscheduler is not None {
        try {
            self._apscheduler.remove_job(job_id);
        } except Exception as e {
            logger.debug(f"Could not remove APScheduler job {job_id}: {e}");
        }
    }
    result = self._delete_job_from_db(job_id);
    if result {
        logger.debug(f"Deleted dynamic job id={job_id}");
    }
    return result;
}

"""Execute a scheduled walker or function in the context of the given user."""
impl JacScaleScheduler._execute_task(
    name: str, username: str, is_walker: bool
) -> None {
    import asyncio;
    label = 'walker' if is_walker else 'function';
    try {
        if self._server is None {
            logger.error(f"Cannot execute {label} '{name}': server reference not set");
            return;
        }
        introspector = self._server.introspector;
        if is_walker {
            registry = introspector._walkers or introspector.get_walkers();
        } else {
            registry = introspector._functions or introspector.get_functions();
        }
        if name not in registry {
            logger.error(f"{label.capitalize()} '{name}' not found in server registry");
            return;
        }
        target = registry[name];
        logger.debug(f"Executing scheduled {label} '{name}' as '{username}'");

        async def _run {
            if is_walker {
                result = await self._server.execution_manager.spawn_walker(
                    target, {}, username
                );
            } else {
                result = await self._server.execution_manager.execute_function(
                    target, {}, username
                );
            }
            if isinstance(result, dict) and 'error' in result {
                logger.error(
                    f"Scheduled {label} '{name}' error: {result.get('error')}"
                );
            }
        }

        try {
            loop = asyncio.get_event_loop();
            if loop.is_running() {
                asyncio.ensure_future(_run());
            } else {
                loop.run_until_complete(_run());
            }
        } except RuntimeError {
            asyncio.run(_run());
        }
    } except Exception as e {
        logger.error(f"Error executing {label} '{name}': {e}");
    }
}

"""Add a job to APScheduler with the given trigger configuration."""
impl JacScaleScheduler._schedule_apscheduler_job(
    job_id: str,
    name: str,
    trigger: str,
    interval: (float | None),
    cron: (str | None),
    date: (str | None),
    username: str,
    is_walker: bool = True
) -> None {
    if self._apscheduler is None {
        raise RuntimeError("APScheduler is not initialized");
    }

    def job_func {
        self._execute_task(name, username, is_walker);
    }

    if trigger == 'interval' {
        if interval is None {
            raise ValueError("interval (seconds) required for trigger='interval'");
        }
        trigger_kwargs = {'seconds': float(interval)};
    } elif trigger == 'cron' {
        if not cron {
            raise ValueError("cron expression required for trigger='cron'");
        }
        fields = cron.strip().split();
        if len(fields) != 5 {
            raise ValueError(
                f"Cron must have 5 fields (min hour day month weekday), got: {cron}"
            );
        }
        (f_min, f_hour, f_day, f_month, f_weekday) = fields;
        trigger_kwargs = {
            'minute': f_min,
            'hour': f_hour,
            'day': f_day,
            'month': f_month,
            'day_of_week': f_weekday
        };
    } elif trigger == 'date' {
        if not date {
            raise ValueError("date (ISO datetime string) required for trigger='date'");
        }
        trigger_kwargs = {'run_date': date};
    } else {
        raise ValueError(
            f"Unknown trigger '{trigger}'. Valid values: interval, cron, date"
        );
    }
    self._apscheduler.add_job(
        job_func, trigger, id=job_id, replace_existing=True, **trigger_kwargs
    );
}

"""Persist a job record to MongoDB or in-memory store. Returns the job ID."""
impl JacScaleScheduler._persist_job(job_data: dict) -> str {
    if self._db is not None {
        try {
            result = self._db.insert_one(self._collection, dict(job_data));
            return str(result.inserted_id);
        } except Exception as e {
            logger.warning(f"MongoDB persist failed, using in-memory: {e}");
        }
    }
    job_id = str(job_data.get('_id', str(uuid4())));
    self._in_memory_jobs[job_id] = dict(job_data);
    return job_id;
}

"""Load all active job records from MongoDB or in-memory store."""
impl JacScaleScheduler._load_jobs_from_db -> list[dict] {
    if self._db is not None {
        try {
            jobs: list[dict] = [];
            for doc in self._db.find(self._collection, {'status': 'active'}) {
                doc['_id'] = str(doc['_id']);
                jobs.append(doc);
            }
            return jobs;
        } except Exception as e {
            logger.warning(f"MongoDB load failed, using in-memory: {e}");
        }
    }
    return list(self._in_memory_jobs.values());
}

"""Delete a job record from MongoDB or in-memory store."""
impl JacScaleScheduler._delete_job_from_db(job_id: str) -> bool {
    if self._db is not None {
        try {
            result = self._db.delete_one(self._collection, {'_id': job_id});
            return result.deleted_count > 0;
        } except Exception as e {
            logger.warning(f"MongoDB delete failed, using in-memory: {e}");
        }
    }
    if job_id in self._in_memory_jobs {
        del self._in_memory_jobs[job_id];
        return True;
    }
    return False;
}

"""Update a job record in MongoDB or in-memory store."""
impl JacScaleScheduler._update_job_in_db(job_id: str, updates: dict) -> bool {
    if self._db is not None {
        try {
            result = self._db.update_one(
                self._collection, {'_id': job_id}, {'$set': updates}
            );
            return result.modified_count > 0;
        } except Exception as e {
            logger.warning(f"MongoDB update failed, using in-memory: {e}");
        }
    }
    if job_id in self._in_memory_jobs {
        self._in_memory_jobs[job_id].update(updates);
        return True;
    }
    return False;
}
