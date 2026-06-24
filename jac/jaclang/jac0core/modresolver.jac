"""Module resolver utilities."""
import importlib.util;
import os;
import sys;
import from jaclang.jac0core.ext_registry { MODULE_SUFFIXES, language_of }

# Cache of resolved project roots, keyed by the directory we started the
# upward walk from. A `None` value records "no jac.toml above here" so we
# never re-walk a non-project directory on the hot import path.
glob _project_root_cache: dict = {},
     # Stack of directories for the files currently being imported, innermost last.
     # `jac_import` pushes the importing file's directory before executing it and
     # pops it after. `get_jac_search_paths` reads the top so that at runtime a
     # bare (no-dot) import resolves against the importing file's OWN directory
     # first -- matching the compile-time resolver's own-directory-first rule (and
     # Python's sibling-first intuition). Mirrors the existing sys.path push/pop in
     # jac_import; the same single-threaded import assumptions apply.
     _import_base_stack: list = [];

"""Push the importing file's directory as the active import base."""
def push_import_base(base_dir: str) {
    _import_base_stack.append(base_dir);
}

"""Pop the active import base pushed by the most recent push_import_base."""
def pop_import_base {
    if _import_base_stack {
        _import_base_stack.pop();
    }
}

"""Find the nearest project root (the directory holding `jac.toml`).

Walks upward from `start` (a file or directory path); when `start` is None the
walk begins at the current working directory. Returns the project-root directory
as a string, or None for standalone scripts that live outside any project.

This is the anchor for "project-root absolute" imports: a no-dot import like
`engine.math.vec3` resolves against this directory from anywhere in the project,
independent of how deep the importing file sits. Kept as a dependency-free
filesystem walk (no jaclang.project.config import) because it runs on the hot
import-resolution path; results are memoized in `_project_root_cache`.
"""
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
    found = None;
    probe = current;
    while True {
        if os.path.isfile(os.path.join(probe, 'jac.toml')) {
            found = probe;
            break;
        }
        parent = os.path.dirname(probe);
        if (parent == probe) {
            break;
        }
        probe = parent;
    }
    _project_root_cache[current] = found;
    return found;
}

"""Construct a list of paths to search for Jac modules."""
def get_jac_search_paths(base_path: (str | None) = None) -> list[str] {
    paths = [];
    if base_path {
        paths.append(base_path);
    }
    # The directory of the file currently being imported takes priority, so a
    # bare (no-dot) import of a sibling module resolves to that sibling rather
    # than a same-named module at the project root or cwd. This mirrors the
    # compile-time resolver's own-directory-first rule, keeping native and
    # interpreted resolution consistent.
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
    # sys.path already carries the bundled runtime and -- promoted to its front by
    # _jac_finder.add_project_venv_to_path -- the project's .jac/venv. The host's
    # system/user site-packages are deliberately NOT consulted: third-party code
    # lives only in the project venv, so resolution stays hermetic regardless of
    # any Python installed on the host.
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

"""Construct a list of paths to search for Python modules."""
def get_py_search_paths(base_path: (str | None) = None) -> list[str] {
    paths = [];
    if base_path {
        paths.append(base_path);
    }
    paths.append(os.getcwd());
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
    # Jac module files, in canonical codespace precedence (shared registry).
    for jac_suffix in MODULE_SUFFIXES {
        if os.path.isfile((candidate + jac_suffix)) {
            return ((candidate + jac_suffix), 'jac');
        }
    }
    if os.path.isfile((candidate + '.py')) {
        return ((candidate + '.py'), 'py');
    }
    # .pyi after .py so co-located stubs defer to real sources;
    # essential for relative imports inside typeshed packages
    # (e.g. `from .path import ...` in os/__init__.pyi).
    if os.path.isfile((candidate + '.pyi')) {
        return ((candidate + '.pyi'), 'pyi');
    }
    if os.path.isfile((candidate + '.js')) {
        return ((candidate + '.js'), 'js');
    }
    return None;
}

"""Resolve the built-in `@jac/*` virtual module alias.

`@jac/runtime` is baked into the language - it is mapped to the single canonical
client runtime at `jaclang/runtimelib/client_runtime.cl.jac`, which the bundler
also compiles, so static analysis and the bundle resolve the same file.

Returns `(path, lang)` when `target` begins with `@jac/`, otherwise `None`.
"""
def _resolve_jac_virtual_module(target: str) -> (tuple[(str, str)] | None) {
    if not target.startswith('@jac/') {
        return None;
    }
    import jaclang.runtimelib as _runtimelib;
    runtime_dir = os.path.dirname(_runtimelib.__file__);
    module_name = target[len('@jac/'):];
    # `@jac/runtime` resolves to the framework-specific client runtime source.
    if module_name == 'runtime' {
        import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
        path = resolve_client_runtime_cl_path();
        if os.path.isfile(path) {
            return (path, 'jac');
        }
    }
    # Fallback: search for a file under the runtime directory by extension.
    for (ext, lang) in [('.cl.jac', 'jac'), ('.jac', 'jac'), ('.js', 'js')] {
        path = os.path.join(runtime_dir, (module_name + ext));
        if os.path.isfile(path) {
            return (path, lang);
        }
    }
    # Fallback: check packages that registered a jac.modules entry point.
    # Plugins (e.g. jac-desktop) self-register their @jac/* modules this way
    # without writing files into jaclang's runtimelib directory.
    # Entry point value is "module.path:attr_or_callable". If the loaded object
    # is callable, it is invoked and must return an absolute path string.
    # If it is already a string, it is used directly.
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

"""Return the filesystem path of a `@jac/*` virtual module, or None if unknown.

Single source of truth for the `@jac/<name>` → backing-file mapping shared by
the module resolver (so the type checker agrees with the bundler) and the
ECMAScript pass (so the client manifest registers the same file).
"""
def resolve_jac_virtual_module_path(target: str) -> (str | None) {
    result = _resolve_jac_virtual_module(target);
    return result[0] if result else None;
}

"""Return the public export names a `@jac/*` module advertises, or [].

Packages whose virtual module is built from `obj` types (which the generic
export extractor can't see) self-describe their public symbols via a
`jac.module_exports` entry point named for the module (e.g. `desktop`). The
entry point resolves to a list, or a callable returning one. This keeps the
per-SDK symbol list in the owning package instead of hardcoded in the compiler.
"""
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

"""Get path aliases from project config [plugins.client.paths]."""
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

"""Resolve a path alias to its actual filesystem path.

Checks if target matches any configured path alias from [plugins.client.paths].
Supports wildcard patterns like "@components/*" -> "./components/*"
"""
def _resolve_path_alias(target: str, base_path: str) -> (str | None) {
    if not target.startswith('@') {
        return None;
    }
    aliases = _get_path_aliases();
    if not aliases {
        return None;
    }
    # Get project root from config
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

"""Resolve module path and infer language."""
def resolve_module(target: str, base_path: str) -> tuple[(str, str)] {
    base_dir = os.path.dirname(base_path);
    # Built-in `@jac/*` virtual aliases (e.g. `@jac/runtime`) take precedence
    # so static analysis agrees with the bundler's runtime resolution.
    jac_virtual = _resolve_jac_virtual_module(target);
    if jac_virtual {
        return jac_virtual;
    }
    # Check for path aliases first (e.g., @components/Button -> ./components/Button)
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
    # Local files in base_dir take priority over typeshed for non-relative
    # imports. Without this a local `ast.na.jac` (or .jac / .py) sitting
    # next to the importer is silently shadowed by `stdlib/ast.pyi`, so
    # the type checker sees an unrelated module's symbols (or none at
    # all). Mirrors the same fix applied to NaIRGenPass's struct
    # registration; covered by the fix_shadow_entry.na.jac fixture.
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
        # PEP 561 stub packages: an installed `<pkg>-stubs` distribution (e.g.
        # `types-requests` -> `requests-stubs/`) supplies type stubs for an
        # otherwise-untyped runtime package. Prefer it over the runtime `.py`
        # resolved by importlib below, matching mypy/pyright precedence. These
        # live in the project venv's site-packages, already on the search path.
        for sp in get_jac_search_paths(base_path) {
            res = _candidate_from_stub_package(sp, actual_parts);
            if res {
                return res;
            }
        }
    }
    # Fallback to Python's importlib for modules not in typeshed
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

    # For relative imports (level > 0), check local path FIRST before global paths
    base_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path);
    for _ in range(max((level - 1), 0)) {
        base_dir = os.path.dirname(base_dir);
    }
    if level > 0 {
        # Relative import: check local directory first
        res = _candidate_from(base_dir, actual_parts);
        if res {
            return res;
        }
    }

    # Search global paths
    for sp in get_jac_search_paths(base_path) {
        res = _candidate_from(sp, actual_parts);
        if res {
            return res;
        }
    }

    # Fallback to base_dir for non-relative imports
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

"""Infer language for target relative to base path."""
def infer_language(target: str, base_path: str) -> str {
    (_, lang) = resolve_module(target, base_path);
    return lang;
}

"""Resolve only the path component for a target."""
def resolve_relative_path(target: str, base_path: str) -> str {
    (path, _) = resolve_module(target, base_path);
    return path;
}

"""Convert Jac-style import path to JavaScript-style import path.

    Transforms relative paths to be valid JavaScript:
    - .utils -> ./utils.js
    - ..lib -> ../lib.js
    - ...config -> ../../config.js

    Args:
        path: Jac-style import path (potentially with leading dots)

    Returns:
        JavaScript-style import path with .js extension for relative imports
    """
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

"""Return the vendored typeshed *stdlib* stub directory if available.

Only the stdlib stubs are bundled. Third-party type stubs are NOT shipped:
they are installed per-project into `.jac/venv` by `jac add` (as PEP 561
`types-*` packages) and resolved from there via `_candidate_from_stub_package`.
This keeps the binary lean and makes third-party types track the *installed*
version instead of a stale vendored snapshot.
"""
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

"""Find .pyi files in typeshed, trying module.pyi then package/__init__.pyi."""
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

"""Find a PEP 561 `<pkg>-stubs` package under `base` for the import `parts`.

A stub-only distribution (e.g. `types-requests`) installs a top-level
`requests-stubs/` directory of `.pyi` files. Only the *first* import component
gets the `-stubs` suffix; submodules resolve inside it verbatim. So
`requests.sessions` -> `<base>/requests-stubs/sessions.pyi` (or that dir's
`__init__.pyi`), and bare `requests` -> `<base>/requests-stubs/__init__.pyi`.
"""
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
