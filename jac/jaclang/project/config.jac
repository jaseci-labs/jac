import copy;
import os;
import re;
import sys;
import tomllib;
import from pathlib { Path }

glob CAPABILITY_SECTIONS: tuple[str, ...] = (
         "byllm",
         "scale",
         "client",
         "mcp",
         "desktop"
     );

obj PersonConfig {
    has name: str = "",
        email: str = "";
}

glob RUN_KEYS: list[str] = ["session", "main", "cache", "diagnostics"],
     NATIVE_KEYS: list[str] = ["link_mode", "require", "target", "opt", "debug", "threads"],
     MEMORY_KEYS: list[str] = ["profile", "enforce", "exempt"],
     MEMORY_PROFILES: list[str] = ["managed", "rc", "nogc"],
     PLACEMENT_KEYS: list[str] = ["default", "pins"],
     PLACEMENT_ALIASES: dict[str, str] = {"sv": "server", "na": "native", "server": "server", "native": "native"},
     BUILD_KEYS: list[str] = ["dir"],
     BUILD_RETIRED: dict[str, str] = {
         "default_codespace": "[placement] default",
         "native": "[native]",
         "native_closure_cap": "nothing: a module's whole import closure is always judged for native placement"
     },
     TEST_KEYS: list[str] = [
         "directory",
         "directories",
         "isolate",
         "serial",
         "filter",
         "verbose",
         "fail_fast",
         "max_failures"
     ],
     PROJECT_KEYS: list[str] = [
         "name",
         "version",
         "description",
         "authors",
         "maintainers",
         "license",
         "readme",
         "keywords",
         "classifiers",
         "requires-python",
         "jac-version",
         "entry-point",
         "kind",
         "default-app",
         "exports",
         "urls",
         "include"
     ],
     INCLUDE_KEYS: list[str] = ["packages", "data"],
     SERVE_KEYS: list[str] = [
         "host",
         "port",
         "session",
         "main",
         "docs_enabled",
         "graph_enabled",
         "cors_origins",
         "public_origin",
         "on_conflict",
         "conflict_max_attempts",
         "conflict_backoff_ms",
         "workers",
         "tls",
         "proxy",
         "limits",
         "timeouts",
         "access_log",
         "compression",
         "websocket",
         "auth"
     ],
     SERVE_CONFLICT_MODES: list[str] = ["retry", "fail"],
     WORKERS_KEYS: list[str] = [
         "count",
         "threads",
         "max_requests",
         "max_requests_jitter",
         "request_timeout",
         "boot_timeout",
         "hang_timeout"
     ],
     TLS_KEYS: list[str] = ["certfile", "keyfile", "ca_certs", "min_version"],
     PROXY_KEYS: list[str] = ["trusted"],
     LIMITS_KEYS: list[str] = [
         "max_connections",
         "backlog",
         "max_body_bytes",
         "max_header_bytes",
         "max_header_count",
         "max_request_line_bytes",
         "multipart_spool_bytes"
     ],
     TIMEOUTS_KEYS: list[str] = ["header", "body", "keepalive", "drain", "close"],
     ACCESS_LOG_KEYS: list[str] = ["enabled", "format", "suppress_health_checks"],
     COMPRESSION_KEYS: list[str] = ["enabled", "min_bytes", "level"],
     WEBSOCKET_KEYS: list[str] = [
         "allowed_origins",
         "max_message_bytes",
         "ping_interval",
         "ping_timeout"
     ],
     FORMAT_KEYS: list[str] = ["outfile"],
     LINT_KEYS: list[str] = ["select", "ignore", "exclude"],
     CHECK_KEYS: list[str] = [
         "print_errs",
         "lint",
         "exclude",
         "suppress",
         "suppress_categories",
         "enforce_access",
         "warn_native_seams",
         "untyped-external"
     ],
     DOT_KEYS: list[str] = ["depth", "traverse", "bfs", "edge_limit", "node_limit", "format"],
     CACHE_KEYS: list[str] = ["enabled", "dir"],
     STORAGE_KEYS: list[str] = [
         "type",
         "base_path",
         "create_dirs",
         "bucket",
         "prefix",
         "region",
         "endpoint_url",
         "project_id",
         "public_read"
     ],
     ENVIRONMENT_KEYS: list[str] = ["default_profile"],
     CLIENT_ERRORS_KEYS: list[str] = ["verbose"],
     DATABASE_KEYS: list[str] = ["indexes", "retention_days", "postgres_dist", "postgres_version"],
     NETWORK_KEYS: list[str] = ["offline"],
     TOOLCHAINS_KEYS: list[str] = ["system"],
     DEV_KEYS: list[str] = [
         "jaclang_source",
         "exact",
         "pod_binary",
         "jobs",
         "test_jobs",
         "check_jobs",
         "fmt_jobs"
     ],
     RETIRED_SECTIONS: dict[str, str] = {
         "gc": "the [gc] section was retired; use [memory] profile / enforce / exempt",
         "arch": "[arch] was removed from jac.toml: an archwire.jac seals the directory it sits in. Delete the [arch] table and run `jac arch init --strip` in each directory it closed"
     };

def _toml_key(key: str) -> str;

def _parse_person(t: TomlTable, key: str, index: int, item: any) -> PersonConfig;

def _parse_persons_at(t: TomlTable, key: str) -> list[PersonConfig];

obj PackageIncludeConfig {
    has packages: list[str] = [],
        data: dict[str, list[str]] = {};

    def apply(t: TomlTable);
}

obj ProjectConfig {
    has name: str = "",
        version: str = "0.1.0",
        description: str = "",
        authors: list[PersonConfig] = [],
        maintainers: list[PersonConfig] = [],
        license: str = "",
        readme: str = "README.md",
        keywords: list[str] = [],
        classifiers: list[str] = [],
        requires_python: str = "",
        jac_version: str = "",
        entry_point: str = "main",
        entry_point_declared: bool = False,
        kind: str = "",
        default_app: str = "",
        exports: list[str] = [],
        urls: dict[str, str] = {},
        `include: PackageIncludeConfig = PackageIncludeConfig();

    def apply(t: TomlTable);
}

obj RunConfig {
    has session: str = "",
        main: bool = True,
        cache: bool = True,
        diagnostics: str = "error";

    def apply(t: TomlTable);
}

obj NativeConfig {
    has link_mode: str = "objects",
        require: list[str] = [],
        target: str = "",
        opt: int = 2,
        debug: bool = False,
        threads: int = 4;

    def apply(t: TomlTable);
}

obj MemoryConfig {
    has profile: str = "managed",
        enforce: list[str] = [],
        exempt: list[str] = [];

    def gc_mode -> str;
    def apply(t: TomlTable);
}

obj PlacementConfig {
    has default_codespace: str = "native",
        pins: dict[str, str] = {};

    def apply(t: TomlTable);
}

obj BuildConfig {
    has dir: str = ".jac";

    def apply(t: TomlTable);
}

obj TestConfig {
    has directory: str = "",
        directories: list[str] = [],
        isolate: list[str] = [],
        serial: list[str] = [],
        filter: str = "",
        verbose: bool = False,
        fail_fast: bool = False,
        max_failures: int = 0;

    def apply(t: TomlTable);
}

obj ServeWorkersConfig {
    has count: str = "",
        threads: str = "auto",
        max_requests: int = 0,
        max_requests_jitter: int = 0,
        request_timeout: float = 0.0,
        boot_timeout: float = 120.0,
        hang_timeout: float = 30.0;

    def apply(t: TomlTable);
}

obj ServeTlsConfig {
    has certfile: str = "",
        keyfile: str = "",
        ca_certs: str = "",
        min_version: str = "1.2";

    def apply(t: TomlTable);
}

obj ServeProxyConfig {
    has trusted: list[str] = [];

    def apply(t: TomlTable);
}

obj ServeLimitsConfig {
    has max_connections: int = 0,
        backlog: int = 2048,
        max_body_bytes: int = 104857600,
        max_header_bytes: int = 65536,
        max_header_count: int = 100,
        max_request_line_bytes: int = 8192,
        multipart_spool_bytes: int = 1048576;

    def apply(t: TomlTable);
}

obj ServeTimeoutsConfig {
    has header: float = 30.0,
        body: float = 60.0,
        keepalive: float = 65.0,
        drain: float = 10.0,
        close: float = 5.0;

    def apply(t: TomlTable);
}

obj ServeAccessLogConfig {
    has enabled: bool = True,
        format: str = "text",
        suppress_health_checks: bool = False;

    def apply(t: TomlTable);
}

obj ServeCompressionConfig {
    has enabled: bool = True,
        min_bytes: int = 1024,
        level: int = 4;

    def apply(t: TomlTable);
}

obj ServeWebSocketConfig {
    has allowed_origins: list[str] = [],
        max_message_bytes: int = 0,
        ping_interval: float = 20.0,
        ping_timeout: float = 20.0;

    def apply(t: TomlTable);
}

obj ServeConfig {
    has host: str = "0.0.0.0",
        port: int = 8000,
        session: str = "",
        main: bool = True,
        docs_enabled: bool = True,
        graph_enabled: bool = True,
        cors_origins: list[str] = ["*"],
        public_origin: str = "",
        on_conflict: str = "retry",
        conflict_max_attempts: int = 5,
        conflict_backoff_ms: int = 0,
        workers: ServeWorkersConfig = ServeWorkersConfig(),
        tls: ServeTlsConfig = ServeTlsConfig(),
        proxy: ServeProxyConfig = ServeProxyConfig(),
        limits: ServeLimitsConfig = ServeLimitsConfig(),
        timeouts: ServeTimeoutsConfig = ServeTimeoutsConfig(),
        access_log: ServeAccessLogConfig = ServeAccessLogConfig(),
        compression: ServeCompressionConfig = ServeCompressionConfig(),
        websocket: ServeWebSocketConfig = ServeWebSocketConfig(),
        auth: dict[str, any] = {};

    def apply(t: TomlTable);
}

obj FormatConfig {
    has outfile: str = "";

    def apply(t: TomlTable);
}

obj LintConfig {
    has select: list[str] = ["default"],
        ignore: list[str] = [],
        exclude: list[str] = [];

    def apply(t: TomlTable);
}

obj CheckConfig {
    has print_errs: bool = True,
        lint: LintConfig = LintConfig(),
        exclude: list[str] = [],
        suppress: list[str] = [],
        suppress_categories: list[str] = [],
        enforce_access: bool = False,
        warn_native_seams: bool = True,
        untyped_external: str = "warning";

    def apply(t: TomlTable);
}

obj DotConfig {
    has depth: int = -1,
        traverse: bool = False,
        bfs: bool = False,
        edge_limit: int = 512,
        node_limit: int = 512,
        format: str = "dot";

    def apply(t: TomlTable);
}

obj CacheConfig {
    has enabled: bool = True,
        dir: str = "cache";

    def apply(t: TomlTable);
}

obj StorageConfig {
    has storage_type: str = "local",
        base_path: str = "./storage",
        create_dirs: bool = True,
        bucket: str = "",
        prefix: str = "",
        region: str = "us-east-1",
        endpoint_url: (str | None) = None,
        project_id: str = "",
        public_read: bool = False;

    def apply(t: TomlTable);
}

obj EnvironmentConfig {
    has default_profile: str = "";

    def apply(t: TomlTable);
}

obj ClientErrorsConfig {
    has verbose: bool = False;

    def apply(t: TomlTable);
}

obj ClientConfig {
    has framework: str = "react",
        paths: dict[str, str] = {};

    def apply(t: TomlTable);
}

obj DatabaseConfig {
    has indexes: dict[str, list[str]] = {},
        retention_days: int = 0,
        postgres_dist: str = "",
        postgres_version: str = "";

    def apply(t: TomlTable);
}

obj NetworkConfig {
    has offline: bool = False;

    def apply(t: TomlTable);
}

obj ToolchainsConfig {
    has system: bool = True;

    def apply(t: TomlTable);
}

obj DevConfig {
    has jaclang_source: str = "",
        exact: bool = False,
        pod_binary: str = "",
        jobs: str = "",
        test_jobs: str = "",
        check_jobs: str = "",
        fmt_jobs: str = "";

    def apply(t: TomlTable);
}

obj UnresolvedRef {
    has path: str = "",
        var: str = "",
        raw: str = "",
        required: bool = False,
        message: str = "",
        unsupported: bool = False,
        form: str = "";

    def describe -> str;
    def reason -> str;
}

def interpolate_env_vars(
    value: str,
    environ: dict[str, str] | None = None,
    sink: list[UnresolvedRef] | None = None
) -> str;

def _env_reference(body: str, environ: dict[str, str]) -> tuple[str, UnresolvedRef | None];

def resolve_env_refs(
    data: any, environ: dict[str, str] | None = None, path: str = ""
) -> tuple[any, list[UnresolvedRef]];

def _resolve_env_into(
    item: any, at: str, environ: dict[str, str] | None, refs: list[UnresolvedRef]
) -> any;

def report_env_findings(
    refs: list[UnresolvedRef], context: str, hint: str = ""
) -> None;

def find_project_root(start: Path | None = None) -> tuple[Path, Path] | None;

def is_in_project -> bool;

def serialize_toml(data: dict[str, any], prefix: str = "") -> str;

def toml_value(value: any) -> str;

def toml_minimal_update(
    text: str, old_doc: dict[str, any], new_doc: dict[str, any], roots: list[str]
) -> str | None;

obj JacConfig {
    has persistence: PersistenceConfig = PersistenceConfig(),
        project: ProjectConfig = ProjectConfig(),
        run: RunConfig = RunConfig(),
        build: BuildConfig = BuildConfig(),
        native: NativeConfig = NativeConfig(),
        memory: MemoryConfig = MemoryConfig(),
        placement: PlacementConfig = PlacementConfig(),
        `test: TestConfig = TestConfig(),
        serve: ServeConfig = ServeConfig(),
        format: FormatConfig = FormatConfig(),
        check: CheckConfig = CheckConfig(),
        dot: DotConfig = DotConfig(),
        cache: CacheConfig = CacheConfig(),
        storage: StorageConfig = StorageConfig(),
        environment: EnvironmentConfig = EnvironmentConfig(),
        client_errors: ClientErrorsConfig = ClientErrorsConfig(),
        client: ClientConfig = ClientConfig(),
        dev: DevConfig = DevConfig(),
        database: DatabaseConfig = DatabaseConfig(),
        network: NetworkConfig = NetworkConfig(),
        toolchains: ToolchainsConfig = ToolchainsConfig(),
        dependencies: dict[str, PackageDep] = {},
        dev_dependencies: dict[str, PackageDep] = {},
        pypi_dependencies: dict[str, str] = {},
        pypi_dev_dependencies: dict[str, str] = {},
        pypi_git_dependencies: dict[str, dict[str, str]] = {},
        plugin_dependencies: dict[str, dict[str, any]] = {},
        registries: dict[str, str] = {},
        scripts: dict[str, str] = {},
        plugins: dict[str, dict[str, any]] = {},
        environments: dict[str, dict[str, any]] = {},
        project_root: Path | None = None,
        toml_path: Path | None = None,
        config_files: list[Path] | None = None,
        active_profile: str = "",
        profile_override: str | None = None,
        _raw_data: dict[str, any] = {},
        entrypoints: dict[str, dict[str, str]] = {},
        optional_dependencies: dict[str, dict[str, str]] = {},
        discovered_from_ancestor: bool = False,
        apps: dict[str, AppConfig] = {},
        is_workspace: bool = False,
        _base_data: dict[str, any] = {},
        _layers: list[tuple[str, str]] = [],
        unresolved: list[UnresolvedRef] = [];

    has default_app: str { getter; }

    static def discover(
        start_path: Path | None = None, profile: str | None = None
    ) -> JacConfig | None;

    static def resolve(
        start_path: Path | None = None, profile: str | None = None
    ) -> JacConfig | None;

    static def load(toml_path: Path) -> JacConfig;
    static def from_toml_str(
        toml_str: str, toml_path: Path | None = None
    ) -> JacConfig;

    def apply_profile(profile_name: str, _visited: set[str] | None = None) -> None;
    def apply_profile_overlay(profile_name: str | None = None) -> None;
    def get_plugin_deps(dep_type: str) -> dict[str, any];
    def get_plugin_config(plugin_name: str) -> dict[str, any];
    def get_section(name: str) -> dict[str, any] | None;
    def get_build_dir -> Path;
    def get_cache_dir -> Path;
    def get_venv_dir -> Path;
    def get_data_dir -> Path;
    def get_client_dir -> Path;
    def is_valid -> bool;
    def save -> None;
    def persist_doc(doc: dict[str, any]) -> None;
    def _write_toml_text(text: str) -> None;
    def add_dependency(
        name: str, version: str, dev: bool = False, dep_type: str = "pypi"
    ) -> None;

    def remove_dependency(
        name: str, dev: bool = False, dep_type: str = "pypi"
    ) -> bool;

    def merge_dependency_tables(
        data: dict[str, any], section_prefix: str = ""
    ) -> None;

    def merge_from_toml_file(toml_path: Path) -> None;
    def merge_apps_table(apps_table: dict[str, any]) -> None;
    def app(name: str) -> AppConfig | None;
    def resolve_app(name: str = "") -> AppConfig;
    def resolved_kind(app: AppConfig) -> str;
    def effective_for_app(name: str) -> JacConfig;
    def app_for_path(abs_path: str) -> AppConfig | None;
    def app_for_target(entry_path: str = "") -> AppConfig | None;
    def serving_apps -> list[AppConfig];
}

def _parse_toml_data(data: dict[str, any], toml_path: Path | None = None) -> JacConfig;

def _origin_of(toml_path: Path | None) -> str;

def _apply_sections(cfg: JacConfig, t: TomlTable);

def _apply_capabilities(cfg: JacConfig, t: TomlTable);

def _apply_named_tables(cfg: JacConfig, t: TomlTable);

def _check_retired(t: TomlTable);

def _deep_merge(base: dict[str, any], `override: dict[str, any]) -> dict[str, any];

def _interpolate_recursive(`obj: any) -> any;

glob _config: JacConfig | None = None,
     _config_explicit: bool = False,
     _config_by_root: dict[str, JacConfig | None] = {};

def get_config(
    start_path: Path | None = None,
    force_discover: bool = False,
    profile: str | None = None
) -> JacConfig | None;

def set_config(config: JacConfig | None) -> None;

def pin_project_scope(config: JacConfig | None) -> None;

def project_scope_is_pinned -> bool;

def get_explicit_config -> JacConfig | None;

def get_config_for_path(
    start_path: Path, profile: str | None = None, force_discover: bool = False
) -> JacConfig | None;

def get_config_for_dir(start_dir: str) -> JacConfig | None;

def offline_mode -> bool;

def use_system_toolchains -> bool;

def active_profile_name(config: JacConfig | None) -> str;
