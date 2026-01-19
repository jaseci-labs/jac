"""Implementation of Jac project configuration module."""

# ===============================================================================
# Environment Variable Interpolation Implementation
# ===============================================================================
impl interpolate_env_vars(
    value: str
) -> str {
    import os;
    import re;
    if not isinstance(value, str) {
        return value;
    }
    # Pattern to match ${VAR}, ${VAR:-default}, ${VAR:?error}
    pattern = r"\$\{([^}:]+)(?:(:[-?])([^}]*))?\}";
    def replace_env_var(match: re.Match) -> str {
        var_name = match.group(1);
        operator = match.group(2);
        operand = match.group(3) or "";

        env_value = os.environ.get(var_name);

        if env_value is not None {
            return env_value;
        }

        if operator == ":-" {
            return operand;
        } elif operator == ":?" {
            raise ValueError(f"Environment variable {var_name} is required: {operand}") ;
        } else {
            raise ValueError(f"Environment variable {var_name} is not set") ;
        }
    }
    return re.sub(pattern, replace_env_var, value);
}

# ===============================================================================
# Project Discovery Implementation
# ===============================================================================
impl find_project_root(
    start: Path | None = None
) -> tuple[Path, Path] | None {
    import from pathlib { Path }
    if start is None {
        start = Path.cwd();
    }
    current = start.resolve();
    while current != current.parent {
        toml_path = current / "jac.toml";
        if toml_path.exists() {
            return (current, toml_path);
        }
        current = current.parent;
    }
    toml_path = current / "jac.toml";
    if toml_path.exists() {
        return (current, toml_path);
    }
    return None;
}

impl is_in_project -> bool {
    return find_project_root() is not None;
}

# ===============================================================================
# JacConfig Implementation
# ===============================================================================
impl JacConfig.discover(
    start_path: Path | None = None
) -> JacConfig | None {
    import from pathlib { Path }
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, toml_path) = result;
    return JacConfig.load(toml_path);
}

impl JacConfig.load(toml_path: Path) -> JacConfig {
    import tomllib;
    if not toml_path.exists() {
        raise FileNotFoundError(f"Configuration file not found: {toml_path}") ;
    }
    with open(toml_path, "rb") as f {
        data = tomllib.load(f);
    }
    config = _parse_toml_data(data, toml_path);
    config.apply_env_interpolation();
    return config;
}

impl JacConfig.from_toml_str(toml_str: str, toml_path: Path | None = None) -> JacConfig {
    import tomllib;
    data = tomllib.loads(toml_str);
    return _parse_toml_data(data, toml_path);
}

impl JacConfig.apply_env_interpolation -> None {
    self.plugins = _interpolate_recursive(self.plugins);
    self.plugin_dependencies = _interpolate_recursive(self.plugin_dependencies);
    self.scripts = _interpolate_recursive(self.scripts);
    self.environments = _interpolate_recursive(self.environments);
}

impl JacConfig.apply_cli_overrides(args: dict[(str, Any)]) -> None {
    if args.get("session") {
        self.run.session = args["session"];
    }
    if "main" in args {
        self.run.main = args["main"];
    }
    if "cache" in args {
        self.run.cache = args["cache"];
    }
    if args.get("port") {
        self.serve.port = args["port"];
    }
    if args.get("directory") {
        self.test.directory = args["directory"];
    }
    if "verbose" in args {
        self.test.verbose = args["verbose"];
    }
    if args.get("xit") {
        self.test.fail_fast = args["xit"];
    }
    if args.get("maxfail") {
        self.test.max_failures = args["maxfail"];
    }
}

impl JacConfig.apply_profile(profile_name: str) -> None {
    if profile_name not in self.environments {
        return;
    }
    profile = self.environments[profile_name];
    if "inherits" in profile {
        parent_name = profile["inherits"];
        if parent_name in self.environments {
            self.apply_profile(parent_name);
        }
    }
    def deep_merge(base: dict, override: dict) -> dict {
        result = base.copy();
        for (key, value) in override.items() {
            if key in result
            and isinstance(result[key], dict)
            and isinstance(value, dict) {
                result[key] = deep_merge(result[key], value);
            } else {
                result[key] = value;
            }
        }
        return result;
    }
    if "run" in profile {
        for (key, value) in profile["run"].items() {
            if hasattr(self.run, key) {
                setattr(self.run, key, value);
            }
        }
    }
    if "serve" in profile {
        for (key, value) in profile["serve"].items() {
            if hasattr(self.serve, key) {
                setattr(self.serve, key, value);
            }
        }
    }
    if "test" in profile {
        for (key, value) in profile["test"].items() {
            if hasattr(self.test, key) {
                setattr(self.test, key, value);
            }
        }
    }
    if "plugins" in profile {
        self.plugins = deep_merge(self.plugins, profile["plugins"]);
    }
}

impl JacConfig.get_plugin_deps(dep_type: str) -> dict[str, Any] {
    deps = self.plugin_dependencies.get(dep_type, {});
    # Filter out the "dev" key which holds dev dependencies
    return {
        k: v
        for (k, v) in deps.items()
        if k != "dev"
    };
}

impl JacConfig.get_plugin_config(plugin_name: str) -> dict[str, Any] {
    return self.plugins.get(plugin_name, {});
}

"""Get the base build directory for all artifacts."""
impl JacConfig.get_build_dir -> Path {
    import from pathlib { Path }
    base = self.project_root or Path.cwd();
    return base / self.build.dir;
}

"""Get the bytecode cache directory (.jac/cache)."""
impl JacConfig.get_cache_dir -> Path {
    return self.get_build_dir() / "cache";
}

"""Get the Python packages directory (.jac/packages)."""
impl JacConfig.get_packages_dir -> Path {
    return self.get_build_dir() / "packages";
}

"""Get the data directory for runtime artifacts (.jac/data)."""
impl JacConfig.get_data_dir -> Path {
    return self.get_build_dir() / "data";
}

"""Get the client build directory (.jac/client)."""
impl JacConfig.get_client_dir -> Path {
    return self.get_build_dir() / "client";
}

impl JacConfig.is_valid -> bool {
    return self.toml_path is not None and self.toml_path.exists();
}

impl JacConfig.save -> None {
    if self.toml_path is None {
        raise ValueError("No toml_path set, cannot save configuration") ;
    }
    # Load existing data or start fresh
    if self.toml_path.exists() {
        with open(self.toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } else {
        doc = {};
    }
    # Update Python dependencies
    if "dependencies" not in doc {
        doc["dependencies"] = {};
    }
    for (name, version) in self.dependencies.items() {
        doc["dependencies"][name] = version;
    }
    if self.dev_dependencies {
        if "dev-dependencies" not in doc {
            doc["dev-dependencies"] = {};
        }
        for (name, version) in self.dev_dependencies.items() {
            doc["dev-dependencies"][name] = version;
        }
    }
    # Update plugin dependencies (npm, etc.)
    # Replace the entire plugin dep section to handle removals
    for (dep_type, deps) in self.plugin_dependencies.items() {
        if dep_type not in doc["dependencies"] {
            doc["dependencies"][dep_type] = {};
        }
        # Handle dev deps separately
        dev_deps = deps.get("dev", {}) if isinstance(deps.get("dev"), dict) else {};
        regular_deps = {
            k: v
            for (k, v) in deps.items()
            if k != "dev"
        };
        # Replace the entire section (to handle removals)
        doc["dependencies"][dep_type] = regular_deps.copy();
        if dev_deps {
            doc["dependencies"][dep_type]["dev"] = dev_deps;
        }
    }
    # Update plugins configuration
    # Always update plugins section if it exists in doc or we have data to write
    has_existing_plugins = "plugins" in doc;
    needs_update = self.plugins or self.plugins_config.disabled is not None;
    if has_existing_plugins or needs_update {
        if "plugins" not in doc {
            doc["plugins"] = {};
        }
        for (plugin_name, plugin_config) in self.plugins.items() {
            doc["plugins"][plugin_name] = plugin_config;
        }
        # Persist disabled plugins list - handle both setting and clearing
        if self.plugins_config.disabled {
            doc["plugins"]["disabled"] = self.plugins_config.disabled;
        } elif "disabled" in doc.get("plugins", {}) {
            del doc["plugins"]["disabled"] ;  # Remove if empty
        }
    }
    # Write using simple TOML serializer
    with open(self.toml_path, "w") as f {
        f.write(_serialize_toml(doc));
    }
}

# Check if a TOML key needs quoting (bare keys can only contain A-Za-z0-9_-)
def _needs_quoting(
    key: str
) -> bool {
    import re;
    return not bool(re.match(r'^[A-Za-z0-9_-]+$', key));
}

# Quote a TOML key if necessary
def _quote_key(key: str) -> str {
    if _needs_quoting(key) {
        escaped = key.replace("\\", "\\\\").replace('"', '\\"');
        return f'"{escaped}"';
    }
    return key;
}

# Simple TOML serializer (does not preserve comments)
def _serialize_toml(
    data: dict, prefix: str = ""
) -> str {
    lines: list[str] = [];
    tables: list[tuple[str, dict]] = [];

    # First pass: write simple key-value pairs
    for (key, value) in data.items() {
        if isinstance(value, dict) {
            # Collect tables for later
            table_key = f"{prefix}{key}" if prefix else key;
            tables.append((table_key, value));
        } else {
            lines.append(f"{_quote_key(key)} = {_toml_value(value)}");
        }
    }

    # Add blank line before tables if we had values
    if lines and tables {
        lines.append("");
    }

    # Second pass: write tables
    for (table_key, table_data) in tables {
        # Check if this is a nested table or has nested tables
        has_nested = any(isinstance(v, dict) for v in table_data.values());
        if has_nested {
            # Write nested tables with dotted keys
            simple_values: list[tuple[str, Any]] = [];
            nested_tables: list[tuple[str, dict]] = [];
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
                    lines.append(f"{_quote_key(k)} = {_toml_value(v)}");
                }
                lines.append("");
            }
            for (nested_key, nested_data) in nested_tables {
                nested_content = _serialize_toml(
                    {nested_key: nested_data}, f"{table_key}."
                );
                lines.append(nested_content);
            }
        } else {
            lines.append(f"[{table_key}]");
            for (k, v) in table_data.items() {
                lines.append(f"{_quote_key(k)} = {_toml_value(v)}");
            }
            lines.append("");
        }
    }

    return "\n".join(lines);
}

# Convert a Python value to TOML representation
def _toml_value(value: Any) -> str {
    if isinstance(value, bool) {
        return "true" if value else "false";
    } elif isinstance(value, int) {
        return str(value);
    } elif isinstance(value, float) {
        return str(value);
    } elif isinstance(value, str) {
        # Escape quotes and backslashes
        escaped = value.replace("\\", "\\\\").replace('"', '\\"');
        return f'"{escaped}"';
    } elif isinstance(value, list) {
        items = [_toml_value(item) for item in value];
        return f"[{', '.join(items)}]";
    } else {
        # Fallback: convert to string
        return f'"{value}"';
    }
}

impl JacConfig.add_dependency(
    name: str, version: str, dev: bool = False, dep_type: str = "python"
) -> None {
    if dep_type == "python" {
        if dev {
            self.dev_dependencies[name] = version;
        } else {
            self.dependencies[name] = version;
        }
    } elif dep_type == "git" {
        self.git_dependencies[name] = {"git": version};
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
    name: str, dev: bool = False, dep_type: str = "python"
) -> bool {
    if dep_type == "python" {
        if dev {
            if name in self.dev_dependencies {
                del self.dev_dependencies[name] ;
                return True;
            }
        } else {
            if name in self.dependencies {
                del self.dependencies[name] ;
                return True;
            }
        }
    } elif dep_type == "git" {
        if name in self.git_dependencies {
            del self.git_dependencies[name] ;
            return True;
        }
    } else {
        if dep_type in self.plugin_dependencies {
            if dev and "dev" in self.plugin_dependencies[dep_type] {
                if name in self.plugin_dependencies[dep_type]["dev"] {
                    del self.plugin_dependencies[dep_type]["dev"][name] ;
                    return True;
                }
            } elif name in self.plugin_dependencies[dep_type] {
                del self.plugin_dependencies[dep_type][name] ;
                return True;
            }
        }
    }
    return False;
}

# ===============================================================================
# Helper Functions Implementation
# ===============================================================================
impl _parse_toml_data(
    data: dict[str, Any], toml_path: Path | None = None
) -> JacConfig {
    config = JacConfig();
    config._raw_data = data;
    if toml_path {
        config.toml_path = toml_path;
        config.project_root = toml_path.parent;
    }
    if "project" in data {
        proj = data["project"];
        config.project = ProjectConfig(
            name=proj.get("name", ""),
            version=proj.get("version", "0.1.0"),
            description=proj.get("description", ""),
            authors=proj.get("authors", []),
            license=proj.get("license", ""),
            readme=proj.get("readme", "README.md"),
            jac_version=proj.get("jac-version", ""),
            entry_point=proj.get("entry-point", "main.jac"),
            urls=proj.get("urls", {})
        );
    }
    if "dependencies" in data {
        deps = data["dependencies"];
        for (key, value) in deps.items() {
            if isinstance(value, str) {
                config.dependencies[key] = value;
            } elif isinstance(value, dict) {
                if key == "git" {
                    config.git_dependencies = value;
                } elif key == "npm" {
                    config.plugin_dependencies["npm"] = value;
                } else {
                    config.plugin_dependencies[key] = value;
                }
            }
        }
    }
    if "dev-dependencies" in data {
        dev_deps = data["dev-dependencies"];
        for (key, value) in dev_deps.items() {
            if isinstance(value, str) {
                config.dev_dependencies[key] = value;
            } elif isinstance(value, dict) {
                # Handle plugin dev dependencies like [dev-dependencies.npm]
                if key not in config.plugin_dependencies {
                    config.plugin_dependencies[key] = {};
                }
                config.plugin_dependencies[key]["dev"] = value;
            }
        }
    }
    if "run" in data {
        run_data = data["run"];
        config.run = RunConfig(
            session=run_data.get("session", ""),
            main=run_data.get("main", True),
            cache=run_data.get("cache", True)
        );
    }
    if "build" in data {
        build_data = data["build"];
        config.build = BuildConfig(
            typecheck=build_data.get("typecheck", False),
            dir=build_data.get("dir", ".jac")
        );
    }
    if "test" in data {
        test_data = data["test"];
        config.test = TestConfig(
            directory=test_data.get("directory", ""),
            filter=test_data.get("filter", ""),
            verbose=test_data.get("verbose", False),
            fail_fast=test_data.get("fail_fast", False),
            max_failures=test_data.get("max_failures", 0)
        );
    }
    if "serve" in data {
        serve_data = data["serve"];
        config.serve = ServeConfig(
            port=serve_data.get("port", 8000),
            session=serve_data.get("session", ""),
            main=serve_data.get("main", True),
            cl_route_prefix=serve_data.get("cl_route_prefix", "cl"),
            base_route_app=serve_data.get("base_route_app", "")
        );
    }
    if "format" in data {
        fmt = data["format"];
        config.format = FormatConfig(
            outfile=fmt.get("outfile", ""), fix=fmt.get("fix", False)
        );
    }
    if "check" in data {
        check_data = data["check"];
        config.check = CheckConfig(
            print_errs=check_data.get("print_errs", True),
            warnonly=check_data.get("warnonly", False)
        );
    }
    if "dot" in data {
        dot_data = data["dot"];
        config.dot = DotConfig(
            depth=dot_data.get("depth", -1),
            traverse=dot_data.get("traverse", False),
            bfs=dot_data.get("bfs", False),
            edge_limit=dot_data.get("edge_limit", 512),
            node_limit=dot_data.get("node_limit", 512),
            format=dot_data.get("format", "dot")
        );
    }
    if "cache" in data {
        cache_data = data["cache"];
        config.cache = CacheConfig(
            enabled=cache_data.get("enabled", True),
            dir=cache_data.get("dir", ".jac_cache")
        );
    }
    if "plugins" in data {
        plugins_data = data["plugins"];
        config.plugins_config = PluginsConfig(
            discovery=plugins_data.get("discovery", "auto"),
            enabled=plugins_data.get("enabled", []),
            disabled=plugins_data.get("disabled", [])
        );
        for (key, value) in plugins_data.items() {
            if isinstance(value, dict) {
                config.plugins[key] = value;
            }
        }
    }
    if "environment" in data {
        env = data["environment"];
        config.environment = EnvironmentConfig(
            default_profile=env.get("default_profile", "")
        );
    }
    if "environments" in data {
        config.environments = data["environments"];
    }
    if "scripts" in data {
        config.scripts = data["scripts"];
    }
    return config;
}

impl _interpolate_recursive(obj: Any) -> Any {
    if isinstance(obj, str) {
        try {
            return interpolate_env_vars(obj);
        } except ValueError {
            return obj;
        }
    } elif isinstance(obj, dict) {
        return {k: _interpolate_recursive(v) for (k, v) in obj.items()};
    } elif isinstance(obj, list) {
        return [_interpolate_recursive(item) for item in obj];
    }
    return obj;
}

# ===============================================================================
# Global Configuration Singleton Implementation
# ===============================================================================
impl get_config(
    force_discover: bool = False
) -> JacConfig | None {
    global _config;
    if _config is None or force_discover {
        _config = JacConfig.discover();
    }
    return _config;
}

impl set_config(config: JacConfig) -> None {
    global _config;
    _config = config;
}
