impl _env_reference(
    body: str, environ: dict[str, str]
) -> tuple[str, UnresolvedRef | None] {
    if body == "" or not (body[0].isalpha() or body[0] == "_") or not body[0].isascii() {
        return ("${" + body + "}", None);
    }
    end = 1;
    while end < len(body)
        and body[end].isascii()
        and (body[end].isalnum() or body[end] == "_") {
        end += 1;
    }
    var_name = body[:end];
    rest = body[end:];
    if rest != "" and not (rest.startswith(":-") or rest.startswith(":?")) {
        return (
            "${" + body + "}",
            UnresolvedRef(var=var_name, unsupported=True, form="${" + body + "}")
        );
    }
    if var_name in environ {
        return (environ[var_name], None);
    }
    operator = rest[:2];
    operand = rest[2:];
    if operator == ":-" {
        return (operand, None);
    }
    return (
        "${" + body + "}",
        UnresolvedRef(var=var_name, required=operator == ":?", message=operand)
    );
}

impl interpolate_env_vars(
    value: str,
    environ: dict[str, str] | None = None,
    sink: list[UnresolvedRef] | None = None
) -> str {
    source: dict[str, str] = dict(os.environ) if environ is None else environ;
    out: list[str] = [];
    pos = 0;
    while True {
        start = value.find("${", pos);
        if start < 0 {
            out.append(value[pos:]);
            break;
        }
        close = value.find("}", start + 2);
        if close < 0 {
            out.append(value[pos:]);
            break;
        }
        out.append(value[pos:start]);
        (text, record) = _env_reference(value[start + 2:close], source);
        if record is not None {
            if sink is None {
                raise ValueError(record.describe());
            }
            sink.append(record);
        }
        out.append(text);
        pos = close + 1;
    }
    return "".join(out);
}

impl UnresolvedRef.describe -> str {
    if self.unsupported {
        return f"Unsupported form {self.form}: jac reads ${{VAR}}, "
        "${VAR:-default} and ${VAR:?message}";
    }
    return f"Environment variable {self.var} is required: {self.message}"
        if self.required
        else f"Environment variable {self.var} is not set";
}

impl UnresolvedRef.reason -> str {
    if self.unsupported {
        return f"{self.form} is not a form jac reads "
        "(use ${VAR}, ${VAR:-default} or ${VAR:?message})";
    }
    return f"{self.var} is not set" + (f" ({self.message})" if self.message else "");
}

impl find_project_root(start: Path | None = None) -> tuple[Path, Path] | None {
    return _find_project_root(start);
}

impl is_in_project -> bool {
    return find_project_root() is not None;
}

impl JacConfig.discover(
    start_path: Path | None = None, profile: str | None = None
) -> JacConfig | None {
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, toml_path) = result;
    config = JacConfig.load(toml_path);
    base = start_path if start_path is not None else Path.cwd();
    config.discovered_from_ancestor = project_root.resolve() != base.resolve();
    if profile {
        config.apply_profile_overlay(profile);
    }
    return config;
}

impl JacConfig.load(toml_path: Path) -> JacConfig {
    if not toml_path.exists() {
        raise FileNotFoundError(f"Configuration file not found: {toml_path}");
    }
    data = read_toml_with_encoding(str(toml_path));
    config = _parse_toml_data(data, toml_path);
    config.config_files = [toml_path];
    return config;
}

impl JacConfig.resolve(
    start_path: Path | None = None, profile: str | None = None
) -> JacConfig | None {
    config = JacConfig.discover(start_path=start_path);
    if config is not None {
        config.profile_override = profile.strip() if profile is not None else None;
        selected = config.profile_override
            if config.profile_override is not None
            else active_profile_name(config).strip();
        config.apply_profile_overlay(selected or None);
    }
    return config;
}

impl JacConfig.from_toml_str(
    toml_str: str, toml_path: Path | None = None
) -> JacConfig {
    try {
        data = tomllib.loads(toml_str);
    } except tomllib.TOMLDecodeError as exc {
        raise MalformedJacTomlError(file_path=_origin_of(toml_path), original=exc);
    }
    return _parse_toml_data(data, toml_path);
}

impl _origin_of(toml_path: Path | None) -> str {
    return str(toml_path) if toml_path is not None else "jac.toml";
}

impl _toml_key(key: str) -> str {
    return key.replace("_", "-");
}

impl _parse_person(t: TomlTable, key: str, index: int, item: any) -> PersonConfig {
    if isinstance(item, str) {
        return PersonConfig(name=item, email="");
    }
    if not isinstance(item, dict) {
        raise t.error(
            f"{key}[{index}]", f"expected a string or a table, got {toml_kind(item)}"
        );
    }
    person = TomlTable(data=item, where=t.child_where(f"{key}[{index}]"), origin=t.origin);
    found = PersonConfig();
    for field in person.keys() {
        if field == "name" {
            found.name = person.text(field);
        } elif field == "email" {
            found.email = person.text(field);
        } else {
            raise person.unknown(field, ["name", "email"]);
        }
    }
    return found;
}

impl _parse_persons_at(t: TomlTable, key: str) -> list[PersonConfig] {
    raw = t.data[key];
    if not isinstance(raw, list) {
        raise t.error(key, f"expected an array, got {toml_kind(raw)}");
    }
    people: list[PersonConfig] = [];
    index = 0;
    for item in raw {
        people.append(_parse_person(t, key, index, item));
        index += 1;
    }
    return people;
}

impl PackageIncludeConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "packages" {
            self.packages = t.texts(key);
        } elif key == "data" {
            self.data = t.text_list_map(key);
        } else {
            raise t.unknown(key, INCLUDE_KEYS);
        }
    }
}

impl ProjectConfig.apply(t: TomlTable) {
    for key in t.keys() {
        name = _toml_key(key);
        if name == "name" {
            self.name = t.text(key);
        } elif name == "version" {
            self.version = t.text(key);
        } elif name == "description" {
            self.description = t.text(key);
        } elif name == "authors" {
            self.authors = _parse_persons_at(t, key);
        } elif name == "maintainers" {
            self.maintainers = _parse_persons_at(t, key);
        } elif name == "license" {
            self.license = t.text(key);
        } elif name == "readme" {
            self.readme = t.text(key);
        } elif name == "keywords" {
            self.keywords = t.texts(key);
        } elif name == "classifiers" {
            self.classifiers = t.texts(key);
        } elif name == "requires-python" {
            self.requires_python = t.text(key);
        } elif name == "jac-version" {
            self.jac_version = t.text(key);
        } elif name == "entry-point" {
            self.entry_point = validate_entry_point(t.text(key));
            self.entry_point_declared = True;
        } elif name == "kind" {
            self.kind = t.text(key);
        } elif name == "default-app" {
            self.default_app = t.text(key).strip();
        } elif name == "exports" {
            self.exports = t.texts(key);
        } elif name == "urls" {
            self.urls = t.text_map(key);
        } elif name == "include" {
            included = PackageIncludeConfig();
            included.apply(t.table(key));
            self.`include = included;
        } else {
            raise t.unknown(key, PROJECT_KEYS);
        }
    }
}

impl RunConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "session" {
            self.session = t.text(key);
        } elif key == "main" {
            self.main = t.flag(key);
        } elif key == "cache" {
            self.cache = t.flag(key);
        } elif key == "diagnostics" {
            self.diagnostics = t.text(key);
        } else {
            raise t.unknown(key, RUN_KEYS);
        }
    }
}

impl NativeConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "link_mode" {
            mode = t.text(key);
            if mode != "objects" and mode != "bitcode" {
                raise t.error(key, "must be objects or bitcode");
            }
            self.link_mode = mode;
        } elif key == "require" {
            self.require = t.texts(key);
        } elif key == "target" {
            self.target = t.text(key);
        } elif key == "opt" {
            self.opt = t.integer(key);
        } elif key == "debug" {
            self.debug = t.flag(key);
        } elif key == "threads" {
            threads = t.integer(key);
            if threads < 1 {
                raise t.error(key, "must be at least 1");
            }
            self.threads = threads;
        } else {
            raise t.unknown(key, NATIVE_KEYS);
        }
    }
}

impl MemoryConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "profile" {
            profile = t.text(key).strip().lower();
            if profile not in MEMORY_PROFILES {
                raise t.error(key, f"must be one of {', '.join(MEMORY_PROFILES)}");
            }
            self.profile = profile;
        } elif key == "enforce" {
            self.enforce = t.texts(key);
        } elif key == "exempt" {
            self.exempt = t.texts(key);
        } else {
            raise t.unknown(key, MEMORY_KEYS);
        }
    }
    if self.profile == "nogc" and (self.enforce or self.exempt) {
        raise t.error(
            "enforce/exempt",
            "cannot be set under profile = 'nogc': every module is held to the contract"
        );
    }
}

impl MemoryConfig.gc_mode -> str {
    if self.profile == "rc" {
        return "rc";
    }
    if self.profile == "nogc" {
        return "none";
    }
    return "cycles";
}

impl PlacementConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "default" {
            raw = t.text(key).strip().lower();
            if raw not in PLACEMENT_ALIASES {
                raise t.error(key, "must be one of 'server'/'sv', 'native'/'na'");
            }
            self.default_codespace = PLACEMENT_ALIASES[raw];
        } elif key == "pins" {
            pins = dict(self.pins);
            for (pattern, place) in t.text_map(key).items() {
                pins[pattern] = place;
            }
            self.pins = pins;
        } else {
            raise t.unknown(key, PLACEMENT_KEYS);
        }
    }
}

impl BuildConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key in BUILD_RETIRED {
            raise t.error(key, f"was retired; use {BUILD_RETIRED[key]}");
        }
        if key == "dir" {
            self.dir = t.text(key);
        } else {
            raise t.unknown(key, BUILD_KEYS);
        }
    }
}

impl TestConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "directory" {
            self.directory = t.text(key);
        } elif key == "directories" {
            self.directories = t.texts(key);
        } elif key == "isolate" {
            self.isolate = t.texts(key);
        } elif key == "serial" {
            self.serial = t.texts(key);
        } elif key == "filter" {
            self.filter = t.text(key);
        } elif key == "verbose" {
            self.verbose = t.flag(key);
        } elif key == "fail_fast" {
            self.fail_fast = t.flag(key);
        } elif key == "max_failures" {
            self.max_failures = t.integer(key);
        } else {
            raise t.unknown(key, TEST_KEYS);
        }
    }
}

impl ServeWorkersConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "count" {
            self.count = t.scalar_text(key);
        } elif key == "threads" {
            self.threads = t.scalar_text(key);
        } elif key == "max_requests" {
            self.max_requests = t.integer(key);
        } elif key == "max_requests_jitter" {
            self.max_requests_jitter = t.integer(key);
        } elif key == "request_timeout" {
            self.request_timeout = t.number(key);
        } elif key == "boot_timeout" {
            self.boot_timeout = t.number(key);
        } elif key == "hang_timeout" {
            self.hang_timeout = t.number(key);
        } else {
            raise t.unknown(key, WORKERS_KEYS);
        }
    }
}

impl ServeTlsConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "certfile" {
            self.certfile = t.text(key);
        } elif key == "keyfile" {
            self.keyfile = t.text(key);
        } elif key == "ca_certs" {
            self.ca_certs = t.text(key);
        } elif key == "min_version" {
            self.min_version = t.scalar_text(key);
        } else {
            raise t.unknown(key, TLS_KEYS);
        }
    }
}

impl ServeProxyConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "trusted" {
            self.trusted = t.texts(key);
        } else {
            raise t.unknown(key, PROXY_KEYS);
        }
    }
}

impl ServeLimitsConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "max_connections" {
            self.max_connections = t.integer(key);
        } elif key == "backlog" {
            self.backlog = t.integer(key);
        } elif key == "max_body_bytes" {
            self.max_body_bytes = t.integer(key);
        } elif key == "max_header_bytes" {
            self.max_header_bytes = t.integer(key);
        } elif key == "max_header_count" {
            self.max_header_count = t.integer(key);
        } elif key == "max_request_line_bytes" {
            self.max_request_line_bytes = t.integer(key);
        } elif key == "multipart_spool_bytes" {
            self.multipart_spool_bytes = t.integer(key);
        } else {
            raise t.unknown(key, LIMITS_KEYS);
        }
    }
}

impl ServeTimeoutsConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "header" {
            self.header = t.number(key);
        } elif key == "body" {
            self.body = t.number(key);
        } elif key == "keepalive" {
            self.keepalive = t.number(key);
        } elif key == "drain" {
            self.drain = t.number(key);
        } elif key == "close" {
            self.close = t.number(key);
        } else {
            raise t.unknown(key, TIMEOUTS_KEYS);
        }
    }
}

impl ServeAccessLogConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "enabled" {
            self.enabled = t.flag(key);
        } elif key == "format" {
            self.format = t.text(key);
        } elif key == "suppress_health_checks" {
            self.suppress_health_checks = t.flag(key);
        } else {
            raise t.unknown(key, ACCESS_LOG_KEYS);
        }
    }
}

impl ServeCompressionConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "enabled" {
            self.enabled = t.flag(key);
        } elif key == "min_bytes" {
            self.min_bytes = t.integer(key);
        } elif key == "level" {
            self.level = t.integer(key);
        } else {
            raise t.unknown(key, COMPRESSION_KEYS);
        }
    }
}

impl ServeWebSocketConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "allowed_origins" {
            self.allowed_origins = t.texts(key);
        } elif key == "max_message_bytes" {
            self.max_message_bytes = t.integer(key);
        } elif key == "ping_interval" {
            self.ping_interval = t.number(key);
        } elif key == "ping_timeout" {
            self.ping_timeout = t.number(key);
        } else {
            raise t.unknown(key, WEBSOCKET_KEYS);
        }
    }
}

impl ServeConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "host" {
            self.host = t.text(key);
        } elif key == "port" {
            self.port = t.integer(key);
        } elif key == "session" {
            self.session = t.text(key);
        } elif key == "main" {
            self.main = t.flag(key);
        } elif key == "docs_enabled" {
            self.docs_enabled = t.flag(key);
        } elif key == "graph_enabled" {
            self.graph_enabled = t.flag(key);
        } elif key == "cors_origins" {
            self.cors_origins = t.text_or_texts(key);
        } elif key == "public_origin" {
            self.public_origin = t.text(key);
        } elif key == "on_conflict" {
            mode = t.text(key).strip().lower();
            if mode not in SERVE_CONFLICT_MODES {
                raise t.error(key, "must be 'retry' or 'fail'");
            }
            self.on_conflict = mode;
        } elif key == "conflict_max_attempts" {
            self.conflict_max_attempts = t.integer(key);
        } elif key == "conflict_backoff_ms" {
            self.conflict_backoff_ms = t.integer(key);
        } elif key == "workers" {
            if isinstance(t.data[key], dict) {
                self.workers.apply(t.table(key));
            } else {
                self.workers.count = t.scalar_text(key);
            }
        } elif key == "tls" {
            self.tls.apply(t.table(key));
        } elif key == "proxy" {
            self.proxy.apply(t.table(key));
        } elif key == "limits" {
            self.limits.apply(t.table(key));
        } elif key == "timeouts" {
            self.timeouts.apply(t.table(key));
        } elif key == "access_log" {
            self.access_log.apply(t.table(key));
        } elif key == "compression" {
            self.compression.apply(t.table(key));
        } elif key == "websocket" {
            self.websocket.apply(t.table(key));
        } elif key == "auth" {
            self.auth = _deep_merge(self.auth, t.raw_table(key));
        } else {
            raise t.unknown(key, SERVE_KEYS);
        }
    }
}

impl FormatConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "outfile" {
            self.outfile = t.text(key);
        } else {
            raise t.unknown(key, FORMAT_KEYS);
        }
    }
}

impl LintConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "select" {
            self.select = t.texts(key);
        } elif key == "ignore" {
            self.ignore = t.texts(key);
        } elif key == "exclude" {
            self.exclude = t.texts(key);
        } else {
            raise t.unknown(key, LINT_KEYS);
        }
    }
}

impl CheckConfig.apply(t: TomlTable) {
    for key in t.keys() {
        name = _toml_key(key);
        if key == "print_errs" {
            self.print_errs = t.flag(key);
        } elif key == "lint" {
            self.lint.apply(t.table(key));
        } elif key == "exclude" {
            self.exclude = t.texts(key);
        } elif key == "suppress" {
            self.suppress = t.texts(key);
        } elif key == "suppress_categories" {
            self.suppress_categories = t.texts(key);
        } elif key == "enforce_access" {
            self.enforce_access = t.flag(key);
        } elif key == "warn_native_seams" {
            self.warn_native_seams = t.flag(key);
        } elif name == "untyped-external" {
            level = t.text(key);
            if level != "warning" and level != "error" {
                raise t.error(key, "must be 'warning' or 'error'");
            }
            self.untyped_external = level;
        } else {
            raise t.unknown(key, CHECK_KEYS);
        }
    }
}

impl DotConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "depth" {
            self.depth = t.integer(key);
        } elif key == "traverse" {
            self.traverse = t.flag(key);
        } elif key == "bfs" {
            self.bfs = t.flag(key);
        } elif key == "edge_limit" {
            self.edge_limit = t.integer(key);
        } elif key == "node_limit" {
            self.node_limit = t.integer(key);
        } elif key == "format" {
            self.format = t.text(key);
        } else {
            raise t.unknown(key, DOT_KEYS);
        }
    }
}

impl CacheConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "enabled" {
            self.enabled = t.flag(key);
        } elif key == "dir" {
            self.dir = t.text(key);
        } else {
            raise t.unknown(key, CACHE_KEYS);
        }
    }
}

impl StorageConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "type" {
            self.storage_type = t.text(key);
        } elif key == "base_path" {
            self.base_path = t.text(key);
        } elif key == "create_dirs" {
            self.create_dirs = t.flag(key);
        } elif key == "bucket" {
            self.bucket = t.text(key);
        } elif key == "prefix" {
            self.prefix = t.text(key);
        } elif key == "region" {
            self.region = t.text(key);
        } elif key == "endpoint_url" {
            self.endpoint_url = t.optional_text(key);
        } elif key == "project_id" {
            self.project_id = t.text(key);
        } elif key == "public_read" {
            self.public_read = t.flag(key);
        } else {
            raise t.unknown(key, STORAGE_KEYS);
        }
    }
}

impl EnvironmentConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "default_profile" {
            self.default_profile = t.text(key);
        } else {
            raise t.unknown(key, ENVIRONMENT_KEYS);
        }
    }
}

impl ClientErrorsConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "verbose" {
            self.verbose = t.flag(key);
        } else {
            raise t.unknown(key, CLIENT_ERRORS_KEYS);
        }
    }
}

impl ClientConfig.apply(t: TomlTable) {
    if t.has_key("framework") {
        self.framework = t.text("framework");
    }
    if t.has_key("paths") {
        paths = dict(self.paths);
        paths.update(t.text_map("paths"));
        self.paths = paths;
    }
}

impl DatabaseConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "indexes" {
            indexes = dict(self.indexes);
            for (arch, fields) in t.text_list_map(key).items() {
                indexes[arch] = fields;
            }
            self.indexes = indexes;
        } elif key == "retention_days" {
            days = t.scalar_text(key).strip();
            if not days.isdigit() {
                raise t.error(key, "must be a whole number of days");
            }
            self.retention_days = int(days);
        } elif key == "postgres_dist" {
            self.postgres_dist = t.text(key);
        } elif key == "postgres_version" {
            self.postgres_version = t.scalar_text(key);
        } else {
            raise t.unknown(key, DATABASE_KEYS);
        }
    }
}

impl NetworkConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "offline" {
            self.offline = t.flag(key);
        } else {
            raise t.unknown(key, NETWORK_KEYS);
        }
    }
}

impl ToolchainsConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "system" {
            self.system = t.flag(key);
        } else {
            raise t.unknown(key, TOOLCHAINS_KEYS);
        }
    }
}

impl DevConfig.apply(t: TomlTable) {
    for key in t.keys() {
        if key == "jaclang_source" {
            self.jaclang_source = t.text(key);
        } elif key == "exact" {
            self.exact = t.flag(key);
        } elif key == "pod_binary" {
            self.pod_binary = t.text(key);
        } elif key == "jobs" {
            self.jobs = t.scalar_text(key);
        } elif key == "test_jobs" {
            self.test_jobs = t.scalar_text(key);
        } elif key == "check_jobs" {
            self.check_jobs = t.scalar_text(key);
        } elif key == "fmt_jobs" {
            self.fmt_jobs = t.scalar_text(key);
        } else {
            raise t.unknown(key, DEV_KEYS);
        }
    }
}

impl _check_retired(t: TomlTable) {
    for (section, detail) in RETIRED_SECTIONS.items() {
        if t.has_key(section) {
            raise t.error(section, detail);
        }
    }
    if t.has_key("scale") {
        scale = t.raw_table("scale");
        if "microservices" in scale {
            raise t.error(
                "scale.microservices",
                "was removed: declare each service as an [apps.<name>] table "
                    "(kind = \"service\", entry-point, route) and move the gateway "
                    "settings (logs, ingress, cors, boot keys) to [scale.gateway]. "
                    "See the Breaking Changes page "
                    "(docs/community/breaking-changes.md, Workspaces)"
            );
        }
    }
}

impl _apply_sections(cfg: JacConfig, t: TomlTable) {
    _check_retired(t);
    if t.has_key("project") {
        cfg.project.apply(t.table("project"));
    }
    if t.has_key("run") {
        cfg.run.apply(t.table("run"));
    }
    if t.has_key("build") {
        cfg.build.apply(t.table("build"));
    }
    if t.has_key("memory") {
        cfg.memory.apply(t.table("memory"));
    }
    if t.has_key("native") {
        cfg.native.apply(t.table("native"));
    }
    if t.has_key("placement") {
        cfg.placement.apply(t.table("placement"));
    }
    if t.has_key("test") {
        cfg.`test.apply(t.table("test"));
    }
    if t.has_key("serve") {
        cfg.serve.apply(t.table("serve"));
    }
    if t.has_key("format") {
        cfg.format.apply(t.table("format"));
    }
    if t.has_key("check") {
        cfg.check.apply(t.table("check"));
    }
    if t.has_key("dot") {
        cfg.dot.apply(t.table("dot"));
    }
    if t.has_key("cache") {
        cfg.cache.apply(t.table("cache"));
    }
    if t.has_key("storage") {
        cfg.storage.apply(t.table("storage"));
    }
    if t.has_key("client_errors") {
        cfg.client_errors.apply(t.table("client_errors"));
    }
    if t.has_key("client") {
        cfg.client.apply(t.table("client"));
    }
    if t.has_key("database") {
        cfg.database.apply(t.table("database"));
    }
    if t.has_key("network") {
        cfg.network.apply(t.table("network"));
    }
    if t.has_key("toolchains") {
        cfg.toolchains.apply(t.table("toolchains"));
    }
    if t.has_key("dev") {
        cfg.dev.apply(t.table("dev"));
    }
    if t.has_key("environment") {
        cfg.environment.apply(t.table("environment"));
    }
    _apply_capabilities(cfg, t);
    cfg.merge_dependency_tables(t.data, t.where + "." if t.where else "");
    _apply_named_tables(cfg, t);
}

impl _apply_capabilities(cfg: JacConfig, t: TomlTable) {
    for feature in CAPABILITY_SECTIONS {
        if not t.has_key(feature) {
            continue;
        }
        table = t.raw_table(feature);
        if feature in cfg.plugins {
            cfg.plugins[feature] = _deep_merge(cfg.plugins[feature], table);
        } else {
            cfg.plugins[feature] = table;
        }
    }
}

impl _apply_named_tables(cfg: JacConfig, t: TomlTable) {
    if t.has_key("scripts") {
        for (name, command) in t.text_map("scripts").items() {
            cfg.scripts[name] = command;
        }
    }
    if t.has_key("entrypoints") {
        groups = t.table("entrypoints");
        for group in groups.keys() {
            refs = groups.text_map(group);
            merged = dict(cfg.entrypoints.get(group, {}));
            for (name, ref) in refs.items() {
                merged[name] = ref;
            }
            cfg.entrypoints[group] = merged;
        }
    }
    if t.has_key("optional-dependencies") {
        groups = t.table("optional-dependencies");
        for group in groups.keys() {
            deps = groups.text_map(group);
            merged = dict(cfg.optional_dependencies.get(group, {}));
            for (name, spec) in deps.items() {
                merged[name] = spec;
            }
            cfg.optional_dependencies[group] = merged;
        }
    }
}

impl JacConfig.apply_profile(
    profile_name: str, _visited: set[str] | None = None
) -> None {
    if _visited is None {
        self._layers.append(("profile", profile_name));
        _visited = set();
    }
    if profile_name not in self.environments or profile_name in _visited {
        return;
    }
    _visited.add(profile_name);
    profile = TomlTable(
        data=dict(self.environments[profile_name]),
        where=f"environments.{profile_name}",
        origin=_origin_of(self.toml_path)
    );
    if profile.has_key("inherits") {
        parent_name = profile.text("inherits");
        if parent_name not in self.environments {
            raise profile.error(
                "inherits", f"names '{parent_name}', which is not a profile"
            );
        }
        self.apply_profile(parent_name, _visited=_visited);
        del profile.data["inherits"];
    }
    _apply_sections(self, profile);
    if profile.has_key("apps") {
        self.merge_apps_table(profile.raw_table("apps"));
    }
}

impl JacConfig.merge_apps_table(apps_table: dict[str, any]) -> None {
    if not apps_table {
        return;
    }
    base = self._base_data.get("apps");
    if not isinstance(base, dict) {
        raise ValueError(
            "an overlay declares [apps] but jac.toml does not; "
            "declare every app in jac.toml and let the overlay retune it"
        );
    }
    merged = _deep_merge(copy.deepcopy(base), copy.deepcopy(apps_table));
    self._base_data["apps"] = merged;
    self._raw_data["apps"] = copy.deepcopy(merged);
    project = self._base_data.get("project", {});
    self.apps = parse_apps(
        project if isinstance(project, dict) else {}, _interpolate_recursive(merged)
    );
}

impl JacConfig.apply_profile_overlay(profile_name: str | None = None) -> None {
    if self.project_root is None {
        return;
    }
    self._layers.append(("overlay", profile_name or ""));
    if profile_name {
        self.merge_from_toml_file(self.project_root / f"jac.{profile_name}.toml");
        self.apply_profile(profile_name, _visited=set());
        self.active_profile = profile_name;
    }
    self.merge_from_toml_file(self.project_root / "jac.local.toml");
}

impl JacConfig.merge_from_toml_file(toml_path: Path) -> None {
    if not toml_path.exists() {
        return;
    }
    raw: dict[str, any] = read_toml_with_encoding(str(toml_path));
    (resolved, refs) = resolve_env_refs(raw);
    data: dict[str, any] = resolved;
    self.unresolved = self.unresolved + refs;
    layer = TomlTable(data=data, where="", origin=str(toml_path));
    _apply_sections(self, layer);
    if layer.has_key("environments") {
        environments = layer.table("environments");
        for name in environments.keys() {
            self.environments[name] = environments.raw_table(name);
        }
    }
    if self.config_files is None {
        self.config_files = [];
    }
    if toml_path not in self.config_files {
        self.config_files.append(toml_path);
    }
    for (key, value) in data.items() {
        current = self._raw_data.get(key);
        if isinstance(current, dict) and isinstance(value, dict) {
            current.update(value);
        } else {
            self._raw_data[key] = value;
        }
    }
    if layer.has_key("apps") {
        self.merge_apps_table(layer.raw_table("apps"));
    }
}

impl _parse_toml_data(
    data: dict[str, any], toml_path: Path | None = None
) -> JacConfig {
    (resolved, refs) = resolve_env_refs(data);
    doc: dict[str, any] = resolved;
    config = JacConfig();
    config.unresolved = refs;
    config._raw_data = data;
    config._base_data = copy.deepcopy(data);
    if toml_path is not None {
        config.toml_path = toml_path;
        config.project_root = toml_path.parent;
    }
    top = TomlTable(data=doc, where="", origin=_origin_of(toml_path));
    _apply_sections(config, top);
    if top.has_key("environments") {
        environments = top.table("environments");
        for name in environments.keys() {
            config.environments[name] = environments.raw_table(name);
        }
    }
    project: dict[str, any] = top.raw_table("project") if top.has_key("project") else {};
    if top.has_key("apps") {
        config.apps = parse_apps(project, top.raw_table("apps"));
        config.is_workspace = True;
    } else {
        if config.project.default_app {
            raise top.error("project.default-app", "requires an [apps] table");
        }
        app = implicit_app(config.project);
        config.apps = {app.name: app};
    }
    config.persistence = parse_persistence(
        top.raw_table("persistence") if top.has_key("persistence") else {},
        config.project.name
    );
    return config;
}

impl _interpolate_recursive(`obj: any) -> any {
    (resolved, _) = resolve_env_refs(`obj);
    return resolved;
}

impl resolve_env_refs(
    data: any, environ: dict[str, str] | None = None, path: str = ""
) -> tuple[any, list[UnresolvedRef]] {
    refs: list[UnresolvedRef] = [];
    return (_resolve_env_into(data, path, environ, refs), refs);
}

impl _resolve_env_into(
    item: any, at: str, environ: dict[str, str] | None, refs: list[UnresolvedRef]
) -> any {
    if isinstance(item, str) {
        found: list[UnresolvedRef] = [];
        resolved = interpolate_env_vars(item, environ, found);
        for ref in found {
            ref.path = at;
            ref.raw = resolved;
            refs.append(ref);
        }
        return resolved;
    }
    if isinstance(item, dict) {
        table: dict[str, any] = {};
        for (key, value) in item.items() {
            name = str(key);
            table[name] = _resolve_env_into(
                value, f"{at}.{name}" if at else name, environ, refs
            );
        }
        return table;
    }
    if isinstance(item, list) {
        items: list[any] = [];
        index = 0;
        for value in item {
            items.append(_resolve_env_into(value, f"{at}[{index}]", environ, refs));
            index += 1;
        }
        return items;
    }
    return item;
}

impl JacConfig.get_plugin_deps(dep_type: str) -> dict[str, any] {
    deps = self.plugin_dependencies.get(dep_type, {});

    return {
        k: v
        for (k, v) in deps.items()
        if k != "dev" and not isinstance(v, dict)
    };
}

impl JacConfig.get_plugin_config(plugin_name: str) -> dict[str, any] {
    return self.plugins.get(plugin_name, {});
}

impl JacConfig.get_section(name: str) -> dict[str, any] | None {
    section = self._raw_data.get(name) if isinstance(self._raw_data, dict) else None;
    return section if isinstance(section, dict) else None;
}

impl JacConfig.get_build_dir -> Path {
    base = self.project_root or Path.cwd();
    return base / self.build.dir;
}

impl JacConfig.get_cache_dir -> Path {
    return self.get_build_dir() / self.cache.dir;
}

impl JacConfig.get_venv_dir -> Path {
    return self.get_build_dir() / "venv";
}

impl JacConfig.get_data_dir -> Path {
    return self.get_build_dir() / "data";
}

impl JacConfig.get_client_dir -> Path {
    return self.get_build_dir() / "client";
}

impl JacConfig.is_valid -> bool {
    return self.toml_path is not None and self.toml_path.exists();
}

impl JacConfig.save -> None {
    if self.toml_path is None {
        raise ValueError("No toml_path set, cannot save configuration");
    }

    text = "";
    old_doc: dict[str, any] = {};
    if self.toml_path.exists() {
        text = read_file_with_encoding(str(self.toml_path));
        try {
            old_doc = tomllib.loads(text);
        } except tomllib.TOMLDecodeError as exc {
            raise MalformedJacTomlError(file_path=str(self.toml_path), original=exc);
        }
    }
    doc = copy.deepcopy(old_doc);

    doc["dependencies"] = _dependency_doc(self, dev=False);
    dev_doc = _dependency_doc(self, dev=True);
    if dev_doc or "dev-dependencies" in doc {
        doc["dev-dependencies"] = dev_doc;
    }

    if text {
        updated = toml_minimal_update(
            text, old_doc, doc, ["dependencies", "dev-dependencies"]
        );
        if updated is not None {
            self._write_toml_text(updated);
            return;
        }
    }
    self.persist_doc(doc);
}

def _dependency_doc(config: JacConfig, dev: bool) -> dict[str, any];

impl JacConfig.persist_doc(doc: dict[str, any]) -> None {
    self._write_toml_text(serialize_toml(doc));
}

impl JacConfig._write_toml_text(text: str) -> None {
    if self.toml_path is None {
        raise ValueError("No toml_path set, cannot save configuration");
    }
    if self.discovered_from_ancestor {
        sys.stderr.write(
            f"warning: no jac.toml in the current directory -- modifying {self.toml_path}\n"
                "  Run this command from the project root, "
                "or 'jac create' here to start a new project.\n"
        );
    }
    with open(str(self.toml_path), "w") as f {
        f.write(text);
    }
}

def _needs_quoting(key: str) -> bool;

def _quote_key(key: str) -> str;

glob INLINE_SPEC_KEYS: set[str] = {
         "version",
         "path",
         "git",
         "rev",
         "branch",
         "tag",
         "registry",
         "extras"
     };

def _toml_is_inline(
    lines: list[str], path: tuple[str, ...], value: dict[str, any]
) -> bool;

def _toml_flatten_into(
    view: dict[tuple[str, ...], dict[str, any]],
    path: tuple[str, ...],
    table: dict[str, any],
    lines: list[str]
);

def _toml_flatten(
    doc: dict[str, any], roots: list[str], lines: list[str]
) -> dict[tuple[str, ...], dict[str, any]] | None;

def _toml_token_alt(name: str) -> str;

def _toml_find_span(
    lines: list[str], parts: tuple[str, ...]
) -> tuple[int, int] | None;

def _toml_find_key(
    lines: list[str], span: tuple[int, int], key: str
) -> tuple[int, int] | None;

def _toml_value_end(line: str, start: int) -> int | None;

def _toml_replace_key(
    lines: list[str], parts: tuple[str, ...], key: str, value_text: str
) -> bool;

def _toml_delete_key(lines: list[str], parts: tuple[str, ...], key: str) -> bool;

def _toml_insert_key(
    lines: list[str], parts: tuple[str, ...], key: str, value_text: str
) -> bool;

def _toml_append_section(
    lines: list[str], parts: tuple[str, ...], flat: dict[str, any]
);

def _toml_remove_section(lines: list[str], parts: tuple[str, ...]) -> bool;

impl toml_minimal_update(
    text: str, old_doc: dict[str, any], new_doc: dict[str, any], roots: list[str]
) -> str | None {
    lines: list[str] = text.split("\n");
    old_view = _toml_flatten(old_doc, roots, lines);
    new_view = _toml_flatten(new_doc, roots, lines);
    if old_view is None or new_view is None {
        return None;
    }
    for path in sorted(set(old_view.keys()) | set(new_view.keys())) {
        old_flat = old_view.get(path);
        new_flat = new_view.get(path);
        if new_flat is None {
            if not _toml_remove_section(lines, path) and old_flat {
                return None;
            }
            continue;
        }
        if old_flat is None {
            if new_flat {
                if _toml_find_span(lines, path) is not None {
                    return None;
                }
                _toml_append_section(lines, path, new_flat);
            }
            continue;
        }
        removed = [
            k
            for k in old_flat.keys()
            if k not in new_flat
        ];
        added = {
            k: v
            for (k, v) in new_flat.items()
            if k not in old_flat
        };
        changed = {
            k: v
            for (k, v) in new_flat.items()
            if k in old_flat and old_flat[k] != v
        };
        if not (removed or added or changed) {
            continue;
        }
        if _toml_find_span(lines, path) is None {
            if removed or changed or old_flat {
                return None;
            }
            _toml_append_section(lines, path, added);
            continue;
        }
        for k in removed {
            if not _toml_delete_key(lines, path, k) {
                return None;
            }
        }
        for (k, v) in changed.items() {
            if not _toml_replace_key(lines, path, k, toml_value(v)) {
                return None;
            }
        }
        for (k, v) in added.items() {
            if not _toml_insert_key(lines, path, k, toml_value(v)) {
                return None;
            }
        }
    }
    return "\n".join(lines);
}

impl serialize_toml(data: dict[str, any], prefix: str = "") -> str {
    lines: list[str] = [];
    tables: list[tuple[str, dict[str, any]]] = [];

    for (key, value) in data.items() {
        if isinstance(value, dict) {
            quoted_key = _quote_key(key);
            table_key = f"{prefix}{quoted_key}" if prefix else quoted_key;
            tables.append((table_key, value));
        } else {
            lines.append(f"{_quote_key(key)} = {toml_value(value)}");
        }
    }

    if lines and tables {
        lines.append("");
    }

    for (table_key, table_data) in tables {
        has_nested = any(isinstance(v, dict) for v in table_data.values());
        if has_nested {
            simple_values: list[tuple[str, any]] = [];
            nested_tables: list[tuple[str, dict[str, any]]] = [];
            for (k, v) in table_data.items() {
                if isinstance(v, dict) {
                    nested_tables.append((k, v));
                } else {
                    simple_values.append((k, v));
                }
            }
            if simple_values {
                lines.append(f"[{table_key}]");
                for (k, v) in simple_values {
                    lines.append(f"{_quote_key(k)} = {toml_value(v)}");
                }
                lines.append("");
            }
            for (nested_key, nested_data) in nested_tables {
                nested_content = serialize_toml(
                    {nested_key: nested_data}, f"{table_key}."
                );
                lines.append(nested_content);
            }
        } else {
            lines.append(f"[{table_key}]");
            for (k, v) in table_data.items() {
                lines.append(f"{_quote_key(k)} = {toml_value(v)}");
            }
            lines.append("");
        }
    }

    return "\n".join(lines);
}

impl toml_value(value: any) -> str {
    if value is None {
        return '""';
    } elif isinstance(value, bool) {
        return "true" if value else "false";
    } elif isinstance(value, int) {
        return str(value);
    } elif isinstance(value, float) {
        return str(value);
    } elif isinstance(value, str) {
        escaped = value.replace("\\", "\\\\").replace('"', '\\"');
        return f'"{escaped}"';
    } elif isinstance(value, list) {
        items = [toml_value(item) for item in value];
        return f"[{', '.join(items)}]";
    } elif isinstance(value, dict) {
        if not value {
            return "{}";
        }
        pairs = [f"{_quote_key(k)} = {toml_value(v)}" for (k, v) in value.items()];
        return "{ " + ", ".join(pairs) + " }";
    } else {
        return f'"{value}"';
    }
}

impl JacConfig.merge_dependency_tables(
    data: dict[str, any], section_prefix: str = ""
) -> None {
    if isinstance(data.get("registries"), dict) {
        for (name, url) in data["registries"].items() {
            self.registries[str(name)] = str(url);
        }
    }
    for (section, dev) in (("dependencies", False), ("dev-dependencies", True)) {
        table = data.get(section);
        if not isinstance(table, dict) {
            continue;
        }
        tables = split_dependency_table(table, dev, section_prefix + section);
        (self.dev_dependencies if dev else self.dependencies).update(tables.packages);
        (self.pypi_dev_dependencies if dev else self.pypi_dependencies).update(
            tables.pypi
        );
        self.pypi_git_dependencies.update(tables.pypi_git);
        for (eco, deps) in tables.ecosystems.items() {
            bucket = self.plugin_dependencies.setdefault(eco, {});
            if dev {
                bucket.setdefault("dev", {}).update(deps);
            } else {
                bucket.update(deps);
            }
        }
    }
}

impl JacConfig.add_dependency(
    name: str, version: str, dev: bool = False, dep_type: str = "pypi"
) -> None {
    if dep_type == "pypi" {
        if dev {
            self.pypi_dev_dependencies[name] = version;
        } else {
            self.pypi_dependencies[name] = version;
        }
    } elif dep_type == "pypi-git" {
        self.pypi_git_dependencies[name] = {"git": version};
    } elif dep_type == "jac" {
        (self.dev_dependencies if dev else self.dependencies)[name] = PackageDep(
            name=name, version=version or "*", dev=dev
        );
    } else {
        if dep_type not in self.plugin_dependencies {
            self.plugin_dependencies[dep_type] = {};
        }
        if dev {
            if "dev" not in self.plugin_dependencies[dep_type] {
                self.plugin_dependencies[dep_type]["dev"] = {};
            }
            self.plugin_dependencies[dep_type]["dev"][name] = version;
        } else {
            self.plugin_dependencies[dep_type][name] = version;
        }
    }
}

impl JacConfig.remove_dependency(
    name: str, dev: bool = False, dep_type: str = "pypi"
) -> bool {
    if dep_type == "pypi" {
        table = self.pypi_dev_dependencies if dev else self.pypi_dependencies;
        if name in table {
            del table[name];
            return True;
        }
    } elif dep_type == "pypi-git" {
        if name in self.pypi_git_dependencies {
            del self.pypi_git_dependencies[name];
            return True;
        }
    } elif dep_type == "jac" {
        packages = self.dev_dependencies if dev else self.dependencies;
        if name in packages {
            del packages[name];
            return True;
        }
    } elif dep_type in self.plugin_dependencies {
        if dev and "dev" in self.plugin_dependencies[dep_type] {
            if name in self.plugin_dependencies[dep_type]["dev"] {
                del self.plugin_dependencies[dep_type]["dev"][name];
                return True;
            }
        } elif name in self.plugin_dependencies[dep_type] {
            del self.plugin_dependencies[dep_type][name];
            return True;
        }
    }
    return False;
}

impl report_env_findings(
    refs: list[UnresolvedRef], context: str, hint: str = ""
) -> None {
    if not refs {
        return;
    }
    lines = [f"  {ref.path}: {ref.reason()}" for ref in refs];
    tail = f"\n{hint}" if hint else "";
    raise ValueError(context + "\n" + "\n".join(lines) + tail);
}

impl get_config(
    start_path: Path | None = None,
    force_discover: bool = False,
    profile: str | None = None
) -> JacConfig | None {
    if force_discover {
        _config = None;
        _config_explicit = False;
        _config_by_root = {};
    }
    if _config_explicit {
        return _config;
    }
    if _config is None or profile is not None {
        base = start_path or (_config.project_root if _config else None) or Path.cwd();
        _config = get_config_for_path(base, profile=profile);
        if _config is not None and _config.project_root is not None {
            _config.discovered_from_ancestor = (
                _config.project_root.resolve() != base.resolve()
            );
        }
    }
    return _config;
}

impl pin_project_scope(config: JacConfig | None) -> None {
    _config = config;

    _config_explicit = True;

    _config_by_root = {};
}

impl project_scope_is_pinned -> bool {
    return _config_explicit;
}

impl set_config(config: JacConfig | None) -> None {
    _config = config;

    _config_explicit = config is not None;

    _config_by_root = {};
}

impl get_explicit_config -> JacConfig | None {
    return _config if _config_explicit else None;
}

impl get_config_for_dir(start_dir: str) -> JacConfig | None {
    return get_config_for_path(Path(start_dir));
}

impl active_profile_name(config: JacConfig | None) -> str {
    requested = os.environ.get("JAC_PROFILE", "").strip();
    if requested or config is None {
        return requested;
    }
    return config.environment.default_profile or "";
}

impl get_config_for_path(
    start_path: Path, profile: str | None = None, force_discover: bool = False
) -> JacConfig | None {
    explicit = get_explicit_config();
    if explicit is not None {
        project_root = explicit.project_root;
        if project_root is None
            or start_path.resolve().is_relative_to(project_root.resolve()) {
            return explicit;
        }
    }
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, _) = result;
    key = str(project_root);
    cached = _config_by_root.get(key);
    if force_discover
        or key not in _config_by_root
        or (
            profile is not None
            and cached is not None
            and cached.profile_override != profile.strip()
        ) {
        selected = profile
            if profile is not None
            else (cached.profile_override if cached is not None else None);
        _config_by_root[key] = JacConfig.resolve(
            start_path=project_root, profile=selected
        );
        if _config is not None and _config.project_root == project_root {
            _config = _config_by_root[key];
        }
    }
    return _config_by_root[key];
}

impl JacConfig.app(name: str) -> AppConfig | None {
    return self.apps.get(name);
}

impl JacConfig.resolve_app(name: str = "") -> AppConfig {
    names = ", ".join(self.apps.keys());
    if name {
        found = self.apps.get(name);
        if found is None {
            raise ValueError(
                f"Unknown app '{name}'; apps in jac.toml: {names or '(none)'}"
            );
        }
        return found;
    }
    if not self.apps {
        return implicit_app(self.project);
    }
    if self.default_app and self.default_app in self.apps {
        return self.apps[self.default_app];
    }
    if len(self.apps) == 1 {
        return next(iter(self.apps.values()));
    }
    raise ValueError(
        f"Workspace has {len(self.apps)} apps ({names}); pass an app name or "
        "set [project] default-app"
    );
}

impl JacConfig.resolved_kind(app: AppConfig) -> str {
    if app.kind {
        return app.kind;
    }

    root_dir = str(self.project_root) if self.project_root else "";
    entry_file = resolve_entry(self, root_dir, app) if root_dir else "";
    return resolve_app_kind(self, app, entry_file);
}

impl JacConfig.effective_for_app(name: str) -> JacConfig {
    app = self.apps.get(name);
    if app is None {
        raise ValueError(
            f"Unknown app '{name}'; apps in jac.toml: "
            f"{', '.join(self.apps.keys()) or '(none)'}"
        );
    }
    data = copy.deepcopy(self._base_data);
    if app.overlays {
        data = _deep_merge(data, copy.deepcopy(app.overlays));
    }
    cfg = _parse_toml_data(data, self.toml_path);
    cfg.discovered_from_ancestor = self.discovered_from_ancestor;
    cfg.profile_override = self.profile_override;
    if self.toml_path is not None {
        cfg.config_files = [self.toml_path];
    }
    for (layer, arg) in list(self._layers) {
        if layer == "profile" {
            cfg.apply_profile(arg);
        } else {
            cfg.apply_profile_overlay(arg or None);
        }
    }
    return cfg;
}

impl JacConfig.app_for_target(entry_path: str = "") -> AppConfig | None {
    if not self.is_workspace or not self.apps {
        return None;
    }
    if not entry_path {
        return None;
    }
    app = self.app_for_path(os.path.abspath(entry_path));
    return None if app is None or app.implicit else app;
}

impl JacConfig.app_for_path(abs_path: str) -> AppConfig | None {
    abs_path = origin_for_source(abs_path);
    if self.project_root is None {
        return None;
    }
    for app in self.apps.values() {
        if app.contains(str(self.project_root), abs_path) {
            return app;
        }
    }
    return None;
}

impl JacConfig.serving_apps -> list[AppConfig] {
    out: list[AppConfig] = [];
    for app in self.apps.values() {
        spec = kind_spec(self.resolved_kind(app));
        if spec is not None and spec.has_server {
            out.append(app);
        }
    }
    return out;
}

impl JacConfig.default_app.getter -> str {
    return self.project.default_app;
}

impl _deep_merge(base: dict[str, any], `override: dict[str, any]) -> dict[str, any] {
    result = base.copy();
    for (key, value) in `override.items() {
        if key in result
            and isinstance(result[key], dict)
            and isinstance(value, dict) {
            result[key] = _deep_merge(result[key], value);
        } else {
            result[key] = value;
        }
    }
    return result;
}

impl _dependency_doc(config: JacConfig, dev: bool) -> dict[str, any] {
    packages = config.dev_dependencies if dev else config.dependencies;
    out: dict[str, any] = {
        name: dep.to_toml() for (name, dep) in sorted(packages.items())
    };
    pypi: dict[str, any] = dict(
        config.pypi_dev_dependencies if dev else config.pypi_dependencies
    );
    if not dev {
        for (name, info) in config.pypi_git_dependencies.items() {
            pypi[name] = dict(info);
        }
    }
    if pypi {
        out["pypi"] = pypi;
    }
    if not dev {
        for (eco, deps) in config.plugin_dependencies.items() {
            regular = {
                k: v
                for (k, v) in deps.items()
                if k != "dev"
            };
            dev_deps = deps.get("dev") if isinstance(deps.get("dev"), dict) else {};
            table = dict(regular);
            if dev_deps {
                table["dev"] = dict(dev_deps);
            }
            out[eco] = table;
        }
    }
    return out;
}

impl _needs_quoting(key: str) -> bool {
    return not bool(re.`match(r'^[A-Za-z0-9_-]+$', key));
}

impl _quote_key(key: str) -> str {
    if _needs_quoting(key) {
        escaped = key.replace("\\", "\\\\").replace('"', '\\"');
        return f'"{escaped}"';
    }
    return key;
}

impl _toml_is_inline(
    lines: list[str], path: tuple[str, ...], value: dict[str, any]
) -> bool {
    if not value or _toml_find_span(lines, path) is not None {
        return False;
    }
    return all(not isinstance(v, dict) for v in value.values())
        and any(k in INLINE_SPEC_KEYS for k in value);
}

impl _toml_flatten_into(
    view: dict[tuple[str, ...], dict[str, any]],
    path: tuple[str, ...],
    table: dict[str, any],
    lines: list[str]
) {
    flat: dict[str, any] = {};
    for (k, v) in table.items() {
        if isinstance(v, dict) and not _toml_is_inline(lines, path + (k, ), v) {
            _toml_flatten_into(view, path + (k, ), v, lines);
        } else {
            flat[k] = v;
        }
    }
    view[path] = flat;
}

impl _toml_flatten(
    doc: dict[str, any], roots: list[str], lines: list[str]
) -> dict[tuple[str, ...], dict[str, any]] | None {
    view: dict[tuple[str, ...], dict[str, any]] = {};
    for root_key in roots {
        if root_key not in doc {
            continue;
        }
        table = doc[root_key];
        if not isinstance(table, dict) {
            return None;
        }
        _toml_flatten_into(view, (root_key, ), table, lines);
    }
    return view;
}

impl _toml_token_alt(name: str) -> str {
    alts: list[str] = [];
    if name and not _needs_quoting(name) {
        alts.append(re.escape(name));
    }
    basic = name.replace("\\", "\\\\").replace('"', '\\"');
    alts.append(re.escape(f'"{basic}"'));
    if "'" not in name {
        alts.append(re.escape(f"'{name}'"));
    }
    return "(?:" + "|".join(alts) + ")";
}

impl _toml_find_span(
    lines: list[str], parts: tuple[str, ...]
) -> tuple[int, int] | None {
    header_re = re.compile(
        r"^\s*\[\s*"
            + r"\s*\.\s*".join([_toml_token_alt(p) for p in parts])
            + r"\s*\]\s*(?:#.*)?$"
    );
    header = -1;
    for (i, line) in enumerate(lines) {
        if header_re.`match(line) {
            if header >= 0 {
                return None;
            }
            header = i;
        }
    }
    if header < 0 {
        return None;
    }
    end = len(lines);
    for j in range(header + 1, len(lines)) {
        if lines[j].lstrip().startswith("[") {
            end = j;
            break;
        }
    }
    return (header, end);
}

impl _toml_find_key(
    lines: list[str], span: tuple[int, int], key: str
) -> tuple[int, int] | None {
    key_re = re.compile(r"^\s*" + _toml_token_alt(key) + r"\s*=\s*");
    found = -1;
    value_start = -1;
    for i in range(span[0] + 1, span[1]) {
        m = key_re.`match(lines[i]);
        if m {
            if found >= 0 {
                return None;
            }
            found = i;
            value_start = m.end();
        }
    }
    if found < 0 {
        return None;
    }
    return (found, value_start);
}

impl _toml_value_end(line: str, start: int) -> int | None {
    n = len(line);
    if start >= n {
        return None;
    }
    c = line[start];
    if c in ('"', "'") {
        if line[start:start + 3] == c * 3 {
            closing = line.find(c * 3, start + 3);
            return closing + 3 if closing >= 0 else None;
        }
        j = start + 1;
        while j < n {
            if line[j] == "\\" and c == '"' {
                j += 2;
                continue;
            }
            if line[j] == c {
                return j + 1;
            }
            j += 1;
        }
        return None;
    }
    if c in ("[", "{") {
        depth = 0;
        in_str = "";
        j = start;
        while j < n {
            ch = line[j];
            if in_str {
                if ch == "\\" and in_str == '"' {
                    j += 2;
                    continue;
                }
                if ch == in_str {
                    in_str = "";
                }
            } elif ch in ('"', "'") {
                in_str = ch;
            } elif ch in ("[", "{") {
                depth += 1;
            } elif ch in ("]", "}") {
                depth -= 1;
                if depth == 0 {
                    return j + 1;
                }
            }
            j += 1;
        }
        return None;
    }
    j = start;
    while j < n and line[j] != "#" {
        j += 1;
    }
    while j > start and line[j - 1] in (" ", "\t") {
        j -= 1;
    }
    return j if j > start else None;
}

impl _toml_replace_key(
    lines: list[str], parts: tuple[str, ...], key: str, value_text: str
) -> bool {
    span = _toml_find_span(lines, parts);
    if span is None {
        return False;
    }
    hit = _toml_find_key(lines, span, key);
    if hit is None {
        return False;
    }
    (idx, value_start) = hit;
    line = lines[idx];
    value_end = _toml_value_end(line, value_start);
    if value_end is None or not re.`match(r"^\s*(?:#.*)?$", line[value_end:]) {
        return False;
    }
    lines[idx] = line[:value_start] + value_text + line[value_end:];
    return True;
}

impl _toml_delete_key(lines: list[str], parts: tuple[str, ...], key: str) -> bool {
    span = _toml_find_span(lines, parts);
    if span is None {
        return False;
    }
    hit = _toml_find_key(lines, span, key);
    if hit is None {
        return False;
    }
    lines.pop(hit[0]);
    return True;
}

impl _toml_insert_key(
    lines: list[str], parts: tuple[str, ...], key: str, value_text: str
) -> bool {
    span = _toml_find_span(lines, parts);
    if span is None {
        return False;
    }
    at = span[0];
    for j in range(span[0] + 1, span[1]) {
        stripped = lines[j].strip();
        if stripped and not stripped.startswith("#") {
            at = j;
        }
    }
    lines.insert(at + 1, f"{_quote_key(key)} = {value_text}");
    return True;
}

impl _toml_append_section(
    lines: list[str], parts: tuple[str, ...], flat: dict[str, any]
) {
    while lines and not lines[-1].strip() {
        lines.pop();
    }
    if lines {
        lines.append("");
    }
    header = ".".join([_quote_key(p) for p in parts]);
    lines.append(f"[{header}]");
    for (k, v) in flat.items() {
        lines.append(f"{_quote_key(k)} = {toml_value(v)}");
    }
    lines.append("");
}

impl _toml_remove_section(lines: list[str], parts: tuple[str, ...]) -> bool {
    span = _toml_find_span(lines, parts);
    if span is None {
        return False;
    }
    for _ in range(span[1] - span[0]) {
        lines.pop(span[0]);
    }
    return True;
}

impl offline_mode -> bool {
    config = get_config();
    return config is not None and config.network.offline;
}

impl use_system_toolchains -> bool {
    config = get_config();
    return config is None or config.toolchains.system;
}
