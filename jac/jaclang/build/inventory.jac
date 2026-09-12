import from jaclang.compiler.session.cache.keys { content_stamp }
import os;
import from pathlib { Path }

glob _SKIP: set[str] = {
         '.jac',
         '.git',
         '.venv',
         'venv',
         'node_modules',
         '__pycache__'
     };

def _inventory(`root: str, inputs: bool = False) -> dict[str, tuple[int, str]] {
    result: dict[str, tuple[int, str]] = {};
    for (directory, dirs, files) in os.walk(`root) {
        dirs[:] = sorted(
            d
            for d in dirs
            if ((d not in _SKIP) and not d.startswith('.'))
        );
        for name in sorted(files) {
            if inputs
                and name.endswith(
                    ('.log', '.db', '.db-wal', '.db-shm', '.sqlite', '.sqlite3')
                ) {
                continue;
            }
            path = os.path.join(directory, name);

            result[path] = content_stamp(str(path));
        }
    }
    for path in Path(`root).`glob('jac*.toml') {
        result[str(path)] = content_stamp(str(path));
    }
    return result;
}


import os;
import type from jaclang.compiler.session.session { JacProgram }
import jaclang.compiler.ir.schema as uni;


glob SPACE_SERVER: str = 'server',
     SPACE_CLIENT: str = 'client',
     SPACE_NATIVE: str = 'native';

glob TOOLCHAIN_NATIVE_ONLY_REL: tuple = ("runtime", "na_stdlib"),
     TOOLCHAIN_MIXED_NATIVE_REL: tuple = ("client", "targets", "desktop", "native");


def project_root_of(source_path: str) -> (str | None) {
    import from jaclang.compiler.session.resolver { find_jac_project_root }
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


def declared_path_spaces(source_path: str, prog: JacProgram) -> set[str] {
    import from jaclang.compiler.api { module_spaces }
    module = prog.compile(source_path, symtab_ir_only=True);
    return {space.value for space in module_spaces(prog, module).spaces};
}


def _errors_for_path(prog: JacProgram, ap: str) -> int {
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


def discover_spaces(
    paths: list[str], prog: JacProgram | None = None
) -> dict[str, set[str]] {
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.analysis.boundaries.classify { hub_module_for_path }
    target = prog if prog is not None else JacProgram();
    out: dict[str, set[str]] = {};
    for p in paths {
        ap = os.path.abspath(p);
        mod = hub_module_for_path(ap, target);
        if mod is None {
            try {
                mod = target.compile(file_path=ap, no_cgen=True);
            } except Exception {}
        }
        import from jaclang.compiler.api { module_spaces }
        spaces = {space.value for space in module_spaces(target, mod).spaces}
            if mod is not None and _errors_for_path(target, ap) == 0
            else {SPACE_SERVER};
        out[ap] = spaces;
    }
    if prog is None {
        target.release_compile_closure();
    }
    return out;
}


def pinned_module_space(source_path: str) -> str {
    import from jaclang.compiler.analysis.placement.pins { config_module_pin }
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


def toolchain_native_by_policy(
    package_dir: str, source_path: str, program: JacProgram | None = None
) -> bool {
    rel = os.path.relpath(os.path.abspath(source_path), os.path.abspath(package_dir));
    native_only = os.path.join(*TOOLCHAIN_NATIVE_ONLY_REL) + os.sep;
    if rel.startswith(native_only) {
        return True;
    }
    mixed = os.path.join(*TOOLCHAIN_MIXED_NATIVE_REL) + os.sep;
    if rel.startswith(mixed) {
        import from jaclang.compiler.api { native_path_eligible }
        return native_path_eligible(source_path, program);
    }
    return False;
}
