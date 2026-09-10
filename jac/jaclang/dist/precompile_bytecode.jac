import hashlib;
import json;
import marshal;
import os;
import shutil;
import sys;
import time;
import zlib;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core { ext_registry }
import from jaclang.compiler.driver.jir { patch_co_filenames_bytes }
import from jaclang.compiler.driver.jir {
    write_precompiled_jir,
    FLAG_PRECOMPILED,
    FLAG_BOOTSTRAP,
    HEADER_SIZE,
    SECTIONS_MAGIC,
    SEC_BYTECODE,
    SEC_MODKEY,
    parse_header,
    read_sections,
    SEC_CTDEPS,
    SEC_DEBUG_SRC,
    NATIVE_SECTIONS,
    SEC_NIFACE,
    SEC_NOBJ,
    SEC_PLACEMENT,
    FORMAT_VERSION,
    compute_precompile_module_key,
    get_module_cache_path,
    is_module_cache_valid,
    precompiled_jir_matches_source,
    read_section_bytes,
    rebase_ct_deps_section,
    running_compiler_digest,
    PRECOMPILE_SENTINEL
}
import from jaclang.jac0core.sealed {
    MANIFEST_NAME,
    MANIFEST_FORMAT,
    JIR_FORMAT_VERSION as SEALED_JIR_FORMAT_VERSION,
    PRECOMPILE_SENTINEL as SEALED_SENTINEL,
    HEADER_SIZE as SEALED_HEADER_SIZE,
    SECTIONS_MAGIC as SEALED_SECTIONS_MAGIC,
    SEC_BYTECODE as SEALED_SEC_BYTECODE,
    SEC_DEBUG_SRC as SEALED_SEC_DEBUG_SRC,
    SEC_NIFACE as SEALED_SEC_NIFACE,
    SEC_NOBJ as SEALED_SEC_NOBJ
}

glob RESULT_NAME: str = "PRECOMPILE_RESULT.json";

def compiler_identity -> str {
    digest = running_compiler_digest();
    if digest.startswith("0:") {
        raise RuntimeError(
            "Precompile aborted: no compiler sources found under the running "
            "jaclang package, so this build cannot state which compiler it is. "
            "Every seeded .jir would then be reusable by any other compiler at "
            "this version -- the #8178 failure mode. Check that the seed tree and "
            "compiler/ ship with the running jaclang."
        );
    }
    return digest;
}

def find_package_dir(source_dir: str) -> str | None {
    src = Path(source_dir).resolve();
    if not src.is_dir() {
        console.error(f"Error: {source_dir} is not a directory");
        return None;
    }
    excluded: list[str] = [
        "tests",
        "test",
        "scripts",
        "docs",
        ".git",
        ".github",
        "node_modules"
    ];

    for child in sorted(src.iterdir()) {
        if child.is_dir() and child.name not in excluded {
            init_py = child / "__init__.py";
            init_jac = child / "__init__.jac";
            if init_py.is_file() or init_jac.is_file() {
                return str(child);
            }
        }
    }
    return None;
}

def _nested_project_dirs(package_dir: str) -> list[str] {
    pkg = Path(package_dir);
    roots: list[str] = [];
    for toml in pkg.rglob("jac.toml") {
        d = toml.parent;
        if d != pkg {
            roots.append(str(d) + os.sep);
        }
    }
    return roots;
}

def find_jac_files(package_dir: str) -> list[str] {
    import from jaclang.compiler.placement.placement_facts { native_only }
    result: list[str] = [];
    skipped: list[str] = [];
    pkg = Path(package_dir);
    for jac_file in sorted(pkg.rglob("*.jac")) {
        if not jac_file.is_file() {
            continue;
        }
        rel_path = jac_file.relative_to(pkg);
        rel = str(rel_path);

        if any(
            part.startswith(".") or part == "__pycache__" for part in rel_path.parts
        ) {
            continue;
        }

        if (
            ".test." in rel
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or rel.startswith(".")
            or ".impl." in jac_file.name
        ) {
            continue;
        }
        if native_only(str(jac_file)) {
            skipped.append(rel);
            continue;
        }
        result.append(str(jac_file));
    }
    if skipped {
        console.print(
            f"  Leaving {len(skipped)} native-only module(s) to the native builder: "
                + ", ".join(skipped[:8])
        );
    }
    return result;
}

def package_native_units(package_dir: str) -> list[str] {
    import from jaclang.compiler.placement.placement_facts { native_units_of }
    base = os.path.abspath(package_dir);
    nested = _nested_project_dirs(package_dir);
    pkg = Path(package_dir);
    sources: list[str] = [];
    for jac_file in sorted(pkg.rglob("*.jac")) {
        rel_path = jac_file.relative_to(pkg);
        rel = str(rel_path);
        if any(
            part.startswith(".") or part == "__pycache__" for part in rel_path.parts
        ) {
            continue;
        }
        if (
            ".test." in rel
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or ".impl." in jac_file.name
            or any(str(jac_file).startswith(n) for n in nested)
        ) {
            continue;
        }
        sources.append(str(jac_file));
    }
    return native_units_of(base, sources);
}

glob _sealable_cache: dict[str, list[str]] = {},
     _placement_cache: dict[str, dict[str, set[str]]] = {};

def sealable_sources(package_dir: str) -> list[str] {
    key = os.path.abspath(package_dir);
    cached = _sealable_cache.get(key);
    if cached is not None {
        return cached;
    }
    import from jaclang.bootstrap_manifest { is_seed_source }
    base = os.path.abspath(package_dir);
    nested = _nested_project_dirs(package_dir);
    candidates = [
        p
        for p in find_jac_files(package_dir)
        if not is_seed_source(os.path.relpath(p, base).replace(os.sep, "/"))
            and not any(p.startswith(n) for n in nested)
    ];
    if Path(package_dir).name == "jaclang" {
        result = list(candidates);
    } else {
        import from jaclang.compiler.placement.placement_facts {
            discover_spaces,
            spaces_are_client_only
        }
        import from jaclang.compiler.driver.program { JacProgram }
        discovery = JacProgram();
        facts = discover_spaces(candidates, discovery);
        _placement_cache[key] = facts;
        if discovery.errors_had {
            console.print(
                f"  Placement discovery hit {len(discovery.errors_had)} "
                "error(s); sealing every candidate so each failure surfaces "
                "per-file instead of being skipped."
            );
            result = candidates;
        } else {
            skipped = [
                p
                for p in candidates
                if spaces_are_client_only(facts[os.path.abspath(p)])
            ];
            result = [
                p
                for p in candidates
                if p not in skipped
            ];
            if skipped {
                names = ", ".join(
                    str(Path(p).relative_to(Path(key))) for p in skipped[:8]
                );
                console.print(
                    f"  Skipping {len(skipped)} client-only module(s): {names}"
                );
            }
        }
        discovery.release_compile_closure();
    }
    _sealable_cache[key] = result;
    return result;
}

def placement_facts_map(package_dir: str) -> dict[str, list[str]] {
    key = os.path.abspath(package_dir);
    sealable_sources(package_dir);
    facts = _placement_cache.get(key);
    if not facts {
        return {};
    }
    out: dict[str, list[str]] = {};
    for (ap, spaces) in facts.items() {
        rel = Path(ap).relative_to(Path(key)).as_posix();
        out[rel] = sorted(spaces);
    }
    return out;
}

def _emit_unit_diagnostics(jac_path: str, programs: list) {
    import from jaclang.compiler.driver.source_failures {
        compiler_source_failure_details
    }
    stashed = compiler_source_failure_details(jac_path);
    if stashed {
        stash_lines = stashed.splitlines();
        for line in stash_lines[:40] {
            console.error(line);
        }
        if len(stash_lines) > 40 {
            console.error(f"  ... and {len(stash_lines) - 40} more line(s)");
        }
        return;
    }
    norm = os.path.normpath(jac_path);
    stem = norm[:-4] if norm.endswith(".jac") else norm;
    base = os.path.basename(stem) + ".";
    lines: list[str] = [];
    seen: set[str] = set();
    for prog in programs {
        for alert in prog.errors_had {
            try {
                alert_path = os.path.normpath(alert.loc.mod_path);
            } except Exception {
                continue;
            }
            if not (
                alert_path == norm
                or alert_path.startswith(stem + ".")
                or os.path.basename(alert_path).startswith(base)
            ) {
                continue;
            }
            pretty = alert.pretty_print();
            if pretty not in seen {
                seen.add(pretty);
                lines.append(pretty);
            }
        }
    }
    for line in lines[:10] {
        console.error(line);
    }
    if len(lines) > 10 {
        console.error(f"  ... and {len(lines) - 10} more error(s)");
    }
}

glob _unit_program: list = [];

def _ct_deps_extra(jac_path: str, pkg_root: str) -> dict[int, bytes] {
    try {
        cache_path = get_module_cache_path(jac_path);
        if not cache_path.exists() {
            return {};
        }
        raw = read_section_bytes(cache_path.read_bytes(), SEC_CTDEPS);
        if not raw {
            return {};
        }
        return {
            int(SEC_CTDEPS): rebase_ct_deps_section(raw, os.path.normpath(pkg_root))
        };
    } except Exception {
        return {};
    }
}

def _native_extra(jac_path: str, pkg_root: str) -> dict[int, bytes] {
    import from jaclang.compiler.driver.jir {
        SEC_NCTDEPS,
        NativeStamp,
        native_section_variants,
        pack_native_variants
    }
    out: dict[int, bytes] = {};
    try {
        cache_path = get_module_cache_path(jac_path);
        if not cache_path.exists() {
            return out;
        }
        data = cache_path.read_bytes();
        for sec in list(NATIVE_SECTIONS) + [SEC_PLACEMENT] {
            raw = read_section_bytes(data, sec);
            if raw is None {
                continue;
            }
            if sec == SEC_PLACEMENT {
                import from jaclang.compiler.driver.jir { rebase_placement_section }
                raw = rebase_placement_section(raw, os.path.normpath(pkg_root));
            }
            if sec == SEC_NCTDEPS {
                rebased: dict[str, bytes] = {};
                for (key, record) in native_section_variants(raw).items() {
                    unpacked = NativeStamp.unpack_record(record);
                    if unpacked is not None {
                        wrapped = unpacked[0].pack(
                            rebase_ct_deps_section(
                                unpacked[1], os.path.normpath(pkg_root)
                            )
                        );
                        rebased.update(native_section_variants(wrapped));
                    }
                }
                raw = pack_native_variants(rebased);
            }
            out[int(sec)] = raw;
        }
    } except Exception {}
    return out;
}

def _unit_extra(jac_path: str, pkg_root: str, embed_src: bool) -> dict[int, bytes] {
    extra: dict[int, bytes] = _ct_deps_extra(jac_path, pkg_root);
    extra.update(_native_extra(jac_path, pkg_root));
    if embed_src {
        extra[int(SEC_DEBUG_SRC)] = zlib.compress(Path(jac_path).read_bytes(), 9);
    }
    return extra;
}

glob _unit_native_program: list = [];

def precompile_native_unit(jac_path: str, collect: bool = True) -> str {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.cli.workpool { maybe_malloc_trim }
    if not _unit_native_program {
        _unit_native_program.append(JacProgram());
    }
    program = _unit_native_program[0];
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        native_unit=True,
        skip_native_engine=True
    );
    ent = program.native_units().ensure(
        jac_path, compile_on_miss=True, options=options
    );
    if ent is None {
        _emit_unit_diagnostics(jac_path, [program]);
    }
    program.release_compile_closure(collect=collect);
    maybe_malloc_trim();
    return ent.digest if ent is not None else "";
}

def precompile_unit(
    jac_path: str, pkg_root: str, embed_src: bool = False, collect: bool = True
) -> bytes | None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.cli.workpool { maybe_malloc_trim }

    try {
        import from jaclang.compiler.driver.jir { cache_mode }
        (rebuild_units, _np) = cache_mode();
        cache_path = get_module_cache_path(jac_path);
        if (not rebuild_units) and is_module_cache_valid(jac_path, cache_path) {
            cached_bc = read_section_bytes(cache_path.read_bytes(), SEC_BYTECODE);
            if cached_bc is not None {
                rewrapped = patch_co_filenames_bytes(
                    cached_bc, pkg_root, PRECOMPILE_SENTINEL
                );
                return write_precompiled_jir(
                    rewrapped,
                    compute_precompile_module_key(jac_path),
                    FLAG_PRECOMPILED,
                    _unit_extra(jac_path, pkg_root, embed_src)
                );
            }
        }
    } except Exception {}

    compiler = Jac.get_compiler();

    if not _unit_program {
        import from jaclang.compiler.driver.compile_options { CompileOptions }
        fresh = JacProgram();
        fresh.options = CompileOptions(skip_native_engine=True);
        _unit_program.append(fresh);
    }
    program = _unit_program[0];
    compiler.unit_collect = collect;
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    if code is None {
        _emit_unit_diagnostics(jac_path, [program, compiler.selfhost.program]);
    }
    program.release_compile_closure(collect=collect);
    compiler.selfhost.program.release_compile_closure(collect=collect);
    maybe_malloc_trim();
    if code is None {
        return None;
    }
    patched = patch_co_filenames_bytes(
        marshal.dumps(code), pkg_root, PRECOMPILE_SENTINEL
    );
    return write_precompiled_jir(
        patched,
        compute_precompile_module_key(jac_path),
        FLAG_PRECOMPILED,
        _unit_extra(jac_path, pkg_root, embed_src)
    );
}

def seal_bootstrap(pkg_dir: Path, out_dir: Path, embed_src: bool) -> int {
    import from jaclang.jac0 {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    failed = 0;
    if pkg_dir.name != "jaclang" {
        return failed;
    }
    import from jaclang.bootstrap_manifest { seed_abs_entries, is_native_only }
    (seed_dirs, seed_files) = seed_abs_entries(str(pkg_dir));
    seed_sources: list[Path] = [
        Path(p)
        for p in seed_files
        if str(p).endswith(".jac")
    ];
    for d in seed_dirs {
        seed_sources.extend(Path(d).rglob("*.jac"));
    }
    for jac_file in sorted(seed_sources) {
        if ext_registry.is_annex(str(jac_file)) {
            continue;
        }
        if any(
            part.startswith(".") or part == "__pycache__"
            for part in jac_file.relative_to(pkg_dir).parts
        ) {
            continue;
        }
        if is_native_only(str(jac_file.relative_to(pkg_dir)).replace(os.sep, "/")) {
            continue;
        }
        try {
            impl_paths = jac0_impls(str(jac_file));
            impl_sources: list[tuple[str, str]] = [];
            for impl_path in impl_paths {
                impl_sources.append(
                    (Path(impl_path).read_text(encoding="utf-8"), impl_path)
                );
            }
            py_source = jac0_compile(
                jac_file.read_text(encoding="utf-8"),
                str(jac_file),
                impl_sources=impl_sources or None
            );
            code = compile(py_source, str(jac_file), "exec");
            bc = patch_co_filenames_bytes(
                marshal.dumps(code), str(pkg_dir), PRECOMPILE_SENTINEL
            );
            extra: dict[int, bytes] | None = None;
            if embed_src {
                extra = {int(SEC_DEBUG_SRC): zlib.compress(jac_file.read_bytes(), 9)};
            }
            jir_rel = jac_file.relative_to(pkg_dir).with_suffix(".jir");
            jir_path = out_dir / jir_rel;
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(write_precompiled_jir(bc, "", FLAG_BOOTSTRAP, extra));
        } except Exception as e {
            console.error(f"BOOTSTRAP FAIL: {jac_file.name} - {e}");
            failed += 1;
        }
    }
    return failed;
}

glob PRECOMPILED_KEEP_DIRS: tuple[str, ...] = ();

def prune_stale_precompiled_dirs(precompiled_dir: Path, pyver: str) -> int {
    removed = 0;
    for stale_dir in sorted(precompiled_dir.iterdir()) {
        if not stale_dir.is_dir()
            or stale_dir.name == pyver
            or stale_dir.name in PRECOMPILED_KEEP_DIRS {
            continue;
        }
        shutil.rmtree(stale_dir, ignore_errors=True);
        removed += 1;
    }
    return removed;
}

def jir_to_module(pkg_name: str, rel_jir: str) -> tuple[str, str, bool] {
    source_rel = rel_jir[:-4] + ".jac";
    name = os.path.basename(source_rel);
    parts = [
        p
        for p in os.path.dirname(source_rel).split("/")
        if p
    ];
    is_pkg = name in ext_registry.INIT_FILES;
    if is_pkg {
        fullname = ".".join([pkg_name] + parts);
    } else {
        fullname = ".".join([pkg_name] + parts + [ext_registry.base_stem(name)]);
    }
    return (source_rel, fullname, is_pkg);
}

def bundle_app(config: any, app: str = "") -> any {
    if app {
        named = config.app(app);
        if named is not None {
            return named;
        }
    }
    try {
        return config.resolve_app("");
    } except ValueError {}
    serving = config.serving_apps();
    if serving {
        return serving[0];
    }
    for candidate in config.apps.values() {
        return candidate;
    }
    return None;
}

def app_metadata(pkg_path: Path, pkg_name: str, app: str = "") -> dict[str, any] {
    if not (pkg_path / "jac.toml").is_file() {
        return {};
    }
    import from jaclang.project.config { get_config_for_path }
    import from jaclang.project.kinds { resolve_app_kind, resolve_entry }
    import from jaclang.server.sealed_serve { CLIENT_DIST_REL, NATIVE_DIR_REL }

    config = get_config_for_path(pkg_path);
    if config is None {
        return {};
    }
    chosen = bundle_app(config, app);
    entry_path = resolve_entry(config, str(pkg_path), chosen)
        if chosen is not None
        else "";
    kind = (
        resolve_app_kind(config, chosen, entry_path) if chosen is not None else "cli"
    );

    `entry: dict[str, str] = {};
    if entry_path and Path(entry_path).is_file() {
        rel = Path(entry_path).resolve().relative_to(pkg_path.resolve()).as_posix();
        stem = ext_registry.base_stem(os.path.basename(entry_path));
        `entry = {"module": f"{pkg_name}.{stem}", "path": rel};
    }

    caps: list[str] = [];
    if kind in ["service", "service-mesh", "web-app", "desktop", "mobile"] {
        caps.append("has-server");
    }
    if `entry {
        caps.append("has-entry");
    }
    if (pkg_path / CLIENT_DIST_REL).is_dir()
        or kind in ["web-app", "desktop", "mobile"] {
        caps.append("has-client");
    }
    if (pkg_path / NATIVE_DIR_REL).is_dir() {
        caps.append("has-native");
    }
    if kind in ["py-package", "js-package"] or not `entry {
        caps.append("attachable");
    }

    meta = {
        "kind": kind,
        "app": chosen.name if chosen is not None else "",
        "capabilities": caps,
        "entry": `entry
    };
    native_dir = pkg_path / NATIVE_DIR_REL;
    if native_dir.is_dir() {
        triples = sorted(
            [
                d.name
                for d in native_dir.iterdir()
                if d.is_dir()
            ]
        );
        if triples {
            caps.append("platform-locked");
            meta["triples"] = triples;
        }
    }
    return meta;
}

def collect_payloads(pkg_path: Path) -> dict[str, str] {
    import from jaclang.server.sealed_serve {
        SERVE_MANIFEST_REL,
        CLIENT_DIST_REL,
        NATIVE_DIR_REL
    }
    payloads: dict[str, str] = {};
    sm = pkg_path / SERVE_MANIFEST_REL;
    if sm.is_file() {
        payloads[Path(SERVE_MANIFEST_REL).as_posix()] = hashlib.sha256(
            sm.read_bytes()
        ).hexdigest();
    }
    for payload_dir in [pkg_path / CLIENT_DIST_REL, pkg_path / NATIVE_DIR_REL] {
        if not payload_dir.is_dir() {
            continue;
        }
        for f in sorted(payload_dir.rglob("*")) {
            if f.is_file() {
                payloads[f.relative_to(pkg_path).as_posix()] = hashlib.sha256(
                    f.read_bytes()
                ).hexdigest();
            }
        }
    }
    return payloads;
}

def seal_finalize(
    pkg_path: Path,
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    embed_src: bool,
    app: str = ""
) -> int {
    writes = (
        FORMAT_VERSION,
        HEADER_SIZE,
        SECTIONS_MAGIC,
        SEC_BYTECODE,
        SEC_DEBUG_SRC,
        SEC_NIFACE,
        SEC_NOBJ,
        PRECOMPILE_SENTINEL
    );
    reads = (
        SEALED_JIR_FORMAT_VERSION,
        SEALED_HEADER_SIZE,
        SEALED_SECTIONS_MAGIC,
        SEALED_SEC_BYTECODE,
        SEALED_SEC_DEBUG_SRC,
        SEALED_SEC_NIFACE,
        SEALED_SEC_NOBJ,
        SEALED_SENTINEL
    );
    if reads != writes {
        console.error(
            f"JIR format drift: jir.jac writes {writes} but sealed.py "
            f"reads {reads}. Update jaclang/jac0core/sealed.py."
        );
        return 1;
    }

    missing = [
        str(Path(p).relative_to(pkg_path))
        for p in sealable_sources(str(pkg_path))
        if not (
            precompiled_dir / pyver / Path(p).relative_to(pkg_path).with_suffix(".jir")
        ).is_file()
    ];
    if missing {
        console.error(
            f"Seal incomplete: {len(missing)} sealable module(s) have no JIR "
            f"(first: {missing[:5]}). The compile pass failed or was skipped."
        );
        return 1;
    }

    identity = compiler_identity();
    foreign: list[str] = [];
    for p in sealable_sources(str(pkg_path)) {
        rel = Path(p).relative_to(pkg_path);
        jir = precompiled_dir / pyver / rel.with_suffix(".jir");
        if not precompiled_jir_matches_source(
            jir.read_bytes(), p, identity, str(pkg_path)
        ) {
            foreign.append(str(rel));
        }
    }
    if foreign {
        console.error(
            f"Seal aborted: {len(foreign)} module(s) carry stale JIRs "
            f"(first: {foreign[:5]}). Their source, compiler identity, or "
            "compile-time dependencies no longer match. Delete "
            f"{precompiled_dir} and re-run the precompile."
        );
        return 1;
    }
    console.print(f"  Compiler identity: {identity} (verified over every JIR)");

    out_dir = precompiled_dir / pyver;

    stale_boot = precompiled_dir / "bootstrap";
    if stale_boot.is_dir() {
        shutil.rmtree(stale_boot, ignore_errors=True);
    }

    console.print("  Freezing the bootstrap seed layer...");
    boot_failed = seal_bootstrap(pkg_path, out_dir, embed_src);
    if boot_failed > 0 {
        console.error(f"Seal aborted: {boot_failed} bootstrap module(s) failed.");
        return 1;
    }

    manifest_modules: dict[str, dict[str, any]] = {};
    n_boot = 0;
    for jir in sorted(out_dir.rglob("*.jir")) {
        rel_jir = jir.relative_to(out_dir).as_posix();
        (source_rel, fullname, is_pkg) = jir_to_module(pkg_name, rel_jir);
        `entry = {
            "module": fullname,
            "jir": rel_jir,
            "package": is_pkg,
            "sha256": hashlib.sha256(jir.read_bytes()).hexdigest()
        };
        import from jaclang.bootstrap_manifest { is_native_only, is_seed_source }
        if is_seed_source(source_rel) and not is_native_only(source_rel) {
            `entry["bootstrap"] = True;
            n_boot += 1;
        }
        if is_native_only(source_rel) {
            `entry["native_only"] = True;
        }
        manifest_modules[source_rel] = `entry;
    }
    console.print(f"  Manifest modules: {len(manifest_modules)} ({n_boot} bootstrap)");

    native_record: (dict | None) = None;
    try {
        native_record = seal_native(pkg_path, out_dir, pkg_name, manifest_modules);
    } except Exception as e {
        console.error(f"Seal aborted: native artifact failed: {e}");
        return 1;
    }

    payloads = collect_payloads(pkg_path);
    if payloads {
        console.print(f"  Payload files: {len(payloads)}");
    }
    app_meta = app_metadata(pkg_path, pkg_name, app);
    if app_meta {
        console.print(
            f"  App: kind={app_meta.get('kind')} caps={app_meta.get('capabilities')}"
        );
    }
    placement = placement_facts_map(str(pkg_path)) if pkg_name != "jaclang" else {};
    if placement {
        console.print(f"  Placement facts: {len(placement)} modules");
        app_meta = dict(app_meta);
        app_meta["placement"] = placement;
    }
    write_manifest(
        precompiled_dir,
        pkg_name,
        pyver,
        manifest_modules,
        payloads,
        app_meta,
        native_record
    );
    console.print(f"  Manifest: {precompiled_dir / MANIFEST_NAME}");
    return 0;
}

def seal_native(
    pkg_path: Path, out_dir: Path, pkg_name: str, manifest_modules: dict
) -> (dict | None) {
    import from jaclang.compiler.driver.schedules { native_pipeline_available }
    units = package_native_units(str(pkg_path));
    if not units {
        return None;
    }
    (toolchain_ok, why) = native_pipeline_available();
    if not toolchain_ok {
        raise RuntimeError(f"{len(units)} native unit(s) to seal but {why}");
    }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        build_link_plan,
        link_artifact
    }
    import from jaclang.compiler.backends.native.kernel_resolve { kernel_lib_name }
    import from jaclang.compiler.driver.jir {
        native_section_payload,
        read_section_bytes as _rsb
    }
    import from jaclang.compiler.driver.native_iface { NativeIface }
    import from jaclang.server.sealed_serve { NATIVE_DIR_REL }

    prog = JacProgram();
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        native_unit=True,
        skip_native_engine=True
    );
    if pkg_name == "jaclang" {
        import from jaclang.compiler.native_scope { kernel_root_path }
        roots = [kernel_root_path()];
        artifact_rel = os.path.join("compiler", kernel_lib_name());
    } else {
        roots = list(units);
        artifact_rel = os.path.join(
            NATIVE_DIR_REL, "lib" + pkg_name + _shared_suffix()
        );
    }
    console.print(f"  Native units: {len(units)} (roots: {len(roots)})");
    import time;
    native_start = time.monotonic();

    import from jaclang.compiler.driver.compile_options { NATIVE_LINK_MODE_BITCODE }
    plan = build_link_plan(
        prog, roots, options, mode=NATIVE_LINK_MODE_BITCODE, native_unit=True
    );
    artifact_path = pkg_path / artifact_rel;
    artifact_path.parent.mkdir(parents=True, exist_ok=True);
    result = link_artifact(
        plan, str(artifact_path), ArtifactKind.SHARED, log=console.print
    );

    console.print(
        f"  Native build: {time.monotonic() - native_start:.1f}s; "
            + f"analysis/lowering/codegen: {prog.analysis.cache_events.get(
                'native_unit_analysis', 0
            )}/"
            + f"{prog.analysis.cache_events.get('native_unit_lower', 0)}/"
            + f"{prog.analysis.cache_events.get('native_unit_codegen', 0)}"
    );
    unit_records: dict[str, dict] = {};
    stamp = prog.native_units().stamp_for(options);
    for u in plan.units {
        try {
            rel = Path(u.path).resolve().relative_to(pkg_path.resolve()).as_posix();
        } except ValueError {
            continue;
        }
        mod_entry = manifest_modules.get(rel);
        if mod_entry is None {
            raise RuntimeError(f"native unit {rel} has no sealed JIR");
        }
        _refresh_native_twin(out_dir / mod_entry["jir"], u.path, str(pkg_path));
        jir_bytes = (out_dir / mod_entry["jir"]).read_bytes();
        sealed_iface = NativeIface.read_digest(
            native_section_payload(_rsb(jir_bytes, SEC_NIFACE), stamp)
        );
        if sealed_iface != u.digest {
            raise RuntimeError(
                f"native unit {rel}: the sealed JIR carries interface "
                f"{(sealed_iface or 'none')[:12]} but the artifact linked "
                f"{u.digest[:12]}; re-run the compile pass"
            );
        }
        unit_records[rel] = {"jir": mod_entry["jir"], "iface_digest": u.digest};
    }
    console.print(
        f"  Native artifact: {artifact_rel} (plan {result.plan_digest[:12]}, "
        f"layout {result.layout_digest[:12]})"
    );
    return {
        "units": unit_records,
        "artifact": {
            "path": Path(artifact_rel).as_posix(),
            "sha256": result.sha256,
            "layout_digest": result.layout_digest,
            "plan_digest": result.plan_digest,
            "triple": plan.triple,
            "mode": plan.mode
        }
    };
}

def _refresh_native_twin(twin: Path, jac_path: str, pkg_root: str) -> None {
    """Carry a unit's native sections from the module cache into its sealed
JIR twin. A dual module's twin was written by the compile pass, before the
plan compiled the module as a native unit; the plan's products are what
the artifact linked, so the twin takes them now.""";
    fresh = _native_extra(jac_path, pkg_root);
    if not fresh {
        return;
    }
    data = twin.read_bytes();
    header = parse_header(data[:HEADER_SIZE]);
    if header is None {
        return;
    }
    magic: any = SECTIONS_MAGIC;
    pos = data.find(magic, HEADER_SIZE);
    if pos < 0 {
        return;
    }
    sections = read_sections(data, pos + len(magic));
    changed = False;
    for (sec, raw) in fresh.items() {
        if sections.get(sec) != raw {
            sections[sec] = raw;
            changed = True;
        }
    }
    if not changed {
        return;
    }
    bytecode = sections.pop(SEC_BYTECODE, None);
    module_key = (sections.pop(SEC_MODKEY, b"") or b"").decode("utf-8");
    twin.write_bytes(
        write_precompiled_jir(bytecode, module_key, header.flags, sections)
    );
}

def _shared_suffix -> str {
    if sys.platform == "darwin" {
        return ".dylib";
    }
    if sys.platform.startswith("win") {
        return ".dll";
    }
    return ".so";
}

def write_manifest(
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    modules: dict[str, dict[str, any]],
    payloads: (dict[str, str] | None) = None,
    app_meta: (dict[str, any] | None) = None,
    native_record: (dict[str, any] | None) = None
) {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version("jaclang");
    } except Exception {
        jac_ver = "0.0.0";
    }
    manifest: dict[str, any] = {
        "format": MANIFEST_FORMAT,
        "package": pkg_name,
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": jac_ver,
        "compiler_digest": compiler_identity(),
        "modules": modules
    };
    if payloads {
        manifest["payloads"] = payloads;
    }
    if app_meta {
        manifest.update(app_meta);
    }
    if native_record {
        manifest["native"] = native_record;
    }
    (precompiled_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
}

def _precompile_retire(served: int, rss_mb: int) -> bool {
    import from jaclang.cli.workpool { env_int, should_retire }
    return should_retire(
        served,
        env_int("JAC_PRECOMPILE_RECYCLE", 0),
        rss_mb,
        env_int("JAC_PRECOMPILE_RECYCLE_MB", 4096)
    );
}

def precompile_exit(code: int) {
    sys.stdout.flush();
    sys.stderr.flush();
    os._exit(code);
}

def main {
    args = sys.argv[1:];
    seal = "--seal" in args;
    seal_compile = "--seal-compile" in args;
    finalize_only = "--seal-finalize" in args;
    embed_src = "--debug-src" in args;
    jobs_arg = "";
    app_arg = "";
    for a in args {
        if a.startswith("--jobs=") {
            jobs_arg = a[len("--jobs="):];
        }
        if a.startswith("--app=") {
            app_arg = a[len("--app="):];
        }
    }
    args = [
        a
        for a in args
        if not a.startswith("--")
    ];
    if not args {
        console.print(
            "Usage: jac precompile <package-source-dir> [--seal|--seal-finalize] [--debug-src]"
        );
        console.print("\nExamples:");
        console.print("  jac precompile ./jac");
        console.print("  jac precompile ./jac/jaclang/scale");
        console.print("\n--seal: precompile, freeze the bootstrap seed tier, and emit");
        console.print("        MANIFEST.json (JIR-authoritative image; .jac sources");
        console.print(
            "        stay on disk for tracebacks, never compiled at runtime)."
        );
        console.print(
            "--seal-compile: compile only (exclude the seed tier), no finalize -- the"
        );
        console.print("        payload build's crash-tolerant first pass.");
        console.print(
            "--seal-finalize: run ONLY the seal step over an already-precompiled tree"
        );
        console.print(
            "        (verify completeness, build the manifest, freeze) -- resilient"
        );
        console.print(
            "        to the best-effort compile crashing on a native module."
        );
        console.print(
            "--debug-src: embed zlib source text in each .jir (dev tracebacks)."
        );
        console.print(
            "--jobs=N: precompile units across N forked workers (also "
            "JAC_PRECOMPILE_JOBS / JAC_JOBS; 0 = serial, default auto)."
        );
        sys.`exit(1);
    }
    run_precompile(
        args[0],
        seal=seal,
        seal_compile=seal_compile,
        finalize_only=finalize_only,
        embed_src=embed_src,
        jobs_arg=jobs_arg,
        app=app_arg
    );
}

def run_precompile(
    source_dir: str,
    seal: bool = False,
    seal_compile: bool = False,
    finalize_only: bool = False,
    embed_src: bool = False,
    jobs_arg: str = "",
    app: str = ""
) {
    exclude_seed = seal or seal_compile;
    package_dir = find_package_dir(source_dir);
    if package_dir is None {
        console.error(f"Could not find a Python package in {source_dir}");
        sys.`exit(1);
    }

    pkg_name = Path(package_dir).name;
    if (seal or seal_compile or finalize_only)
        and pkg_name != "jaclang"
        and not (Path(package_dir) / "jac.toml").is_file() {
        console.error(
            f"Seal aborted: {package_dir} has no jac.toml. An app seal reads "
            "placement, nested-project scoping, and app metadata from the "
            "project config; sealing without it would compile every module "
            "including client code. Stage a sanitized jac.toml first."
        );
        sys.`exit(1);
    }
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    precompiled_dir = Path(package_dir) / "_precompiled";

    if finalize_only {
        console.print(f"Sealing {pkg_name} for {pyver} (finalize)...");
        precompile_exit(
            seal_finalize(
                Path(package_dir), precompiled_dir, pkg_name, pyver, embed_src, app
            )
        );
    }

    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");
    console.print(f"  Compiler identity: {compiler_identity()}");

    jac_files = (
        sealable_sources(package_dir) if exclude_seed else find_jac_files(package_dir)
    );
    console.print(f"  Found {len(jac_files)} .jac files");
    native_units_set: set[str] = set();
    native_only_units: list[str] = [];
    if exclude_seed {
        import from jaclang.compiler.placement.placement_facts { native_only }
        for unit in package_native_units(package_dir) {
            native_units_set.add(unit);
            if native_only(unit) {
                native_only_units.append(unit);
            }
        }
        if native_units_set {
            console.print(
                f"  Native units: {len(native_units_set)} "
                f"({len(native_only_units)} native-only)"
            );
        }
        for unit in native_only_units {
            if unit not in jac_files {
                jac_files.append(unit);
            }
        }
    }

    if not jac_files and not exclude_seed {
        console.print("  No .jac files to precompile.");
        sys.`exit(0);
    }

    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);
    (precompiled_dir / RESULT_NAME).unlink(missing_ok=True);

    prune_stale_precompiled_dirs(precompiled_dir, pyver);
    pkg_path = Path(package_dir);
    expected: set[str] = {
        str(Path(p).relative_to(pkg_path).with_suffix(".jir")) for p in jac_files
    };
    for old_jir in sorted(out_dir.rglob("*.jir")) {
        if str(old_jir.relative_to(out_dir)) not in expected {
            old_jir.unlink();
        }
    }

    import from jaclang.compiler.driver.jir { read_debug_source }
    import from jaclang.cli.workpool {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }

    raw_jobs = jobs_setting("precompile", jobs_arg);
    workers = resolve_jobs(raw_jobs, env_var="JAC_PRECOMPILE_JOBS");
    use_pool = (
        pool_available()
        and not forced_serial(raw_jobs)
        and workers > 1
        and len(jac_files) > 1
    );
    counts: dict[str, int] = {"compiled": 0, "reused": 0, "failed": 0};

    import gc;
    import from jaclang.compiler.driver.compiler { COMPILE_GC_THRESHOLDS }
    if (
        not os.environ.get("JAC_GC_NO_COMPILE_BOOST")
        and gc.get_threshold()[0] < COMPILE_GC_THRESHOLDS[0]
    ) {
        gc.set_threshold(*COMPILE_GC_THRESHOLDS);
    }

    def unit_job(request: dict[(str, any)]) -> dict[(str, any)] {
        jac_path = str(request["path"]);
        rel = Path(jac_path).relative_to(pkg_path);
        jir_path = out_dir / rel.with_suffix(".jir");
        try {
            if jir_path.is_file() {
                existing = jir_path.read_bytes();
                if precompiled_jir_matches_source(
                    existing, jac_path, package_root=package_dir
                )
                    and embed_src == (read_debug_source(existing) is not None) {
                    return {"status": "reused", "rel": str(rel)};
                }
            }
            is_native = bool(
                native_units_set and os.path.realpath(jac_path) in native_units_set
            );
            if is_native
                and not precompile_native_unit(jac_path, collect=not use_pool) {
                jir_path.unlink(missing_ok=True);
                return {
                    "status": "failed",
                    "rel": str(rel),
                    "message": f"FAIL (native unit did not lower): {rel}"
                };
            }
            if jac_path in native_only_units {
                jir_bytes: (bytes | None) = write_precompiled_jir(
                    None,
                    compute_precompile_module_key(jac_path),
                    FLAG_PRECOMPILED,
                    _unit_extra(jac_path, package_dir, embed_src)
                );
            } else {
                jir_bytes = precompile_unit(
                    jac_path, package_dir, embed_src, collect=not use_pool
                );
            }
            if jir_bytes is None {
                jir_path.unlink(missing_ok=True);
                return {
                    "status": "failed",
                    "rel": str(rel),
                    "message": f"  SKIP (no bytecode): {rel}"
                };
            }
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(jir_bytes);
            return {"status": "compiled", "rel": str(rel)};
        } except Exception as e {
            jir_path.unlink(missing_ok=True);
            return {
                "status": "failed",
                "rel": str(rel),
                "message": f"FAIL: {rel} - {e}"
            };
        }
    }

    def on_dispatch(idx: int, path: str) {
        done = counts["compiled"] + counts["reused"] + counts["failed"];
        label = str(Path(path).relative_to(pkg_path))[:60].ljust(60);
        sys.stderr.write(f"\r  [{done + 1}/{len(jac_files)}] {label}");
        sys.stderr.flush();
    }

    def on_record(idx: int, record: dict[(str, any)]) -> None {
        rel = str(Path(jac_files[idx]).relative_to(pkg_path));
        result = record.get("result");
        if not isinstance(result, dict) {
            detail = record.get("crash") or record.get("error") or "no result";
            console.error(f"FAIL: {rel} - {detail}");
            (out_dir / Path(rel).with_suffix(".jir")).unlink(missing_ok=True);
            counts["failed"] += 1;
            return;
        }
        status = str(result.get("status") or "failed");
        message = str(result.get("message") or "");
        if status == "failed" and message {
            if message.lstrip().startswith("SKIP") {
                console.print(message);
            } else {
                console.error(message);
            }
        }
        counts[status] = counts.get(status, 0) + 1;
    }

    pool = WorkPool(
        items=list(jac_files),
        job=unit_job,
        on_record=on_record,
        jobs=min(workers, len(jac_files)),
        retire=_precompile_retire,
        on_dispatch=on_dispatch,
        rss_log_env="JAC_PRECOMPILE_RSS_LOG",
        crash_prefix="jac-precompile-crash-"
    );
    if use_pool {
        pool.run();
    } else {
        pool.run_inline();
    }
    compiled = counts["compiled"];
    reused = counts["reused"];
    failed = counts["failed"];

    sys.stderr.write("\n");
    sys.stderr.flush();

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules"
            + f" ({reused} reused, {failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Python version: {pyver}");

    (precompiled_dir / RESULT_NAME).write_text(
        json.dumps(
            {
                "total": len(jac_files),
                "compiled": compiled,
                "reused": reused,
                "failed": failed
            }
        )
            + "\n",
        encoding="utf-8"
    );

    if seal {
        precompile_exit(
            seal_finalize(pkg_path, precompiled_dir, pkg_name, pyver, embed_src, app)
        );
    }

    precompile_exit(1 if failed else 0);
}

with entry:__main__ {
    main();
}
