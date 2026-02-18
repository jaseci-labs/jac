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
# Multi-File Config Discovery
# ===============================================================================
impl discover_config_files(
    project_root: Path, profile: str | None = None
) -> list[Path] {
    import from pathlib { Path }
    files: list[Path] = [];
    # 1. Base config (always)
    base = project_root / "jac.toml";
    if base.exists() {
        files.append(base);
    }
    # 2. Profile-specific file (only when profile is set)
    if profile {
        profile_path = project_root / f"jac.{profile}.toml";
        if profile_path.exists() {
            files.append(profile_path);
        }
    }
    # 3. Local overrides (always, if present)
    local_path = project_root / "jac.local.toml";
    if local_path.exists() {
        files.append(local_path);
    }
    return files;
}

# ===============================================================================
# JacConfig Implementation
# ===============================================================================
impl JacConfig.discover(
    start_path: Path | None = None, profile: str | None = None
) -> JacConfig | None {
    import from pathlib { Path }
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, toml_path) = result;
    config = JacConfig.load(toml_path);
    if profile {
        config.apply_profile_overlay(profile);
    }
    return config;
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
    config.config_files = [toml_path];
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

"""Deep merge two dicts: recursively merges nested dicts, overwrites scalars."""
def _deep_merge(base: dict, override: dict) -> dict {
    result = base.copy();
    for (key, value) in override.items() {
        if key in result and isinstance(result[key], dict) and isinstance(value, dict) {
            result[key] = _deep_merge(result[key], value);
        } else {
            result[key] = value;
        }
    }
    return result;
}

impl JacConfig.apply_profile(profile_name: str, _visited: set | None = None) -> None {
    if profile_name not in self.environments {
        return;
    }
    # Cycle detection
    if _visited is None {
        _visited = set();
    }
    if profile_name in _visited {
        return;
    }
    _visited.add(profile_name);
    profile = self.environments[profile_name];
    # Handle inheritance first
    if "inherits" in profile {
        parent_name = profile["inherits"];
        if parent_name in self.environments {
            self.apply_profile(parent_name, _visited=_visited);
        }
    }
    # Generic sections: setattr loop
    section_map: dict = {
        "run": self.run,
        "build": self.build,
        "test": self.test,
        "serve": self.serve,
        "format": self.format,
        "dot": self.dot,
        "cache": self.cache,
        "environment": self.environment
    };
    for (section, obj) in section_map.items() {
        if section in profile {
            for (key, value) in profile[section].items() {
                if hasattr(obj, key) {
                    setattr(obj, key, value);
                }
            }
        }
    }
    # Special case: project (kebab-case -> snake_case)
    if "project" in profile {
        for (key, value) in profile["project"].items() {
            attr = key.replace("-", "_");
            if hasattr(self.project, attr) {
                setattr(self.project, attr, value);
            }
        }
    }
    # Special case: check (nested lint)
    if "check" in profile {
        check_data = profile["check"];
        for (key, value) in check_data.items() {
            if key == "lint" and isinstance(value, dict) {
                for (lk, lv) in value.items() {
                    if hasattr(self.check.lint, lk) {
                        setattr(self.check.lint, lk, lv);
                    }
                }
            } elif hasattr(self.check, key) {
                setattr(self.check, key, value);
            }
        }
    }
    # Special case: storage (type -> storage_type)
    if "storage" in profile {
        storage_data = profile["storage"];
        for (key, value) in storage_data.items() {
            if key == "type" {
                self.storage.storage_type = value;
            } elif hasattr(self.storage, key) {
                setattr(self.storage, key, value);
            }
        }
    }
    # Plugins: deep merge
    if "plugins" in profile {
        self.plugins = _deep_merge(self.plugins, profile["plugins"]);
    }
    # Dict sections: merge
    if "dependencies" in profile {
        for (key, value) in profile["dependencies"].items() {
            if isinstance(value, str) {
                self.dependencies[key] = value;
            }
        }
    }
    if "dev-dependencies" in profile {
        for (key, value) in profile["dev-dependencies"].items() {
            if isinstance(value, str) {
                self.dev_dependencies[key] = value;
            }
        }
    }
    if "scripts" in profile {
        self.scripts.update(profile["scripts"]);
    }
}

"""Apply profile overlay files on top of the base config.

Handles the full multi-file merge sequence in correct priority order:
  1. jac.<profile>.toml (if profile is set and file exists)
  2. [environments.<profile>] in-file overrides (if profile is set)
  3. jac.local.toml (always, if present — highest file priority)
"""
impl JacConfig.apply_profile_overlay(profile_name: str | None = None) -> None {
    if self.project_root is None {
        return;
    }
    if profile_name {
        # Step 1: Merge profile-specific file (e.g. jac.prod.toml)
        profile_path = self.project_root / f"jac.{profile_name}.toml";
        self.merge_from_toml_file(profile_path);
        # Step 2: Apply in-file [environments.<profile>] overrides
        self.apply_profile(profile_name);
        self.active_profile = profile_name;
    }
    # Step 3: Merge local overrides (always highest file priority)
    local_path = self.project_root / "jac.local.toml";
    self.merge_from_toml_file(local_path);
}

impl JacConfig.merge_from_toml_file(toml_path: Path) -> None {
    import tomllib;
    if not toml_path.exists() {
        return;
    }
    with open(toml_path, "rb") as f {
        data = tomllib.load(f);
    }
    data = _interpolate_recursive(data);
    section_map: dict = {
        "run": self.run,
        "build": self.build,
        "test": self.test,
        "serve": self.serve,
        "format": self.format,
        "dot": self.dot,
        "cache": self.cache,
        "environment": self.environment
    };
    for (section, obj) in section_map.items() {
        if section in data {
            for (key, value) in data[section].items() {
                if hasattr(obj, key) {
                    setattr(obj, key, value);
                }
            }
        }
    }
    if "project" in data {
        proj = data["project"];
        for (key, value) in proj.items() {
            attr = key.replace("-", "_");
            if hasattr(self.project, attr) {
                setattr(self.project, attr, value);
            }
        }
    }
    # Check section with nested lint
    if "check" in data {
        check_data = data["check"];
        for (key, value) in check_data.items() {
            if key == "lint" and isinstance(value, dict) {
                for (lk, lv) in value.items() {
                    if hasattr(self.check.lint, lk) {
                        setattr(self.check.lint, lk, lv);
                    }
                }
            } elif hasattr(self.check, key) {
                setattr(self.check, key, value);
            }
        }
    }
    # Storage section with type -> storage_type mapping
    if "storage" in data {
        storage_data = data["storage"];
        for (key, value) in storage_data.items() {
            if key == "type" {
                self.storage.storage_type = value;
            } elif hasattr(self.storage, key) {
                setattr(self.storage, key, value);
            }
        }
    }
    if "plugins" in data {
        plugins_data = data["plugins"];
        if "discovery" in plugins_data {
            self.plugins_config.discovery = plugins_data["discovery"];
        }
        if "enabled" in plugins_data {
            self.plugins_config.enabled = plugins_data["enabled"];
        }
        if "disabled" in plugins_data {
            self.plugins_config.disabled = plugins_data["disabled"];
        }
        for (key, value) in plugins_data.items() {
            if isinstance(value, dict) {
                if key in self.plugins {
                    self.plugins[key] = _deep_merge(self.plugins[key], value);
                } else {
                    self.plugins[key] = value;
                }
            }
        }
    }
    # Dict sections: merge rather than replace
    if "dependencies" in data {
        deps = data["dependencies"];
        for (key, value) in deps.items() {
            if isinstance(value, str) {
                self.dependencies[key] = value;
            } elif isinstance(value, dict) {
                if key == "git" {
                    self.git_dependencies.update(value);
                } else {
                    if key not in self.plugin_dependencies {
                        self.plugin_dependencies[key] = {};
                    }
                    self.plugin_dependencies[key].update(value);
                }
            }
        }
    }
    if "dev-dependencies" in data {
        dev_deps = data["dev-dependencies"];
        for (key, value) in dev_deps.items() {
            if isinstance(value, str) {
                self.dev_dependencies[key] = value;
            } elif isinstance(value, dict) {
                if key not in self.plugin_dependencies {
                    self.plugin_dependencies[key] = {};
                }
                if "dev" not in self.plugin_dependencies[key] {
                    self.plugin_dependencies[key]["dev"] = {};
                }
                self.plugin_dependencies[key]["dev"].update(value);
            }
        }
    }
    if "environments" in data {
        self.environments.update(data["environments"]);
    }
    if "scripts" in data {
        self.scripts.update(data["scripts"]);
    }
    if self.config_files is None {
        self.config_files = [];
    }
    if toml_path not in self.config_files {
        self.config_files.append(toml_path);
    }
    # Merge raw data for _is_explicitly_set checks
    for (key, value) in data.items() {
        if key in self._raw_data
        and isinstance(self._raw_data[key], dict)
        and isinstance(value, dict) {
            self._raw_data[key].update(value);
        } else {
            self._raw_data[key] = value;
        }
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

"""Get the virtual environment directory (.jac/venv)."""
impl JacConfig.get_venv_dir -> Path {
    return self.get_build_dir() / "venv";
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
    # Replace Python dependencies (use replace to handle removals)
    # Preserve sub-tables (git, npm, etc.) that live under [dependencies]
    old_deps = doc.get("dependencies", {});
    sub_tables = {
        k: v
        for (k, v) in old_deps.items()
        if isinstance(v, dict)
    };
    doc["dependencies"] = dict(self.dependencies);
    # Restore sub-tables
    for (k, v) in sub_tables.items() {
        doc["dependencies"][k] = v;
    }
    # Replace git dependencies under [dependencies.git]
    if self.git_dependencies {
        doc["dependencies"]["git"] = dict(self.git_dependencies);
    } elif "git" in doc.get("dependencies", {}) {
        del doc["dependencies"]["git"];
    }
    # Replace dev-dependencies (use replace to handle removals)
    if self.dev_dependencies {
        doc["dev-dependencies"] = dict(self.dev_dependencies);
    } elif "dev-dependencies" in doc {
        doc["dev-dependencies"] = {};
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
            del doc["plugins"]["disabled"];  # Remove if empty
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
                del self.dev_dependencies[name];
                return True;
            }
        } else {
            if name in self.dependencies {
                del self.dependencies[name];
                return True;
            }
        }
    } elif dep_type == "git" {
        if name in self.git_dependencies {
            del self.git_dependencies[name];
            return True;
        }
    } else {
        if dep_type in self.plugin_dependencies {
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
        lint_config = LintConfig();
        if "lint" in check_data {
            lint_data = check_data["lint"];
            lint_config = LintConfig(
                select=lint_data.get("select", ["default"]),
                ignore=lint_data.get("ignore", []),
                exclude=lint_data.get("exclude", [])
            );
        }
        config.check = CheckConfig(
            print_errs=check_data.get("print_errs", True),
            warnonly=check_data.get("warnonly", False),
            lint=lint_config
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
    if "storage" in data {
        storage_data = data["storage"];
        config.storage = StorageConfig(
            storage_type=storage_data.get("type", "local"),
            base_path=storage_data.get("base_path", "./storage"),
            create_dirs=storage_data.get("create_dirs", True)
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
    start_path: Path | None = None, force_discover: bool = False
) -> JacConfig | None {
    global _config;
    if _config is None or force_discover {
        _config = JacConfig.discover(start_path=start_path);
    }
    return _config;
}

impl set_config(config: JacConfig) -> None {
    global _config;
    _config = config;
}
