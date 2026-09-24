import from jaclang.compiler.backends.native.linker_common {
    object_undefined_symbols,
    select_ar_members
}

def resolve_floor_dir(pkg_root: str, triple: str) -> (str | None) {
    import from jaclang.compiler.backends.native.floor {
        resolve_floor_dir as implementation
    }
    return implementation(pkg_root, triple);
}

def floor_lib_dir(triple: str) -> (str | None) {
    import from jaclang.compiler.backends.native.floor {
        floor_lib_dir as implementation
    }
    return implementation(triple);
}

def clib_to_archive_name(clib_path: str) -> str {
    import from jaclang.compiler.backends.native.floor {
        clib_to_archive_name as implementation
    }
    return implementation(clib_path);
}

def collect_floor_archives(
    clib_paths: list[str], clib_symbol_lib: dict[str, str], triple: str, is_macos: bool
) -> tuple[list[bytes], set[str]] {
    import from jaclang.compiler.backends.native.floor {
        collect_floor_archives as implementation
    }
    return implementation(clib_paths, clib_symbol_lib, triple, is_macos);
}

def clib_needed_libs(
    needed_libs: list[str], clib_paths: list[str], floor_handled: set[str]
) -> dict[str, str] {
    import from jaclang.compiler.backends.native.floor {
        clib_needed_libs as implementation
    }
    return implementation(needed_libs, clib_paths, floor_handled);
}

def clib_symbol_lib_map(
    clib_symbol_lib: dict[str, str],
    floor_handled: set[str],
    lib_norm: dict[str, str],
    shared: bool,
    is_macos: bool
) -> dict[str, str] {
    import from jaclang.compiler.backends.native.floor {
        clib_symbol_lib_map as implementation
    }
    return implementation(clib_symbol_lib, floor_handled, lib_norm, shared, is_macos);
}

def musl_lib_dir(triple: str) -> (str | None) {
    import os;
    import from jaclang.runtime.graph_utils { triple_arch }
    env = os.environ.get("JAC_NATIVE_MUSL_DIR", "");
    if env and os.path.isdir(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    want = triple_arch(triple);
    pbs = os.path.join(pkg_root, ".pbs-build");
    if os.path.isdir(pbs) {
        for d in sorted(os.listdir(pbs)) {
            libdir = os.path.join(pbs, d, "musl", "lib");
            if os.path.isdir(libdir)
                and os.path.isfile(os.path.join(libdir, "libc.a"))
                and (want in d) {
                return libdir;
            }
        }
    }
    import from jaclang.dist.fused_binary { bundled_floor_roots }
    for floor in bundled_floor_roots(pkg_root) {
        if not os.path.isdir(floor) {
            continue;
        }
        for d in sorted(os.listdir(floor)) {
            cand = os.path.join(floor, d, "musl");
            if os.path.isdir(cand)
                and os.path.isfile(os.path.join(cand, "libc.a"))
                and (want in d) {
                return cand;
            }
        }
    }
    return None;
}

obj StaticRuntime {
    has archives: list[bytes],
        crt_objects: list[bytes];

    def select(objects: list[bytes]) -> list[bytes] {
        import hashlib;
        work_roots: list[str] = [];
        known: set[str] = set();
        for blob in list(objects) + self.crt_objects {
            for u in object_undefined_symbols(blob) {
                if u not in known {
                    known.add(u);
                    work_roots.append(u);
                }
            }
        }

        member_bytes: list[bytes] = [];
        seen_members: set[bytes] = set();
        changed = True;
        while changed {
            changed = False;
            for data in self.archives {
                for m in select_ar_members(data, work_roots) {
                    key = hashlib.sha256(m.data).digest();
                    if key in seen_members {
                        continue;
                    }
                    seen_members.add(key);
                    member_bytes.append(m.data);
                    changed = True;
                    for u in object_undefined_symbols(m.data) {
                        if u not in known {
                            known.add(u);
                            work_roots.append(u);
                        }
                    }
                }
            }
        }
        return member_bytes;
    }
}

def load_musl_static(triple: str) -> (StaticRuntime | None) {
    import os;
    lib_dir = musl_lib_dir(triple);
    if lib_dir is None {
        return None;
    }
    libc_a = os.path.join(lib_dir, "libc.a");
    if not os.path.isfile(libc_a) {
        return None;
    }

    crt_objects: list[bytes] = [];
    have_crt1 = False;
    for crt_name in ["crt1.o", "crti.o", "crtn.o"] {
        p = os.path.join(lib_dir, crt_name);
        if os.path.isfile(p) {
            with open(p, "rb") as cf {
                crt_objects.append(cf.read());
            }
            if crt_name == "crt1.o" {
                have_crt1 = True;
            }
        }
    }
    if not have_crt1 {
        return None;
    }

    archives_data: list[bytes] = [];
    for af in ["libc.a", "libzigc.a", "libcompiler_rt.a"] {
        p = os.path.join(lib_dir, af);
        if os.path.isfile(p) {
            with open(p, "rb") as archive {
                archives_data.append(archive.read());
            }
        }
    }

    return StaticRuntime(archives=archives_data, crt_objects=crt_objects);
}

def collect_musl_static(
    objects: list[bytes], triple: str
) -> (tuple[list[bytes], list[bytes]] | None) {
    runtime = load_musl_static(triple);
    if runtime is None {
        return None;
    }
    return (runtime.select(objects), runtime.crt_objects);
}
