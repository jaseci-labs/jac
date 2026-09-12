import from jaclang.compiler.session.target_options { native_target_os }

def native_stdlib_root -> (str | None) {
    import os;
    import jaclang;
    if not jaclang?.__file__ {
        return None;
    }
    stdlib_dir = os.path.join(
        os.path.dirname(jaclang.__file__), "runtime", "na_stdlib"
    );
    return stdlib_dir if os.path.isdir(stdlib_dir) else None;
}

def is_native_by_location(file_path: str) -> bool {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return False;
    }
    ap = os.path.abspath(file_path);
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    return ap.startswith(os.path.join(pkg, "runtime", "na_stdlib") + os.sep);
}

glob SHARED_RUNTIME_MODULES: tuple[str, ...] = (
         "jaclang.runtime.graph_fragment",

     ),
     CLIENT_RUNTIME_SOURCE_PATHS: list[str] = [
         "client/client_runtime.jac",
         "client/client_runtime_core.jac",
         "client/solid_runtime.jac",
         "client/pwa_runtime.jac",
         "client/wasm_host.jac",
         "client/webgl.jac",
         "client/endpoint_cache.jac",
         "client/auth_contract.jac",
         "client/client_mobui.jac",
         "client/client_react_core.jac",
         "client/client_runtime_native.jac",
         "client/targets/desktop/plugin/desktop_api.jac"
     ];


def is_client_by_location(file_path: str) -> bool {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return False;
    }
    ap = os.path.abspath(file_path);
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    for rel in CLIENT_RUNTIME_SOURCE_PATHS {
        if ap == os.path.join(pkg, rel.replace("/", os.sep)) {
            return True;
        }
    }
    return False;
}

def is_shared_runtime_module(file_path: str) -> bool {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return False;
    }
    package = os.path.dirname(os.path.realpath(str(jaclang.__file__)));
    path = os.path.realpath(file_path);
    return any(
        path == os.path.join(package, *module.split('.')[1:]) + '.jac'
        for module in SHARED_RUNTIME_MODULES
    );
}

def is_bundled_native_module(module_name: str) -> bool {
    import os;
    stdlib_dir = native_stdlib_root();
    if stdlib_dir is None or not module_name {
        return False;
    }
    path_name = module_name.lstrip('.').replace('.', os.sep);
    return _native_variant_path(os.path.join(stdlib_dir, path_name)) is not None;
}

def _native_variant_path(base_no_ext: str) -> (str | None) {
    import os;
    _osv = os.path.join(f"{base_no_ext}.{native_target_os()}.jac");
    if os.path.exists(_osv) {
        return _osv;
    }
    _plain = f"{base_no_ext}.jac";
    if os.path.exists(_plain) {
        return _plain;
    }
    return None;
}

def _inferred_native_path(candidate: (str | None)) -> (str | None) {
    if candidate is None {
        return None;
    }
    import from jaclang.compiler.bootstrap.native_scope { scope_allows_inferred_path }
    if not scope_allows_inferred_path(candidate) {
        return None;
    }
    import from jaclang.compiler.api { native_path_eligible }
    return candidate if native_path_eligible(candidate) else None;
}

def resolve_native_module(
    module_name: str, base_dir: str, allow_inferred: bool = True
) -> tuple[(str | None, str | None)] {
    import os;
    clean = module_name.lstrip('.');
    path_name = clean.replace('.', os.sep);

    if allow_inferred {
        local = _inferred_native_path(
            _native_variant_path(os.path.join(base_dir, clean))
        );
        if local is not None {
            return (str(os.path.relpath(local, os.path.abspath(base_dir))), local);
        }
        if path_name != clean {
            search = os.path.abspath(base_dir);
            while True {
                cand = _inferred_native_path(
                    _native_variant_path(os.path.join(search, path_name))
                );
                if cand is not None {
                    rel = str(os.path.relpath(cand, os.path.abspath(base_dir)));
                    return (rel, cand);
                }
                parent = os.path.dirname(search);
                if parent == search {
                    break;
                }
                search = parent;
            }
        }
    }

    if clean.startswith('jaclang.') {
        import jaclang as _jl;
        _pkg = os.path.dirname(os.path.abspath(_jl.__file__));
        _parts = clean.split('.')[1:];
        _cand = os.path.join(_pkg, *_parts) + '.jac';
        import from jaclang.compiler.bootstrap.native_scope {
            in_native_scope_path,
            scope_lowering_active
        }
        if scope_lowering_active() {
            if in_native_scope_path(_cand) and os.path.isfile(_cand) {
                return (path_name, _cand);
            }
        }
        if clean in SHARED_RUNTIME_MODULES and os.path.isfile(_cand) {
            return (path_name, _cand);
        }
    }

    bundled_root = native_stdlib_root();
    if bundled_root is not None {
        bundled = _native_variant_path(os.path.join(bundled_root, path_name));
        if bundled is not None {
            return (path_name, bundled);
        }
    }
    return (None, None);
}
