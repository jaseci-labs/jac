impl interpolate_env_vars(value: str) -> str {
    import os;
    import re;
    if not isinstance(value, str) {
        return value;
    }

    pattern = r"\$\{([^}:]+)(?:(:[-?])([^}]*))?\}";
    def replace_env_var(`match: re.Match) -> str {
        var_name = `match.group(1);
        operator = `match.group(2);
        operand = `match.group(3) or "";

        env_value = os.environ.get(var_name);

        if env_value is not None {
            return env_value;
        }

        if operator == ":-" {
            return operand;
        } elif operator == ":?" {
            raise ValueError(f"Environment variable {var_name} is required: {operand}");
        } else {
            raise ValueError(f"Environment variable {var_name} is not set");
        }
    }
    return re.sub(pattern, replace_env_var, value);
}

impl find_project_root(start: Path | None = None) -> tuple[Path, Path] | None {
    import from jaclang.compiler.driver.modresolver {
        find_project_root as _find_project_root
    }
    return _find_project_root(start);
}

impl is_in_project -> bool {
    return find_project_root() is not None;
}

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

    base = start_path if start_path is not None else Path.cwd();
    config.discovered_from_ancestor = project_root.resolve() != base.resolve();
    if profile {
        config.apply_profile_overlay(profile);
    }
    return config;
}

impl JacConfig.load(toml_path: Path) -> JacConfig {
    import from jaclang.project.tomlio { read_toml_with_encoding }
    if not toml_path.exists() {
        raise FileNotFoundError(f"Configuration file not found: {toml_path}");
    }
    data = read_toml_with_encoding(str(toml_path));
    config = _parse_toml_data(data, toml_path);
    config.config_files = [toml_path];
    return config;
}

impl JacConfig.from_toml_str(
    toml_str: str, toml_path: Path | None = None
) -> JacConfig {
    import tomllib;
    data = tomllib.loads(toml_str);
    return _parse_toml_data(data, toml_path);
}

def _deep_merge(base: dict[str, any], `override: dict[str, any]) -> dict[str, any] {
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

impl JacConfig._section_map -> dict[
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
] {
    return {
        "run": self.run,
        "build": self.build,
        "test": self.`test,
        "serve": self.serve,
        "format": self.format,
        "dot": self.dot,
        "cache": self.cache,
        "environment": self.environment,
        "client": self.client
    };
}

impl JacConfig.apply_profile(
    profile_name: str, _visited: set[str] | None = None
) -> None {
    if _visited is None {
        self._layers.append(("profile", profile_name));
        _visited = set();
    }
    if profile_name not in self.environments {
        return;
    }
    if profile_name in _visited {
        return;
    }
    _visited.add(profile_name);
    profile = self.environments[profile_name];

    if "inherits" in profile {
        parent_name = profile["inherits"];
        if parent_name in self.environments {
            self.apply_profile(parent_name, _visited=_visited);
        }
    }

    section_map = self._section_map();
    for (section, obj) in section_map.items() {
        if section in profile {
            profile_section: dict[str, any] = profile[section];
            for (key, value) in profile_section.items() {
                if hasattr(obj, key) {
                    setattr(obj, key, value);
                }
            }
        }
    }

    if "project" in profile {
        profile_project: dict[str, any] = profile["project"];
        for (key, value) in profile_project.items() {
            attr = key.replace("-", "_");
            if hasattr(self.project, attr) {
                setattr(self.project, attr, value);
            }
        }
    }

    if "check" in profile {
        check_data: dict[str, any] = profile["check"];
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

    if "storage" in profile {
        storage_data: dict[str, any] = profile["storage"];
        for (key, value) in storage_data.items() {
            if key == "type" {
                self.storage.storage_type = value;
            } elif hasattr(self.storage, key) {
                setattr(self.storage, key, value);
            }
        }
    }

    for _feat in CAPABILITY_SECTIONS {
        if _feat in profile and isinstance(profile[_feat], dict) {
            if _feat in self.plugins {
                self.plugins[_feat] = _deep_merge(self.plugins[_feat], profile[_feat]);
            } else {
                self.plugins[_feat] = profile[_feat];
            }
        }
    }

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

impl JacConfig.apply_profile_overlay(profile_name: str | None = None) -> None {
    if self.project_root is None {
        return;
    }
    self._layers.append(("overlay", profile_name or ""));
    if profile_name {
        profile_path = self.project_root / f"jac.{profile_name}.toml";
        self.merge_from_toml_file(profile_path);

        self.apply_profile(profile_name, _visited=set());
        self.active_profile = profile_name;
    }

    local_path = self.project_root / "jac.local.toml";
    self.merge_from_toml_file(local_path);
}

impl JacConfig.merge_from_toml_file(toml_path: Path) -> None {
    import from jaclang.project.tomlio { read_toml_with_encoding }
    if not toml_path.exists() {
        return;
    }
    data: dict[str, any] = read_toml_with_encoding(str(toml_path));
    data = _interpolate_recursive(data);
    section_map = self._section_map();
    for (section, obj) in section_map.items() {
        if section in data {
            data_section: dict[str, any] = data[section];
            for (key, value) in data_section.items() {
                if hasattr(obj, key) {
                    setattr(obj, key, value);
                }
            }
        }
    }
    if "project" in data {
        proj: dict[str, any] = data["project"];
        for (key, value) in proj.items() {
            attr = key.replace("-", "_");
            if attr == "authors" {
                self.project.authors = _parse_persons(value);
            } elif attr == "maintainers" {
                self.project.maintainers = _parse_persons(value);
            } elif attr == "include" {
                self.project.`include = _parse_include(value);
            } elif hasattr(self.project, attr) {
                setattr(self.project, attr, value);
            }
        }
    }

    if "check" in data {
        check_data: dict[str, any] = data["check"];
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

    if "storage" in data {
        storage_data: dict[str, any] = data["storage"];
        for (key, value) in storage_data.items() {
            if key == "type" {
                self.storage.storage_type = value;
            } elif hasattr(self.storage, key) {
                setattr(self.storage, key, value);
            }
        }
    }
    if "gc" in data {
        gc_data = data["gc"];
        if "default" in gc_data {
            _gcd = str(gc_data["default"]).strip().lower();
            if _gcd in ("cycles", "rc", "none") {
                self.gc.`default = _gcd;
            }
        }
        if "enforce" in gc_data and isinstance(gc_data["enforce"], dict) {
            enf = gc_data["enforce"];
            if "modules" in enf {
                self.gc.enforce.modules = [str(_m) for _m in enf["modules"]];
            }
            if "grandfathered" in enf {
                self.gc.enforce.grandfathered = [
                    str(_m) for _m in enf["grandfathered"]
                ];
            }
        }
    }
    for _feat in CAPABILITY_SECTIONS {
        if _feat in data and isinstance(data[_feat], dict) {
            if _feat in self.plugins {
                self.plugins[_feat] = _deep_merge(self.plugins[_feat], data[_feat]);
            } else {
                self.plugins[_feat] = data[_feat];
            }
        }
    }

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
    import from pathlib { Path }
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

    import copy;
    text = "";
    old_doc: dict[str, any] = {};
    if self.toml_path.exists() {
        import tomllib;
        import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
        import from jaclang.project.tomlio { MalformedJacTomlError }
        text = read_file_with_encoding(str(self.toml_path));
        try {
            old_doc = tomllib.loads(text);
        } except tomllib.TOMLDecodeError as exc {
            raise MalformedJacTomlError(str(self.toml_path), exc);
        }
    }
    doc = copy.deepcopy(old_doc);

    old_deps = doc.get("dependencies", {});
    sub_tables = {
        k: v
        for (k, v) in old_deps.items()
        if isinstance(v, dict)
    };
    doc["dependencies"] = dict(self.dependencies);

    for (k, v) in sub_tables.items() {
        doc["dependencies"][k] = v;
    }

    if self.git_dependencies {
        doc["dependencies"]["git"] = dict(self.git_dependencies);
    } elif "git" in doc.get("dependencies", {}) {
        del doc["dependencies"]["git"];
    }

    if self.dev_dependencies {
        doc["dev-dependencies"] = dict(self.dev_dependencies);
    } elif "dev-dependencies" in doc {
        doc["dev-dependencies"] = {};
    }

    for (dep_type, deps) in self.plugin_dependencies.items() {
        if dep_type not in doc["dependencies"] {
            doc["dependencies"][dep_type] = {};
        }

        dev_deps = deps.get("dev", {}) if isinstance(deps.get("dev"), dict) else {};
        regular_deps = {
            k: v
            for (k, v) in deps.items()
            if k != "dev"
        };

        doc["dependencies"][dep_type] = regular_deps.copy();
        if dev_deps {
            doc["dependencies"][dep_type]["dev"] = dev_deps;
        }
    }

    if text {
        updated = _toml_minimal_update(
            text, old_doc, doc, ["dependencies", "dev-dependencies"]
        );
        if updated is not None {
            self._write_toml_text(updated);
            return;
        }
    }
    self.persist_doc(doc);
}

impl JacConfig.persist_doc(doc: dict[str, any]) -> None {
    self._write_toml_text(serialize_toml(doc));
}

impl JacConfig._write_toml_text(text: str) -> None {
    if self.toml_path is None {
        raise ValueError("No toml_path set, cannot save configuration");
    }
    if self.discovered_from_ancestor {
        import from jaclang.cli.console { console }
        console.warning(
            f"No jac.toml in the current directory -- modifying {self.toml_path}"
        );
        console.print(
            "  Run this command from the project root, "
            "or 'jac create' here to start a new project.",
            style="muted"
        );
    }
    with open(self.toml_path, "w") as f {
        f.write(text);
    }
}

def _needs_quoting(key: str) -> bool {
    import re;
    return not bool(re.`match(r'^[A-Za-z0-9_-]+$', key));
}

def _quote_key(key: str) -> str {
    if _needs_quoting(key) {
        escaped = key.replace("\\", "\\\\").replace('"', '\\"');
        return f'"{escaped}"';
    }
    return key;
}

def _toml_flatten_into(
    view: dict[tuple[str, ...], dict[str, any]],
    path: tuple[str, ...],
    table: dict[str, any]
) {
    flat: dict[str, any] = {};
    for (k, v) in table.items() {
        if isinstance(v, dict) {
            _toml_flatten_into(view, path + (k, ), v);
        } else {
            flat[k] = v;
        }
    }
    view[path] = flat;
}

def _toml_flatten(
    doc: dict[str, any], roots: list[str]
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
        _toml_flatten_into(view, (root_key, ), table);
    }
    return view;
}

def _toml_token_alt(name: str) -> str {
    import re;
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

def _toml_find_span(
    lines: list[str], parts: tuple[str, ...]
) -> tuple[int, int] | None {
    import re;
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

def _toml_find_key(
    lines: list[str], span: tuple[int, int], key: str
) -> tuple[int, int] | None {
    import re;
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

def _toml_value_end(line: str, start: int) -> int | None {
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

def _toml_replace_key(
    lines: list[str], parts: tuple[str, ...], key: str, value_text: str
) -> bool {
    import re;
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

def _toml_delete_key(lines: list[str], parts: tuple[str, ...], key: str) -> bool {
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

def _toml_insert_key(
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

def _toml_append_section(
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

def _toml_remove_section(lines: list[str], parts: tuple[str, ...]) -> bool {
    span = _toml_find_span(lines, parts);
    if span is None {
        return False;
    }
    for _ in range(span[1] - span[0]) {
        lines.pop(span[0]);
    }
    return True;
}

def _toml_minimal_update(
    text: str, old_doc: dict[str, any], new_doc: dict[str, any], roots: list[str]
) -> str | None {
    old_view = _toml_flatten(old_doc, roots);
    new_view = _toml_flatten(new_doc, roots);
    if old_view is None or new_view is None {
        return None;
    }
    lines: list[str] = text.split("\n");
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
        } elif name in self.dependencies {
            del self.dependencies[name];
            return True;
        }
    } elif dep_type == "git" {
        if name in self.git_dependencies {
            del self.git_dependencies[name];
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

impl _parse_persons(raw: list[any]) -> list[PersonConfig] {
    result: list[PersonConfig] = [];
    for item in raw {
        if isinstance(item, dict) {
            result.append(
                PersonConfig(name=item.get("name", ""), email=item.get("email", ""))
            );
        } elif isinstance(item, str) {
            result.append(PersonConfig(name=item, email=""));
        }
    }
    return result;
}

impl _parse_include(raw: dict[str, any]) -> PackageIncludeConfig {
    return PackageIncludeConfig(
        packages=raw.get("packages", []), data=raw.get("data", {})
    );
}

impl _parse_toml_data(
    data: dict[str, any], toml_path: Path | None = None
) -> JacConfig {
    import copy;
    raw = data;
    data = _interpolate_recursive(raw);
    config = JacConfig();
    config._raw_data = raw;
    config._base_data = copy.deepcopy(raw);
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
            authors=_parse_persons(proj.get("authors", [])),
            maintainers=_parse_persons(proj.get("maintainers", [])),
            license=proj.get("license", ""),
            readme=proj.get("readme", "README.md"),
            keywords=proj.get("keywords", []),
            classifiers=proj.get("classifiers", []),
            requires_python=proj.get("requires-python", ""),
            jac_version=proj.get("jac-version", ""),
            entry_point=proj.get("entry-point", "main.jac"),
            kind=proj.get("kind", ""),
            default_app=str(
                proj.get("default-app", proj.get("default_app", "")) or ""
            ).strip(),
            urls=proj.get("urls", {}),
            `include=_parse_include(proj.get("include", {}))
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
            cache=run_data.get("cache", True),
            diagnostics=run_data.get("diagnostics", "error")
        );
    }
    if "build" in data {
        build_data = data["build"];
        _codespace_aliases = {"sv": "server", "na": "native"};
        _builtin_cs = BuildConfig().default_codespace;
        _default_cs = str(
            build_data.get("default_codespace", _builtin_cs)
        ).strip().lower();
        _default_cs = _codespace_aliases.get(_default_cs, _default_cs);
        if _default_cs not in ("server", "native") {
            import from jaclang.cli.console { console }
            console.warning(
                f"[build] default_codespace='{build_data.get('default_codespace')}' "
                f"is not one of 'server'/'sv', 'native'/'na'; "
                f"defaulting to '{_builtin_cs}'."
            );
            _default_cs = _builtin_cs;
        }
        _builtin_cap = BuildConfig().native_closure_cap;
        try {
            _cap = int(build_data.get("native_closure_cap", _builtin_cap));
        } except (TypeError, ValueError) {
            _cap = 0;
        }
        if _cap < 1 {
            import from jaclang.cli.console { console }
            console.warning(
                f"[build] native_closure_cap="
                f"'{build_data.get('native_closure_cap')}' must be a positive "
                f"integer; defaulting to {_builtin_cap}."
            );
            _cap = _builtin_cap;
        }
        _native_data = build_data.get("native", {});
        if not isinstance(_native_data, dict) {
            _native_data = {};
        }
        _builtin_native = NativeBuildConfig();
        try {
            _native_opt = int(_native_data.get("opt_level", _builtin_native.opt_level));
        } except (TypeError, ValueError) {
            import from jaclang.cli.console { console }
            console.warning(
                f"[build.native] opt_level="
                f"'{_native_data.get('opt_level')}' must be an integer; "
                f"defaulting to {_builtin_native.opt_level}."
            );
            _native_opt = _builtin_native.opt_level;
        }
        config.build = BuildConfig(
            dir=build_data.get("dir", ".jac"),
            default_codespace=_default_cs,
            native_closure_cap=_cap,
            native=NativeBuildConfig(
                opt_level=_native_opt,
                dump_ir=str(_native_data.get("dump_ir", "")),
                target=str(_native_data.get("target", "")),
                debug=bool(_native_data.get("debug", False)),
                rc_debug_codegen=bool(_native_data.get("rc_debug_codegen", False))
            )
        );
    }
    if "gc" in data {
        gc_data = data["gc"];
        _gc_default = str(gc_data.get("default", "cycles")).strip().lower();
        if _gc_default not in ("cycles", "rc", "none") {
            import from jaclang.cli.console { console }
            console.warning(
                f"[gc] default='{gc_data.get('default')}' is not one of "
                "'cycles', 'rc', 'none'; defaulting to 'cycles'."
            );
            _gc_default = "cycles";
        }
        enforce_cfg = GcEnforceConfig();
        if "enforce" in gc_data and isinstance(gc_data["enforce"], dict) {
            enf = gc_data["enforce"];
            enforce_cfg = GcEnforceConfig(
                modules=[str(_m) for _m in enf.get("modules", [])],
                grandfathered=[str(_m) for _m in enf.get("grandfathered", [])]
            );
        }
        config.gc = GcConfig(`default=_gc_default, enforce=enforce_cfg);
    }
    if "test" in data {
        test_data = data["test"];
        config.`test = TestConfig(
            directory=test_data.get("directory", ""),
            directories=[str(_d) for _d in test_data.get("directories", [])],
            isolate=[str(_p) for _p in test_data.get("isolate", [])],
            serial=[str(_p) for _p in test_data.get("serial", [])],
            filter=test_data.get("filter", ""),
            verbose=test_data.get("verbose", False),
            fail_fast=test_data.get("fail_fast", False),
            max_failures=test_data.get("max_failures", 0)
        );
    }
    if "serve" in data {
        serve_data = data["serve"];

        on_conflict = str(serve_data.get("on_conflict", "retry")).strip().lower();
        if on_conflict not in ("retry", "fail") {
            import from jaclang.cli.console { console }
            console.warning(
                f"[serve] on_conflict='{serve_data.get('on_conflict')}' is not "
                "'retry' or 'fail'; defaulting to 'retry'."
            );
            on_conflict = "retry";
        }
        workers_raw = serve_data.get("workers", {});
        workers_data: dict[str, any] = (
            workers_raw if isinstance(workers_raw, dict) else {"count": workers_raw}
        );
        tls_data: dict[str, any] = serve_data.get("tls", {}) or {};
        proxy_data: dict[str, any] = serve_data.get("proxy", {}) or {};
        limits_data: dict[str, any] = serve_data.get("limits", {}) or {};
        timeouts_data: dict[str, any] = serve_data.get("timeouts", {}) or {};
        access_data: dict[str, any] = serve_data.get("access_log", {}) or {};
        compression_data: dict[str, any] = serve_data.get("compression", {}) or {};
        ws_data: dict[str, any] = serve_data.get("websocket", {}) or {};
        auth_data: dict[str, any] = serve_data.get("auth", {}) or {};
        cors_raw = serve_data.get("cors_origins", ["*"]);
        config.serve = ServeConfig(
            host=str(serve_data.get("host", "0.0.0.0")),
            port=serve_data.get("port", 8000),
            session=serve_data.get("session", ""),
            main=serve_data.get("main", True),
            docs_enabled=bool(serve_data.get("docs_enabled", True)),
            graph_enabled=bool(serve_data.get("graph_enabled", True)),
            cors_origins=[str(_o) for _o in cors_raw]
                if isinstance(cors_raw, list)
                else [str(cors_raw)],
            on_conflict=on_conflict,
            conflict_max_attempts=serve_data.get("conflict_max_attempts", 5),
            conflict_backoff_ms=serve_data.get("conflict_backoff_ms", 0),
            workers=ServeWorkersConfig(
                count=str(workers_data.get("count", "1")),
                threads=str(workers_data.get("threads", "auto")),
                max_requests=int(workers_data.get("max_requests", 0)),
                max_requests_jitter=int(workers_data.get("max_requests_jitter", 0)),
                request_timeout=float(workers_data.get("request_timeout", 0.0)),
                boot_timeout=float(workers_data.get("boot_timeout", 120.0)),
                hang_timeout=float(workers_data.get("hang_timeout", 30.0))
            ),
            tls=ServeTlsConfig(
                certfile=str(tls_data.get("certfile", "")),
                keyfile=str(tls_data.get("keyfile", "")),
                ca_certs=str(tls_data.get("ca_certs", "")),
                min_version=str(tls_data.get("min_version", "1.2"))
            ),
            proxy=ServeProxyConfig(
                trusted=[str(_p) for _p in proxy_data.get("trusted", [])]
            ),
            limits=ServeLimitsConfig(
                max_connections=int(limits_data.get("max_connections", 0)),
                backlog=int(limits_data.get("backlog", 2048)),
                max_body_bytes=int(limits_data.get("max_body_bytes", 104857600)),
                max_header_bytes=int(limits_data.get("max_header_bytes", 65536)),
                max_header_count=int(limits_data.get("max_header_count", 100)),
                max_request_line_bytes=int(
                    limits_data.get("max_request_line_bytes", 8192)
                ),
                multipart_spool_bytes=int(
                    limits_data.get("multipart_spool_bytes", 1048576)
                )
            ),
            timeouts=ServeTimeoutsConfig(
                header=float(timeouts_data.get("header", 30.0)),
                body=float(timeouts_data.get("body", 60.0)),
                keepalive=float(timeouts_data.get("keepalive", 65.0)),
                drain=float(timeouts_data.get("drain", 10.0)),
                close=float(timeouts_data.get("close", 5.0))
            ),
            access_log=ServeAccessLogConfig(
                enabled=bool(access_data.get("enabled", True)),
                format=str(access_data.get("format", "text")),
                suppress_health_checks=bool(
                    access_data.get("suppress_health_checks", False)
                )
            ),
            compression=ServeCompressionConfig(
                enabled=bool(compression_data.get("enabled", True)),
                min_bytes=int(compression_data.get("min_bytes", 1024)),
                level=int(compression_data.get("level", 4))
            ),
            websocket=ServeWebSocketConfig(
                allowed_origins=[str(_o) for _o in ws_data.get("allowed_origins", [])],
                max_message_bytes=int(ws_data.get("max_message_bytes", 0)),
                ping_interval=float(ws_data.get("ping_interval", 20.0)),
                ping_timeout=float(ws_data.get("ping_timeout", 20.0))
            ),
            auth=ServeAuthConfig(
                secret=str(auth_data.get("secret", "")),
                algorithm=str(auth_data.get("algorithm", "HS256")),
                token_ttl_days=int(auth_data.get("token_ttl_days", 7)),
                password_hash_cost=int(auth_data.get("password_hash_cost", 14))
            )
        );
    }
    if "format" in data {
        fmt = data["format"];
        config.format = FormatConfig(outfile=fmt.get("outfile", ""));
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
            lint=lint_config,
            suppress=check_data.get("suppress", []),
            suppress_categories=check_data.get("suppress_categories", []),
            enforce_access=check_data.get("enforce_access", False),
            warn_native_seams=check_data.get("warn_native_seams", True)
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
            enabled=cache_data.get("enabled", True), dir=cache_data.get("dir", "cache")
        );
    }
    if "storage" in data {
        storage_data: dict[str, any] = data["storage"];
        for (key, value) in storage_data.items() {
            if key == "type" {
                config.storage.storage_type = value;
            } elif hasattr(config.storage, key) {
                setattr(config.storage, key, value);
            }
        }
    }
    if "client_errors" in data {
        ce_data = data["client_errors"];
        config.client_errors = ClientErrorsConfig(
            verbose=ce_data.get("verbose", False)
        );
    }
    if "client" in data {
        client_data = data["client"];
        config.client = ClientConfig(framework=client_data.get("framework", "react"));
    }
    if "dev" in data {
        dev_data = data["dev"];

        config.dev = DevConfig(
            jaclang_source=str(dev_data.get("jaclang_source", "")),
            jobs=str(dev_data.get("jobs", "")),
            test_jobs=str(dev_data.get("test_jobs", "")),
            check_jobs=str(dev_data.get("check_jobs", "")),
            fmt_jobs=str(dev_data.get("fmt_jobs", ""))
        );
    }
    _scale_raw = data.get("scale");
    if isinstance(_scale_raw, dict) and "microservices" in _scale_raw {
        raise ValueError(
            "jac.toml [scale.microservices] was removed: declare each service as "
            "an [apps.<name>] table (kind = \"service\", entry-point, route) and "
            "move the gateway settings (logs, ingress, cors, boot keys) to "
            "[scale.gateway]. See the Breaking Changes page "
            "(docs/community/breaking-changes.md, Workspaces)."
        );
    }
    for _feat in CAPABILITY_SECTIONS {
        if _feat in data and isinstance(data[_feat], dict) {
            config.plugins[_feat] = data[_feat];
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
    if "entrypoints" in data {
        for (group, refs) in data["entrypoints"].items() {
            if isinstance(refs, dict) {
                config.entrypoints[group] = dict(refs);
            }
        }
    }
    if "optional-dependencies" in data {
        for (group, deps) in data["optional-dependencies"].items() {
            if isinstance(deps, dict) {
                config.optional_dependencies[group] = dict(deps);
            }
        }
    }
    if "apps" in data {
        config.apps = parse_apps(data.get("project", {}), data["apps"]);
        config.is_workspace = True;
    } else {
        if config.project.default_app {
            raise ValueError("[project] default-app requires an [apps] table");
        }
        app = implicit_app(config);
        config.apps = {app.name: app};
    }
    return config;
}

impl _interpolate_recursive(`obj: any) -> any {
    if isinstance(`obj, str) {
        try {
            return interpolate_env_vars(`obj);
        } except ValueError {
            return `obj;
        }
    } elif isinstance(`obj, dict) {
        return {k: _interpolate_recursive(v) for (k, v) in `obj.items()};
    } elif isinstance(`obj, list) {
        return [_interpolate_recursive(item) for item in `obj];
    }
    return `obj;
}

impl get_config(
    start_path: Path | None = None, force_discover: bool = False
) -> JacConfig | None {
    if (_config is None and not _config_explicit) or force_discover {
        _config = JacConfig.discover(start_path=start_path);

        _config_explicit = False;

        if force_discover {
            _config_by_root = {};
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

impl get_config_for_path(start_path: Path) -> JacConfig | None {
    explicit = get_explicit_config();
    if explicit is not None {
        return explicit;
    }
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, _) = result;
    key = str(project_root);
    if key not in _config_by_root {
        _config_by_root[key] = JacConfig.discover(start_path=project_root);
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
        return implicit_app(self);
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
    import from jaclang.project.kinds { resolve_app_kind, resolve_entry }
    root_dir = str(self.project_root) if self.project_root else "";
    entry_file = resolve_entry(self, root_dir, app) if root_dir else "";
    return resolve_app_kind(self, app, entry_file);
}

impl JacConfig.effective_for_app(name: str) -> JacConfig {
    import copy;
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
        import from jaclang.runtime.runtime { JacRuntime }
        entry_path = JacRuntime.get_full_target_path() or "";
    }
    if not entry_path {
        return None;
    }
    app = self.app_for_path(os.path.abspath(entry_path));
    return None if app is None or app.implicit else app;
}

impl JacConfig.app_for_path(abs_path: str) -> AppConfig | None {
    if self.project_root is None {
        return None;
    }
    root_dir = str(self.project_root);
    if not self.apps {
        implicit = implicit_app(self);
        return implicit if implicit.contains(root_dir, abs_path) else None;
    }
    best: AppConfig | None = None;
    best_depth = -1;
    for app in self.apps.values() {
        if not app.contains(root_dir, abs_path) {
            continue;
        }
        if app.is_file_rooted() {
            return app;
        }
        depth = len(app.root_dir(root_dir));
        if depth > best_depth {
            best = app;
            best_depth = depth;
        }
    }
    return best;
}

impl JacConfig.serving_apps -> list[AppConfig] {
    import from jaclang.project.kinds { kind_spec }
    out: list[AppConfig] = [];
    for app in self.apps.values() {
        spec = kind_spec(self.resolved_kind(app));
        if spec is not None and spec.has_server {
            out.append(app);
        }
    }
    return out;
}

impl JacConfig.owner_app_for_path(abs_path: str) -> tuple[AppConfig | None, bool] {
    app = self.app_for_path(abs_path);
    if app is not None {
        return (app, False);
    }
    serving = self.serving_apps();
    if len(serving) == 1 {
        return (serving[0], False);
    }
    default_app = self.app(self.default_app) if self.default_app else None;
    if default_app is not None and default_app in serving {
        return (default_app, False);
    }
    return (None, len(serving) > 1);
}

impl JacConfig.default_app.getter -> str {
    return self.project.default_app;
}
