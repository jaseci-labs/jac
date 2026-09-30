impl JobQueueStore.insert(
    queue: str,
    target: str,
    args: dict[str, any],
    key: str = "",
    run_at: (datetime | None) = None,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    timeout_s: float = 0.0,
    as_root: str = "",
    enqueued_by: str = ""
) -> str {
    rows = self.store.rows(
        """
        INSERT INTO jac_jobs
            (id, service, queue, target, args, key, status, run_at, max_attempts,
             timeout_s, as_root, enqueued_by)
        VALUES (
            :id, :svc, :q, :t, CAST(:a AS jsonb), :k, :st,
            COALESCE(CAST(:r AS timestamptz), now()), :m, :to, :root, :by
        )
        ON CONFLICT (key) DO NOTHING
        RETURNING id
        """,
        {
            'id': uuid.uuid4().hex,
            'svc': self.service,
            'q': queue,
            't': target,
            'a': json.dumps(args),
            'k': key or None,
            'st': STATUS_QUEUED,
            'r': run_at.isoformat() if run_at is not None else None,
            'm': int(max_attempts),
            'to': float(timeout_s),
            'root': as_root,
            'by': enqueued_by
        }
    );
    if not rows {
        found = self.store.rows("SELECT id FROM jac_jobs WHERE key = :k", {'k': key});
        if not found {
            raise RuntimeError(
                f"job key '{key}' is held by a job this transaction cannot see yet"
            );
        }
        return str(found[0][0]);
    }
    self.store.rows(
        "SELECT pg_notify(:c, :p)", {'c': JOBS_CHANNEL, 'p': f"{self.service}:{queue}"}
    );
    return str(rows[0][0]);
}


impl JobQueueStore.claim(queue: str, owner: str, lease_s: float) -> (JobInfo | None) {
    rows = self.store.rows(
        f"""
        UPDATE jac_jobs
        SET status = :running, attempts = attempts + 1, lease_owner = :w,
            lease_until = now() + make_interval(secs => CAST(:lease AS double precision)),
            updated_at = now()
        WHERE id = (
            SELECT id FROM jac_jobs
            WHERE service = :svc AND queue = :q AND status IN (:queued, :failed)
              AND run_at <= now()
            ORDER BY run_at, created_at
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        )
        RETURNING {JOB_COLUMNS}
        """,
        {
            'running': STATUS_RUNNING,
            'queued': STATUS_QUEUED,
            'failed': STATUS_FAILED,
            'w': owner,
            'lease': float(lease_s),
            'svc': self.service,
            'q': queue
        }
    );
    return _row_to_job(rows[0]) if rows else None;
}


impl JobQueueStore.heartbeat(ids: list[str], owner: str, lease_s: float) -> int {
    if not ids {
        return 0;
    }
    rows = self.store.rows(
        """
        UPDATE jac_jobs
        SET lease_until = now() + make_interval(secs => CAST(:lease AS double precision)),
            updated_at = now()
        WHERE id IN (SELECT jsonb_array_elements_text(CAST(:ids AS jsonb)))
          AND lease_owner = :w AND status = :running
        RETURNING id
        """,
        {
            'lease': float(lease_s),
            'ids': json.dumps(list(ids)),
            'w': owner,
            'running': STATUS_RUNNING
        }
    );
    return len(rows);
}


impl JobQueueStore.complete(id: str, owner: str) -> bool {
    rows = self.store.rows(
        """
        UPDATE jac_jobs
        SET status = :done, lease_owner = '', lease_until = NULL, last_error = '',
            updated_at = now()
        WHERE id = :id AND lease_owner = :w AND status = :running
        RETURNING id
        """,
        {'done': STATUS_DONE, 'id': id, 'w': owner, 'running': STATUS_RUNNING}
    );
    return bool(rows);
}


impl JobQueueStore.fail(
    job: JobInfo, owner: str, error: str, permanent: bool = False
) -> str {
    import from jaclang.server.outbox { backoff_seconds }
    dead = permanent or job.attempts >= job.max_attempts;
    status = STATUS_DEAD if dead else STATUS_FAILED;
    delay = 0.0 if dead else backoff_seconds(job.attempts);
    rows = self.store.rows(
        """
        UPDATE jac_jobs
        SET status = :st, lease_owner = '', lease_until = NULL, last_error = :e,
            run_at = now() + make_interval(secs => CAST(:d AS double precision)),
            updated_at = now()
        WHERE id = :id AND lease_owner = :w AND status = :running
        RETURNING id
        """,
        {
            'st': status,
            'e': error[:ERROR_MAX_CHARS],
            'd': float(delay),
            'id': job.id,
            'w': owner,
            'running': STATUS_RUNNING
        }
    );
    return status if rows else "";
}


impl JobQueueStore.reap -> list[str] {
    rows = self.store.rows(
        """
        UPDATE jac_jobs
        SET status = CASE WHEN attempts >= max_attempts THEN :dead ELSE :queued END,
            lease_owner = '', lease_until = NULL, run_at = now(),
            last_error = 'lease expired: the runner holding this job stopped',
            updated_at = now()
        WHERE status = :running AND lease_until < now()
        RETURNING id
        """,
        {'dead': STATUS_DEAD, 'queued': STATUS_QUEUED, 'running': STATUS_RUNNING}
    );
    return [str(r[0]) for r in rows];
}


impl JobQueueStore.cancel(id: str) -> bool {
    rows = self.store.rows(
        """
        UPDATE jac_jobs SET status = :cancelled, updated_at = now()
        WHERE id = :id AND status IN (:queued, :failed)
        RETURNING id
        """,
        {
            'cancelled': STATUS_CANCELLED,
            'id': id,
            'queued': STATUS_QUEUED,
            'failed': STATUS_FAILED
        }
    );
    return bool(rows);
}


impl JobQueueStore.get(id: str) -> (JobInfo | None) {
    rows = self.store.rows(
        f"SELECT {JOB_COLUMNS} FROM jac_jobs WHERE id = :id", {'id': id}
    );
    return _row_to_job(rows[0]) if rows else None;
}


impl JobQueueStore.counts -> dict[tuple[str, str], int] {
    rows = self.store.rows(
        """
        SELECT queue, status, count(*) FROM jac_jobs
        WHERE service = :svc GROUP BY queue, status
        """,
        {'svc': self.service}
    );
    return {(str(r[0]), str(r[1])): int(r[2]) for r in rows};
}


impl JobQueueStore.prune(retention_s: float) -> int {
    rows = self.store.rows(
        """
        DELETE FROM jac_jobs
        WHERE status IN (:done, :cancelled)
          AND updated_at < now() - make_interval(secs => CAST(:r AS double precision))
        RETURNING id
        """,
        {'done': STATUS_DONE, 'cancelled': STATUS_CANCELLED, 'r': float(retention_s)}
    );
    return len(rows);
}


impl use_store(store: (JobQueueStore | None)) -> None {
    _state.explicit = store;
}


impl bind_service(service: str) -> None {
    _state.service = service;
}


impl bind_system_root(root_id: str) -> None {
    _state.system_roots = _state.system_roots | {root_hex(root_id)};
}


impl target_name(target: any) -> str {
    import from jaclang.data.type_identity { TypeResolutionError, type_module }
    if isinstance(target, str) {
        name = target.strip();
    } else {
        attr = str(getattr(target, '__name__', ''));
        try {
            module = type_module(target) if attr else '';
        } except TypeResolutionError as e {
            raise ValueError(f"{attr} cannot be queued: {e}") from e;
        }
        name = f"{module}:{attr}" if module else attr;
    }
    if not name {
        raise ValueError(
            f"enqueue needs a walker, a function, or its name; got {target!r}"
        );
    }
    return name;
}


impl enqueue(
    target: any,
    args: (dict[str, any] | None) = None,
    key: str = "",
    queue: str = DEFAULT_QUEUE,
    run_at: (datetime | str | None) = None,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    timeout_s: float = 0.0,
    as_root: any = None
) -> str {
    name = target_name(target);
    if int(max_attempts) < 1 {
        raise ValueError(f"max_attempts must be at least 1, got {max_attempts}");
    }
    if float(timeout_s) < 0 {
        raise ValueError(f"timeout_s must be 0 (no limit) or more, got {timeout_s}");
    }
    payload: dict[str, any] = dict(args or {});
    try {
        json.dumps(payload);
    } except (TypeError, ValueError) as e {
        raise ValueError(f"job args must be JSON-serializable: {e}") from e;
    }
    configured = _configured_queues();
    if queue not in configured {
        raise ValueError(
            f"queue '{queue}' is not declared in [scale.jobs] queues "
            f"(declared: {', '.join(sorted(configured))})"
        );
    }
    (run_root, caller) = _resolve_identity(name, as_root);
    _warn_if_disabled();
    return _store_for_request(writable=True).insert(
        queue,
        name,
        payload,
        key=key,
        run_at=_parse_run_at(run_at),
        max_attempts=int(max_attempts),
        timeout_s=float(timeout_s),
        as_root=run_root,
        enqueued_by=caller
    );
}


impl cancel(job_id: str) -> bool {
    return _store_for_request(writable=True).cancel(job_id);
}


impl job_info(job_id: str) -> (JobInfo | None) {
    return _store_for_request(writable=False).get(job_id);
}


impl _iso(value: any) -> str {
    if value is None {
        return "";
    }
    if isinstance(value, datetime) {
        return value.isoformat();
    }
    return str(value);
}


impl _row_to_job(row: tuple[any, ...]) -> JobInfo {
    raw_args = row[4];
    args: dict[str, any] = (
        dict(raw_args)
            if isinstance(raw_args, dict)
            else json.loads(str(raw_args or '{}'))
    );
    return JobInfo(
        id=str(row[0]),
        service=str(row[1] or ""),
        queue=str(row[2]),
        target=str(row[3]),
        args=args,
        key=str(row[5] or ""),
        status=str(row[6]),
        run_at=_iso(row[7]),
        attempts=int(row[8] or 0),
        max_attempts=int(row[9] or DEFAULT_MAX_ATTEMPTS),
        timeout_s=float(row[10] or 0.0),
        lease_owner=str(row[11] or ""),
        lease_until=_iso(row[12]),
        last_error=str(row[13] or ""),
        created_at=_iso(row[14]),
        updated_at=_iso(row[15]),
        as_root=str(row[16] or ""),
        enqueued_by=str(row[17] or "")
    );
}


impl _parse_run_at(run_at: (datetime | str | None)) -> (datetime | None) {
    if run_at is None or run_at == "" {
        return None;
    }
    when: datetime = run_at
        if isinstance(run_at, datetime)
        else datetime.fromisoformat(str(run_at));
    if when.tzinfo is None {
        when = when.replace(tzinfo=timezone.utc);
    }
    return when;
}


impl _configured_queues -> list[str] {
    import from jaclang.scale.config.config_loader { get_scale_config }
    return list(get_scale_config().get_jobs_config()['queues'].keys());
}


impl _store_for_request(writable: bool = True) -> JobQueueStore {
    import from jaclang.server.outbox { primary_pg_store, writable_txn }
    import from jaclang.server.shared_store { shared_store, shared_store_failure }
    explicit = _state.explicit;
    if explicit is not None {
        return explicit;
    }
    primary = primary_pg_store();
    if primary is not None {
        if writable {
            writable_txn(primary);
        }
        return JobQueueStore(store=primary, service=_state.service);
    }
    shared = shared_store();
    if shared is None {
        raise RuntimeError(
            f"the job queue needs the scale database: {shared_store_failure()}"
        );
    }
    return JobQueueStore(store=shared, service=_state.service);
}


impl _warn_if_disabled -> None {
    import from jaclang.scale.config.config_loader { get_scale_config }
    if _state.warned_disabled or get_scale_config().get_jobs_config()['enabled'] {
        return;
    }
    _state.warned_disabled = True;
    logger.warning(
        "enqueue() wrote a job but [scale.jobs] is not enabled, so no runner in "
        "this process will run it. Set [scale.jobs] enabled = true."
    );
}


impl root_hex(value: any) -> str {
    import from uuid { UUID }
    anchor: any = value?.__jac__;
    raw: any = anchor.id if anchor is not None else value;
    try {
        return UUID(str(raw)).hex;
    } except (TypeError, ValueError) {
        raise ValueError(f"as_root must be a root node or a root id, got {value!r}");
    }
}


impl _is_system_root(candidate: str) -> bool {
    import from jaclang.runtime.constants { Constants as Con }
    return candidate == root_hex(Con.SUPER_ROOT_UUID)
        or candidate in _state.system_roots;
}


impl _system_targets -> list[str] {
    import from jaclang.scale.config.config_loader { get_scale_config }
    return list(get_scale_config().get_jobs_config()['system_targets']);
}


impl _resolve_identity(target: str, as_root: any) -> tuple[str, str] {
    import from jaclang { JacRuntime }
    ctx = JacRuntime.peek_context();
    caller = root_hex(ctx.user_root.id) if ctx is not None else "";
    wanted = root_hex(as_root) if as_root is not None and as_root != "" else "";
    if target.rsplit(':', 1)[-1] in _system_targets() {
        return ("", caller);
    }
    if not caller or _is_system_root(caller) {
        return (wanted, caller);
    }
    if wanted and wanted != caller {
        raise PermissionError(
            f"a request running as root {caller} cannot queue a job for root "
            f"{wanted}; only system code may target another root"
        );
    }
    return (caller, caller);
}
