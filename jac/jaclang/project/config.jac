import os;
import re;
import sys;
import tomllib;
import from pathlib { Path }
import from jaclang.project.apps { AppConfig, implicit_app, parse_apps }
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

obj PackageIncludeConfig {
    has packages: list[str] = [],
        data: dict[str, list[str]] = {};
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
        entry_point: str = "main.jac",
        kind: str = "",
        default_app: str = "",
        urls: dict[str, str] = {},
        `include: PackageIncludeConfig = PackageIncludeConfig();
}

obj RunConfig {
    has session: str = "",
        main: bool = True,
        cache: bool = True,
        diagnostics: str = "error";
}

obj NativeBuildConfig {
    has opt_level: int = 2,
        dump_ir: str = "",
        target: str = "",
        debug: bool = False,
        rc_debug_codegen: bool = False;
}

obj GcEnforceConfig {
    has modules: list[str] = [],
        grandfathered: list[str] = [];
}

obj GcConfig {
    has `default: str = "cycles",
        enforce: GcEnforceConfig = GcEnforceConfig();
}

obj BuildConfig {
    has dir: str = ".jac",
        default_codespace: str = "native",
        native_closure_cap: int = 256,
        native: NativeBuildConfig = NativeBuildConfig();
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
}

obj ServeWorkersConfig {
    has count: str = "1",
        threads: str = "auto",
        max_requests: int = 0,
        max_requests_jitter: int = 0,
        request_timeout: float = 0.0,
        boot_timeout: float = 120.0,
        hang_timeout: float = 30.0;
}

obj ServeTlsConfig {
    has certfile: str = "",
        keyfile: str = "",
        ca_certs: str = "",
        min_version: str = "1.2";
}

obj ServeProxyConfig {
    has trusted: list[str] = [];
}

obj ServeLimitsConfig {
    has max_connections: int = 0,
        backlog: int = 2048,
        max_body_bytes: int = 104857600,
        max_header_bytes: int = 65536,
        max_header_count: int = 100,
        max_request_line_bytes: int = 8192,
        multipart_spool_bytes: int = 1048576;
}

obj ServeTimeoutsConfig {
    has header: float = 30.0,
        body: float = 60.0,
        keepalive: float = 65.0,
        drain: float = 10.0,
        close: float = 5.0;
}

obj ServeAccessLogConfig {
    has enabled: bool = True,
        format: str = "text",
        suppress_health_checks: bool = False;
}

obj ServeCompressionConfig {
    has enabled: bool = True,
        min_bytes: int = 1024,
        level: int = 4;
}

obj ServeWebSocketConfig {
    has allowed_origins: list[str] = [],
        max_message_bytes: int = 0,
        ping_interval: float = 20.0,
        ping_timeout: float = 20.0;
}

obj ServeAuthConfig {
    has secret: str = "",
        algorithm: str = "HS256",
        token_ttl_days: int = 7,
        password_hash_cost: int = 14;
}

obj ServeConfig {
    has host: str = "0.0.0.0",
        port: int = 8000,
        session: str = "",
        main: bool = True,
        docs_enabled: bool = True,
        graph_enabled: bool = True,
        cors_origins: list[str] = ["*"],
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
        auth: ServeAuthConfig = ServeAuthConfig();
}

obj FormatConfig {
    has outfile: str = "";
}

obj LintConfig {
    has select: list[str] = ["default"],
        ignore: list[str] = [],
        exclude: list[str] = [];
}

obj CheckConfig {
    has print_errs: bool = True,
        lint: LintConfig = LintConfig(),
        suppress: list[str] = [],
        suppress_categories: list[str] = [],
        enforce_access: bool = False,
        warn_native_seams: bool = True;
}

obj DotConfig {
    has depth: int = -1,
        traverse: bool = False,
        bfs: bool = False,
        edge_limit: int = 512,
        node_limit: int = 512,
        format: str = "dot";
}

obj CacheConfig {
    has enabled: bool = True,
        dir: str = "cache";
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
}

obj EnvironmentConfig {
    has default_profile: str = "";
}

obj ClientErrorsConfig {
    has verbose: bool = False;
}

obj ClientConfig {
    has framework: str = "react";
}

obj DevConfig {
    has jaclang_source: str = "",
        jobs: str = "",
        test_jobs: str = "",
        check_jobs: str = "",
        fmt_jobs: str = "";
}

def interpolate_env_vars(value: str) -> str;

def find_project_root(start: Path | None = None) -> tuple[Path, Path] | None;

def is_in_project -> bool;

def serialize_toml(data: dict[str, any], prefix: str = "") -> str;

def toml_value(value: any) -> str;

obj JacConfig {
    has project: ProjectConfig = ProjectConfig(),
        run: RunConfig = RunConfig(),
        build: BuildConfig = BuildConfig(),
        gc: GcConfig = GcConfig(),
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
        dependencies: dict[str, str] = {},
        dev_dependencies: dict[str, str] = {},
        git_dependencies: dict[str, dict[str, str]] = {},
        plugin_dependencies: dict[str, dict[str, any]] = {},
        scripts: dict[str, str] = {},
        plugins: dict[str, dict[str, any]] = {},
        environments: dict[str, dict[str, any]] = {},
        project_root: Path | None = None,
        toml_path: Path | None = None,
        config_files: list[Path] | None = None,
        active_profile: str = "",
        _raw_data: dict[str, any] = {},
        entrypoints: dict[str, dict[str, str]] = {},
        optional_dependencies: dict[str, dict[str, str]] = {},
        discovered_from_ancestor: bool = False,
        apps: dict[str, AppConfig] = {},
        is_workspace: bool = False,
        _base_data: dict[str, any] = {},
        _layers: list[tuple[str, str]] = [];

    has default_app: str { getter; }

    static def discover(
        start_path: Path | None = None, profile: str | None = None
    ) -> JacConfig | None;

    static def load(toml_path: Path) -> JacConfig;
    static def from_toml_str(
        toml_str: str, toml_path: Path | None = None
    ) -> JacConfig;

    def _section_map -> dict[
        str,
        RunConfig
            | BuildConfig
            | TestConfig
            | ServeConfig
            | FormatConfig
            | DotConfig
            | CacheConfig
            | EnvironmentConfig
            | ClientConfig
    ];

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
        name: str, version: str, dev: bool = False, dep_type: str = "python"
    ) -> None;

    def remove_dependency(
        name: str, dev: bool = False, dep_type: str = "python"
    ) -> bool;

    def merge_from_toml_file(toml_path: Path) -> None;
    def app(name: str) -> AppConfig | None;
    def resolve_app(name: str = "") -> AppConfig;
    def resolved_kind(app: AppConfig) -> str;
    def effective_for_app(name: str) -> JacConfig;
    def app_for_path(abs_path: str) -> AppConfig | None;
    def app_for_target(entry_path: str = "") -> AppConfig | None;
    def serving_apps -> list[AppConfig];
    def owner_app_for_path(abs_path: str) -> tuple[AppConfig | None, bool];
}

def _parse_toml_data(data: dict[str, any], toml_path: Path | None = None) -> JacConfig;

def _parse_persons(raw: list[any]) -> list[PersonConfig];

def _parse_include(raw: dict[str, any]) -> PackageIncludeConfig;

def _interpolate_recursive(`obj: any) -> any;

glob _config: JacConfig | None = None,
     _config_explicit: bool = False,
     _config_by_root: dict[str, JacConfig | None] = {};

def get_config(
    start_path: Path | None = None, force_discover: bool = False
) -> JacConfig | None;

def set_config(config: JacConfig | None) -> None;

def pin_project_scope(config: JacConfig | None) -> None;

def project_scope_is_pinned -> bool;

def get_explicit_config -> JacConfig | None;

def get_config_for_path(start_path: Path) -> JacConfig | None;

def get_config_for_dir(start_dir: str) -> JacConfig | None;
