import os;
import jaclang.jac0core.unitree as uni;

glob SPACE_SERVER: str = 'server',
     SPACE_CLIENT: str = 'client',
     SPACE_NATIVE: str = 'native';

glob TOOLCHAIN_NATIVE_ONLY_REL: tuple = ("runtimelib", "na_stdlib"),
     TOOLCHAIN_MIXED_NATIVE_REL: tuple = (
         "runtimelib",
         "client",
         "targets",
         "desktop",
         "native"
     );


def project_root_of(source_path: str) -> (str | None) {
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    return find_jac_project_root(source_path);
}


def require_project_root(source_path: str) -> str {
    proj_root = project_root_of(source_path);
    if not proj_root {
        raise ValueError(
            f"{source_path} is not inside a jac project (no jac.toml in any "
            "ancestor directory), so placement cannot be resolved for it."
        );
    }
    return proj_root;
}


def module_spaces(mod: (uni.Module | None)) -> set[str] {
    if mod is None {
        return {SPACE_SERVER};
    }
    if mod.decided_codespace {
        return {str(mod.decided_codespace)};
    }
    spaces: set[str] = set();
    for stmt in mod.body {
        if isinstance(stmt, uni.ContextAwareNode) {
            spaces.add(str(stmt.code_context));
        }
    }
    if not spaces {
        return {SPACE_SERVER};
    }
    return spaces;
}


def is_client_only(mod: (uni.Module | None)) -> bool {
    return module_spaces(mod) == {SPACE_CLIENT};
}


def emits_server_code(mod: (uni.Module | None)) -> bool {
    return SPACE_SERVER in module_spaces(mod);
}


def declared_path_spaces(source_path: str, prog: any) -> set[str] {
    import from jaclang.jac0core.placement_solver { _materialize_module }
    return module_spaces(_materialize_module(source_path, prog));
}


def _errors_for_path(prog: any, ap: str) -> int {
    count = 0;
    normed = os.path.normpath(ap);
    for e in prog.errors_had {
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == normed {
            count += 1;
        }
    }
    return count;
}


def discover_spaces(paths: list[str], prog: any = None) -> dict[str, set[str]] {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compiler { hub_module_for_path }
    target = prog if prog is not None else JacProgram();
    out: dict[str, set[str]] = {};
    for p in paths {
        ap = os.path.abspath(p);
        mod = hub_module_for_path(ap, target);
        if mod is None {
            try {
                target.compile(file_path=ap, no_cgen=True);
            } except Exception {
                ;
            }
            mod = hub_module_for_path(ap, target);
        }
        spaces = set(module_spaces(mod));
        if _errors_for_path(target, ap) > 0 {
            spaces.add(SPACE_SERVER);
        }
        out[ap] = spaces;
    }
    if prog is None {
        target.release_compile_closure();
    }
    return out;
}


def pinned_module_space(source_path: str) -> str {
    import from jaclang.jac0core.placement_pins { config_module_pin }
    return config_module_pin(source_path);
}


def spaces_are_client_only(spaces: set[str]) -> bool {
    return len(spaces) == 1 and SPACE_CLIENT in spaces;
}


def client_only_paths(paths: list[str]) -> set[str] {
    facts = discover_spaces(paths);
    out: set[str] = set();
    for (p, spaces) in facts.items() {
        if spaces_are_client_only(spaces) {
            out.add(p);
        }
    }
    return out;
}


def sealed_spaces_for(source_path: str) -> (set[str] | None) {
    import json;
    ap = os.path.abspath(source_path);
    d = os.path.dirname(ap);
    while True {
        mf = os.path.join(d, "_precompiled", "MANIFEST.json");
        if os.path.isfile(mf) {
            break;
        }
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
    try {
        with open(mf, "r") as f {
            manifest = json.load(f);
        }
    } except Exception {
        return None;
    }
    placement = manifest.get("placement") or {};
    rel = os.path.relpath(ap, d).replace(os.sep, "/");
    spaces = placement.get(rel);
    if spaces is None {
        return None;
    }
    return set(spaces);
}


def toolchain_native_by_policy(package_dir: str, source_path: str) -> bool {
    rel = os.path.relpath(os.path.abspath(source_path), os.path.abspath(package_dir));
    native_only = os.path.join(*TOOLCHAIN_NATIVE_ONLY_REL) + os.sep;
    if rel.startswith(native_only) {
        return True;
    }
    mixed = os.path.join(*TOOLCHAIN_MIXED_NATIVE_REL) + os.sep;
    if rel.startswith(mixed) {
        import from jaclang.jac0core.placement_solver { native_default_path_ok }
        return native_default_path_ok(source_path);
    }
    return False;
}
