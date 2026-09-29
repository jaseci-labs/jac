import os;

import from jaclang.dist.payload.fsutil {
    clone_env,
    copy_file,
    delete_file,
    delete_tree,
    die,
    file_exists,
    log,
    make_dirs,
    mtime_ns,
    read_bytes,
    run_child,
    sha256_hex,
    walk_sorted,
    write_text
}

impl build_musl(osarch: str, dest: str, zig_exe: str) {
    ztargets = {
        "linux-x86_64": "x86_64-linux-musl",
        "linux-aarch64": "aarch64-linux-musl"
    };
    if osarch not in ztargets {
        die(
            f"build-musl: unsupported osarch '{osarch}' (need linux-x86_64|linux-aarch64)"
        );
    }
    ztarget = ztargets[osarch];

    make_dirs(dest);
    if osarch == "linux-aarch64" {
        build_outline_atomics(dest, zig_exe);
    }
    have_all = all(file_exists(os.path.join(dest, name)) for name in MUSL_MANDATORY);
    if have_all {
        log(f"==> musl runtime already vendored in {dest}; skipping");
        return;
    }

    work = dest + ".musl-work";
    delete_tree(work);
    try {
        cache = os.path.join(work, "cache");
        make_dirs(cache);
        stub = os.path.join(work, "stub.c");
        write_text(stub, MUSL_STUB_C);
        stub_out = os.path.join(work, "stub");

        env = clone_env();
        env["ZIG_GLOBAL_CACHE_DIR"] = cache;
        log(f"==> building static musl ({ztarget}) via {zig_exe} ...");
        if not run_child(
            [zig_exe, "cc", "-target", ztarget, "-static", "-o", stub_out, stub],
            env,
            False
        ) {
            die(f"build-musl: `zig cc -target {ztarget} -static` failed");
        }

        if not os.path.isdir(cache) {
            die(f"build-musl: zig cache dir missing at {cache}");
        }
        found: dict[str, str] = {};
        for (cur, dirnames, filenames) in walk_sorted(cache) {
            for fname in filenames {
                if fname in MUSL_ARTIFACTS and fname not in found {
                    found[fname] = os.path.join(cur, fname);
                }
            }
        }

        staged = 0;
        for name in MUSL_ARTIFACTS {
            src = found.get(name);
            if src is None {
                continue;
            }
            copy_file(src, os.path.join(dest, name));
            staged += 1;
        }
        log(f"==> staged {staged} musl artifact(s) -> {dest}");
        if staged < 4 {
            die(f"build-musl: incomplete harvest ({staged}/6 artifacts)");
        }
    } finally {
        delete_tree(work);
    }
}

impl build_outline_atomics(dest: str, zig_exe: str) {
    import jaclang;
    import subprocess;
    import tempfile;
    source_root = os.path.join(
        os.path.dirname(str(jaclang.__file__)),
        "compiler",
        "backends",
        "native",
        "compiler_rt"
    );
    digest_of: dict[str, str] = {};
    for (cur, dirs, names) in walk_sorted(source_root) {
        for name in names {
            source = os.path.join(cur, name);
            digest_of[os.path.relpath(source, source_root)] = sha256_hex(
                read_bytes(source)
            );
        }
    }
    digest_of["toolchain"] = sha256_hex(
        subprocess.check_output([zig_exe, "version"])
            + b"aarch64-linux-musl:O2:PIC:DISABLE_AARCH64_FMV:models1-5:v1"
    );
    manifest = os.path.join(dest, "ATOMICS.sha256");
    archive = os.path.join(dest, "libclang_rt.atomics.a");
    if file_exists(archive) {
        digest_of["archive"] = sha256_hex(read_bytes(archive));
        if read_source_manifest(manifest) == digest_of {
            return;
        }
    }
    make_dirs(dest);
    log("==> building LLVM AArch64 outline-atomics runtime ...");
    with tempfile.TemporaryDirectory(prefix=".atomics-", dir=dest) as work {
        common = [
            zig_exe,
            "cc",
            "-target",
            "aarch64-linux-musl",
            "-O2",
            "-fPIC",
            "-fno-stack-protector",
            "-I" + source_root,
            "-c"
        ];
        objects: list[str] = [];
        for op in ["cas", "swp", "ldadd", "ldclr", "ldeor", "ldset"] {
            sizes = [1, 2, 4, 8, 16] if op == "cas" else [1, 2, 4, 8];
            for size in sizes {
                for model in range(1, 6) {
                    obj_path = os.path.join(work, f"{op}{size}_{model}.o");
                    if not run_child(
                        common
                            + [
                                "-DL_" + op,
                                f"-DSIZE={size}",
                                f"-DMODEL={model}",
                                "-DVISIBILITY_HIDDEN",
                                os.path.join(source_root, "aarch64", "lse.S"),
                                "-o",
                                obj_path
                            ],
                        None,
                        False
                    ) {
                        die(f"compiler-rt: failed to build {op}{size}_{model}");
                    }
                    objects.append(obj_path);
                }
            }
        }
        cpu = os.path.join(work, "cpu_model.o");
        if not run_child(
            common
                + [
                    "-DDISABLE_AARCH64_FMV",
                    os.path.join(source_root, "cpu_model", "aarch64.c"),
                    "-o",
                    cpu
                ],
            None,
            False
        ) {
            die("compiler-rt: failed to build AArch64 CPU detection");
        }
        objects.append(cpu);
        output = os.path.join(work, "runtime.a");
        if not run_child([zig_exe, "ar", "rcsD", output] + objects, None, False) {
            die("compiler-rt: failed to archive AArch64 builtins");
        }
        os.replace(output, archive);
    }
    digest_of["archive"] = sha256_hex(read_bytes(archive));
    write_source_manifest(manifest, list(digest_of), digest_of);
}

impl collect_wasm_sources(src_root: str) -> WasmSources {
    ws = WasmSources(srcs=[], outs=[], rels=[], hdrs=[], hdr_rels=[]);
    if not os.path.isdir(src_root) {
        die(f"build-wasm-libc: wasm_rt source dir missing at {src_root}");
    }
    for name in sorted(os.listdir(src_root)) {
        full = os.path.join(src_root, name);
        if not os.path.isfile(full) {
            continue;
        }
        if not name.startswith("jac_") or not name.endswith(".c") {
            if name.endswith(".h") {
                ws.hdrs.append(full);
                ws.hdr_rels.append(name);
            }
            continue;
        }
        ws.srcs.append(full);
        ws.rels.append(name);
        ws.outs.append(name[:-1] + "bc");
    }
    vendor = os.path.join(src_root, "vendor");
    if not os.path.isdir(vendor) {
        die(f"build-wasm-libc: vendor dir missing at {vendor}");
    }
    for (cur, dirnames, filenames) in walk_sorted(vendor) {
        rel_dir = os.path.relpath(cur, vendor).replace(os.sep, "/");
        prefix = "" if rel_dir == "." else rel_dir + "/";
        for fname in filenames {
            entry_path = prefix + fname;
            full = os.path.join(cur, fname);
            rel = "vendor/" + entry_path;
            if not entry_path.endswith(".c") {
                if entry_path.endswith(".h") {
                    ws.hdrs.append(full);
                    ws.hdr_rels.append(rel);
                }
                continue;
            }
            ws.srcs.append(full);
            ws.rels.append(rel);
            flat = entry_path.replace("/", "_").replace("\\", "_");
            ws.outs.append(flat[:-1] + "bc");
        }
    }
    return ws;
}

impl read_source_manifest(manifest_path: str) -> dict[str, str] {
    prev: dict[str, str] = {};
    try {
        txt = read_bytes(manifest_path).decode("utf-8", errors="replace");
    } except OSError {
        return prev;
    }
    for ln in txt.split("\n") {
        if len(ln) < 67 or ln[64] != " " {
            continue;
        }
        prev[ln[65:].strip(" \r")] = ln[:64];
    }
    return prev;
}

impl write_source_manifest(
    manifest_path: str, rels: list[str], digest_of: dict[str, str]
) {
    lines: list[str] = [];
    for rel in sorted(rels, key=lambda (r: str) { r.encode("utf-8"); }) {
        d = digest_of.get(rel);
        if d is None {
            continue;
        }
        lines.append(d + " " + rel + "\n");
    }
    write_text(manifest_path, "".join(lines));
}

impl wasm_floor_unit_stale(
    dest: str,
    out_name: str,
    rel: str,
    digest_of: dict[str, str],
    prev: dict[str, str],
    hdrs_changed: bool
) -> bool {
    if mtime_ns(os.path.join(dest, out_name)) is None {
        return True;
    }
    if hdrs_changed {
        return True;
    }
    now = digest_of.get(rel);
    was = prev.get(rel);
    if now is None or was is None {
        return True;
    }
    return now != was;
}

def _wasm_cc_argv(zig_exe: str, src_root: str, out_path: str, src: str) -> list[str] {
    return [
        zig_exe,
        "cc",
        "-target",
        "wasm32-wasi",
        "-O2",
        "-g0",
        "-w",
        "-c",
        "-emit-llvm",
        "-fno-builtin",
        "-include",
        os.path.join(src_root, "prelude.h"),
        f"-I{src_root}/vendor/include",
        f"-I{src_root}/vendor/internal",
        f"-I{src_root}/vendor/arch/wasm32",
        f"-I{src_root}/vendor/private",
        f"-I{src_root}/vendor/math",
        "-D__wasilibc_printscan_no_long_double",
        "-D__wasilibc_printscan_full_support_option=\"long double support disabled\"",
        "-o",
        out_path,
        src
    ];
}

impl build_wasm_libc(src_root: str, dest: str, zig_exe: str) {
    ws = collect_wasm_sources(src_root);
    if not ws.srcs {
        die(f"build-wasm-libc: no sources found under {src_root}");
    }
    make_dirs(dest);

    digest_of: dict[str, str] = {};
    for i in range(len(ws.rels)) {
        digest_of[ws.rels[i]] = sha256_hex(read_bytes(ws.srcs[i]));
    }
    for i in range(len(ws.hdr_rels)) {
        digest_of[ws.hdr_rels[i]] = sha256_hex(read_bytes(ws.hdrs[i]));
    }

    manifest_path = os.path.join(dest, WASM_FLOOR_MANIFEST);
    prev = read_source_manifest(manifest_path);

    hdrs_changed = False;
    for rel in ws.hdr_rels {
        if prev.get(rel) != digest_of[rel] {
            hdrs_changed = True;
            break;
        }
    }

    all_rels = ws.rels + ws.hdr_rels;
    stale = 0;
    for i in range(len(ws.rels)) {
        if wasm_floor_unit_stale(
            dest, ws.outs[i], ws.rels[i], digest_of, prev, hdrs_changed
        ) {
            stale += 1;
        }
    }
    if stale == 0 {
        write_source_manifest(manifest_path, all_rels, digest_of);
        log(f"==> wasm libc bitcode up to date in {dest}; skipping");
        return;
    }

    log(
        f"==> compiling {stale} stale/missing wasm_rt source(s) to bitcode via {zig_exe} ..."
    );
    built = 0;
    for i in range(len(ws.srcs)) {
        out_path = os.path.join(dest, ws.outs[i]);
        if not wasm_floor_unit_stale(
            dest, ws.outs[i], ws.rels[i], digest_of, prev, hdrs_changed
        ) {
            continue;
        }
        if not run_child(
            _wasm_cc_argv(zig_exe, src_root, out_path, ws.srcs[i]), None, False
        ) {
            die(f"build-wasm-libc: zig cc failed for {ws.srcs[i]}");
        }
        built += 1;
    }
    delete_file(os.path.join(dest, "_merged.bc"));

    write_source_manifest(manifest_path, all_rels, digest_of);
    log(f"==> compiled {built} wasm libc bitcode file(s) -> {dest}");
}
