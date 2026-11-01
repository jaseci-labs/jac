impl kernel_native_fact(kind: str, key: str) -> str {
    if kind == FACT_CODEC_TABLES {
        return codec_tables_fact();
    }
    if kind == FACT_CODEC_NAME {
        return codec_name_fact(key);
    }
    if kind == FACT_PRIMITIVE_METHODS {
        return primitive_methods_fact(key);
    }
    if kind == FACT_SEALED_RUNTIME {
        return sealed_runtime_fact();
    }
    if kind == FACT_IMPORT_PATHS {
        return import_paths_fact();
    }
    if kind == FACT_PACKAGE_STORE {
        return package_store_fact();
    }
    if kind == HOST_FACT_STDLIB_MODULES {
        return stdlib_modules_fact();
    }
    if kind == HOST_FACT_GIT_IGNORED {
        return git_ignored_fact(key);
    }
    raise ValueError(f"unknown native fact {kind!r}");
}

impl hex_row(kind: int, name: str) -> str {
    digits: list[str] = [f"{kind:02x}"];
    for ch in name {
        code = ord(ch);
        if code > 127 {
            raise ValueError(f"codec name {name!r} is not ASCII");
        }
        digits.append(f"{code:02x}");
    }
    digits.append("00");
    return "".join(digits);
}

impl codec_kind(module: str) -> int {
    return CODEC_SUPPORTED_KINDS.get(module, CODEC_KIND_OTHER);
}

impl codec_tables_fact -> str {
    alias_rows: list[str] = [];
    for alias in sorted(CODEC_ALIASES) {
        alias_rows.append(hex_row(codec_kind(CODEC_ALIASES[alias]), alias));
    }
    module_rows: list[str] = [];
    for module in CODEC_MODULES {
        module_rows.append(hex_row(codec_kind(module), module));
    }
    return "".join(alias_rows) + FACT_SEP + "".join(module_rows);
}

impl normalize_encoding(name: str) -> str {
    chars: list[str] = [];
    punct = False;
    for ch in name {
        if ch.isalnum() or ch == "." {
            if punct and chars {
                chars.append("_");
            }
            chars.append(ch);
            punct = False;
        } else {
            punct = True;
        }
    }
    return "".join(chars);
}

impl codec_name_fact(key: str) -> str {
    norm = normalize_encoding(key.lower());
    candidates: list[str] = [];
    aliased = CODEC_ALIASES.get(norm) or CODEC_ALIASES.get(norm.replace(".", "_"));
    if aliased {
        candidates.append(aliased);
    }
    candidates.append(norm);
    for module in candidates {
        name = CODEC_NAMES.get(module);
        if name is not None {
            return name;
        }
    }
    return "";
}

impl primitive_methods_fact(type_name: str) -> str {
    registered = JAC_TYPE_REGISTRY.get(type_name);
    if registered is None {
        return "";
    }
    return ",".join(PRIMITIVE_METHODS.get(registered.emitter_suffix, []));
}

impl sealed_runtime_fact -> str {
    import from jaclang.project.modresolver { required_package_root }
    manifest = os.path.join(required_package_root(), PRECOMPILED_DIR, SEALED_MANIFEST);
    return "1" if os.path.isfile(manifest) else "";
}

impl import_paths_fact -> str {
    import from jaclang.project.modresolver { search_roots }
    return FACT_SEP.join(search_roots().interpreter);
}

impl package_store_fact -> str {
    return str(store_root());
}

impl stdlib_modules_fact -> str {
    return FACT_SEP.join(STDLIB_MODULES);
}

impl git_repo_root(path: str) -> (str | None) {
    current = os.path.realpath(path);
    while True {
        if os.path.exists(os.path.join(current, ".git")) {
            return current;
        }
        parent = os.path.dirname(current);
        if parent == current {
            return None;
        }
        current = parent;
    }
}

impl global_excludes_file -> str {
    config_home = os.environ.get("XDG_CONFIG_HOME", "");
    if not config_home {
        home = os.environ.get("HOME", "");
        if not home {
            return "";
        }
        config_home = os.path.join(home, ".config");
    }
    return os.path.join(config_home, "git", "ignore");
}

impl ignore_rules_of(base: str, text: str) -> list[IgnoreRule] {
    rules: list[IgnoreRule] = [];
    for raw in text.splitlines() {
        line = raw.rstrip("\r");
        while line.endswith(" ") and not line.endswith("\\ ") {
            line = line[:-1];
        }
        if not line or line.startswith("#") {
            continue;
        }
        negated = False;
        if line.startswith("!") {
            negated = True;
            line = line[1:];
        } elif line.startswith("\\!") or line.startswith("\\#") {
            line = line[1:];
        }
        dir_only = line.endswith("/");
        if dir_only {
            line = line.rstrip("/");
        }
        if not line {
            continue;
        }
        anchored = "/" in line;
        if line.startswith("/") {
            line = line[1:];
        }
        segments = [
            s
            for s in line.split("/")
            if s
        ];
        if not segments {
            continue;
        }
        rules.append(
            IgnoreRule(
                base=base,
                segments=segments,
                negated=negated,
                dir_only=dir_only,
                anchored=anchored
            )
        );
    }
    return rules;
}

impl ignore_rules_in(path: str, base: str) -> list[IgnoreRule] {
    cached = _IGNORE_RULES.get(path);
    if cached is not None {
        return cached;
    }
    rules: list[IgnoreRule] = [];
    if os.path.isfile(path) {
        with open(path, encoding="utf-8") as handle {
            rules = ignore_rules_of(base, handle.read());
        }
    }
    _IGNORE_RULES[path] = rules;
    return rules;
}

impl segments_match(pattern: list[str], parts: list[str]) -> bool {
    if not pattern {
        return not parts;
    }
    head = pattern[0];
    if head == "**" {
        rest = pattern[1:];
        if not rest {
            return True;
        }
        for start in range(len(parts) + 1) {
            if segments_match(rest, parts[start:]) {
                return True;
            }
        }
        return False;
    }
    if not parts {
        return False;
    }
    if not fnmatch.fnmatchcase(parts[0], head) {
        return False;
    }
    return segments_match(pattern[1:], parts[1:]);
}

impl rule_matches(rule: IgnoreRule, path: str, is_dir: bool) -> bool {
    if rule.dir_only and not is_dir {
        return False;
    }
    if not path.startswith(rule.base + os.sep) {
        return False;
    }
    parts = path[len(rule.base) + 1:].split(os.sep);
    if rule.anchored {
        return segments_match(rule.segments, parts);
    }
    return fnmatch.fnmatchcase(parts[-1], rule.segments[0]);
}

impl rules_for(repo: str, directory: str) -> list[IgnoreRule] {
    rules: list[IgnoreRule] = [];
    excludes = global_excludes_file();
    if excludes {
        rules.extend(ignore_rules_in(excludes, repo));
    }
    rules.extend(ignore_rules_in(os.path.join(repo, ".git", "info", "exclude"), repo));
    chain: list[str] = [];
    current = directory;
    while True {
        chain.append(current);
        if current == repo {
            break;
        }
        parent = os.path.dirname(current);
        if parent == current {
            break;
        }
        current = parent;
    }
    for folder in reversed(chain) {
        rules.extend(ignore_rules_in(os.path.join(folder, ".gitignore"), folder));
    }
    return rules;
}

impl ignored_by_rules(repo: str, path: str, is_dir: bool) -> bool {
    ignored = False;
    for rule in rules_for(repo, os.path.dirname(path)) {
        if rule_matches(rule, path, is_dir) {
            ignored = not rule.negated;
        }
    }
    return ignored;
}

impl is_git_ignored(repo: str, path: str, is_dir: bool) -> bool {
    parent = os.path.dirname(path);
    if parent != repo and parent.startswith(repo + os.sep) {
        held = _IGNORED_DIRS.get(parent);
        if held is None {
            held = is_git_ignored(repo, parent, True);
            _IGNORED_DIRS[parent] = held;
        }
        if held {
            return True;
        }
    }
    return ignored_by_rules(repo, path, is_dir);
}

impl jac_files_under(root_dir: str) -> list[str] {
    found: list[str] = [];
    pending: list[str] = [root_dir];
    while pending {
        directory = pending.pop();
        for name in sorted(os.listdir(directory)) {
            full = os.path.join(directory, name);
            if os.path.isdir(full) {
                if not name.startswith(".")
                    and name not in GIT_WALK_SKIP
                    and not os.path.islink(full) {
                    pending.append(full);
                }
            } elif name.endswith(".jac") {
                found.append(os.path.realpath(full));
            }
        }
    }
    return found;
}

impl git_ignored_fact(root_dir: str) -> str {
    repo = git_repo_root(root_dir);
    if repo is None {
        return "";
    }
    _IGNORE_RULES.clear();
    _IGNORED_DIRS.clear();
    ignored: list[str] = [];
    for path in jac_files_under(root_dir) {
        if path.startswith(repo + os.sep) and is_git_ignored(repo, path, False) {
            ignored.append(path);
        }
    }
    return FACT_SEP.join(sorted(ignored));
}
