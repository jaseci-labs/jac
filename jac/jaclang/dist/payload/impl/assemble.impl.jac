import io;
import os;
import tarfile;

import from compression.zstd { CompressionParameter, compress, decompress }
import from jaclang.dist.payload.fetch { TYPESHED_VENDOR, fetch_typeshed }
import from jaclang.dist.payload.fsutil {
    PayloadDie,
    clone_env,
    copy_file,
    copy_into,
    copy_tree,
    delete_file,
    delete_tree,
    die,
    file_exists,
    host_os_arch,
    log,
    make_dirs,
    read_bytes,
    run_child,
    sha256_hex,
    skip_jaclang,
    skip_none,
    skip_site_template,
    skip_stage_site,
    source_file_mode,
    strip_best_effort,
    toml_string,
    walk_sorted,
    write_bytes,
    write_text
}
import from jaclang.dist.payload.pins { py_ver }
import from jaclang.dist.payload.vendor { MUSL_ARTIFACTS }

impl mk_payload(pbs_py_dir: str, repo_root: str, out: str, opts: MkPayloadOpts) {
    py = resolve_python(pbs_py_dir);
    work = out + ".work";
    delete_tree(work);
    make_dirs(work);

    site = os.path.join(work, "site");
    stage = os.path.join(work, "stage");

    ts_versions = os.path.join(repo_root, TYPESHED_VENDOR, "stdlib", "VERSIONS");
    if not file_exists(ts_versions) {
        fetch_typeshed(repo_root);
    }

    log("==> assembling jaclang site from source (no pyproject build)");
    run_child([py, "-m", "ensurepip", "--upgrade"], None, True);
    run_child([py, "-m", "pip", "install", "--quiet", "--upgrade", "pip"], None, True);
    make_dirs(site);

    assemble_site(repo_root, site, opts);

    stage_floor(pbs_py_dir, work);

    run_precompile_stage(py, pbs_py_dir, site, opts);

    run_stubcat_stage(py, pbs_py_dir, site, opts);

    log("==> bundling watchdog (jac run --dev) + tomlkit");
    delete_tree(os.path.join(site, "__pycache__"));
    run_child(
        [
            py,
            "-m",
            "pip",
            "install",
            "--quiet",
            "watchdog>=3.0.0",
            "tomlkit",
            "--target",
            site
        ],
        None,
        False
    );

    stage_tree(pbs_py_dir, site, stage, opts.musl_dir, opts.wasm_libc_dir);

    precompile_pyc(py, stage);

    tar_zst_dir(stage, out, opts.layer_cache);
    log(f"==> payload: {out}");
    delete_tree(work);
}

impl resolve_python(pbs_py_dir: str) -> str {
    p1 = os.path.join(pbs_py_dir, "install", "bin", f"python{py_ver()}");
    if file_exists(p1) {
        return p1;
    }
    p2 = os.path.join(pbs_py_dir, "install", "bin", "python3");
    if file_exists(p2) {
        return p2;
    }
    raise PayloadDie(f"mkpayload: no python at {pbs_py_dir}/install/bin");
}

impl assemble_site(repo_root: str, site: str, opts: MkPayloadOpts) {
    if opts.link_source is None {
        copy_tree(
            os.path.join(repo_root, "jaclang"),
            os.path.join(site, "jaclang"),
            skip_jaclang
        );

        copy_file(
            os.path.join(repo_root, "bootstrap", "pins.json"),
            os.path.join(site, "jaclang", "dist", "payload", "pins.json")
        );

        awesome_src = os.path.join(repo_root, "examples", "jaclang_org");
        if os.path.isdir(awesome_src) {
            log("==> bundling the jaclang.org site as the --awesome template");
            copy_tree(
                awesome_src, os.path.join(site, "awesome_template"), skip_site_template
            );
        } else {
            log(f"==> no {awesome_src}; --awesome template not bundled");
        }
    } else {
        log(
            f"==> linked-source mode: NOT bundling jaclang (compiler served from {opts.link_source})"
        );
    }
    copy_into(repo_root, "_jac_finder.py", site);
    copy_into(repo_root, "sitecustomize.py", site);
    if opts.link_source is not None {
        write_text(os.path.join(site, "jac_linked_source"), opts.link_source);
    }

    write_dist_info(repo_root, site);

    if opts.link_source is not None {
        return;
    }
    so = opts.shim_so;
    if so is None {
        raise PayloadDie(
            "mkpayload: no LLVM shim (--shim). Run `zig build fetch-llvm` once so the"
            " build can compile + statically link the LLVMPY_* shim."
        );
    }
    dst = site_shim_path(site);
    make_dirs(os.path.dirname(dst));
    log(f"==> bundling Zig-built LLVMPY_* shim ({so})");
    copy_file(so, dst);
    if not file_exists(dst) {
        raise PayloadDie(
            f"mkpayload: bundled {so} but no shim at {dst}; the JIR seal and the"
            " shipped binary both locate it by that exact path."
        );
    }

    # The native compiler kernel is not built here: `jac precompile --seal`
    # (run_precompile_stage) links it through the link plan as the package's
    # native artifact and records it in the manifest, so the shipped image
    # and the kernel it loads are verified together. A linked-source (-Ddev)
    # build returns above and derives its kernel on the first parse.
    _bundle_bun(site, opts);
}

impl _bundle_bun(site: str, opts: MkPayloadOpts) {
    bb = opts.bun_bin;
    if bb is not None {
        bun_dir = os.path.join(site, "jaclang", "client", "_bun");
        make_dirs(bun_dir);
        log(f"==> bundling contained bun runtime ({bb})");
        copy_file(bb, os.path.join(bun_dir, os.path.basename(bb)));
    }
}

impl write_dist_info(repo_root: str, site: str) {
    toml: str | None = None;
    for cand in (
        os.path.join(repo_root, "..", "jac.toml"),
        os.path.join(repo_root, "jac.toml")
    ) {
        try {
            toml = read_bytes(cand).decode("utf-8", errors="replace");
            break;
        } except OSError {
            continue;
        }
    }
    if toml is None {
        raise PayloadDie(
            f"mkpayload: no jac.toml at {repo_root}/../jac.toml or {repo_root}/jac.toml"
        );
    }
    ver = toml_string(toml, "version");
    if ver is None {
        raise PayloadDie("mkpayload: no version in jac.toml");
    }
    di = os.path.join(site, f"jaclang-{ver}.dist-info");
    make_dirs(di);
    write_text(
        os.path.join(di, "METADATA"),
        f"Metadata-Version: 2.1\nName: jaclang\nVersion: {ver}\n"
    );
    write_text(os.path.join(di, "entry_points.txt"), ENTRY_POINTS_TXT);
}

impl run_precompile_stage(py: str, pbs_py_dir: str, site: str, opts: MkPayloadOpts) {
    if opts.skip_precompile or opts.link_source is not None {
        log("==> skipping JIR precompile; modules compile on first run");
        return;
    }
    site_pre = os.path.join(site, "jaclang", "_precompiled");
    pc = opts.precompiled_cache;
    if pc is not None and os.path.isdir(pc) {
        log(f"==> seeding JIR precompile from {pc}");
        copy_tree(pc, site_pre, skip_none);
    }
    precompile(py, pbs_py_dir, site, opts.seal, opts.debug_src);
    if pc is not None {
        delete_tree(pc);
        copy_tree(site_pre, pc, skip_none);
    }
}

impl run_stubcat_stage(py: str, pbs_py_dir: str, site: str, opts: MkPayloadOpts) {
    out_copy = opts.stubcat_out;
    if opts.skip_stubcat or opts.skip_precompile or opts.link_source is not None {
        log("==> skipping the stub catalog; the type checker builds it on first use");
        if out_copy is not None {
            write_bytes(out_copy, b"");
        }
        return;
    }
    site_pre = os.path.join(site, "jaclang", "_precompiled");
    make_dirs(site_pre);
    out = os.path.join(site_pre, "stubcat.bin");
    if not run_stubcat(py, pbs_py_dir, site, out) {
        die("mkpayload: stub catalog build failed (see log above).");
    }
    if out_copy is not None {
        copy_file(out, out_copy);
    }
}

impl run_stubcat(py: str, pbs_py_dir: str, site: str, out: str) -> bool {
    log("==> building the stub catalog (pre-resolved typeshed types)");
    boot = os.path.join(site, "stubcat_boot.py");
    write_text(boot, STUBCAT_BOOT_SRC);
    env = precompile_env(pbs_py_dir, site);
    env["JAC_STUBCAT_BUILDING"] = "1";
    ok = run_child([py, "-S", boot, out], env, True);
    delete_file(boot);
    if not ok or not file_exists(out) {
        return False;
    }
    log(f"   stub catalog: {os.path.getsize(out)} bytes");
    return True;
}

impl precompile_env(pbs_py_dir: str, site: str) -> dict[str, str] {
    env = clone_env();
    env["PYTHONHOME"] = os.path.join(pbs_py_dir, "install");
    env["PYTHONPATH"] = site;
    env["PYTHONUTF8"] = "1";
    env["PYTHONDONTWRITEBYTECODE"] = "1";
    scratch_home = site + ".home";
    make_dirs(scratch_home);
    env["HOME"] = scratch_home;
    env["PATH"] = "/usr/bin:/bin";
    env["JAC_NO_DEV_SOURCE"] = "1";
    env["JAC_STUBCAT_BUILDING"] = "1";
    return env;
}

impl precompile(py: str, pbs_py_dir: str, site: str, seal: bool, debug_src: bool) {
    pc = os.path.join(site, "jaclang", "dist", "precompile_bytecode.jac");
    if not file_exists(pc) {
        return;
    }
    if seal {
        log("==> precompiling + SEALING jaclang (JIR-authoritative image, #7135)");
    } else {
        log("==> precompiling jaclang -> _precompiled JIR (fast first run)");
    }

    boot = os.path.join(site, "precompile_boot.py");
    write_text(boot, PRECOMPILE_BOOT_SRC);
    argv = [py, "-S", boot, site];
    if seal {
        argv.append("--seal-compile");
    }
    if seal and debug_src {
        argv.append("--debug-src");
    }

    env = precompile_env(pbs_py_dir, site);
    run_child(argv, env, True);

    pre_dir = os.path.join(site, "jaclang", "_precompiled");
    result = os.path.join(pre_dir, "PRECOMPILE_RESULT.json");
    if not file_exists(result) {
        die(
            f"mkpayload: precompiler did not run to completion (no {result}); it likely crashed. Fail rather than ship a slow cold-start binary."
        );
    }
    delete_file(result);
    log("   _precompiled: compile pass ran to completion");

    if not seal {
        return;
    }
    fin = [py, "-S", boot, site, "--seal-finalize"];
    if debug_src {
        fin.append("--debug-src");
    }
    log("==> sealing (finalize): completeness check + manifest + freeze bootstrap");
    if not run_child(fin, env, True) {
        die("mkpayload: seal-finalize failed (see log above).");
    }
    if not file_exists(os.path.join(pre_dir, "MANIFEST.json")) {
        die(
            "mkpayload: seal produced no MANIFEST.json; the seal failed (see log above)."
        );
    }
    log(
        "   sealed: MANIFEST.json present; payload boots from JIR (sources ship for tracebacks, never compiled)."
    );
}

impl stage_python_bin(pbs_py_dir: str, stage: str) {
    py = resolve_python(pbs_py_dir);
    bare = os.path.basename(py);
    bin_dst = os.path.join(stage, "python", "bin");
    make_dirs(bin_dst);
    dst = os.path.join(bin_dst, bare);
    copy_file(py, dst);
    os.chmod(dst, 0o755);
    log(f"==> staged project venv interpreter -> python/bin/{bare}");
}

impl stage_tree(
    pbs_py_dir: str,
    site: str,
    stage: str,
    musl_dir: str | None,
    wasm_libc_dir: str | None
) {
    log("==> staging runtime tree (shared libpython + stdlib + site)");
    lib_dst = os.path.join(stage, "python", "lib");
    make_dirs(lib_dst);

    pbs_lib = os.path.join(pbs_py_dir, "install", "lib");
    found = find_libpython(pbs_lib);
    staged_lib = os.path.join(lib_dst, found.bare);
    copy_file(os.path.join(pbs_lib, found.src), staged_lib);
    strip_best_effort(staged_lib);

    stage_stdlib(pbs_lib, lib_dst);

    copy_tree(site, os.path.join(stage, "site"), skip_stage_site);
    strip_best_effort(site_shim_path(os.path.join(stage, "site")));
    strip_kernel_best_effort(os.path.join(stage, "site"));

    stage_python_bin(pbs_py_dir, stage);

    stage_floor(pbs_py_dir, stage);

    if musl_dir is not None {
        stage_musl(musl_dir, stage);
    }
    if wasm_libc_dir is not None {
        stage_wasm_libc(wasm_libc_dir, stage);
    }
}

impl stage_stdlib(pbs_lib: str, lib_dst: str) {
    stdlib_dst = os.path.join(lib_dst, f"python{py_ver()}");
    copy_tree(os.path.join(pbs_lib, f"python{py_ver()}"), stdlib_dst, skip_none);
    for d in STDLIB_PRUNE {
        delete_tree(os.path.join(stdlib_dst, d));
    }
    for name in sorted(os.listdir(stdlib_dst)) {
        full = os.path.join(stdlib_dst, name);
        if os.path.isdir(full) and name.startswith("config-") {
            delete_tree(full);
        }
    }
}

impl precompile_pyc(py: str, stage: str) {
    log("==> precompiling stdlib + site -> hash-based .pyc (survives materialize)");
    stdlib = os.path.join(stage, "python", "lib", f"python{py_ver()}");
    site_dir = os.path.join(stage, "site");
    run_child(
        [
            py,
            "-m",
            "compileall",
            "--invalidation-mode",
            "unchecked-hash",
            "-q",
            "-f",
            "-j",
            "0",
            "-s",
            stage,
            "-p",
            "/jac-rt",
            stdlib,
            site_dir
        ],
        None,
        True
    );
}

impl stage_floor(pbs_py_dir: str, stage: str) {
    osarch = host_os_arch();
    floor_dst = os.path.join(stage, "python", "floor", osarch);
    make_dirs(floor_dst);
    src_lib = os.path.join(pbs_py_dir, "build", "lib");

    staged = 0;
    for name in FLOOR_ARCHIVES {
        src = os.path.join(src_lib, name);
        if not file_exists(src) {
            continue;
        }
        copy_file(src, os.path.join(floor_dst, name));
        staged += 1;
    }
    log(f"==> staged {staged} C-floor archive(s) -> python/floor/{osarch}");

    ca = find_ca_bundle(pbs_py_dir);
    if ca is not None {
        copy_file(ca, os.path.join(stage, "python", "floor", "cacert.pem"));
        log("==> staged CA bundle -> python/floor/cacert.pem");
    } else {
        log(
            "   no CA bundle found under pbs site-packages; ssl floor will fall back to a system bundle"
        );
    }
}

impl stage_musl(musl_dir: str, stage: str) {
    osarch = host_os_arch();
    dst = os.path.join(stage, "python", "floor", osarch, "musl");
    make_dirs(dst);
    staged = 0;
    for name in MUSL_ARTIFACTS {
        src = os.path.join(musl_dir, name);
        if not file_exists(src) {
            continue;
        }
        copy_file(src, os.path.join(dst, name));
        staged += 1;
    }
    log(f"==> staged {staged} musl runtime artifact(s) -> python/floor/{osarch}/musl");
}

impl stage_wasm_libc(wasm_libc_dir: str, stage: str) {
    dst = os.path.join(stage, "python", "floor", "wasm32", "libc");
    make_dirs(dst);
    if not os.path.isdir(wasm_libc_dir) {
        die(
            f"wasm-libc staging: dir missing at {wasm_libc_dir} (run `zig build vendor-wasm-libc`)"
        );
    }
    staged = 0;
    for name in sorted(os.listdir(wasm_libc_dir)) {
        src = os.path.join(wasm_libc_dir, name);
        if not os.path.isfile(src)
            or not name.endswith(".bc")
            or name == "_merged.bc" {
            continue;
        }
        copy_file(src, os.path.join(dst, name));
        staged += 1;
    }
    log(f"==> staged {staged} wasm libc bitcode file(s) -> python/floor/wasm32/libc");
    if staged == 0 {
        die(f"wasm-libc staging: no .bc files in {wasm_libc_dir}");
    }
}

impl find_ca_bundle(pbs_py_dir: str) -> str | None {
    sp = os.path.join(
        pbs_py_dir, "install", "lib", f"python{py_ver()}", "site-packages"
    );
    direct = os.path.join(sp, "pip", "_vendor", "certifi", "cacert.pem");
    if file_exists(direct) {
        return direct;
    }
    if not os.path.isdir(sp) {
        return None;
    }
    for (cur, dirnames, filenames) in walk_sorted(sp) {
        if os.path.basename(cur) == "certifi" and "cacert.pem" in filenames {
            return os.path.join(cur, "cacert.pem");
        }
    }
    return None;
}

impl shim_file_name -> str {
    os_name = host_os_arch().split("-")[0];
    if os_name == "windows" {
        return "jacllvm.dll";
    }
    if os_name == "macos" {
        return "libjacllvm.dylib";
    }
    return "libjacllvm.so";
}

impl site_shim_path(site: str) -> str {
    return os.path.join(
        site, "jaclang", "compiler", "backends", "native", "llvm", shim_file_name()
    );
}

impl find_libpython(lib_dir: str) -> FoundLib {
    so = f"libpython{py_ver()}.so";
    dy = f"libpython{py_ver()}.dylib";
    if file_exists(os.path.join(lib_dir, so)) {
        return FoundLib(src=so, bare=so);
    }
    if file_exists(os.path.join(lib_dir, dy)) {
        return FoundLib(src=dy, bare=dy);
    }
    try {
        names = sorted(os.listdir(lib_dir));
    } except OSError {
        names = [];
    }
    for name in names {
        if name.startswith(so) {
            return FoundLib(src=name, bare=so);
        }
        if name.startswith(dy) {
            return FoundLib(src=name, bare=dy);
        }
    }
    raise PayloadDie(f"mkpayload: shared libpython not found under {lib_dir}");
}

impl is_volatile_path(p: str) -> bool {
    if p.startswith("site/jaclang") {
        if "compiler/backends/native/llvm" in p {
            return False;
        }
        if "client/_bun" in p {
            return False;
        }
        return True;
    }
    return (
        p.startswith("site/_jac_finder.py")
        or p.startswith("site/sitecustomize.py")
        or p.startswith("site/jac_linked_source")
        or p.startswith("site/__pycache__")
    );
}

impl collect_stage_entries(stage: str) -> list[TarEntry] {
    entries: list[TarEntry] = [];
    for (cur, dirnames, filenames) in walk_sorted(stage) {
        rel_dir = os.path.relpath(cur, stage).replace(os.sep, "/");
        prefix = "" if rel_dir == "." else rel_dir + "/";
        for d in dirnames {
            entries.append(TarEntry(path=prefix + d, is_dir=True));
        }
        for fname in filenames {
            entries.append(TarEntry(path=prefix + fname, is_dir=False));
        }
    }
    entries.sort(key=lambda (e: TarEntry) { e.path.encode("utf-8"); });
    return entries;
}

def _tar_info(path: str, is_dir: bool, mode: int, size: int) -> tarfile.TarInfo {
    ti = tarfile.TarInfo(path);
    ti.type = TAR_DIRTYPE if is_dir else TAR_REGTYPE;
    ti.mode = mode;
    ti.size = size;
    ti.mtime = 0;
    ti.uid = 0;
    ti.gid = 0;
    ti.uname = "";
    ti.gname = "";
    return ti;
}

impl tar_stage(stage: str) -> tuple[bytes, bytes] {
    deps_buf = io.BytesIO();
    jac_buf = io.BytesIO();
    deps_tw = tarfile.open(fileobj=deps_buf, mode="w", format=TAR_PAX_FORMAT);
    jac_tw = tarfile.open(fileobj=jac_buf, mode="w", format=TAR_PAX_FORMAT);
    for e in collect_stage_entries(stage) {
        tw = jac_tw if is_volatile_path(e.path) else deps_tw;
        if e.is_dir {
            tw.addfile(_tar_info(e.path, True, 0o755, 0));
            continue;
        }
        full = os.path.join(stage, e.path);
        data = read_bytes(full);
        mode = source_file_mode(full);
        if mode == 0 {
            mode = 0o664;
        }
        tw.addfile(_tar_info(e.path, False, mode, len(data)), io.BytesIO(data));
    }
    return (deps_buf.getvalue(), jac_buf.getvalue());
}

impl tar_zst_dir(stage: str, out: str, layer_cache: str | None) {
    if not os.path.isdir(stage) {
        die(f"mkpayload: stage dir missing at {stage}");
    }
    (deps_tar, jac_tar) = tar_stage(stage);

    deps_frame = deps_frame_cached(layer_cache, deps_tar);

    log(f"==> packing jac layer | zstd -{PAYLOAD_ZSTD_LEVEL}");
    jac_frame = zstd_compress(jac_tar);

    with open(out, "wb") as f {
        f.write(deps_frame);
        f.write(jac_frame);
    }
}

impl zstd_compress(data: bytes) -> bytes {
    opts: dict[int, int] = {
        int(CompressionParameter.compression_level): PAYLOAD_ZSTD_LEVEL,
        int(CompressionParameter.window_log): PAYLOAD_WINDOW_LOG,
        int(CompressionParameter.checksum_flag): 0
    };
    workers = min(os.cpu_count() or 1, 32);
    try {
        mt: dict[int, int] = dict(opts);
        mt[int(CompressionParameter.nb_workers)] = workers;
        return compress(data, options=mt);
    } except Exception {}
    return compress(data, options=opts);
}

impl deps_frame_cached(layer_cache: str | None, tar_bytes: bytes) -> bytes {
    key = sha256_hex(tar_bytes);
    cache_path = (
        os.path.join(layer_cache, f"deps-{key}.tar.zst")
            if layer_cache is not None
            else None
    );

    if cache_path is not None {
        cached: bytes | None = None;
        try {
            cached = read_bytes(cache_path);
        } except OSError {
            log(f"==> deps layer: no cached frame (key {key[:16]}); compressing");
        }
        if cached is not None {
            if frame_decodes_to(cached, tar_bytes) {
                log(f"==> deps layer: reusing cached frame (key {key[:16]})");
                return cached;
            }
            log("==> deps layer: cached frame failed verification; recompressing");
        }
    }

    log(f"==> packing deps layer | zstd -{PAYLOAD_ZSTD_LEVEL}");
    fresh = zstd_compress(tar_bytes);
    if cache_path is not None and layer_cache is not None {
        prune_layer_cache(layer_cache, os.path.basename(cache_path));
        try {
            make_dirs(layer_cache);
            write_bytes(cache_path, fresh);
        } except OSError as e {
            log(f"==> deps layer: cache write failed ({type(e).__name__}); continuing");
        }
    }
    return fresh;
}

impl frame_decodes_to(frame: bytes, expect: bytes) -> bool {
    try {
        got = decompress(frame);
    } except Exception {
        return False;
    }
    return got == expect;
}

impl prune_layer_cache(dir_path: str, keep: str) {
    try {
        names = os.listdir(dir_path);
    } except OSError {
        return;
    }
    for name in names {
        if not name.startswith("deps-")
            or not name.endswith(".tar.zst")
            or name == keep {
            continue;
        }
        stale = os.path.join(dir_path, name);
        if os.path.isfile(stale) {
            delete_file(stale);
        }
    }
}

"""Strip the sealed kernel in the staged site and re-record its sha256 in
the manifest: the seal verified the unstripped artifact, and a stripped
binary must still hash to what the manifest says."""
impl strip_kernel_best_effort(site: str) {
    import hashlib;
    import json;
    manifest_path = os.path.join(site, "jaclang", "_precompiled", "MANIFEST.json");
    if not file_exists(manifest_path) {
        return;
    }
    with open(manifest_path, "r", encoding="utf-8") as f {
        manifest = json.load(f);
    }
    record = (manifest.get("native") or {}).get("artifact");
    if not record {
        return;
    }
    lib = os.path.join(site, "jaclang", record["path"]);
    if not file_exists(lib) {
        return;
    }
    strip_best_effort(lib);
    with open(lib, "rb") as f {
        record["sha256"] = hashlib.sha256(f.read()).hexdigest();
    }
    with open(manifest_path, "w", encoding="utf-8") as f {
        f.write(json.dumps(manifest, sort_keys=True, indent=1) + "\n");
    }
}
