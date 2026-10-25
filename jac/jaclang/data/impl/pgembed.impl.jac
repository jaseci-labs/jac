def _effective_uid -> int;


impl pg_run_candidates -> list[PgRunAs] {
    try {
        import pwd;
    } except ImportError {
        return [];
    }
    names: list[str] = [];
    for raw in [os.environ.get('JAC_PG_USER', ''), os.environ.get('SUDO_USER', '')]
        + PG_RUN_USERS {
        who = raw.strip();
        if who and who not in names {
            names.append(who);
        }
    }
    out: list[PgRunAs] = [];
    for who in names {
        try {
            ent = pwd.getpwnam(who);
        } except KeyError {
            continue;
        }
        if int(ent.pw_uid) == 0 {
            continue;
        }
        out.append(PgRunAs(name=who, uid=int(ent.pw_uid), gid=int(ent.pw_gid)));
    }
    return out;
}


impl pg_priv_plan(euid: int, candidates: list[PgRunAs]) -> PgPrivPlan {
    if euid != 0 {
        return PgPrivPlan(mode=PgPrivMode.AS_IS);
    }
    for cand in candidates {
        if cand.uid != 0 and cand.name {
            return PgPrivPlan(mode=PgPrivMode.DROP, run_as=cand);
        }
    }
    return PgPrivPlan(
        mode=PgPrivMode.BLOCKED,
        reason=(
            'the embedded postgres server cannot run as root (initdb refuses '
            'uid 0) and no unprivileged account was found to drop to. Either '
            'run jac as a normal user, create an account and point '
            'JAC_PG_USER at it, or set JAC_DB_URL to an external Postgres.'
        )
    );
}


impl PgRuntime.postinit -> None {
    self._bin_dir = None;
    self._proc = None;
    self._lock = threading.RLock();
    self._priv = None;
    if self.port == 0 {
        self.port = SOCK_PORT;
    }
}


impl PgRuntime._priv_plan -> PgPrivPlan {
    plan = self._priv;
    if plan is None {
        plan = pg_priv_plan(_effective_uid(), pg_run_candidates());
        self._priv = plan;
    }
    return plan;
}


impl PgRuntime._run_as -> (PgRunAs | None) {
    plan = self._priv_plan();
    assert plan.mode is not PgPrivMode.BLOCKED , plan.reason;
    return plan.run_as;
}


impl PgRuntime._as_user -> dict[str, any] {
    target = self._run_as();
    if target is None {
        return {};
    }
    return {'user': target.uid, 'group': target.gid};
}


impl PgRuntime._grant_dir(path: str) -> None {
    target = self._run_as();
    if target is None {
        return;
    }
    try {
        if os.stat(path).st_uid != target.uid {
            os.chown(path, target.uid, target.gid);
            for (parent, dirnames, filenames) in os.walk(path) {
                for `entry in dirnames + filenames {
                    os.chown(os.path.join(parent, `entry), target.uid, target.gid);
                }
            }
        }
    } except OSError as e {
        logger.warning(f"could not hand {path} to {target.name}: {e}");
        return;
    }
    me = _effective_uid();
    cur = os.path.dirname(os.path.abspath(path));
    while cur != os.path.dirname(cur) {
        try {
            info = os.stat(cur);
        } except OSError {
            return;
        }
        if info.st_uid != me {
            return;
        }
        if not (info.st_mode & 0o011) {
            try {
                os.chmod(cur, info.st_mode | 0o011);
            } except OSError {
                return;
            }
            logger.info(
                f"granted search access on {cur} so postgres can run as "
                f"{target.name}"
            );
        }
        cur = os.path.dirname(cur);
    }
}


impl PgRuntime.conninfo -> ConnInfo {
    if self.tcp {
        return ConnInfo(
            host='127.0.0.1',
            port=self.port,
            user=self.superuser,
            database=self.database
        );
    }
    return ConnInfo(
        port=self.port,
        user=self.superuser,
        database=self.database,
        unix_socket_dir=self._sock_dir()
    );
}


impl PgRuntime._sock_dir -> str {
    import tempfile;
    digest = hashlib.sha1(os.path.abspath(self.data_dir).encode('utf-8')).hexdigest()[:10];
    return os.path.join(tempfile.gettempdir(), f"jacpg-{digest}");
}


impl PgRuntime.ensure -> ConnInfo {
    with self._lock {
        if self.is_running() {
            try {
                self._wait_ready(timeout=3.0);
                self._ensure_database();
                return self.conninfo();
            } except Exception {
                logger.info(
                    'embedded postgres unreachable despite a live pidfile '
                    '(mid-shutdown?); taking the locked start path'
                );
            }
        }
        import fcntl;
        os.makedirs(os.path.dirname(self.data_dir) or '.', exist_ok=True);
        lock_f = open(self.data_dir + '.lock', 'w');
        fcntl.flock(lock_f.fileno(), fcntl.LOCK_EX);
        started = False;
        try {
            if self.is_running() {
                try {
                    self._wait_ready(timeout=3.0);
                } except Exception {
                    death_deadline = time.monotonic() + 40.0;
                    while self.is_running() and time.monotonic() < death_deadline {
                        time.sleep(0.25);
                    }
                }
            }
            if not self.is_running() {
                bin_dir = self._resolve_binaries();
                self._initdb_if_needed(bin_dir);
                self._start(bin_dir);
                started = True;
            }
        } finally {
            fcntl.flock(lock_f.fileno(), fcntl.LOCK_UN);
            lock_f.close();
        }
        self._wait_ready();
        if started {
            self._sweep_on_start();
        }
        self._ensure_database();
        return self.conninfo();
    }
}


impl PgRuntime.is_running -> bool {
    pidfile = os.path.join(self.data_dir, 'postmaster.pid');
    if not os.path.isfile(pidfile) {
        return False;
    }
    try {
        with open(pidfile) as f {
            pid = int(f.readline().strip());
        }
        os.kill(pid, 0);
        return True;
    } except (ValueError, OSError) {
        return False;
    }
}


impl PgRuntime.stop -> None {
    with self._lock {
        if not self.is_running() {
            return;
        }
        bin_dir = self._bin_dir or self._resolve_binaries();
        subprocess.run(
            [
                os.path.join(bin_dir, 'pg_ctl'),
                'stop',
                '-D',
                self.data_dir,
                '-m',
                'fast',
                '-t',
                '30'
            ],
            capture_output=True,
            text=True,
            timeout=60,
            **self._as_user()
        );
    }
}


impl PgRuntime._resolve_binaries -> str {
    if self._bin_dir is None {
        import from jaclang.data.pg_dist { postgres_bin_dir }
        self._bin_dir = postgres_bin_dir();
    }
    return self._bin_dir;
}


impl stop_cluster(data_dir: str) -> None {
    """Stop the embedded cluster at `data_dir` if it is running.

    A desktop app owns its per-app cluster and stops it when the app process
    exits; a missing pidfile or a stopped cluster is a no-op. Failures are
    logged, never raised: this runs from an exit path.
    """;
    rt = PgRuntime(data_dir=data_dir);
    try {
        rt.stop();
    } except Exception as e {
        logger.warning(f"could not stop the embedded postgres at {data_dir}: {e}");
    }
}


impl PgRuntime._initdb_if_needed(bin_dir: str) -> None {
    if os.path.isfile(os.path.join(self.data_dir, 'PG_VERSION')) {
        self._grant_dir(self.data_dir);
        return;
    }
    os.makedirs(self.data_dir, exist_ok=True);
    os.chmod(self.data_dir, 0o700);
    self._grant_dir(self.data_dir);
    res = subprocess.run(
        [
            os.path.join(bin_dir, 'initdb'),
            '-D',
            self.data_dir,
            '-U',
            self.superuser,
            '-A',
            'trust',
            '-E',
            'UTF8',
            '--no-locale'
        ],
        capture_output=True,
        text=True,
        timeout=120,
        **self._as_user()
    );
    assert res.returncode == 0 , f"initdb failed: {res.stderr.strip()}";
}


impl predicate_lock_shortfall(settings: dict[str, int]) -> (str | None) {
    per_txn = settings.get('max_pred_locks_per_transaction', 0);
    slots = settings.get('max_connections', 0)
        + settings.get('max_prepared_transactions', 0);
    pool = per_txn * slots;
    if per_txn >= PG_MAX_PRED_LOCKS_PER_TXN
        or pool >= PG_MAX_PRED_LOCKS_PER_TXN * PG_MAX_CONNECTIONS {
        return None;
    }
    return (
        f"max_pred_locks_per_transaction is {per_txn}, a predicate-lock pool of "
        f"{pool:,} entries for {slots} connections. jac runs request transactions "
        "SERIALIZABLE, and under concurrent load (most of all with more than one "
        "serve worker) that pool runs out and requests fail with '53200 out of "
        "shared memory'. The Postgres jac starts itself uses "
        f"max_pred_locks_per_transaction = {PG_MAX_PRED_LOCKS_PER_TXN}: run "
        f"ALTER SYSTEM SET max_pred_locks_per_transaction = {PG_MAX_PRED_LOCKS_PER_TXN} "
        "and restart Postgres."
    );
}


impl pg_tuning_settings -> dict[str, str] {
    return {
        'max_connections': str(PG_MAX_CONNECTIONS),
        'max_pred_locks_per_transaction': str(PG_MAX_PRED_LOCKS_PER_TXN),
        'idle_in_transaction_session_timeout': str(PG_IDLE_IN_TXN_TIMEOUT_MS)
    };
}


impl PgRuntime._server_opts -> str {
    listen = "-c listen_addresses=127.0.0.1" if self.tcp else "-c listen_addresses=''";
    tuning = ' '.join(f"-c {k}={v}" for (k, v) in pg_tuning_settings().items());
    return (
        f"-p {self.port} {listen} "
        f"-c unix_socket_directories='{self._sock_dir()}' "
        f"-c dynamic_shared_memory_type=posix {tuning}"
    );
}


impl PgRuntime._start(bin_dir: str) -> None {
    os.makedirs(self._sock_dir(), exist_ok=True);
    self._grant_dir(self._sock_dir());
    opts = self._server_opts();
    log_path = os.path.join(self.data_dir, 'server.log');
    res = subprocess.run(
        [
            os.path.join(bin_dir, 'pg_ctl'),
            'start',
            '-D',
            self.data_dir,
            '-o',
            opts,
            '-l',
            log_path,
            '-w',
            '-t',
            '60'
        ],
        capture_output=True,
        text=True,
        timeout=90,
        **self._as_user()
    );
    if res.returncode != 0 {
        tail = '';
        try {
            with open(log_path) as f {
                tail = ''.join(f.readlines()[-15:]);
            }
        } except OSError {}
        assert False , f"postgres failed to start: {res.stderr.strip()}\n{tail}";
    }
}


impl PgRuntime._wait_ready(timeout: float = 60.0) -> None {
    info = self.conninfo();
    deadline = time.monotonic() + timeout;
    last: (Exception | None) = None;
    while time.monotonic() < deadline {
        try {
            conn: any = connect(
                info.user,
                host=info.host,
                port=info.port,
                unix_socket_dir=info.unix_socket_dir,
                database='postgres'
            );
            conn.close();
            return;
        } except Exception as e {
            last = e;
            time.sleep(0.25);
        }
    }
    assert False , f"postgres not ready after {timeout}s: {last}";
}


impl PgRuntime._ensure_database -> None {
    conn: any = connect_admin(self.conninfo());
    try {
        rows = conn.run(
            "SELECT 1 FROM pg_database WHERE datname = :n", n=self.database
        );
        created = not rows;
        if created {
            conn.run(f'CREATE DATABASE "{self.database}"');
        }
        record_database(
            conn, self.database, self.kind, self.owner_path, pid=self.owner_pid
        );
        if self.kind == DbKind.SCRATCH and not self.owner_pid {
            start_heartbeat(self.conninfo(), self.database);
        }
        if created and self.kind == DbKind.SCRATCH {
            self._reap_scratch(conn);
        }
        if created and self.sole_owner_database {
            self._warn_superseded(conn);
        }
    } finally {
        conn.close();
    }
}


impl PgRuntime._warn_superseded(conn: any) -> None {
    try {
        previous = [
            rec.database
            for rec in list_databases(conn, with_size=False)
            if rec.database != self.database
                and rec.kind == DbKind.PROJECT.value
                and rec.owner_path == self.owner_path
        ];
    } except Exception as e {
        logger.debug(f"superseded database check skipped: {e}");
        return;
    }
    if previous {
        logger.warning(
            f"Created database {self.database} for {self.owner_path}, which "
            f"already has data in {', '.join(previous)}. A changed project name "
            "or [persistence] namespace selects a new database and schema "
            "identity; restore the previous namespace to keep that data, or "
            "migrate it explicitly."
        );
    }
}


impl PgRuntime._reap_scratch(conn: any) -> int {
    try {
        records = [
            rec
            for rec in list_databases(conn, prefix=SCRATCH_PREFIX, with_size=False)
            if rec.is_scratch()
        ];
    } except Exception as e {
        logger.debug(f"scratch reap skipped, registry unreadable: {e}");
        return 0;
    }
    return self._reap(conn, records);
}


impl PgRuntime._reap(conn: any, records: list[DbRecord]) -> int {
    by_name = {rec.database: rec for rec in records};
    grace_h = orphan_grace_seconds() // 3600;
    reaped_scratch = 0;
    reaped_orphans = 0;
    try {
        marked = condemn_abandoned(conn, records);
        marked_scratch = len(
            [
                n
                for n in marked
                if by_name[n].is_scratch()
            ]
        );
        if marked_scratch {
            logger.info(
                f"{marked_scratch} scratch database(s) have stopped heartbeating; "
                'they will be reclaimed by a later start if they are still '
                'silent and unused by then'
            );
        }
        if len(marked) > marked_scratch {
            logger.info(
                f"{len(marked) - marked_scratch} database(s) whose project "
                'directory is gone were marked; a later start reclaims them once '
                f"they have been gone for {grace_h}h (JAC_DB_ORPHAN_GRACE_HOURS)"
            );
        }
        if (pardoned := pardon_recovered(conn, records)) {
            logger.info(
                f"{len(pardoned)} database(s) whose project directory is back "
                'were unmarked'
            );
        }
        pending = [
            name
            for name in reclaimable_databases(records)
            if name != self.database
        ];
        deadline = time.monotonic() + SWEEP_DROP_BUDGET_SECONDS;
        for i in range(len(pending)) {
            if time.monotonic() > deadline {
                logger.info(
                    f"{len(pending) - i} reclaimable database(s) left for a later "
                    f"start; this sweep used its {SWEEP_DROP_BUDGET_SECONDS}s"
                );
                break;
            }
            if not drop_if_still_dead(conn, pending[i]) {
                continue;
            }
            if by_name[pending[i]].is_scratch() {
                reaped_scratch += 1;
            } else {
                reaped_orphans += 1;
            }
        }
    } except Exception as e {
        logger.debug(f"database reap failed: {e}");
    }
    if reaped_scratch {
        logger.info(
            f"reclaimed {reaped_scratch} scratch database(s) left by processes "
            'that are no longer running'
        );
    }
    if reaped_orphans {
        logger.info(
            f"reclaimed {reaped_orphans} database(s) whose project directory has "
            f"been gone for more than {grace_h}h"
        );
    }
    return reaped_scratch + reaped_orphans;
}


impl PgRuntime.drop_database(database: str, force: bool = False) -> bool {
    conn: any = connect_admin(self.conninfo());
    try {
        return catalog_drop(conn, database, force=force);
    } finally {
        conn.close();
    }
}


impl PgRuntime.databases(with_size: bool = True) -> list[DbRecord] {
    conn: any = connect_admin(self.conninfo());
    try {
        return list_databases(conn, with_size=with_size);
    } finally {
        conn.close();
    }
}


impl PgRuntime._sweep_on_start -> None {
    try {
        conn: any = connect_admin(self.conninfo());
    } except Exception as e {
        logger.debug(f"cluster sweep skipped, no admin connection: {e}");
        return;
    }
    try {
        self._reap(conn, list_databases(conn, with_size=False));
        if self.retention_days > 0 {
            swept = 0;
            for name in expired_databases(conn, self.retention_days, self.database) {
                if drop_database(conn, name) {
                    swept += 1;
                }
            }
            if swept {
                logger.info(
                    f"retention swept {swept} database(s) unused for more than "
                    f"{self.retention_days} day(s)"
                );
            }
        }
    } except Exception as e {
        logger.debug(f"cluster sweep failed: {e}");
    } finally {
        conn.close();
    }
}


impl PgRuntime.serve -> int {
    bin_dir = self._resolve_binaries();
    self._initdb_if_needed(bin_dir);
    os.makedirs(self._sock_dir(), exist_ok=True);
    self._grant_dir(self._sock_dir());
    argv = [
        os.path.join(bin_dir, 'postgres'),
        '-D',
        self.data_dir,
        '-p',
        str(self.port),
        '-c',
        'listen_addresses=*',
        '-c',
        f"unix_socket_directories={self._sock_dir()}",
        '-c',
        'dynamic_shared_memory_type=posix'
    ];
    proc = subprocess.Popen(argv, **self._as_user());
    self._proc = proc;

    def _forward(signum: int, frame: any) {
        proc.send_signal(int(signal.SIGINT));
    }
    signal.signal(int(signal.SIGTERM), _forward);
    signal.signal(int(signal.SIGINT), _forward);
    return proc.`wait();
}

impl _effective_uid -> int {
    `getter = os?.geteuid;
    return int(`getter()) if `getter is not None else -1;
}
