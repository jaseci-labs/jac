import importlib.util;
import os;
import sys;
import from pathlib { Path }
import from jaclang.jac0core.ext_registry { MODULE_SUFFIXES, language_of }

glob _project_root_cache: dict = {},
     _import_base_stack: list = [];

def push_import_base(base_dir: str) {
    _import_base_stack.append(base_dir);
}

def pop_import_base {
    if _import_base_stack {
        _import_base_stack.pop();
    }
}

def find_project_root(start: (Path | None) = None) -> (tuple | None) {
    if start is None {
        start = Path.cwd();
    }
    current = start.resolve();
    if current.is_file() {
        current = current.parent;
    }
    while current != current.parent {
        toml_path = current / 'jac.toml';
        if toml_path.exists() {
            return (current, toml_path);
        }
        current = current.parent;
    }
    toml_path = current / 'jac.toml';
    if toml_path.exists() {
        return (current, toml_path);
    }
    return None;
}

def find_jac_project_root(start: (str | None) = None) -> (str | None) {
    if start {
        current = os.path.abspath(start);
        if os.path.isfile(current) {
            current = os.path.dirname(current);
        }
    } else {
        current = os.getcwd();
    }
    if (current in _project_root_cache) {
        return _project_root_cache[current];
    }

    result = find_project_root(Path(current));
    found = str(result[0]) if result else None;
    _project_root_cache[current] = found;
    return found;
}

def get_jac_search_paths(base_path: (str | None) = None) -> list[str] {
    paths = [];
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
    paths.append(os.getcwd());
    if ('JACPATH' in os.environ) {
        paths.extend(
            p.strip()
            for p in os.environ['JACPATH'].split(os.pathsep)
            if p.strip()
        );
    }

    paths.extend(sys.path);
    return `list(
        `dict.fromkeys(
            [
                p
                for p in paths
                if p
            ]
        )
    );
}

def _candidate_from(base: str, parts: list[str]) -> (tuple[(str, str)] | None) {
    candidate = os.path.join(base, *parts);
    if os.path.isdir(candidate) {
        if os.path.isfile(os.path.join(candidate, '__init__.jac')) {
            return (os.path.join(candidate, '__init__.jac'), 'jac');
        }
        if os.path.isfile(os.path.join(candidate, '__init__.py')) {
            return (os.path.join(candidate, '__init__.py'), 'py');
        }
        if os.path.isfile(os.path.join(candidate, '__init__.pyi')) {
            return (os.path.join(candidate, '__init__.pyi'), 'pyi');
        }
    }

    for jac_suffix in MODULE_SUFFIXES {
        if os.path.isfile((candidate + jac_suffix)) {
            return ((candidate + jac_suffix), 'jac');
        }
    }
    if os.path.isfile((candidate + '.py')) {
        return ((candidate + '.py'), 'py');
    }

    if os.path.isfile((candidate + '.pyi')) {
        return ((candidate + '.pyi'), 'pyi');
    }
    if os.path.isfile((candidate + '.js')) {
        return ((candidate + '.js'), 'js');
    }
    return None;
}

def _resolve_jac_virtual_module(target: str) -> (tuple[(str, str)] | None) {
    if not target.startswith('@jac/') {
        return None;
    }
    import jaclang.runtimelib as _runtimelib;
    runtime_dir = os.path.dirname(_runtimelib.__file__);
    module_name = target[len('@jac/'):];

    if module_name == 'runtime' {
        import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
        path = resolve_client_runtime_cl_path();
        if os.path.isfile(path) {
            return (path, 'jac');
        }
    }

    for (ext, lang) in [('.cl.jac', 'jac'), ('.jac', 'jac'), ('.js', 'js')] {
        path = os.path.join(runtime_dir, (module_name + ext));
        if os.path.isfile(path) {
            return (path, lang);
        }
    }

    try {
        import importlib.metadata as _meta;
        for ep in _meta.entry_points(group='jac.modules') {
            if ep.name == module_name {
                loaded = ep.load();
                path = loaded() if callable(loaded) else loaded;
                if isinstance(path, str) and os.path.isfile(path) {
                    return (path, 'jac');
                }
            }
        }
    } except Exception {
        ;
    }
    return None;
}

def resolve_jac_virtual_module_path(target: str) -> (str | None) {
    result = _resolve_jac_virtual_module(target);
    return result[0] if result else None;
}

def resolve_jac_virtual_module_exports(target: str) -> list[str] {
    if not target.startswith('@jac/') {
        return [];
    }
    module_name = target[len('@jac/'):];
    try {
        import importlib.metadata as _meta;
        for ep in _meta.entry_points(group='jac.module_exports') {
            if ep.name == module_name {
                loaded = ep.load();
                names = loaded() if callable(loaded) else loaded;
                if isinstance(names, list) {
                    return names;
                }
            }
        }
    } except Exception {
        ;
    }
    return [];
}

def _get_path_aliases -> dict[str, str] {
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config {
            client_config = config.get_plugin_config('client');
            return client_config.get('paths', {});
        }
    } except (ImportError, AttributeError) {
        ;
    }
    return {};
}

def _resolve_path_alias(target: str, base_path: str) -> (str | None) {
    if not target.startswith('@') {
        return None;
    }
    aliases = _get_path_aliases();
    if not aliases {
        return None;
    }

    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        project_root = config.project_root if config else None;
    } except (ImportError, AttributeError) {
        project_root = None;
    }
    if not project_root {
        project_root = os.path.dirname(base_path)
            if os.path.isfile(base_path)
            else base_path;
    }
    for (alias_pattern, target_path) in aliases.items() {
        if alias_pattern.endswith('/*') {
            prefix = alias_pattern[:-2];
            if (target.startswith(prefix + '/') or target == prefix) {
                target_base = target_path.rstrip('/*').lstrip('./');
                if target == prefix {
                    resolved = target_base;
                } else {
                    rest = target[len(prefix) + 1:];
                    resolved = os.path.join(target_base, rest);
                }
                return os.path.join(str(project_root), resolved);
            }
        } else {
            if target == alias_pattern {
                resolved = target_path.lstrip('./');
                return os.path.join(str(project_root), resolved);
            }
        }
    }
    return None;
}

def resolve_module(target: str, base_path: str) -> tuple[(str, str)] {
    base_dir = os.path.dirname(base_path);

    jac_virtual = _resolve_jac_virtual_module(target);
    if jac_virtual {
        return jac_virtual;
    }

    alias_resolved = _resolve_path_alias(target, base_path);
    if alias_resolved {
        res = _candidate_from(
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
    if (os.path.exists(other_target) and os.path.isfile(other_target)) {
        return (os.path.normpath(other_target), 'other');
    }

    if not target.startswith('.') {
        parts = target.split('.');
        level = 0;
        while ((level < len(parts)) and (parts[level] == '')) {
            level += 1;
        }
        actual_parts = parts[level:];
        res = _candidate_from(base_dir, actual_parts);
        if res {
            return res;
        }
        typeshed_paths = get_typeshed_paths();
        for typeshed_dir in typeshed_paths {
            res = _candidate_from_typeshed(typeshed_dir, actual_parts);
            if res {
                return res;
            }
        }

        for sp in get_jac_search_paths(base_path) {
            res = _candidate_from_stub_package(sp, actual_parts);
            if res {
                return res;
            }
        }
    }

    if not target.startswith('.') {
        try {
            spec = importlib.util.find_spec(target);
        } except (ImportError, AttributeError, ValueError) {
            spec = None;
        }
        if (spec and spec.origin and (spec.origin not in {'built-in', 'frozen'})) {
            origin = os.path.normpath(spec.origin);
            lang = language_of(origin);
            if (lang != 'other') {
                return (origin, lang);
            }
        }
    }
    parts = target.split('.');
    level = 0;
    while ((level < len(parts)) and (parts[level] == '')) {
        level += 1;
    }
    actual_parts = parts[level:];

    base_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path);
    for _ in range(max((level - 1), 0)) {
        base_dir = os.path.dirname(base_dir);
    }
    if level > 0 {
        res = _candidate_from(base_dir, actual_parts);
        if res {
            return res;
        }
    }

    for sp in get_jac_search_paths(base_path) {
        res = _candidate_from(sp, actual_parts);
        if res {
            return res;
        }
    }

    if level == 0 {
        res = _candidate_from(base_dir, actual_parts);
        if res {
            return res;
        }
    }
    jacpath = os.getenv('JACPATH');
    if jacpath {
        res = _candidate_from(jacpath, actual_parts);
        if res {
            return res;
        }
        target_jac = actual_parts[-1] + '.jac';
        target_cl_jac = actual_parts[-1] + '.cl.jac';
        target_py = actual_parts[-1] + '.py';
        target_js = actual_parts[-1] + '.js';
        for (root, _, files) in os.walk(jacpath) {
            if (target_jac in files) {
                return (os.path.join(root, target_jac), 'jac');
            }
            if (target_cl_jac in files) {
                return (os.path.join(root, target_cl_jac), 'jac');
            }
            if (target_py in files) {
                return (os.path.join(root, target_py), 'py');
            }
            if (target_js in files) {
                return (os.path.join(root, target_js), 'js');
            }
        }
    }
    return (os.path.join(base_dir, *actual_parts), 'py');
}

def infer_language(target: str, base_path: str) -> str {
    (_, lang) = resolve_module(target, base_path);
    return lang;
}

def resolve_relative_path(target: str, base_path: str) -> str {
    (path, _) = resolve_module(target, base_path);
    return path;
}

glob NPM_RUNTIME_CONDITIONS: tuple = ('browser', 'module', 'import', 'default'),
     NPM_TYPES_CONDITIONS: tuple = ('types', 'import', 'default'),
     NPM_DTS_SUFFIXES: tuple = ('.d.ts', '.d.mts', '.d.cts');

def _find_npm_package(
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
    if (spec.startswith('@') and len(parts) >= 2) {
        (pkg_parts, subpath) = (parts[:2], parts[2:]);
    } else {
        (pkg_parts, subpath) = (parts[:1], parts[1:]);
    }
    pkg_dir = os.path.join(node_modules, *pkg_parts);
    if not os.path.isdir(pkg_dir) {
        return None;
    }
    return (pkg_dir, subpath, node_modules);
}

def _read_package_json(pkg_dir: str) -> dict {
    import json;
    pkg_json = os.path.join(pkg_dir, 'package.json');
    if not os.path.isfile(pkg_json) {
        return {};
    }
    try {
        with open(pkg_json, 'r', encoding='utf-8') as f {
            data = json.load(f);
        }
    } except (OSError, ValueError) {
        return {};
    }
    return data if isinstance(data, dict) else {};
}

def _resolve_export_target(
    target: object, conditions: tuple, pkg_dir: str, star_sub: (str | None) = None
) -> (str | None) {
    if isinstance(target, str) {
        rel = target;
        if (star_sub is not None and '*' in rel) {
            rel = rel.replace('*', star_sub);
        }
        candidate = os.path.normpath(os.path.join(pkg_dir, rel));
        return candidate if os.path.isfile(candidate) else None;
    }
    if isinstance(target, list) {
        for item in target {
            resolved = _resolve_export_target(item, conditions, pkg_dir, star_sub);
            if resolved {
                return resolved;
            }
        }
        return None;
    }
    if isinstance(target, dict) {
        for (key, value) in target.items() {
            if key.startswith('.') {
                continue;
            }
            if (key in conditions or key == 'default') {
                resolved = _resolve_export_target(value, conditions, pkg_dir, star_sub);
                if resolved {
                    return resolved;
                }
            }
        }
    }
    return None;
}

def _resolve_pkg_exports(
    exports: object, subpath: str, conditions: tuple, pkg_dir: str
) -> (str | None) {
    if isinstance(exports, dict) {
        has_subpath_keys = `any(k.startswith('.') for k in exports.keys());
        if not has_subpath_keys {
            if subpath == '.' {
                return _resolve_export_target(exports, conditions, pkg_dir);
            }
            return None;
        }
        if subpath in exports {
            return _resolve_export_target(exports[subpath], conditions, pkg_dir);
        }

        best_key: (str | None) = None;
        best_sub: (str | None) = None;
        for key in exports.keys() {
            if ('*' not in key or not key.startswith('.')) {
                continue;
            }
            (prefix, _, suffix) = key.partition('*');
            if (
                subpath.startswith(prefix)
                and subpath.endswith(suffix)
                and len(subpath) >= len(prefix) + len(suffix)
            ) {
                if (
                    best_key is None or len(prefix) > len(best_key.partition('*')[0])
                ) {
                    best_key = key;
                    best_sub = subpath[len(prefix):len(subpath) - len(suffix)]
                        if suffix
                        else subpath[len(prefix):];
                }
            }
        }
        if best_key is not None {
            return _resolve_export_target(
                exports[best_key], conditions, pkg_dir, star_sub=best_sub
            );
        }
        return None;
    }
    if subpath == '.' {
        return _resolve_export_target(exports, conditions, pkg_dir);
    }
    return None;
}

def resolve_client_npm_package(spec: str, base_path: str) -> (str | None) {
    found = _find_npm_package(spec, base_path);
    if found is None {
        return None;
    }
    (pkg_dir, subpath, _) = found;
    data = _read_package_json(pkg_dir);

    exports = data.get('exports');
    if exports is not None {
        subpath_key = './' + '/'.join(subpath) if subpath else '.';
        resolved = _resolve_pkg_exports(
            exports, subpath_key, NPM_RUNTIME_CONDITIONS, pkg_dir
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

def resolve_client_npm_declarations(spec: str, base_path: str) -> (str | None) {
    found = _find_npm_package(spec, base_path);
    if found is None {
        return None;
    }
    (pkg_dir, subpath, node_modules) = found;
    data = _read_package_json(pkg_dir);

    exports = data.get('exports');
    if exports is not None {
        subpath_key = './' + '/'.join(subpath) if subpath else '.';
        resolved = _resolve_pkg_exports(
            exports, subpath_key, NPM_TYPES_CONDITIONS, pkg_dir
        );
        if (resolved and resolved.endswith(NPM_DTS_SUFFIXES)) {
            return resolved;
        }
    }

    if subpath {
        target = os.path.join(pkg_dir, *subpath);
        for suffix in NPM_DTS_SUFFIXES {
            if os.path.isfile((target + suffix)) {
                return os.path.normpath((target + suffix));
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
        for key in ('types', 'typings') {
            val = data.get(key);
            if (isinstance(val, str) and val) {
                candidate = os.path.normpath(os.path.join(pkg_dir, val));
                if os.path.isfile(candidate) {
                    return candidate;
                }
            }
        }
        entry = resolve_client_npm_package(spec, base_path);
        if entry {
            sibling = sibling_declaration_file(entry);
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

def _resolve_at_types_declarations(
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
            if os.path.isfile((target + suffix)) {
                return os.path.normpath((target + suffix));
            }
        }
        nested = os.path.join(target, 'index.d.ts');
        return os.path.normpath(nested) if os.path.isfile(nested) else None;
    }
    types_data = _read_package_json(types_dir);
    for key in ('types', 'typings') {
        val = types_data.get(key);
        if (isinstance(val, str) and val) {
            candidate = os.path.normpath(os.path.join(types_dir, val));
            if os.path.isfile(candidate) {
                return candidate;
            }
        }
    }
    index_dts = os.path.join(types_dir, 'index.d.ts');
    return os.path.normpath(index_dts) if os.path.isfile(index_dts) else None;
}

def sibling_declaration_file(js_path: str) -> (str | None) {
    (stem, ext) = os.path.splitext(js_path);
    by_ext = {'.mjs': '.d.mts', '.cjs': '.d.cts', '.js': '.d.ts'};
    preferred = by_ext.get(ext);
    suffixes = (preferred, ) + tuple(
        s
        for s in NPM_DTS_SUFFIXES
        if s != preferred
    )
        if preferred
        else NPM_DTS_SUFFIXES;
    for suffix in suffixes {
        candidate = stem + suffix;
        if os.path.isfile(candidate) {
            return os.path.normpath(candidate);
        }
    }
    return None;
}

def _npm_file_with_ext(candidate: str) -> (str | None) {
    if os.path.isfile(candidate) {
        return os.path.normpath(candidate);
    }
    for ext in ('.js', '.mjs', '.cjs', '.json') {
        if os.path.isfile((candidate + ext)) {
            return os.path.normpath((candidate + ext));
        }
    }
    return None;
}

def _npm_package_entry(pkg_dir: str, data: dict) -> (str | None) {
    entries: list[str] = [];
    for key in ('module', 'main') {
        val = data.get(key);
        if (isinstance(val, str) and val) {
            entries.append(os.path.join(pkg_dir, val));
        }
    }
    entries.append(os.path.join(pkg_dir, 'index'));
    for entry in entries {
        resolved = _npm_file_with_ext(entry);
        if resolved {
            return resolved;
        }
        nested = _npm_file_with_ext(os.path.join(entry, 'index'));
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

def convert_to_js_import_path(path: str) -> str {
    if not path {
        return path;
    }
    if (path.startswith('./') or path.startswith('../')) {
        return path;
    }
    dot_count = 0;
    for char in path {
        if (char == '.') {
            dot_count += 1;
        } else {
            break;
        }
    }
    common_extensions = (
        '.js',
        '.mjs',
        '.cjs',
        '.css',
        '.scss',
        '.sass',
        '.less',
        '.wasm',
        '.json',
        '.ts',
        '.tsx'
    );
    if (dot_count > 0) {
        rest_of_path = path[dot_count:];
        if ('.' in rest_of_path) {
            last_dot_idx = rest_of_path.rfind('.');
            before_last_dot = rest_of_path[:last_dot_idx];
            after_last_dot = rest_of_path[last_dot_idx:];
            if (after_last_dot in common_extensions) {
                rest_of_path = before_last_dot.replace('.', '/') + after_last_dot;
            } else {
                rest_of_path = rest_of_path.replace('.', '/');
            }
        } else {
            rest_of_path = rest_of_path or '';
        }
        if (dot_count == 1) {
            js_path = ('./' + rest_of_path) if rest_of_path else '.';
        } else {
            parent_dirs = '../' * (dot_count - 1);
            js_path = (parent_dirs[:-1] + ('/' + rest_of_path)) if rest_of_path else '';
        }
        if (js_path in ('.', '..')) {
            return js_path;
        }
        if not js_path.endswith(common_extensions) {
            js_path += '.js';
        }
        return js_path;
    }
    return path;
}

def get_typeshed_paths -> list[str] {
    base = os.path.join(os.path.dirname(__file__), '..', 'vendor', 'typeshed');
    base = os.path.abspath(base);
    stdlib = os.path.join(base, 'stdlib');
    paths = [];
    if os.path.isdir(stdlib) {
        paths.append(stdlib);
    }
    return paths;
}

def _candidate_from_typeshed(
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
        if parts {
            inner_pkg_init_pyi = os.path.join(
                candidate_prefix, parts[-1], '__init__.pyi'
            );
            if os.path.isfile(inner_pkg_init_pyi) {
                return (inner_pkg_init_pyi, 'pyi');
            }
        }
    }
    return None;
}

def _candidate_from_stub_package(
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
        if os.path.isfile(init_pyi) {
            return (init_pyi, 'pyi');
        }
        return None;
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

def is_untyped_third_party_module(path: str) -> bool {
    if not path.endswith('.py') {
        return False;
    }
    normalized = path.replace('\\', '/');
    if ('/site-packages/' not in normalized)
    and ('/dist-packages/' not in normalized) {
        return False;
    }
    mod_path = Path(path);
    if mod_path.with_suffix('.pyi').exists() {
        return False;
    }
    pkg_dir = mod_path.parent;
    while pkg_dir.name not in ('site-packages', 'dist-packages') {
        if (pkg_dir / 'py.typed').exists() {
            return False;
        }
        parent = pkg_dir.parent;
        if parent == pkg_dir {
            break;
        }
        pkg_dir = parent;
    }
    return True;
}
