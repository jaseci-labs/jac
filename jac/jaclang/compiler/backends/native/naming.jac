import hashlib;

import from jaclang.compiler.backends.common.artifacts { InteropManifest }
import from jaclang.compiler.session.native_resolution { native_stdlib_root }

def native_test_symbol(name: str, line: int) -> str {
    return f"__jac_test_{name}_{line}";
}

def native_safe_sym(src: str) -> str {
    if src in ("osp_kernel", "fmt_kernel", "region_kernel") {
        return src;
    }
    safe = '';
    for ch in src {
        if ((ch >= 'a') and (ch <= 'z'))
            or ((ch >= 'A') and (ch <= 'Z'))
            or ((ch >= '0') and (ch <= '9'))
            or (ch == '_') {
            safe += ch;
        } else {
            safe += '_';
        }
    }
    return f"{safe}_{hashlib.sha1(src.encode()).hexdigest()[:8]}";
}

def native_library_function_symbol(mod_path: str, name: str) -> str {
    import os;
    library_root = native_stdlib_root();
    if library_root is None {
        return name;
    }
    source = os.path.realpath(mod_path);
    root_path = os.path.realpath(library_root) + os.sep;
    if not source.startswith(root_path) {
        return name;
    }
    module_name = source[len(root_path):].replace(os.sep, "/");
    return f"__jac_lib_{native_safe_sym(module_name)}_{name}";
}

def module_dotted_name(mod_path: str, mod_name: str = "") -> str {
    import os;
    path = mod_path.replace("\\", "/");
    if not path {
        return mod_name;
    }
    idx = path.rfind("/jaclang/");
    stem = path[idx + 1:] if idx >= 0 else os.path.basename(path);
    for ext in (".impl.jac", ".test.jac", ".jac", ".py") {
        if stem.endswith(ext) {
            stem = stem[:-len(ext)];
            break;
        }
    }
    if stem.endswith("/__init__") {
        stem = stem[:-len("/__init__")];
    }
    return stem.replace("/", ".");
}

def native_module_key(path: str) -> str {
    import os;
    rp = os.path.realpath(path);
    base = os.path.basename(rp);
    dot = base.rfind(".");
    stem = base[0:dot] if dot > 0 else base;
    return f"{stem}:{hashlib.sha1(rp.encode()).hexdigest()[:12]}";
}

def native_glob_init_name(src: str, manifest: (InteropManifest | None)) -> str {
    key: str = src;
    if manifest is not None {
        sources = manifest.native_transitive_sources;
        keys = manifest.native_transitive_keys;
        i: int = 0;
        while i < len(sources) {
            if sources[i] == src and i < len(keys) and keys[i] != "" {
                key = keys[i];
            }
            i += 1;
        }
    }
    return f"__jac_glob_init_{native_safe_sym(key)}";
}

def native_glob_init_symbols(manifest: (InteropManifest | None)) -> list[str] {
    syms: list[str] = [];
    sources: list[str] = [];
    if manifest is not None {
        sources = manifest.native_transitive_sources;
    }
    for src in sources {
        if not src {
            continue;
        }
        sym = native_glob_init_name(src, manifest);
        if sym not in syms {
            syms.append(sym);
        }
    }
    syms.append("__jac_glob_init");
    return syms;
}

def native_wasm_stem(path: str) -> str {
    import os;
    stem = os.path.splitext(os.path.basename(path))[0];
    for marker in ('.cl', ) {
        if stem.endswith(marker) {
            stem = stem[0:-len(marker)];
        }
    }
    return stem;
}
