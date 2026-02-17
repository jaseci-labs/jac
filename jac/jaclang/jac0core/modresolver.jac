"""Module resolver utilities."""
import importlib.util;
import os;
import site;
import sys;
"""Construct a list of paths to search for Jac modules."""
def get_jac_search_paths(base_path: (str | None) = None) -> list[str] {
    paths = [];
    if base_path {
        paths.append(base_path);
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
    site_pkgs = site.getsitepackages();
    if site_pkgs {
        paths.extend(site_pkgs);
    }
    user_site = getattr(site, 'getusersitepackages', None);
    if user_site {
        user_dir = user_site();
        if user_dir {
            paths.append(user_dir);
        }
    }
    return `list(`dict.fromkeys(filter(None, paths)));
}

"""Construct a list of paths to search for Python modules."""
def get_py_search_paths(base_path: (str | None) = None) -> list[str] {
    paths = [];
    if base_path {
        paths.append(base_path);
    }
    paths.append(os.getcwd());
    return `list(`dict.fromkeys(filter(None, paths)));
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
    }
    if os.path.isfile((candidate + '.jac')) {
        return ((candidate + '.jac'), 'jac');
    }
    if os.path.isfile((candidate + '.sv.jac')) {
        return ((candidate + '.sv.jac'), 'jac');
    }
    if os.path.isfile((candidate + '.na.jac')) {
        return ((candidate + '.na.jac'), 'jac');
    }
    if os.path.isfile((candidate + '.cl.jac')) {
        return ((candidate + '.cl.jac'), 'jac');
    }
    if os.path.isfile((candidate + '.py')) {
        return ((candidate + '.py'), 'py');
    }
    if os.path.isfile((candidate + '.js')) {
        return ((candidate + '.js'), 'js');
    }
    return None;
}

"""Resolve module path and infer language."""
def resolve_module(target: str, base_path: str) -> tuple[(str, str)] {
    base_dir = os.path.dirname(base_path);
    if target.startswith('.') {
        other_target = os.path.join(base_dir, convert_to_js_import_path(target));
    } else {
        other_target = os.path.join(base_dir, target);
    }
    if (os.path.exists(other_target) and os.path.isfile(other_target)) {
        return (os.path.normpath(other_target), 'other');
    }
    if not target.startswith('.') {
        try {
            spec = importlib.util.find_spec(target);
        } except (ImportError, AttributeError, ValueError) {
            spec = None;
        }
        if (spec and spec.origin and (spec.origin not in {'built-in','frozen'})) {
            origin = os.path.normpath(spec.origin);
            ext = os.path.splitext(origin)[1].lower();
            if (ext in {'.jac','.pyi','.py','.js','.ts','.jsx','.tsx'}) {
                if (ext == '.jac') {
                    return (origin, 'jac');
                }
                if (ext == '.pyi') {
                    return (origin, 'pyi');
                }
                if (ext == '.py') {
                    return (origin, 'py');
                }
                if (ext in {'.js','.ts','.jsx','.tsx'}) {
                    return (origin, 'js');
                }
                return (origin, 'other');
            }
        }
    }
    parts = target.split('.');
    level = 0;
    while ((level < len(parts)) and (parts[level] == '')) {
        level += 1;
    }
    actual_parts = parts[level:];
    for sp in get_jac_search_paths(base_path) {
        res = _candidate_from(sp, actual_parts);
        if res {
            return res;
        }
    }
    typeshed_paths = get_typeshed_paths();
    for typeshed_dir in typeshed_paths {
        res = _candidate_from_typeshed(typeshed_dir, actual_parts);
        if res {
            return res;
        }
    }
    if typeshed_paths {
        stub_pyi_path = os.path.join(typeshed_paths[0], *actual_parts) + '.pyi';
        if os.path.isfile(stub_pyi_path) {
            return (stub_pyi_path, 'pyi');
        }
    }
    base_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path);
    for _ in range(max((level - 1), 0)) {
        base_dir = os.path.dirname(base_dir);
    }
    res = _candidate_from(base_dir, actual_parts);
    if res {
        return res;
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
        for (`root, _, files) in os.walk(jacpath) {
            if (target_jac in files) {
                return (os.path.join(`root, target_jac), 'jac');
            }
            if (target_cl_jac in files) {
                return (os.path.join(`root, target_cl_jac), 'jac');
            }
            if (target_py in files) {
                return (os.path.join(`root, target_py), 'py');
            }
            if (target_js in files) {
                return (os.path.join(`root, target_js), 'js');
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

"""Return the typeshed stubs and stdlib directories if available."""
def get_typeshed_paths -> list[str] {
    base = os.path.join(os.path.dirname(__file__), '..', 'vendor', 'typeshed');
    base = os.path.abspath(base);
    stubs = os.path.join(base, 'stubs');
    stdlib = os.path.join(base, 'stdlib');
    paths = [];
    if os.path.isdir(stubs) {
        paths.append(stubs);
    }
    if os.path.isdir(stdlib) {
        paths.append(stdlib);
    }
    return paths;
}

"""Find .pyi files in typeshed, trying module.pyi then package/__init__.pyi."""
def _candidate_from_typeshed(base: str, parts: list[str]) -> (tuple[(str, str)] | None) {
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
