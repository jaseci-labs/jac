import io;
import os;
import time;
import tarfile;

import from compression.zstd {
    CompressionParameter,
    compress,
    decompress,
    zstd_version_info
}
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

impl mk_payload(python_dir: str, repo_root: str, out: str, opts: MkPayloadOpts) {
    opts.measurements.output_path = os.environ.get("JAC_BUILD_METRICS", "")
        or out + ".metrics.json";
    try {
        with opts.measurements.stage("payload") {
            py = resolve_python(python_dir);
            work = out + ".work";
            delete_tree(work);
            make_dirs(work);
            site = os.path.join(work, "site");
            stage = os.path.join(work, "stage");
            ts_versions = os.path.join(
                repo_root, TYPESHED_VENDOR, "stdlib", "VERSIONS"
            );
            if not file_exists(ts_versions) {
                fetch_typeshed(repo_root);
            }
            log("==> assembling jaclang site from source (no pyproject build)");
            make_dirs(site);
            with opts.measurements.stage("assemble_site") {
                assemble_site(repo_root, site, opts);
            }
            import from jaclang.dist.payload.python_dependencies {
                install_dependencies
            }
            with opts.measurements.stage("python_dependencies") {
                reused = install_dependencies(
                    py,
                    site,
                    os.path.join(
                        opts.layer_cache
                            or os.path.join(repo_root, ".jac", "cache", "payload"),
                        "producers"
                    )
                );
                opts.measurements.cache_outcome(
                    "python_dependencies", "hit" if reused else "miss"
                );
            }
            with opts.measurements.stage("stage_floor") {
                stage_floor(python_dir, work);
            }
            with opts.measurements.stage("precompile_and_seal") {
                run_precompile_stage(py, python_dir, site, opts);
            }
            delete_tree(os.path.join(site, "__pycache__"));
            with opts.measurements.stage("stage_tree") {
                stage_tree(python_dir, site, stage, opts.musl_dir, opts.wasm_libc_dir);
            }
            with opts.measurements.stage("python_bytecode") {
                precompile_pyc(py, stage, opts);
            }
            with opts.measurements.stage("archive_and_compress") {
                tar_zst_dir(stage, out, opts.layer_cache, opts.measurements);
            }
            log(f"==> payload: {out}");
            delete_tree(work);
        }
    } finally {
        opts.measurements.flush();
    }
}

impl resolve_python(python_dir: str) -> str {
    p1 = os.path.join(python_dir, "install", "bin", f"python{py_ver()}");
    if file_exists(p1) {
        return p1;
    }
    p2 = os.path.join(python_dir, "install", "bin", "python3");
    if file_exists(p2) {
        return p2;
    }
    raise PayloadDie(f"mkpayload: no python at {python_dir}/install/bin");
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
        copy_file(
            os.path.join(repo_root, "bootstrap", "python", "sources.json"),
            os.path.join(site, "jaclang", "dist", "payload", "python-sources.json")
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

    with opts.measurements.stage("compiler_kernel") {
        build_compiler_kernel(repo_root, site, opts);
    }
    _bundle_bun(site, opts);
}

impl build_compiler_kernel(repo_root: str, site: str, opts: MkPayloadOpts) {
    so = opts.shim_so;
    assert so is not None;
    import sys;
    jc_name = (
        "libjac_compiler.dylib" if sys.platform == "darwin" else "libjac_compiler.so"
    );
    jc_src = os.path.join(repo_root, "jaclang", "compiler", "jc_unit.jac");
    jc_dst = os.path.join(site, "jaclang", "compiler", jc_name);
    if not file_exists(jc_src) {
        log("==> no compiler kernel unit in this tree; skipping kernel build");
        return;
    }
    if os.environ.get("JAC_PAYLOAD_SKIP_KERNEL") == "1" {
        log("==> skipping native compiler kernel (JAC_PAYLOAD_SKIP_KERNEL=1)");
        return;
    }
    import hashlib;
    import json;
    import from pathlib { Path }
    import from jaclang.compiler.driver.jir { compute_content_sha256 }
    import from jaclang.compiler.types.stubcat.locate { type_system_digest }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.dist.payload.artifacts { ArtifactStore }
    cache = ArtifactStore(
        Path(opts.layer_cache or os.path.join(repo_root, ".jac", "cache", "payload"))
            / "producers"
    );
    def input_key -> str {
        inputs = [
            "compiler-kernel-v1",
            type_system_digest(os.path.join(repo_root, "jaclang")),
            compute_content_sha256(so),
            host_os_arch(),
            sys.version,
            compute_content_sha256(sys.executable),
            CompileOptions().codegen_identity(),
            compute_content_sha256(__file__),
            compute_content_sha256(
                os.path.join(os.path.dirname(__file__), "impl", "assemble.impl.jac")
            )
        ];
        for ancestor in [
            Path(repo_root).resolve(),
            *Path(repo_root).resolve().parents
        ] {
            config = ancestor / "jac.toml";
            if config.is_file() {
                inputs.append(compute_content_sha256(str(config)));
            }
        }
        return hashlib.sha256(json.dumps(inputs).encode()).hexdigest();
    }
    key = input_key();
    outputs = {
        jc_name: Path(jc_dst),
        jc_name + ".layout.json": Path(jc_dst + ".layout.json")
    };
    with cache.lock("compiler_kernel", key) {
        if cache.restore("compiler_kernel", key, outputs) {
            log("==> reusing completed native compiler kernel and layout");
            opts.measurements.cache_outcome("compiler_kernel", "hit");
            return;
        }
        opts.measurements.cache_outcome("compiler_kernel", "miss");
        log(f"==> building native compiler kernel (jac build --native --lib {jc_src})");
        jc_boot = (
            "import os, sys\n"
            + "root, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]\n"
            + "sys.path.insert(0, root)\n"
            + "import _jac_finder\n"
            + "_jac_finder.install()\n"
            + "from jaclang.cli.commands.native_build import native_build\n"
            + "rc = int(native_build(src, output=dst, lib=True) or 0)\n"
            + "sys.stdout.flush()\n"
            + "sys.stderr.flush()\n"
            + "os._exit(rc)\n"
        );
        jc_env = clone_env();
        jc_env["JAC_LLVM_SHIM"] = os.path.abspath(so);
        jc_env["JAC_COMPILER_LIB"] = "off";
        jc_env["JAC_NO_DEV_SOURCE"] = "1";
        jc_env["JAC_STUBCAT_BUILDING"] = "1";
        jc_ok = run_child(
            [sys.executable, "-I", "-c", jc_boot, repo_root, jc_src, jc_dst],
            jc_env,
            True
        );
        if (
            not jc_ok
            or not file_exists(jc_dst)
            or not file_exists(jc_dst + ".layout.json")
        ) {
            raise PayloadDie(
                f"mkpayload: native compiler kernel build failed; the shipped"
                f" binary requires {jc_dst} and its .layout.json sidecar."
            );
        }
        if input_key() != key {
            raise PayloadDie(
                "mkpayload: compiler kernel inputs changed during construction"
            );
        }
        cache.publish("compiler_kernel", key, outputs);
    }
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

impl run_precompile_stage(py: str, python_dir: str, site: str, opts: MkPayloadOpts) {
    if opts.skip_precompile or opts.link_source is not None {
        run_stubcat_stage(py, python_dir, site, opts);
        log("==> skipping JIR precompile; modules compile on first run");
        return;
    }
    site_pre = os.path.join(site, "jaclang", "_precompiled");
    pc = opts.precompiled_cache;
    import from jaclang.jac0core.cache_paths { FileLock }
    if pc is not None {
        with FileLock(pc + ".lock") {
            if os.path.isdir(pc) {
                log(f"==> seeding JIR precompile from {pc}");
                copy_tree(pc, site_pre, skip_none);
            }
        }
    }

    delete_file(os.path.join(site_pre, "MANIFEST.json"));
    run_stubcat_stage(py, python_dir, site, opts);
    precompile(
        py,
        python_dir,
        site,
        opts.seal,
        opts.debug_src,
        opts.skip_stubcat,
        measurements=opts.measurements
    );
    if pc is not None {
        with FileLock(pc + ".lock") {
            delete_tree(pc);
            copy_tree(site_pre, pc, skip_none);
        }
    }
}

impl run_stubcat_stage(py: str, python_dir: str, site: str, opts: MkPayloadOpts) {
    out_copy = opts.stubcat_out;
    if opts.skip_stubcat or opts.skip_precompile or opts.link_source is not None {
        log("==> skipping the stub catalog; the type checker builds it on first use");
        delete_file(os.path.join(site, "jaclang", "_precompiled", "stubcat.bin"));
        if out_copy is not None {
            write_bytes(out_copy, b"");
        }
        return;
    }
    site_pre = os.path.join(site, "jaclang", "_precompiled");
    make_dirs(site_pre);
    out = os.path.join(site_pre, "stubcat.bin");
    with opts.measurements.stage("stub_catalog") {
        built = run_stubcat(py, python_dir, site, out);
    }
    if not built {
        die("mkpayload: stub catalog build failed (see log above).");
    }
    import json;
    with open(out + ".json", "r", encoding="utf-8") as metadata {
        reused = bool(json.load(metadata).get("reused"));
    }
    opts.measurements.cache_outcome("stub_catalog", "hit" if reused else "miss");
    if out_copy is not None {
        copy_file(out, out_copy);
    }
}

impl run_stubcat(py: str, python_dir: str, site: str, out: str) -> bool {
    log("==> building the stub catalog (pre-resolved typeshed types)");
    boot = os.path.join(site, "stubcat_boot.py");
    write_text(boot, STUBCAT_BOOT_SRC);
    env = precompile_env(python_dir, site);
    env["JAC_STUBCAT_BUILDING"] = "1";
    ok = run_child([py, "-S", boot, out], env, True);
    delete_file(boot);
    if not ok or not file_exists(out) {
        return False;
    }
    log(f"   stub catalog: {os.path.getsize(out)} bytes");
    return True;
}

impl precompile_env(python_dir: str, site: str) -> dict[str, str] {
    env = clone_env();
    env["PYTHONHOME"] = os.path.join(python_dir, "install");
    env["PYTHONPATH"] = site;
    env["PYTHONUTF8"] = "1";
    env["PYTHONDONTWRITEBYTECODE"] = "1";
    scratch_home = site + ".home";
    make_dirs(scratch_home);
    env["HOME"] = scratch_home;
    env["PATH"] = "/usr/bin:/bin";
    env["JAC_NO_DEV_SOURCE"] = "1";
    import sys;
    kernel = os.path.join(
        site,
        "jaclang",
        "compiler",
        "libjac_compiler.dylib" if sys.platform == "darwin" else "libjac_compiler.so"
    );
    env["JAC_COMPILER_LIB"] = kernel
        if file_exists(kernel) and file_exists(kernel + ".layout.json")
        else "off";
    for name in (
        "JAC_STUBCAT_BUILDING",
        "JAC_STUBCAT_FILE",
        "JAC_STUBCAT_OFF",
        "JAC_STUBCAT_LEN"
    ) {
        env.pop(name, None);
    }
    return env;
}

impl precompile(
    py: str,
    python_dir: str,
    site: str,
    seal: bool,
    debug_src: bool,
    skip_stubcat: bool = False,
    measurements: BuildMeasurements | None = None
) {
    timings = measurements if measurements is not None else BuildMeasurements();
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

    env = precompile_env(python_dir, site);
    if skip_stubcat {
        env["JAC_STUBCAT_BUILDING"] = "1";
    }
    pre_dir = os.path.join(site, "jaclang", "_precompiled");
    result = os.path.abspath(timings.output_path) + ".precompile.json"
        if timings.output_path
        else os.path.join(os.path.dirname(site), "precompile-result.json");
    env["JAC_PRECOMPILE_METRICS"] = result;
    import json;
    with timings.stage("module_precompile") {
        env["JAC_PRECOMPILE_START_TIME"] = str(time.perf_counter());
        compiled = run_child(argv, env, True);
        if not file_exists(result) {
            die(f"mkpayload: precompiler produced no completion result: {result}");
        }
        with open(result, "r", encoding="utf-8") as metrics_file {
            timings.compilation = json.load(metrics_file);
        }
        if not compiled
            or not timings.compilation.get("complete", False)
            or timings.compilation.get("failed", 0) {
            die("mkpayload: precompile failed (see log above).");
        }
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
    env["JAC_SEAL_METRICS"] = result;
    with timings.stage("seal_finalize") {
        env["JAC_PRECOMPILE_START_TIME"] = str(time.perf_counter());
        sealed = run_child(fin, env, True);
        if file_exists(result) {
            with open(result, "r", encoding="utf-8") as metrics_file {
                timings.compilation["seal"] = json.load(metrics_file);
            }
        }
        if not sealed {
            die("mkpayload: seal-finalize failed (see log above).");
        }
        if not file_exists(os.path.join(pre_dir, "MANIFEST.json")) {
            die("mkpayload: seal produced no MANIFEST.json (see log above).");
        }
    }
    delete_file(result);
    log(
        "   sealed: MANIFEST.json present; payload boots from JIR (sources ship for tracebacks, never compiled)."
    );
}

impl stage_python_bin(python_dir: str, stage: str) {
    py = resolve_python(python_dir);
    bare = os.path.basename(py);
    bin_dst = os.path.join(stage, "python", "bin");
    make_dirs(bin_dst);
    dst = os.path.join(bin_dst, bare);
    copy_file(py, dst);
    os.chmod(dst, 0o755);
    log(f"==> staged project venv interpreter -> python/bin/{bare}");
}

impl stage_tree(
    python_dir: str,
    site: str,
    stage: str,
    musl_dir: str | None,
    wasm_libc_dir: str | None
) {
    log("==> staging runtime tree (shared libpython + stdlib + site)");
    lib_dst = os.path.join(stage, "python", "lib");
    make_dirs(lib_dst);

    python_lib = os.path.join(python_dir, "install", "lib");
    found = find_libpython(python_lib);
    staged_lib = os.path.join(lib_dst, found.bare);
    copy_file(os.path.join(python_lib, found.src), staged_lib);
    strip_best_effort(staged_lib);

    stage_stdlib(python_lib, lib_dst);

    copy_tree(site, os.path.join(stage, "site"), skip_stage_site);
    strip_best_effort(site_shim_path(os.path.join(stage, "site")));
    import sys as _sys;
    strip_best_effort(
        os.path.join(
            stage,
            "site",
            "jaclang",
            "compiler",
            "libjac_compiler.dylib"
                if _sys.platform == "darwin"
                else "libjac_compiler.so"
        )
    );

    stage_python_bin(python_dir, stage);

    copy_tree(
        os.path.join(python_dir, "licenses"),
        os.path.join(stage, "python", "licenses"),
        skip_none
    );

    stage_floor(python_dir, stage);

    if musl_dir is not None {
        stage_musl(musl_dir, stage);
    }
    if wasm_libc_dir is not None {
        stage_wasm_libc(wasm_libc_dir, stage);
    }
}

impl stage_stdlib(python_lib: str, lib_dst: str) {
    stdlib_dst = os.path.join(lib_dst, f"python{py_ver()}");
    copy_tree(
        os.path.join(python_lib, f"python{py_ver()}"),
        stdlib_dst,
        lambda (path: str) -> bool { return "site-packages"
            in path.replace("\\", "/").split("/"); }
    );
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

impl precompile_pyc(py: str, stage: str, opts: MkPayloadOpts | None = None) {
    import from jaclang.dist.payload.python_bytecode { precompile_tree }
    cache = opts.layer_cache if opts is not None else None;
    if cache is None {
        import from jaclang.jac0core.cache_paths { get_jir_cache_dir }
        cache = str(get_jir_cache_dir() / "payload");
    }
    counts = precompile_tree(py, stage, os.path.join(cache, "producers"));
    log(
        f"==> Python bytecode: {counts['compiled']} compiled, {counts['reused']} reused"
    );
    if opts is not None {
        opts.measurements.cache_outcomes["python_bytecode"] = counts;
    }
}

impl stage_floor(python_dir: str, stage: str) {
    osarch = host_os_arch();
    floor_dst = os.path.join(stage, "python", "floor", osarch);
    make_dirs(floor_dst);
    src_lib = os.path.join(python_dir, "build", "lib");

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

    pinned_ca = os.path.join(stage, "site", "pip", "_vendor", "certifi", "cacert.pem");
    ca = pinned_ca if file_exists(pinned_ca) else find_ca_bundle(python_dir);
    if ca is not None {
        copy_file(ca, os.path.join(stage, "python", "floor", "cacert.pem"));
        log("==> staged CA bundle -> python/floor/cacert.pem");
    } else {
        log(
            "   no CA bundle found in the Python distribution; ssl floor will fall back to a system bundle"
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

impl find_ca_bundle(python_dir: str) -> str | None {
    bundled = os.path.join(python_dir, "build", "cacert.pem");
    if file_exists(bundled) {
        return bundled;
    }
    sp = os.path.join(
        python_dir, "install", "lib", f"python{py_ver()}", "site-packages"
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

impl tar_zst_dir(
    stage: str,
    out: str,
    layer_cache: str | None,
    measurements: BuildMeasurements | None = None
) {
    if not os.path.isdir(stage) {
        die(f"mkpayload: stage dir missing at {stage}");
    }
    (deps_tar, jac_tar) = tar_stage(stage);

    deps_frame = compressed_frame_cached(layer_cache, "deps", deps_tar, measurements);

    jac_frame = compressed_frame_cached(layer_cache, "jac", jac_tar, measurements);

    import from jaclang.jac0core.cache_paths { atomic_write }
    atomic_write(out, deps_frame + jac_frame);
}

impl zstd_options -> dict[int, int] {
    opts: dict[int, int] = {
        int(CompressionParameter.compression_level): PAYLOAD_ZSTD_LEVEL,
        int(CompressionParameter.window_log): PAYLOAD_WINDOW_LOG,
        int(CompressionParameter.checksum_flag): 0
    };
    (_, max_workers) = CompressionParameter.nb_workers.bounds();
    if max_workers > 0 {
        opts[int(CompressionParameter.nb_workers)] = min(
            os.process_cpu_count() or 1, 32, max_workers
        );
    }
    return opts;
}

impl zstd_compress(data: bytes) -> bytes {
    return compress(data, options=zstd_options());
}

impl deps_frame_cached(layer_cache: str | None, tar_bytes: bytes) -> bytes {
    return compressed_frame_cached(layer_cache, "deps", tar_bytes);
}

impl compressed_frame_cached(
    layer_cache: str | None,
    name: str,
    tar_bytes: bytes,
    measurements: BuildMeasurements | None = None
) -> bytes {
    import json;
    import sys;
    key = sha256_hex(
        json.dumps([zstd_version_info, zstd_options(), sys.version]).encode()
            + tar_bytes
    );
    cache_path = (
        os.path.join(layer_cache, f"{name}-{key}.tar.zst")
            if layer_cache is not None
            else None
    );

    import from jaclang.jac0core.cache_paths { FileLock }
    lock: FileLock | None = None;
    if layer_cache is not None {
        try {
            lock = FileLock(os.path.join(layer_cache, name + ".lock"));
            lock.acquire();
        } except OSError {
            lock = None;
        }
    }
    try {
        if cache_path is not None {
            cached: bytes | None = None;
            try {
                cached = read_bytes(cache_path);
            } except OSError {
                log(f"==> {name} layer: no cached frame (key {key[:16]}); compressing");
            }
            if cached is not None {
                if frame_decodes_to(cached, tar_bytes) {
                    log(f"==> {name} layer: reusing cached frame (key {key[:16]})");
                    if measurements is not None {
                        measurements.cache_outcome(name + "_frame", "hit");
                    }
                    return cached;
                }
                log(
                    f"==> {name} layer: cached frame failed verification; recompressing"
                );
            }
        }

        log(f"==> packing {name} layer | zstd -{PAYLOAD_ZSTD_LEVEL}");
        if measurements is not None {
            measurements.cache_outcome(name + "_frame", "miss");
        }
        fresh = zstd_compress(tar_bytes);
        if lock is not None and cache_path is not None and layer_cache is not None {
            prune_layer_cache(layer_cache, os.path.basename(cache_path));
            try {
                make_dirs(layer_cache);
                import from jaclang.jac0core.cache_paths { atomic_write }
                atomic_write(cache_path, fresh);
            } except OSError as e {
                log(
                    f"==> {name} layer: cache write failed ({type(
                        e
                    ).__name__}); continuing"
                );
            }
        }
        return fresh;
    } finally {
        if lock is not None {
            lock.release();
        }
    }
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
    prefix = keep.split("-", 1)[0] + "-";
    try {
        names = os.listdir(dir_path);
    } except OSError {
        return;
    }
    for name in names {
        if not name.startswith(prefix)
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
