import re;
import ssl;
import from pathlib { Path }
import from urllib.parse { urlsplit }
import from jaclang.runtime.object_interop { fields, is_record }


impl TlsSettings.build_context -> any {
    if not self.enabled() {
        return None;
    }
    if not self.keyfile {
        raise ServeConfigError(
            "[serve.tls] certfile is set without keyfile; TLS needs both "
            "(or JAC_SERVE_TLS_KEYFILE)."
        );
    }
    for (label, path) in (('certfile', self.certfile), ('keyfile', self.keyfile)) {
        if not Path(path).is_file() {
            raise ServeConfigError(f"[serve.tls] {label} does not exist: {path}");
        }
    }
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);
    floor = {'1.2': ssl.TLSVersion.TLSv1_2, '1.3': ssl.TLSVersion.TLSv1_3}.get(
        self.min_version
    );
    if floor is None {
        raise ServeConfigError(
            f"[serve.tls] min_version must be '1.2' or '1.3', got {self.min_version!r}"
        );
    }
    ctx.minimum_version = floor;
    ctx.load_cert_chain(self.certfile, self.keyfile);
    if self.ca_certs {
        ctx.load_verify_locations(self.ca_certs);
        ctx.verify_mode = ssl.CERT_OPTIONAL;
    }
    return ctx;
}


impl AuthSettings.resolve_secret(base_path: str) -> str {
    import from jaclang.server.serving.authcrypt {
        PLACEHOLDER_JWT_SECRET,
        project_signing_secret
    }
    secret = self.secret.strip();
    if secret and secret != PLACEHOLDER_JWT_SECRET {
        return secret;
    }
    if in_cluster() {
        raise ServeConfigError(
            "no signing secret is configured and this process runs in a cluster, "
            "where a per-replica secret would make replicas reject one another's "
            "tokens. Set [serve.auth] secret or JAC_SERVE_AUTH_SECRET."
        );
    }
    return project_signing_secret(secret_home(base_path));
}


def table_value(current: any, raw: any, label: str) -> any {
    if isinstance(current, bool) {
        if not isinstance(raw, bool) {
            raise ServeConfigError(f"{label} must be true or false, got {raw!r}");
        }
        return raw;
    }
    if isinstance(current, int) {
        if isinstance(raw, bool) or not isinstance(raw, int) {
            raise ServeConfigError(f"{label} must be an integer, got {raw!r}");
        }
        return raw;
    }
    if isinstance(current, float) {
        if isinstance(raw, bool) or not isinstance(raw, (int, float)) {
            raise ServeConfigError(f"{label} must be a number, got {raw!r}");
        }
        return float(raw);
    }
    if isinstance(current, list) {
        if not isinstance(raw, list)
            or not all(isinstance(item, str) for item in raw) {
            raise ServeConfigError(f"{label} must be a list of strings, got {raw!r}");
        }
        return list(raw);
    }
    if not isinstance(raw, str) {
        raise ServeConfigError(f"{label} must be a string, got {raw!r}");
    }
    return raw;
}


def env_typed(current: any, name: str) -> any {
    if isinstance(current, bool) {
        raw = str(env_value(name)).lower();
        if raw not in ENV_TRUE + ENV_FALSE {
            raise ServeConfigError(
                f"{ENV_PREFIX}{name} must be true or false, got {raw!r}"
            );
        }
        return raw in ENV_TRUE;
    }
    if isinstance(current, int) {
        return env_int(name, current);
    }
    if isinstance(current, float) {
        return env_float(name, current);
    }
    if isinstance(current, list) {
        return env_list(name, current);
    }
    return env_value(name);
}


impl overlay_table(
    target: object, table: dict[str, any], env: str, section: str, moved: dict[str, str]
) -> None {
    names = [f.name for f in fields(target)];
    for key in table {
        if key in names {
            continue;
        }
        if key in moved {
            raise ServeConfigError(f"[{section}] {key} has moved to {moved[key]}");
        }
        raise ServeConfigError(
            f"[{section}] has no key {key!r}; its keys are {', '.join(names)}"
        );
    }
    for name in names {
        current = getattr(target, name);
        env_name = env + name.upper();
        if is_record(current) {
            nested = table.get(name, {});
            if not isinstance(nested, dict) {
                raise ServeConfigError(f"[{section}.{name}] must be a table");
            }
            overlay_table(current, nested, env_name + '_', f"{section}.{name}", {});
        } elif env_value(env_name) {
            setattr(target, name, env_typed(current, env_name));
        } elif name in table {
            setattr(
                target, name, table_value(current, table[name], f"[{section}] {name}")
            );
        }
    }
}


impl removed_table(config: (JacConfig | None)) -> list[str] {
    if config is None {
        return [];
    }
    scale = config.get_plugin_config('scale');
    if not isinstance(scale, dict) or 'auth' not in scale {
        return [];
    }
    leftover = scale['auth'];
    keys = list(leftover) if isinstance(leftover, dict) else [];
    if not keys {
        return ["[scale.auth] was removed; its settings live in [serve.auth.email]"];
    }
    return [
        f"[scale.auth] {key} has moved to {SCALE_AUTH_MOVED_KEYS[key]}"
            if key in SCALE_AUTH_MOVED_KEYS
            else f"[scale.auth] {key} was removed and has no replacement"
        for key in keys
    ];
}


impl IdentifierSettings.enabled -> list[str] {
    return [
        kind
        for kind in IDENTIFIER_KINDS
        if getattr(self, kind) != 'off'
    ];
}

impl IdentifierSettings.login_identifiers -> list[str] {
    return list(self.login_with) if self.login_with else list(IDENTIFIER_KINDS);
}


impl AuthSettings.from_table(table: dict[str, any]) -> AuthSettings {
    settings = AuthSettings();
    overlay_table(settings, table, 'AUTH_', 'serve.auth', AUTH_MOVED_KEYS);
    settings.password.hash_cost = max(10, min(17, settings.password.hash_cost));
    return settings;
}


impl AuthSettings.problems -> list[str] {
    out: list[str] = [];
    ids = self.identifiers;
    for kind in IDENTIFIER_KINDS {
        mode = getattr(ids, kind);
        if mode not in IDENTIFIER_MODES {
            out.append(
                f"[serve.auth.identifiers] {kind} must be 'required', 'optional' "
                f"or 'off', got {mode!r}"
            );
        }
    }
    if out {
        return out;
    }
    enabled = ids.enabled();
    if not enabled {
        out.append(
            "[serve.auth.identifiers] username and email are both 'off'; an "
            "account needs at least one identifier"
        );
    }
    for name in ids.login_with {
        if name not in IDENTIFIER_KINDS {
            out.append(
                f"[serve.auth.identifiers] login_with names {name!r}; it may "
                f"name only {', '.join(IDENTIFIER_KINDS)}"
            );
        }
    }
    login = ids.login_identifiers();
    required = [
        kind
        for kind in enabled
        if getattr(ids, kind) == 'required'
    ];
    reachable = any(kind in login for kind in required)
        or (not required and all(kind in login for kind in enabled));
    if enabled and not reachable {
        out.append(
            f"[serve.auth.identifiers] login_with = {login!r} leaves accounts that "
            "hold only the other identifier with no way to log in"
        );
    }
    if self.email.verification not in VERIFICATION_MODES {
        out.append(
            "[serve.auth.email] verification must be 'none', 'optional' or "
            f"'required', got {self.email.verification!r}"
        );
    }
    if ids.email == 'off' {
        if self.email.verification != 'none' {
            out.append(
                "[serve.auth.email] verification is "
                f"{self.email.verification!r} while [serve.auth.identifiers] "
                "email is 'off'"
            );
        }
        if self.email.allowed_domains {
            out.append(
                "[serve.auth.email] allowed_domains is set while "
                "[serve.auth.identifiers] email is 'off'"
            );
        }
    }
    if self.email.verify_token_ttl_seconds < 1
        or self.email.reset_token_ttl_seconds < 1 {
        out.append(
            "[serve.auth.email] verify_token_ttl_seconds and "
            "reset_token_ttl_seconds must be at least 1"
        );
    }
    if self.username.min_length < 1
        or self.username.max_length < self.username.min_length {
        out.append(
            "[serve.auth.username] needs 1 <= min_length <= max_length, got "
            f"{self.username.min_length} and {self.username.max_length}"
        );
    }
    if self.username.pattern {
        try {
            re.compile(self.username.pattern);
        } except re.error as e {
            out.append(f"[serve.auth.username] pattern is not a valid regex: {e}");
        }
    }
    pw = self.password;
    if pw.min_length < 1 or pw.max_length < pw.min_length {
        out.append(
            "[serve.auth.password] needs 1 <= min_length <= max_length, got "
            f"{pw.min_length} and {pw.max_length}"
        );
    }
    unknown = [
        name
        for name in pw.require
        if name not in PASSWORD_CLASSES
    ];
    if unknown {
        out.append(
            f"[serve.auth.password] require names {unknown!r}; it may name only "
            f"{', '.join(PASSWORD_CLASSES)}"
        );
    }
    if pw.min_length < len(set(pw.require)) {
        out.append(
            f"[serve.auth.password] min_length = {pw.min_length} is shorter than "
            f"the {len(set(pw.require))} character classes it requires"
        );
    }
    if pw.history < 0 or pw.max_age_days < 0 {
        out.append(
            "[serve.auth.password] history and max_age_days must not be negative"
        );
    }
    if self.lockout.max_attempts < 0 or self.lockout.window_seconds < 1 {
        out.append(
            "[serve.auth.lockout] needs max_attempts >= 0 and window_seconds >= 1"
        );
    }
    return out;
}


impl secret_home(base_path: str) -> str {
    import from jaclang.project.config { find_project_root }
    start = Path(base_path) if base_path else Path.cwd();
    found = find_project_root(start);
    if found is not None {
        return str(found[0]);
    }
    return base_path or '.';
}


impl cpu_quota -> int {
    try {
        text = Path('/sys/fs/cgroup/cpu.max').read_text(encoding='utf-8').strip();
        parts = text.split();
        if len(parts) == 2 and parts[0] != 'max' {
            quota = int(parts[0]);
            period = int(parts[1]);
            if quota > 0 and period > 0 {
                return max(1, -(-quota // period));
            }
        }
    } except (OSError, ValueError) {}
    try {
        quota_text = Path('/sys/fs/cgroup/cpu/cpu.cfs_quota_us').read_text(
            encoding='utf-8'
        ).strip();
        period_text = Path('/sys/fs/cgroup/cpu/cpu.cfs_period_us').read_text(
            encoding='utf-8'
        ).strip();
        quota_v1 = int(quota_text);
        period_v1 = int(period_text);
        if quota_v1 > 0 and period_v1 > 0 {
            return max(1, -(-quota_v1 // period_v1));
        }
    } except (OSError, ValueError) {}
    counter: any = os?.process_cpu_count;
    counted = counter() if counter is not None else os.cpu_count();
    return max(1, int(counted or 1));
}


impl resolve_count(raw: str, quota: int, label: str) -> int {
    text = str(raw).strip().lower();
    if text == WORKERS_AUTO {
        return quota;
    }
    try {
        value = int(text);
    } except ValueError {
        raise ServeConfigError(
            f"{label} must be a positive integer or 'auto', got {raw!r}"
        );
    }
    if value < 1 {
        raise ServeConfigError(f"{label} must be at least 1, got {value}");
    }
    return value;
}


impl default_threads(worker_count: int, quota: int) -> int {
    per_worker = max(1, quota // max(1, worker_count));
    return min(32, per_worker * 4 + 4);
}


impl ServeSettings.load(
    base_path: str = '',
    overrides: (dict[str, any] | None) = None,
    config: (JacConfig | None) = None
) -> ServeSettings {
    given = dict(overrides or {});
    if config is None {
        start = Path(base_path) if base_path else None;
        config = JacConfig.discover(start);
    }
    cfg: ServeConfig = config.serve if config is not None else ServeConfig();
    removed = removed_table(config);
    if removed {
        raise ServeConfigError('\n'.join(f"- {p}" for p in removed));
    }
    quota = cpu_quota();

    workers_raw = str(
        given.get('workers') or env_value('WORKERS') or cfg.workers.count
    );
    worker_count = resolve_count(workers_raw, quota, '[serve.workers] count');
    threads_raw = str(
        given.get('threads') or env_value('THREADS') or cfg.workers.threads
    );
    threads = default_threads(worker_count, quota)
        if threads_raw.strip().lower() == WORKERS_AUTO
        else resolve_count(threads_raw, quota, '[serve.workers] threads');

    port = (
        int(given['port'])
            if 'port' in given and given['port'] is not None
            else env_int('PORT', cfg.port)
    );
    host_override = given.get('host');
    host = str(host_override) if host_override else (env_value('HOST') or cfg.host);

    settings = ServeSettings(
        base_path=base_path,
        host=host,
        port=port,
        strict_port=bool(given.get('strict_port', False)),
        dev=bool(given.get('dev', False)),
        no_client=bool(given.get('no_client', False)),
        client_dist=str(given.get('client_dist') or ''),
        static_only=bool(given.get('static_only', False)),
        docs_enabled=env_bool('DOCS', cfg.docs_enabled),
        graph_enabled=env_bool('GRAPH', cfg.graph_enabled),
        cors_origins=env_list('CORS_ORIGINS', list(cfg.cors_origins)),
        public_origin=(env_value('PUBLIC_ORIGIN') or cfg.public_origin).rstrip('/'),
        workers=WorkerSettings(
            count=worker_count,
            threads=threads,
            max_requests=env_int('MAX_REQUESTS', cfg.workers.max_requests),
            max_requests_jitter=env_int(
                'MAX_REQUESTS_JITTER', cfg.workers.max_requests_jitter
            ),
            request_timeout=env_float('REQUEST_TIMEOUT', cfg.workers.request_timeout),
            boot_timeout=env_float('BOOT_TIMEOUT', cfg.workers.boot_timeout),
            hang_timeout=env_float('HANG_TIMEOUT', cfg.workers.hang_timeout)
        ),
        tls=TlsSettings(
            certfile=env_value('TLS_CERTFILE') or cfg.tls.certfile,
            keyfile=env_value('TLS_KEYFILE') or cfg.tls.keyfile,
            ca_certs=env_value('TLS_CA_CERTS') or cfg.tls.ca_certs,
            min_version=env_value('TLS_MIN_VERSION') or cfg.tls.min_version
        ),
        proxy=ProxySettings(trusted=env_list('PROXY_TRUSTED', list(cfg.proxy.trusted))),
        limits=LimitSettings(
            max_connections=env_int('MAX_CONNECTIONS', cfg.limits.max_connections),
            backlog=env_int('BACKLOG', cfg.limits.backlog),
            max_body_bytes=env_int('MAX_BODY_BYTES', cfg.limits.max_body_bytes),
            max_header_bytes=env_int('MAX_HEADER_BYTES', cfg.limits.max_header_bytes),
            max_header_count=env_int('MAX_HEADER_COUNT', cfg.limits.max_header_count),
            max_request_line_bytes=env_int(
                'MAX_REQUEST_LINE_BYTES', cfg.limits.max_request_line_bytes
            ),
            multipart_spool_bytes=env_int(
                'MULTIPART_SPOOL_BYTES', cfg.limits.multipart_spool_bytes
            )
        ),
        timeouts=TimeoutSettings(
            header=env_float('HEADER_TIMEOUT', cfg.timeouts.header),
            body=env_float('BODY_TIMEOUT', cfg.timeouts.body),
            keepalive=env_float('KEEPALIVE_TIMEOUT', cfg.timeouts.keepalive),
            drain=env_float('DRAIN_TIMEOUT', cfg.timeouts.drain),
            close=env_float('CLOSE_TIMEOUT', cfg.timeouts.close)
        ),
        access_log=AccessLogSettings(
            enabled=env_bool('ACCESS_LOG', cfg.access_log.enabled),
            format=(env_value('ACCESS_LOG_FORMAT') or cfg.access_log.format).lower(),
            suppress_health_checks=env_bool(
                'ACCESS_LOG_SUPPRESS_HEALTH', cfg.access_log.suppress_health_checks
            )
        ),
        compression=CompressionSettings(
            enabled=env_bool('COMPRESSION', cfg.compression.enabled),
            min_bytes=env_int('COMPRESSION_MIN_BYTES', cfg.compression.min_bytes),
            level=env_int('COMPRESSION_LEVEL', cfg.compression.level)
        ),
        websocket=WebSocketSettings(
            allowed_origins=env_list(
                'WS_ALLOWED_ORIGINS', list(cfg.websocket.allowed_origins)
            ),
            max_message_bytes=env_int(
                'WS_MAX_MESSAGE_BYTES', cfg.websocket.max_message_bytes
            ),
            ping_interval=env_float('WS_PING_INTERVAL', cfg.websocket.ping_interval),
            ping_timeout=env_float('WS_PING_TIMEOUT', cfg.websocket.ping_timeout)
        ),
        auth=AuthSettings.from_table(cfg.auth)
    );
    return settings;
}


impl ServeSettings.validate -> list[str] {
    problems: list[str] = self.auth.problems();
    if self.access_log.format not in ('text', 'json') {
        problems.append(
            f"[serve.access_log] format must be 'text' or 'json', got "
            f"{self.access_log.format!r}"
        );
    }
    if self.compression.level < 1 or self.compression.level > 9 {
        problems.append(
            f"[serve.compression] level must be 1..9, got {self.compression.level}"
        );
    }
    if self.public_origin {
        origin = urlsplit(self.public_origin);
        if origin.scheme not in ('http', 'https')
            or not origin.netloc
            or '@' in origin.netloc
            or origin.path
            or origin.query
            or origin.fragment {
            problems.append(
                f"{ENV_PREFIX}PUBLIC_ORIGIN must be a scheme and host such as "
                f"https://app.example.com, got {self.public_origin!r}"
            );
        }
    }
    if self.timeouts.drain < 0 or self.timeouts.close < 0 {
        problems.append("[serve.timeouts] drain and close must not be negative");
    }
    if self.workers.request_timeout < 0 {
        problems.append("[serve.workers] request_timeout must not be negative");
    }
    if self.workers.max_requests < 0 or self.workers.max_requests_jitter < 0 {
        problems.append("[serve.workers] max_requests and jitter must not be negative");
    }
    try {
        self.tls.build_context();
    } except ServeConfigError as e {
        problems.append(str(e));
    } except (OSError, ssl.SSLError) as e {
        problems.append(f"[serve.tls] could not load the certificate: {e}");
    }
    if self.workers.multi_process() {
        if self.dev {
            problems.append(
                "--dev hot reload watches files and swaps modules in one process; "
                f"run with workers = 1 for development, not {self.workers.count}."
            );
        }
        if not hasattr(os, 'fork') {
            problems.append(
                "this platform cannot fork worker processes; use workers = 1"
            );
        }
        try {
            self.auth.resolve_secret(self.base_path);
        } except ServeConfigError as e {
            problems.append(str(e));
        } except RuntimeError as e {
            problems.append(str(e));
        }
    }
    return problems;
}


impl ServeSettings.warnings -> list[str] {
    lockout = self.auth.lockout;
    if in_cluster() and lockout.max_attempts > 0 and not self.proxy.trusted {
        return [
            "[serve.auth.lockout] counts failed logins per source address and "
            "identity, but [serve.proxy] trusted is empty in a cluster, so every "
            "caller arrives from the ingress address and the limit is per identity: "
            f"{lockout.max_attempts} wrong passwords from anyone lock that "
            f"account's login for {lockout.window_seconds} seconds. List the "
            "ingress in [serve.proxy] trusted (JAC_SERVE_PROXY_TRUSTED), or set "
            "[serve.auth.lockout] max_attempts = 0."
        ];
    }
    return [];
}


impl ServeSettings.require_valid -> None {
    problems = self.validate();
    if problems {
        raise ServeConfigError('\n'.join(f"- {p}" for p in problems));
    }
}
