impl pinned_major -> int {
    `override = os.environ.get('JAC_PG_VERSION', '');
    if `override {
        try {
            return int(`override.split('.')[0]);
        } except ValueError {
            logger.warning(
                f"JAC_PG_VERSION={`override!r} is not a version; using {PG_MAJOR}"
            );
        }
    }
    return PG_MAJOR;
}


impl dist_cache_dir -> str {
    return os.path.join(
        os.path.expanduser(os.environ.get('JAC_CACHE_HOME', '~/.cache/jac')),
        'pg',
        'dist'
    );
}


def _effective_uid -> int {
    `getter = os?.geteuid;
    return int(`getter()) if `getter is not None else -1;
}


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


def _platform_slug -> (str | None) {
    sys_name = platform.system();
    mach = platform.machine().lower();
    arch = {
        'x86_64': 'amd64',
        'amd64': 'amd64',
        'aarch64': 'arm64v8',
        'arm64': 'arm64v8'
    }.get(
        mach
    );
    if arch is None {
        return None;
    }
    if sys_name == 'Linux' {
        return f"linux-{arch}";
    }
    if sys_name == 'Darwin' {
        return f"darwin-{arch}";
    }
    return None;
}


def _pg_major_of(bin_dir: str) -> (int | None) {
    postgres = os.path.join(bin_dir, 'postgres');
    if not os.path.isfile(postgres) {
        return None;
    }
    try {
        out = subprocess.run(
            [postgres, '--version'], capture_output=True, text=True, timeout=10
        ).stdout;

        token = out.strip().split()[-1] if out.strip() else '';
        for part in out.strip().split() {
            if part[:1].isdigit() {
                token = part;
                break;
            }
        }
        digits = '';
        for ch in token {
            if ch.isdigit() {
                digits += ch;
            } else {
                break;
            }
        }
        return int(digits) if digits else None;
    } except Exception as e {
        logger.debug(f"pg version probe failed for {postgres}: {e}");
        return None;
    }
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


impl PgRuntime._as_user -> dict {
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


impl PgRuntime.fetch_dist -> str {
    found = self._resolve_from_env() or self._resolve_from_zonky();
    assert found is not None , (
        'could not fetch the embedded postgres distribution: set JAC_PG_DIST '
        'to an existing distribution, or allow network access to Maven '
        'Central so it can be downloaded'
    );
    self._bin_dir = found;
    return found;
}


impl PgRuntime._resolve_binaries -> str {
    if self._bin_dir is not None {
        return self._bin_dir;
    }
    found = (
        self._resolve_from_env()
        or self._resolve_from_path()
        or self._resolve_from_zonky()
    );
    assert found is not None , (
        "no usable postgres binaries: set JAC_PG_DIST, install postgres on "
        "PATH, or allow network access to Maven Central for the embedded "
        "distribution"
    );
    self._bin_dir = found;
    return found;
}


impl PgRuntime._resolve_from_env -> (str | None) {
    dist = os.environ.get('JAC_PG_DIST', '');
    if not dist {
        return None;
    }
    droot = os.path.expanduser(dist);
    for cand in [os.path.join(droot, 'bin'), droot] {
        if os.path.isfile(os.path.join(cand, 'postgres')) {
            return cand;
        }
    }
    logger.warning(f"JAC_PG_DIST={dist!r} has no bin/postgres; ignoring");
    return None;
}


impl PgRuntime._resolve_from_path -> (str | None) {
    want = pinned_major();
    exe = shutil.which('postgres');
    candidates: list[str] = [];
    if exe {
        candidates.append(os.path.dirname(os.path.realpath(exe)));
    }

    for base in ['/usr/lib/postgresql', '/usr/pgsql', '/opt/homebrew/opt'] {
        if os.path.isdir(base) {
            for `entry in sorted(os.listdir(base), reverse=True) {
                cand = os.path.join(base, `entry, 'bin');
                if os.path.isfile(os.path.join(cand, 'postgres')) {
                    candidates.append(cand);
                }
            }
        }
    }
    best: (str | None) = None;
    best_major = 0;
    for cand in candidates {
        major = _pg_major_of(cand);
        if major == want {
            return cand;
        }
        if major is not None and major >= 14 and major > best_major {
            best_major = major;
            best = cand;
        }
    }
    if best is not None {
        logger.warning(
            f"postgres {want} not found on PATH; using the installed "
            f"postgres {best_major} at {best} (set JAC_PG_DIST or "
            f"JAC_PG_VERSION to override)"
        );
    }
    return best;
}


impl PgRuntime._resolve_from_zonky -> (str | None) {
    want = pinned_major();
    got = self._download_zonky(want);
    if got is not None {
        return got;
    }
    versions = self._zonky_versions();
    majors = sorted(
        {
            int(v.split('.')[0])
            for v in versions
            if v[:1].isdigit()
        }
    );
    if not majors {
        return None;
    }
    newest = majors[-1];
    if newest == want {
        return None;
    }
    logger.warning(
        f"postgres {want} not yet published to the embedded channel; "
        f"using {newest} (set JAC_PG_DIST to override)"
    );
    return self._download_zonky(newest);
}


impl PgRuntime._zonky_versions -> list[str] {
    slug = _platform_slug();
    if slug is None {
        return [];
    }
    url = f"{ZONKY_BASE}{slug}/maven-metadata.xml";
    try {
        resp = urllib.request.urlopen(url, timeout=30);
        try {
            body = resp.read().decode('utf-8', errors='replace');
        } finally {
            resp.close();
        }
    } except Exception as e {
        logger.debug(f"zonky metadata fetch failed: {e}");
        return [];
    }
    out: list[str] = [];
    for chunk in body.split('<version>')[1:] {
        out.append(chunk.split('</version>')[0].strip());
    }
    return out;
}


impl PgRuntime._download_zonky(major: int) -> (str | None) {
    slug = _platform_slug();
    if slug is None {
        return None;
    }
    versions = [
        v
        for v in self._zonky_versions()
        if v.split('.')[0] == str(major)
    ];
    if not versions {
        return None;
    }
    version = versions[-1];
    dist_dir = os.path.join(dist_cache_dir(), f"{slug}-{version}");
    bin_dir = os.path.join(dist_dir, 'bin');
    if os.path.isfile(os.path.join(bin_dir, 'postgres')) {
        return bin_dir;
    }

    import from jaclang.jac0core.cache_paths { FileLock }
    lock_path = Path(dist_cache_dir()) / f".{slug}-{version}.lock";
    with FileLock(lock_path) {
        if os.path.isfile(os.path.join(bin_dir, 'postgres')) {
            return bin_dir;
        }
        return self._fetch_dist(slug, version, dist_dir, bin_dir);
    }
}


impl PgRuntime._fetch_dist(
    slug: str, version: str, dist_dir: str, bin_dir: str
) -> (str | None) {
    name = f"embedded-postgres-binaries-{slug}";
    jar_url = f"{ZONKY_BASE}{slug}/{version}/{name}-{version}.jar";
    logger.info(f"fetching embedded postgres {version} ({slug})...");
    tmp = dist_dir + '.part';
    shutil.rmtree(tmp, ignore_errors=True);
    os.makedirs(tmp, exist_ok=True);
    import from jaclang.toolchains.store { Artifact, fetch, extract }
    try {
        with urllib.request.urlopen(jar_url + '.sha1', timeout=30) as response {
            want_sha = response.read().decode().strip().split()[0];
        }
        jar_path = fetch(
            Artifact("postgres", version, slug, jar_url, want_sha, "sha1")
        );
        with zipfile.ZipFile(jar_path) as zf {
            txz: (str | None) = None;
            for n in zf.namelist() {
                if n.endswith('.txz') {
                    txz = n;
                    break;
                }
            }
            assert txz is not None , f"no .txz payload in {jar_url}";
            txz_name: str = txz;
            extract(jar_path, Path(tmp));
        }
        extract(Path(tmp) / txz_name, Path(tmp));
        os.remove(os.path.join(tmp, txz_name));
        os.replace(tmp, dist_dir);
    } except Exception as e {
        shutil.rmtree(tmp, ignore_errors=True);
        logger.warning(f"embedded postgres download failed: {e}");
        return None;
    }
    return bin_dir if os.path.isfile(os.path.join(bin_dir, 'postgres')) else None;
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
    import from jaclang.data.pgload { connect }
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
    import from jaclang.data.dbcatalog {
        connect_admin,
        record_database,
        start_heartbeat
    }
    conn: any = connect_admin(self.conninfo());
    try {
        rows = conn.run(
            "SELECT 1 FROM pg_database WHERE datname = :n", n=self.database
        );
        created = not rows;
        if created {
            conn.run(f'CREATE DATABASE "{self.database}"');
        }
        record_database(conn, self.database, self.kind, self.owner_path);
        if self.kind == DbKind.SCRATCH {
            start_heartbeat(self.conninfo(), self.database);
        }
        if created and self.kind == DbKind.SCRATCH {
            self._reap_scratch(conn);
        }
    } finally {
        conn.close();
    }
}


impl PgRuntime._reap_scratch(conn: any) -> int {
    import from jaclang.data.dbcatalog {
        condemn_stale_scratch,
        dead_scratch_databases,
        drop_if_still_dead,
        list_databases
    }
    reaped = 0;
    try {
        records = list_databases(conn);
        if (marked := condemn_stale_scratch(conn, records)) {
            logger.info(
                f"{len(marked)} scratch database(s) have stopped heartbeating; "
                'they will be reclaimed by a later start if they are still '
                'silent and unused by then'
            );
        }
        for name in dead_scratch_databases(records) {
            if name != self.database and drop_if_still_dead(conn, name) {
                reaped += 1;
            }
        }
    } except Exception as e {
        logger.debug(f"scratch reap failed: {e}");
        return reaped;
    }
    if reaped {
        logger.info(
            f"reclaimed {reaped} scratch database(s) left by processes that "
            'are no longer running'
        );
    }
    return reaped;
}


impl PgRuntime.drop_database(database: str, force: bool = False) -> bool {
    import from jaclang.data.dbcatalog { connect_admin, drop_database as catalog_drop }
    conn: any = connect_admin(self.conninfo());
    try {
        return catalog_drop(conn, database, force=force);
    } finally {
        conn.close();
    }
}


impl PgRuntime.databases -> list {
    import from jaclang.data.dbcatalog { connect_admin, list_databases }
    conn: any = connect_admin(self.conninfo());
    try {
        return list_databases(conn);
    } finally {
        conn.close();
    }
}


impl PgRuntime._sweep_on_start -> None {
    import from jaclang.data.dbcatalog {
        connect_admin,
        drop_database,
        expired_databases
    }
    try {
        conn: any = connect_admin(self.conninfo());
    } except Exception as e {
        logger.debug(f"cluster sweep skipped, no admin connection: {e}");
        return;
    }
    try {
        self._reap_scratch(conn);
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
