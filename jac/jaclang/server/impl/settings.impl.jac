import ssl;
import from pathlib { Path }


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
        auth=AuthSettings(
            secret=env_value('AUTH_SECRET') or cfg.auth.secret,
            algorithm=env_value('AUTH_ALGORITHM') or cfg.auth.algorithm,
            token_ttl_days=env_int('AUTH_TOKEN_TTL_DAYS', cfg.auth.token_ttl_days),
            password_hash_cost=max(
                10,
                min(17, env_int('AUTH_PASSWORD_HASH_COST', cfg.auth.password_hash_cost))
            )
        )
    );
    return settings;
}


impl ServeSettings.validate -> list[str] {
    problems: list[str] = [];
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


impl ServeSettings.require_valid -> None {
    problems = self.validate();
    if problems {
        raise ServeConfigError('\n'.join(f"- {p}" for p in problems));
    }
}
