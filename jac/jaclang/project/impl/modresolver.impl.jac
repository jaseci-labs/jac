impl install_search_roots(interpreter_paths: list[str]) {
    roots = SearchRoots();
    for path in interpreter_paths {
        if path and os.path.isabs(path) and path not in roots.interpreter {
            roots.interpreter.append(path);
        }
    }
    for path in roots.interpreter {
        if os.path.basename(path) in SITE_DIR_NAMES and os.path.isdir(path) {
            roots.sites.append(path);
            for (name, target) in editable_mappings(path).items() {
                if name not in roots.editable {
                    roots.editable[name] = target;
                }
            }
        }
    }
    _SEARCH_ROOTS.clear();
    _SEARCH_ROOTS.append(roots);
    _DECLARED_VIRTUAL.clear();
    _DECLARED_SCANNED.clear();
}

impl search_roots -> SearchRoots {
    if not _SEARCH_ROOTS {
        raise RuntimeError(
            "no Python search roots are installed: the compile request carries "
            "the interpreter's module search path and the kernel installs it "
            "with install_search_roots before resolving imports"
        );
    }
    return _SEARCH_ROOTS[0];
}

impl editable_mappings(site_dir: str) -> dict[str, str] {
    found: dict[str, str] = {};
    for name in sorted(os.listdir(site_dir)) {
        if name.startswith(EDITABLE_FINDER_PREFIX)
            and name.endswith(EDITABLE_FINDER_SUFFIX) {
            for (top, target) in editable_mapping_of(os.path.join(site_dir, name)).items() {
                if top not in found {
                    found[top] = target;
                }
            }
        }
    }
    return found;
}

impl quoted_strings(text: str) -> list[str] {
    found: list[str] = [];
    i = 0;
    while i < len(text) {
        quote = text[i];
        if quote != "'" and quote != '"' {
            i += 1;
            continue;
        }
        i += 1;
        chars: list[str] = [];
        while i < len(text) and text[i] != quote {
            if text[i] == "\\" and i + 1 < len(text) {
                i += 1;
            }
            chars.append(text[i]);
            i += 1;
        }
        found.append("".join(chars));
        i += 1;
    }
    return found;
}

impl editable_mapping_of(finder_path: str) -> dict[str, str] {
    with open(finder_path, encoding='utf-8') as handle {
        text = handle.read();
    }
    mapping: dict[str, str] = {};
    for line in text.splitlines() {
        if not line.startswith('MAPPING') or '=' not in line {
            continue;
        }
        strings = quoted_strings(line[line.index('=') + 1:]);
        pair = 0;
        while pair + 1 < len(strings) {
            mapping[strings[pair]] = strings[pair + 1];
            pair += 2;
        }
        break;
    }
    return mapping;
}

impl use_stub_catalog(catalog: (StubCatalog | None)) {
    _STUB_CATALOG.clear();
    if catalog is not None {
        _STUB_CATALOG.append(catalog);
    }
}

impl active_stub_catalog -> (StubCatalog | None) {
    return _STUB_CATALOG[0] if _STUB_CATALOG else None;
}

impl push_import_base(base_dir: str) {
    _import_base_stack.append(base_dir);
}

impl pop_import_base {
    if _import_base_stack {
        _import_base_stack.pop();
    }
}

impl probe_python_root(root: str, name: str) -> PythonProbe {
    probe = PythonProbe();
    stem = os.path.join(root, name);
    is_dir = os.path.isdir(stem);
    if is_dir {
        init_names: list[str] = [];
        for suffix in module_suffixes() {
            init_names.append('__init__' + suffix);
        }
        init_names.extend(['__init__.py', '__init__.pyi']);
        init = _find_under(stem, init_names);
        if init is not None {
            probe.origin = init;
            probe.package_dir = stem;
            return probe;
        }
    }
    for suffix in module_suffixes() + list(PY_SOURCE_SUFFIXES) {
        if os.path.isfile(stem + suffix) {
            probe.origin = stem + suffix;
            return probe;
        }
    }
    if os.path.isdir(root) {
        prefix = name + '.';
        for entry_name in sorted(os.listdir(root)) {
            if entry_name.startswith(prefix)
                and entry_name.endswith(PY_EXTENSION_SUFFIXES)
                and os.path.isfile(os.path.join(root, entry_name)) {
                probe.origin = os.path.join(root, entry_name);
                return probe;
            }
        }
    }
    if is_dir {
        probe.namespace_dir = stem;
    }
    return probe;
}

impl find_python_module(parts: list[str]) -> (PythonModuleSite | None) {
    if not parts {
        return None;
    }
    roots = search_roots();
    search: list[str] = list(roots.interpreter);
    last = len(parts) - 1;
    for (index, part) in enumerate(parts) {
        found = PythonProbe();
        portions: list[str] = [];
        editable = roots.editable.get(part) if index == 0 else None;
        if editable is not None {
            found = probe_python_root(os.path.dirname(editable), os.path.basename(editable));
            if not found.origin and found.namespace_dir {
                portions.append(found.namespace_dir);
            }
        }
        if not found.origin and not portions {
            for root in search {
                probe = probe_python_root(root, part);
                if probe.origin {
                    found = probe;
                    break;
                }
                if probe.namespace_dir {
                    portions.append(probe.namespace_dir);
                }
            }
        }
        if found.origin {
            if index == last {
                return PythonModuleSite(origin=found.origin);
            }
            if not found.package_dir {
                return None;
            }
            search = [found.package_dir];
            continue;
        }
        if not portions {
            return None;
        }
        if index == last {
            return PythonModuleSite(namespace_dirs=portions);
        }
        search = portions;
    }
    return None;
}

impl find_project_root(start: (Path | None) = None) -> (tuple[Path, Path] | None) {
    if start is None {
        start = Path(os.getcwd());
    }
    current = os.path.abspath(str(start));
    if os.path.isfile(current) {
        current = os.path.dirname(current);
    }
    while True {
        toml_path = os.path.join(current, 'jac.toml');
        if os.path.isfile(toml_path) {
            return (Path(current), Path(toml_path));
        }
        parent = os.path.dirname(current);
        if parent == current {
            return None;
        }
        current = parent;
    }
}

impl find_jac_project_root(start: (str | None) = None) -> (str | None) {
    if start {
        current = os.path.abspath(start);
        if os.path.isfile(current) {
            current = os.path.dirname(current);
        }
    } else {
        current = os.getcwd();
    }
    if current in _project_root_cache {
        return _project_root_cache[current];
    }
    result = find_project_root(Path(current));
    found = str(result[0]) if result else None;
    _project_root_cache[current] = found;
    return found;
}

impl is_scoped_package_name(name: str) -> bool {
    parts = (name or '').split('/');
    if len(parts) != 2 {
        return False;
    }
    for part in parts {
        if not part or not part.isascii() or not part[0].isalpha() {
            return False;
        }
        if part != part.lower() {
            return False;
        }
        if not part.replace('_', '').isalnum() {
            return False;
        }
    }
    return True;
}

impl _ensure_self_mount(mounts: str, name: str, project_root: str) {
    parts = name.split('/');
    link = os.path.join(mounts, parts[0], parts[1]);
    if os.path.lexists(link) {
        return;
    }
    os.makedirs(os.path.dirname(link), exist_ok=True);
    os.symlink(os.path.realpath(project_root), link, target_is_directory=True);
}

impl _mounts_entry(project_root: str) -> tuple[str, str] {
    import from jaclang.project.config { get_config_for_dir }
    if project_root not in _mounts_by_root {
        cfg = get_config_for_dir(project_root);
        if cfg is None {
            raise RuntimeError(f"no jac.toml configuration under {project_root}");
        }
        mounts = os.path.join(project_root, cfg.build.dir, MOUNTS_DIR_NAME);
        _mounts_by_root[project_root] = (mounts, cfg.project.name);
    }
    return _mounts_by_root[project_root];
}

impl project_mounts_dir(project_root: str) -> str {
    return _mounts_entry(project_root)[0];
}

impl enclosing_mounts(project_root: str) -> (str | None) {
    mounts = os.path.dirname(os.path.dirname(os.path.normpath(project_root)));
    if os.path.basename(mounts) == MOUNTS_DIR_NAME
        and os.path.basename(os.path.dirname(mounts)) == '.jac' {
        return mounts;
    }
    return None;
}

impl project_mounts(project_root: str) -> (str | None) {
    (mounts, name) = _mounts_entry(project_root);
    if project_root not in _self_mounted {
        _self_mounted.add(project_root);
        if is_scoped_package_name(name) {
            _ensure_self_mount(mounts, name, project_root);
        }
    }
    return mounts if os.path.isdir(mounts) else None;
}

impl module_name_in(root_dir: str, path: str) -> (str | None) {
    real_root = os.path.realpath(root_dir);
    real_path = os.path.realpath(path);
    if not real_path.startswith(real_root + os.sep) {
        return None;
    }
    rel = os.path.relpath(real_path, real_root);
    stem = '';
    if rel.endswith('.jac') {
        stem = rel[:-4];
    } elif rel.endswith('.py') {
        stem = rel[:-3];
    } else {
        return None;
    }
    parts = stem.split(os.sep);
    if parts and parts[-1] == '__init__' {
        parts = parts[:-1];
    }
    if not parts {
        return None;
    }
    for part in parts {
        if not part.isidentifier() {
            return None;
        }
    }
    return '.'.join(parts);
}

impl get_jac_search_paths(base_path: (str | None) = None) -> list[str] {
    paths: list[str] = [];
    if base_path {
        paths.append(base_path);
    }
    active_base = _import_base_stack[-1] if _import_base_stack else None;
    if active_base {
        paths.append(active_base);
    }
    project_root = find_jac_project_root(base_path or active_base);
    if project_root {
        paths.append(project_root);
    }
    for owner in (project_root, find_jac_project_root(None)) {
        if not owner {
            continue;
        }
        around = enclosing_mounts(owner);
        if around {
            paths.append(around);
            nested = project_mounts_dir(owner);
            if os.path.isdir(nested) {
                paths.append(nested);
            }
            continue;
        }
        mounts = project_mounts(owner);
        if mounts {
            paths.append(mounts);
        }
    }
    paths.append(os.getcwd());
    jacpath = os.environ.get('JACPATH', '');
    for part in jacpath.split(os.pathsep) {
        if part.strip() {
            paths.append(part.strip());
        }
    }
    paths.extend(search_roots().interpreter);
    unique: list[str] = [];
    for path in paths {
        if path and path not in unique {
            unique.append(path);
        }
    }
    return unique;
}

impl required_package_root -> str {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    pkg_dir = jaclang_pkg_root();
    if not pkg_dir {
        raise RuntimeError(
            "the jaclang package pkg_dir is not set; the kernel sets it from the "
            "request before resolving modules"
        );
    }
    return pkg_dir;
}

impl language_of(path: str) -> str {
    tables = host_layout_tables();
    if path.endswith(tables.jac_suffix) {
        return 'jac';
    }
    if path.endswith('.pyi') {
        return 'pyi';
    }
    if path.endswith('.py') {
        return 'py';
    }
    for suffix in tables.foreign_suffixes {
        if suffix not in ('.py', '.pyi') and path.endswith(suffix) {
            return 'js';
        }
    }
    return 'other';
}

impl module_suffixes -> list[str] {
    return list(host_layout_tables().module_suffixes);
}

impl subtree_has_jac(directory: str) -> bool {
    jac_suffix = host_layout_tables().jac_suffix;
    stack: list[str] = [directory];
    while stack {
        current = stack.pop();
        if not os.access(current, os.R_OK | os.X_OK) {
            continue;
        }
        subdirs: list[str] = [];
        for name in os.listdir(current) {
            full = os.path.join(current, name);
            if os.path.islink(full) {
                if os.path.isfile(os.path.join(full, 'jac.toml')) {
                    return True;
                }
                if name.endswith(jac_suffix) and os.path.isfile(full) {
                    return True;
                }
                continue;
            }
            if os.path.isdir(full) {
                if not name.startswith('.') and name not in WALK_SKIP_DIRS {
                    subdirs.append(full);
                }
            } elif name.endswith(jac_suffix) {
                return True;
            }
        }
        stack.extend(subdirs);
    }
    return False;
}

impl is_jac_namespace_package(directory: str) -> bool {
    if os.path.isfile(os.path.join(directory, '__init__.py')) {
        return False;
    }
    for init_name in host_layout_tables().init_files {
        if os.path.isfile(os.path.join(directory, init_name)) {
            return False;
        }
    }
    return subtree_has_jac(directory);
}

impl case_blind_filesystem -> bool {
    if not _CASE_BLIND_FS {
        probe = os.path.realpath(required_package_root());
        folder = os.path.dirname(probe);
        swapped = os.path.join(folder, os.path.basename(probe).swapcase());
        _CASE_BLIND_FS.append(swapped != probe and os.path.exists(swapped));
    }
    return _CASE_BLIND_FS[0];
}

impl named_exactly_any(candidate: str) -> bool {
    if not case_blind_filesystem() {
        return True;
    }
    folder = os.path.dirname(candidate) or ".";
    if not os.path.isdir(folder) {
        return True;
    }
    wanted = os.path.basename(candidate);
    for name in os.listdir(folder) {
        if name == wanted or name.startswith(wanted + ".") {
            return True;
        }
    }
    return False;
}

impl _find_under(directory: str, file_names: list[str]) -> (str | None) {
    for name in file_names {
        candidate = os.path.join(directory, name);
        if os.path.isfile(candidate) {
            return candidate;
        }
    }
    return None;
}

impl resolve_local_module(base: str, parts: list[str]) -> (tuple[(str, str)] | None) {
    candidate = os.path.join(base, *parts);
    if parts and not named_exactly_any(candidate) {
        return None;
    }
    if os.path.isdir(candidate) {
        for (init_name, lang) in (
            ('__init__.jac', 'jac'),
            ('__init__.py', 'py'),
            ('__init__.pyi', 'pyi')
        ) {
            init = os.path.join(candidate, init_name);
            if os.path.isfile(init) {
                return (init, lang);
            }
        }
    }
    for jac_suffix in module_suffixes() {
        if os.path.isfile(candidate + jac_suffix) {
            return (candidate + jac_suffix, 'jac');
        }
    }
    for (suffix, lang) in (('.py', 'py'), ('.pyi', 'pyi'), ('.js', 'js')) {
        if os.path.isfile(candidate + suffix) {
            return (candidate + suffix, lang);
        }
    }
    return None;
}

impl _namespace_candidate(base: str, parts: list[str]) -> (tuple[(str, str)] | None) {
    candidate = os.path.join(base, *parts);
    if os.path.isdir(candidate) and is_jac_namespace_package(candidate) {
        return (candidate, 'jac');
    }
    return None;
}

impl _self_tree_candidate(
    base_dir: str, actual_parts: list[str]
) -> (tuple[(str, str)] | None) {
    is_compiler_pkg = actual_parts[0] == COMPILER_PACKAGE;
    cur = os.path.abspath(base_dir);
    while True {
        parent = os.path.dirname(cur);
        if parent == cur {
            return None;
        }
        if os.path.basename(cur) == actual_parts[0] {
            if not is_compiler_pkg or os.path.isdir(os.path.join(cur, 'compiler')) {
                res = resolve_local_module(parent, actual_parts);
                if res {
                    return res;
                }
                res = _namespace_candidate(parent, actual_parts);
                if res {
                    return res;
                }
            }
        }
        cur = parent;
    }
}

impl virtual_module_basenames(module_name: str) -> list[str] {
    source = JAC_VIRTUAL_MODULE_SOURCES.get(module_name);
    if source is None or source == module_name {
        return [module_name];
    }
    return [source, module_name];
}

impl parse_entry_points(text: str) -> dict[str, dict[str, str]] {
    groups: dict[str, dict[str, str]] = {};
    current: (dict[str, str] | None) = None;
    for raw in text.splitlines() {
        line = raw.strip();
        if not line or line.startswith('#') or line.startswith(';') {
            continue;
        }
        if line.startswith('[') and line.endswith(']') {
            name = line[1:-1].strip();
            if name not in groups {
                groups[name] = {};
            }
            current = groups[name];
            continue;
        }
        if current is None or '=' not in line {
            continue;
        }
        key = line[:line.index('=')].strip();
        current[key] = line[line.index('=') + 1:].strip();
    }
    return groups;
}

impl declared_virtual_modules -> dict[str, JacVirtualModule] {
    if _DECLARED_SCANNED {
        return _DECLARED_VIRTUAL;
    }
    _DECLARED_SCANNED.append(True);
    for site in search_roots().sites {
        for name in sorted(os.listdir(site)) {
            if not name.endswith('.dist-info') {
                continue;
            }
            points = os.path.join(site, name, 'entry_points.txt');
            if not os.path.isfile(points) {
                continue;
            }
            with open(points, encoding='utf-8') as handle {
                groups = parse_entry_points(handle.read());
            }
            for (module_name, rel) in groups.get(JAC_MODULES_GROUP, {}).items() {
                declared = _DECLARED_VIRTUAL.get(module_name);
                if declared is None {
                    declared = JacVirtualModule(name=module_name);
                    _DECLARED_VIRTUAL[module_name] = declared;
                }
                if not declared.path {
                    declared.path = os.path.normpath(os.path.join(site, rel));
                }
            }
            for (module_name, names) in groups.get(JAC_MODULE_EXPORTS_GROUP, {}).items() {
                declared = _DECLARED_VIRTUAL.get(module_name);
                if declared is None {
                    declared = JacVirtualModule(name=module_name);
                    _DECLARED_VIRTUAL[module_name] = declared;
                }
                if not declared.exports {
                    declared.exports = [
                        n.strip()
                        for n in names.split(',')
                        if n.strip()
                    ];
                }
            }
        }
    }
    return _DECLARED_VIRTUAL;
}

impl _resolve_jac_virtual_module(target: str) -> (tuple[(str, str)] | None) {
    import from jaclang.compiler.backends.es.backends.registry { resolve_active_backend }
    if not target.startswith(JAC_VIRTUAL_PREFIX) {
        return None;
    }
    module_name = target[len(JAC_VIRTUAL_PREFIX):];
    runtime_dir = os.path.join(required_package_root(), 'client');
    if module_name == 'runtime' {
        path = os.path.join(
            runtime_dir, resolve_active_backend().runtime_source_basename()
        );
        if os.path.isfile(path) {
            return (path, 'jac');
        }
    }
    for basename in virtual_module_basenames(module_name) {
        for (ext, lang) in (('.jac', 'jac'), ('.js', 'js')) {
            path = os.path.join(runtime_dir, basename + ext);
            if os.path.isfile(path) {
                return (path, lang);
            }
        }
    }
    declared = declared_virtual_modules().get(module_name);
    if declared is not None and declared.path and os.path.isfile(declared.path) {
        return (declared.path, 'jac');
    }
    return None;
}

impl resolve_jac_virtual_module_path(target: str) -> (str | None) {
    result = _resolve_jac_virtual_module(target);
    return result[0] if result else None;
}

impl resolve_jac_virtual_module_exports(target: str) -> list[str] {
    if not target.startswith(JAC_VIRTUAL_PREFIX) {
        return [];
    }
    declared = declared_virtual_modules().get(target[len(JAC_VIRTUAL_PREFIX):]);
    return list(declared.exports) if declared is not None else [];
}

impl _get_path_aliases -> dict[str, str] {
    config = get_config();
    if config is None {
        return {};
    }
    return dict(config.client.paths);
}

impl _resolve_path_alias(target: str, base_path: str) -> (str | None) {
    if not target.startswith('@') {
        return None;
    }
    aliases = _get_path_aliases();
    if not aliases {
        return None;
    }
    config = get_config();
    project_root = str(config.project_root) if config and config.project_root else '';
    if not project_root {
        project_root = os.path.dirname(base_path)
            if os.path.isfile(base_path)
            else base_path;
    }
    for (alias_pattern, target_path) in aliases.items() {
        if alias_pattern.endswith('/*') {
            prefix = alias_pattern[:-2];
            if target.startswith(prefix + '/') or target == prefix {
                target_base = target_path.rstrip('/*').lstrip('./');
                if target == prefix {
                    resolved = target_base;
                } else {
                    resolved = os.path.join(target_base, target[len(prefix) + 1:]);
                }
                return os.path.join(project_root, resolved);
            }
        } elif target == alias_pattern {
            return os.path.join(project_root, target_path.lstrip('./'));
        }
    }
    return None;
}

impl is_path_alias_import(target: str, base_path: str) -> bool {
    return _resolve_path_alias(target, base_path) is not None;
}

impl resolve_module(
    target: str, base_path: str, string_spec: bool = False
) -> tuple[(str, str)] {
    base_dir = os.path.dirname(base_path);
    jac_virtual = _resolve_jac_virtual_module(target);
    if jac_virtual {
        return jac_virtual;
    }
    alias_resolved = _resolve_path_alias(target, base_path);
    if alias_resolved {
        res = resolve_local_module(
            os.path.dirname(alias_resolved), [os.path.basename(alias_resolved)]
        );
        if res {
            return res;
        }
        if os.path.isfile(alias_resolved) {
            return (alias_resolved, language_of(alias_resolved));
        }
    }
    if target.startswith('.') {
        other_target = os.path.join(base_dir, convert_to_js_import_path(target));
    } else {
        other_target = os.path.join(base_dir, target);
    }
    if os.path.isfile(other_target) {
        return (os.path.normpath(other_target), 'other');
    }
    if string_spec and not target.startswith('.') {
        return (target, 'js');
    }
    if not target.startswith('.') {
        actual_parts = [
            p
            for p in target.split('.')
            if p
        ];
        if not in_typeshed_tree(base_path) and not in_native_library(base_path) {
            res = resolve_local_module(base_dir, actual_parts);
            if res {
                return res;
            }
            res = _self_tree_candidate(base_dir, actual_parts);
            if res {
                return res;
            }
        }
        res = _candidate_from_stub_catalog(actual_parts);
        if res {
            return res;
        }
        if not _stub_catalog_active() {
            for typeshed_dir in get_typeshed_paths() {
                res = _candidate_from_typeshed(typeshed_dir, actual_parts);
                if res {
                    return res;
                }
            }
        }
        for sp in get_jac_search_paths(base_path) {
            res = _candidate_from_stub_package(sp, actual_parts);
            if res {
                return res;
            }
        }
        site = find_python_module(actual_parts);
        if site is not None and site.origin {
            origin = os.path.normpath(site.origin);
            lang = language_of(origin);
            if lang != 'other' and named_exactly_any(origin) {
                return (origin, lang);
            }
        }
        if site is not None and not site.origin {
            for loc in site.namespace_dirs {
                res = _namespace_candidate(
                    os.path.dirname(loc), [os.path.basename(loc)]
                );
                if res {
                    return res;
                }
            }
        }
    }
    parts = target.split('.');
    level = 0;
    while level < len(parts) and parts[level] == '' {
        level += 1;
    }
    actual_parts = parts[level:];
    base_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path);
    for _ in range(max(level - 1, 0)) {
        base_dir = os.path.dirname(base_dir);
    }
    if level > 0 {
        res = resolve_local_module(base_dir, actual_parts);
        if res {
            return res;
        }
    }
    for sp in get_jac_search_paths(base_path) {
        res = resolve_local_module(sp, actual_parts);
        if res {
            return res;
        }
    }
    if level == 0 {
        res = resolve_local_module(base_dir, actual_parts);
        if res {
            return res;
        }
    }
    jacpath = os.environ.get('JACPATH', '');
    if jacpath {
        res = resolve_local_module(jacpath, actual_parts);
        if res {
            return res;
        }
        wanted = [
            (actual_parts[-1] + '.jac', 'jac'),
            (actual_parts[-1] + '.py', 'py'),
            (actual_parts[-1] + '.js', 'js')
        ];
        pending: list[str] = [jacpath];
        while pending {
            walk_dir = pending.pop(0);
            if not os.path.isdir(walk_dir) {
                continue;
            }
            names = sorted(os.listdir(walk_dir));
            for (file_name, lang) in wanted {
                if file_name in names
                    and os.path.isfile(os.path.join(walk_dir, file_name)) {
                    return (os.path.join(walk_dir, file_name), lang);
                }
            }
            for name in names {
                if os.path.isdir(os.path.join(walk_dir, name)) {
                    pending.append(os.path.join(walk_dir, name));
                }
            }
        }
    }
    if not target.startswith('.') {
        res = _namespace_candidate(base_dir, actual_parts);
        if res {
            return res;
        }
        for sp in get_jac_search_paths(base_path) {
            res = _namespace_candidate(sp, actual_parts);
            if res {
                return res;
            }
        }
    }
    return (os.path.join(base_dir, *actual_parts), 'py');
}

impl infer_language(target: str, base_path: str, string_spec: bool = False) -> str {
    (_, lang) = resolve_module(target, base_path, string_spec=string_spec);
    return lang;
}

impl resolve_relative_path(
    target: str, base_path: str, string_spec: bool = False
) -> str {
    (path, _) = resolve_module(target, base_path, string_spec=string_spec);
    return path;
}

impl _find_npm_package(
    spec: str, base_path: str
) -> (tuple[(str, list[str], str)] | None) {
    if not spec or spec.startswith('.') {
        return None;
    }
    project_root = find_jac_project_root(base_path);
    if not project_root {
        return None;
    }
    node_modules = os.path.join(project_root, '.jac', 'client', 'node_modules');
    if not os.path.isdir(node_modules) {
        return None;
    }
    parts = [
        p
        for p in spec.split('/')
        if p
    ];
    if not parts {
        return None;
    }
    pkg_parts = parts[:1];
    subpath = parts[1:];
    if spec.startswith('@') and len(parts) >= 2 {
        pkg_parts = parts[:2];
        subpath = parts[2:];
    }
    pkg_dir = os.path.join(node_modules, *pkg_parts);
    if not os.path.isdir(pkg_dir) {
        return None;
    }
    return (pkg_dir, subpath, node_modules);
}

impl npm_text(value: object) -> str {
    return value if isinstance(value, str) else '';
}

impl npm_export_of(value: object) -> NpmExport {
    if isinstance(value, str) {
        return NpmExport(path=value);
    }
    export_node = NpmExport();
    if isinstance(value, list) {
        for item in value {
            export_node.targets.append(npm_export_of(item));
        }
    } elif isinstance(value, dict) {
        for (key, item) in value.items() {
            if key.startswith('.') {
                export_node.subpaths.append((key, npm_export_of(item)));
            } else {
                export_node.conditions.append((key, npm_export_of(item)));
            }
        }
    }
    return export_node;
}

impl _read_package_json(pkg_dir: str) -> NpmPackageJson {
    import json;
    pkg_json = os.path.join(pkg_dir, 'package.json');
    if not os.path.isfile(pkg_json) {
        return NpmPackageJson();
    }
    with open(pkg_json, 'r', encoding='utf-8') as f {
        data = json.loads(f.read());
    }
    if not isinstance(data, dict) {
        raise ValueError(f"{pkg_json}: package.json is not an object");
    }
    return NpmPackageJson(
        module=npm_text(data.get('module')),
        main=npm_text(data.get('main')),
        types=npm_text(data.get('types')),
        typings=npm_text(data.get('typings')),
        exports=npm_export_of(data['exports']) if 'exports' in data else None
    );
}

impl _resolve_export_target(
    target: NpmExport,
    conditions: tuple[str, ...],
    pkg_dir: str,
    star_sub: (str | None) = None
) -> (str | None) {
    if target.path {
        rel = target.path;
        if star_sub is not None and '*' in rel {
            rel = rel.replace('*', star_sub);
        }
        candidate = os.path.normpath(os.path.join(pkg_dir, rel));
        return candidate if os.path.isfile(candidate) else None;
    }
    for item in target.targets {
        resolved = _resolve_export_target(item, conditions, pkg_dir, star_sub);
        if resolved {
            return resolved;
        }
    }
    for (key, value) in target.conditions {
        if key in conditions or key == 'default' {
            resolved = _resolve_export_target(value, conditions, pkg_dir, star_sub);
            if resolved {
                return resolved;
            }
        }
    }
    return None;
}

impl _resolve_pkg_exports(
    exports: NpmExport, subpath: str, conditions: tuple[str, ...], pkg_dir: str
) -> (str | None) {
    if not exports.subpaths {
        if subpath == '.' {
            return _resolve_export_target(exports, conditions, pkg_dir);
        }
        return None;
    }
    for (key, value) in exports.subpaths {
        if key == subpath {
            return _resolve_export_target(value, conditions, pkg_dir);
        }
    }
    best: (NpmExport | None) = None;
    best_prefix = '';
    best_sub: (str | None) = None;
    for (key, value) in exports.subpaths {
        if '*' not in key {
            continue;
        }
        (prefix, _, suffix) = key.partition('*');
        if subpath.startswith(prefix)
            and subpath.endswith(suffix)
            and len(subpath) >= len(prefix) + len(suffix) {
            if best is None or len(prefix) > len(best_prefix) {
                best = value;
                best_prefix = prefix;
                best_sub = subpath[len(prefix):len(subpath) - len(suffix)]
                    if suffix
                    else subpath[len(prefix):];
            }
        }
    }
    if best is not None {
        return _resolve_export_target(best, conditions, pkg_dir, star_sub=best_sub);
    }
    return None;
}

impl has_client_npm_package(spec: str, base_path: str) -> bool {
    return _find_npm_package(spec, base_path) is not None;
}

impl resolve_client_npm_package(spec: str, base_path: str) -> (str | None) {
    found = _find_npm_package(spec, base_path);
    if found is None {
        return None;
    }
    (pkg_dir, subpath, _) = found;
    data = _read_package_json(pkg_dir);
    if data.exports is not None {
        subpath_key = './' + '/'.join(subpath) if subpath else '.';
        resolved = _resolve_pkg_exports(
            data.exports, subpath_key, NPM_RUNTIME_CONDITIONS, pkg_dir
        );
        if resolved {
            return resolved;
        }
    }
    if subpath {
        target = os.path.join(pkg_dir, *subpath);
        deep = _npm_file_with_ext(target);
        if deep {
            return deep;
        }
        if os.path.isdir(target) {
            return _npm_package_entry(target, _read_package_json(target));
        }
        return None;
    }
    return _npm_package_entry(pkg_dir, data);
}

impl resolve_client_npm_declarations(spec: str, base_path: str) -> (str | None) {
    found = _find_npm_package(spec, base_path);
    if found is None {
        return None;
    }
    (pkg_dir, subpath, node_modules) = found;
    data = _read_package_json(pkg_dir);
    if data.exports is not None {
        subpath_key = './' + '/'.join(subpath) if subpath else '.';
        resolved = _resolve_pkg_exports(
            data.exports, subpath_key, NPM_TYPES_CONDITIONS, pkg_dir
        );
        if resolved and resolved.endswith(NPM_DTS_SUFFIXES) {
            return resolved;
        }
    }
    if subpath {
        target = os.path.join(pkg_dir, *subpath);
        for suffix in NPM_DTS_SUFFIXES {
            if os.path.isfile(target + suffix) {
                return os.path.normpath(target + suffix);
            }
        }
        nested = os.path.join(target, 'index.d.ts');
        if os.path.isfile(nested) {
            return os.path.normpath(nested);
        }
        deep_entry = resolve_client_npm_package(spec, base_path);
        if deep_entry {
            sibling = sibling_declaration_file(deep_entry);
            if sibling {
                return sibling;
            }
        }
    } else {
        for val in (data.types, data.typings) {
            if val {
                candidate = os.path.normpath(os.path.join(pkg_dir, val));
                if os.path.isfile(candidate) {
                    return candidate;
                }
            }
        }
        package_entry = resolve_client_npm_package(spec, base_path);
        if package_entry {
            sibling = sibling_declaration_file(package_entry);
            if sibling {
                return sibling;
            }
        }
        index_dts = os.path.join(pkg_dir, 'index.d.ts');
        if os.path.isfile(index_dts) {
            return os.path.normpath(index_dts);
        }
    }
    return _resolve_at_types_declarations(spec, subpath, node_modules);
}

impl _resolve_at_types_declarations(
    spec: str, subpath: list[str], node_modules: str
) -> (str | None) {
    parts = [
        p
        for p in spec.split('/')
        if p
    ];
    if parts[0].startswith('@') {
        if len(parts) < 2 {
            return None;
        }
        types_name = parts[0][1:] + '__' + parts[1];
    } else {
        types_name = parts[0];
    }
    types_dir = os.path.join(node_modules, '@types', types_name);
    if not os.path.isdir(types_dir) {
        return None;
    }
    if subpath {
        target = os.path.join(types_dir, *subpath);
        for suffix in NPM_DTS_SUFFIXES {
            if os.path.isfile(target + suffix) {
                return os.path.normpath(target + suffix);
            }
        }
        nested = os.path.join(target, 'index.d.ts');
        return os.path.normpath(nested) if os.path.isfile(nested) else None;
    }
    types_data = _read_package_json(types_dir);
    for val in (types_data.types, types_data.typings) {
        if val {
            candidate = os.path.normpath(os.path.join(types_dir, val));
            if os.path.isfile(candidate) {
                return candidate;
            }
        }
    }
    index_dts = os.path.join(types_dir, 'index.d.ts');
    return os.path.normpath(index_dts) if os.path.isfile(index_dts) else None;
}

impl sibling_declaration_file(js_path: str) -> (str | None) {
    (stem, ext) = os.path.splitext(js_path);
    preferred = '';
    if ext == '.mjs' {
        preferred = '.d.mts';
    } elif ext == '.cjs' {
        preferred = '.d.cts';
    } elif ext == '.js' {
        preferred = '.d.ts';
    }
    suffixes: list[str] = [preferred] if preferred else [];
    for suffix in NPM_DTS_SUFFIXES {
        if suffix != preferred {
            suffixes.append(suffix);
        }
    }
    for suffix in suffixes {
        candidate = stem + suffix;
        if os.path.isfile(candidate) {
            return os.path.normpath(candidate);
        }
    }
    return None;
}

impl _npm_file_with_ext(candidate: str) -> (str | None) {
    if os.path.isfile(candidate) {
        return os.path.normpath(candidate);
    }
    for ext in ('.js', '.mjs', '.cjs', '.json') {
        if os.path.isfile(candidate + ext) {
            return os.path.normpath(candidate + ext);
        }
    }
    return None;
}

impl _npm_package_entry(pkg_dir: str, data: NpmPackageJson) -> (str | None) {
    entries: list[str] = [];
    for val in (data.module, data.main) {
        if val {
            entries.append(os.path.join(pkg_dir, val));
        }
    }
    entries.append(os.path.join(pkg_dir, 'index'));
    for candidate in entries {
        resolved = _npm_file_with_ext(candidate);
        if resolved {
            return resolved;
        }
        nested = _npm_file_with_ext(os.path.join(candidate, 'index'));
        if nested {
            return nested;
        }
    }
    pkg_json = os.path.join(pkg_dir, 'package.json');
    if os.path.isfile(pkg_json) {
        return os.path.normpath(pkg_json);
    }
    return None;
}

impl get_typeshed_paths -> list[str] {
    stdlib = os.path.abspath(
        os.path.join(required_package_root(), 'vendor', 'typeshed', 'stdlib')
    );
    return [stdlib] if os.path.isdir(stdlib) else [];
}

impl in_typeshed_tree(path: str) -> bool {
    return "/vendor/typeshed/" in path.replace("\\", "/");
}

impl in_native_library(path: str) -> bool {
    return "/runtime/na_stdlib/" in path.replace("\\", "/");
}

impl _stub_catalog_active -> bool {
    return active_stub_catalog() is not None;
}

impl _candidate_from_stub_catalog(parts: list[str]) -> (tuple[(str, str)] | None) {
    if not parts {
        return None;
    }
    catalog = active_stub_catalog();
    if catalog is None {
        return None;
    }
    path = catalog.module_path(parts);
    if path is None {
        return None;
    }
    return (path, 'pyi');
}

impl _candidate_from_typeshed(
    base: str, parts: list[str]
) -> (tuple[(str, str)] | None) {
    if not parts {
        return None;
    }
    candidate_prefix = os.path.join(base, *parts);
    module_file_pyi = candidate_prefix + '.pyi';
    if os.path.isfile(module_file_pyi) {
        return (module_file_pyi, 'pyi');
    }
    if os.path.isdir(candidate_prefix) {
        init_pyi = os.path.join(candidate_prefix, '__init__.pyi');
        if os.path.isfile(init_pyi) {
            return (init_pyi, 'pyi');
        }
        inner_pkg_init_pyi = os.path.join(candidate_prefix, parts[-1], '__init__.pyi');
        if os.path.isfile(inner_pkg_init_pyi) {
            return (inner_pkg_init_pyi, 'pyi');
        }
    }
    return None;
}

impl _candidate_from_stub_package(
    base: str, parts: list[str]
) -> (tuple[(str, str)] | None) {
    if not parts {
        return None;
    }
    stub_root = os.path.join(base, parts[0] + '-stubs');
    if not os.path.isdir(stub_root) {
        return None;
    }
    rest = parts[1:];
    if not rest {
        init_pyi = os.path.join(stub_root, '__init__.pyi');
        return (init_pyi, 'pyi') if os.path.isfile(init_pyi) else None;
    }
    candidate_prefix = os.path.join(stub_root, *rest);
    module_file_pyi = candidate_prefix + '.pyi';
    if os.path.isfile(module_file_pyi) {
        return (module_file_pyi, 'pyi');
    }
    if os.path.isdir(candidate_prefix) {
        init_pyi = os.path.join(candidate_prefix, '__init__.pyi');
        if os.path.isfile(init_pyi) {
            return (init_pyi, 'pyi');
        }
    }
    return None;
}

impl is_untyped_third_party_module(path: str) -> bool {
    if not path.endswith('.py') {
        return False;
    }
    normalized = path.replace('\\', '/');
    if '/site-packages/' not in normalized and '/dist-packages/' not in normalized {
        return False;
    }
    if os.path.exists(path[:-3] + '.pyi') {
        return False;
    }
    pkg_dir = os.path.dirname(path);
    while os.path.basename(pkg_dir) not in SITE_DIR_NAMES {
        if os.path.exists(os.path.join(pkg_dir, 'py.typed')) {
            return False;
        }
        parent = os.path.dirname(pkg_dir);
        if parent == pkg_dir {
            break;
        }
        pkg_dir = parent;
    }
    return True;
}
