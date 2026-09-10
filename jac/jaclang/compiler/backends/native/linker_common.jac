def _align(value: int, alignment: int) -> int;

def read_uleb128(b: bytes, o: int) -> tuple[int, int];

def read_sleb128(b: bytes, o: int) -> tuple[int, int];

def encode_uleb128(v: int) -> bytes;

def encode_uleb128_padded5(v: int) -> bytes;

def encode_sleb128(v: int) -> bytes;

def read_leb_name(b: bytes, o: int) -> tuple[str, int];


def _build_strtab(
    strings: list[str], initial_bytes: bytes = b"\x00"
) -> tuple[bytes, dict[str, int]];

def _append_to_blob(
    blob: bytearray, data: bytes, alignment: int, mem_size: int
) -> int;

def _resolve_seg_vaddr(
    seg: str, seg_off: int, code_vaddr: int, rodata_vaddr: int, data_vaddr: int
) -> int;

def _resolve_patch_site(
    reloc_offset: int,
    target_sec: str,
    code_sections: dict[str, tuple[int, int]],
    rodata_sections: dict[str, tuple[int, int]],
    data_sections: dict[str, tuple[int, int]],
    code_bytes: bytearray,
    rodata_bytes: bytearray,
    data_bytes: bytearray,
    code_vaddr: int,
    rodata_vaddr: int,
    data_vaddr: int
) -> tuple[bytearray, int, int] | None;

def _find_entry_vaddr(
    local_sym_map: dict[str, tuple[str, int]], code_vaddr: int
) -> int;

obj ArMember {
    has name: str,
        header_offset: int,
        data: bytes;
}

def parse_ar_archive(data: bytes) -> list[ArMember];

def parse_ar_symbol_index(data: bytes) -> dict[str, int];

def select_ar_members(data: bytes, root_undef: list[str]) -> list[ArMember];

def resolve_floor_dir(pkg_root: str, triple: str) -> (str | None) {
    import os;
    import from jaclang.runtime.graph_utils { triple_arch }
    want = triple_arch(triple);

    pbs = os.path.join(pkg_root, ".pbs-build");
    fallback: (str | None) = None;
    if os.path.isdir(pbs) {
        for d in sorted(os.listdir(pbs)) {
            libdir = os.path.join(pbs, d, "python", "build", "lib");
            if os.path.isdir(libdir) {
                if fallback is None {
                    fallback = libdir;
                }
                if want in d {
                    return libdir;
                }
            }
        }
    }

    import from jaclang.dist.fused_binary { bundled_floor_roots }
    for floor in bundled_floor_roots(pkg_root) {
        if not os.path.isdir(floor) {
            continue;
        }
        for d in sorted(os.listdir(floor)) {
            cand = os.path.join(floor, d);
            if os.path.isdir(cand) and (want in d) {
                return cand;
            }
        }
    }
    return fallback;
}

def floor_lib_dir(triple: str) -> (str | None) {
    import os;
    import from jaclang.compiler.driver.compile_options { env_floor_dir }
    `override = env_floor_dir();
    if `override and os.path.isdir(`override) {
        return `override;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    return resolve_floor_dir(pkg_root, triple);
}

def clib_to_archive_name(clib_path: str) -> str {
    import os;
    return os.path.basename(clib_path).split(".")[0] + ".a";
}

def collect_floor_archives(
    clib_paths: list, clib_symbol_lib: dict, triple: str, is_macos: bool
) -> tuple {
    import os;
    import from jaclang.compiler.backends.native.linker_common { select_ar_members }
    member_bytes: list[bytes] = [];
    handled: set[str] = set();

    tl = triple.lower();
    is_pe = ("windows" in tl) or ("win32" in tl) or ("msvc" in tl) or ("mingw" in tl);
    if is_pe or not clib_paths {
        return (member_bytes, handled);
    }
    lib_dir = floor_lib_dir(triple);
    if lib_dir is None {
        return (member_bytes, handled);
    }

    syms_by_lib: dict[str, list[str]] = {};
    for (sym, raw) in clib_symbol_lib.items() {
        syms_by_lib.setdefault(raw, []).append(sym);
    }

    roots_by_archive: dict[str, list[str]] = {};
    paths_by_archive: dict[str, list[str]] = {};
    for clib_path in clib_paths {
        arch_file = os.path.join(lib_dir, clib_to_archive_name(clib_path));
        if not os.path.isfile(arch_file) {
            continue;
        }
        paths_by_archive.setdefault(arch_file, []).append(clib_path);
        for s in syms_by_lib.get(clib_path, []) {
            roots_by_archive.setdefault(arch_file, []).append(
                ("_" + s) if is_macos else s
            );
        }
    }
    for (arch_file, roots) in roots_by_archive.items() {
        if not roots {
            continue;
        }
        with open(arch_file, "rb") as _f {
            data = _f.read();
        }
        members = select_ar_members(data, roots);
        if not members {
            continue;
        }
        for m in members {
            member_bytes.append(m.data);
        }
        for p in paths_by_archive.get(arch_file, []) {
            handled.add(p);
        }
    }
    return (member_bytes, handled);
}


def clib_needed_libs(
    needed_libs: list[str], clib_paths: list[str], floor_handled: set[str]
) -> dict[str, str] {
    import os;
    lib_norm: dict[str, str] = {};
    for lib_path in clib_paths {
        if lib_path in floor_handled {
            continue;
        }
        needed = lib_path;
        if (not os.path.isabs(lib_path))
            and (not lib_path.startswith("$"))
            and (not lib_path.startswith("@"))
            and ("/" in lib_path or "\\" in lib_path) {
            needed = os.path.basename(lib_path);
        }
        base = os.path.basename(needed);
        if base == "libc.so" {
            needed = "libc.so.6";
        } elif base == "libm.so" {
            needed = "libm.so.6";
        } elif base in ["libc.dylib", "libm.dylib"] {
            needed = "/usr/lib/libSystem.B.dylib";
        }
        if needed not in needed_libs {
            needed_libs.append(needed);
        }
        lib_norm[lib_path] = needed;
    }
    return lib_norm;
}


def clib_symbol_lib_map(
    clib_symbol_lib: dict[str, str],
    floor_handled: set[str],
    lib_norm: dict[str, str],
    shared: bool,
    is_macos: bool
) -> dict[str, str] {
    symbol_lib_map: dict[str, str] = {};
    for (sym, raw) in clib_symbol_lib.items() {
        if raw in floor_handled {
            continue;
        }
        if shared and is_macos {
            symbol_lib_map[sym] = "@process";
        } else {
            symbol_lib_map[sym] = lib_norm.get(raw, raw);
        }
    }
    return symbol_lib_map;
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

def load_outline_atomics(triple: str) -> (StaticRuntime | None) {
    import os;
    import from jaclang.runtime.graph_utils { triple_arch }
    if triple_arch(triple) != "aarch64" or "linux" not in triple {
        return None;
    }
    lib_dir = musl_lib_dir(triple);
    if lib_dir is None {
        return None;
    }
    path = os.path.join(lib_dir, "libclang_rt.atomics.a");
    if not os.path.isfile(path) {
        return None;
    }
    with open(path, "rb") as archive {
        return StaticRuntime(archives=[archive.read()], crt_objects=[]);
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

def object_undefined_symbols(mem: bytes) -> list[str];
