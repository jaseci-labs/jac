import hashlib;
import json;
import marshal;
import os;
import shutil;
import sys;
import zlib;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core { ext_registry }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir {
    write_precompiled_jir,
    FLAG_PRECOMPILED,
    FLAG_BOOTSTRAP,
    SEC_DEBUG_SRC,
    FORMAT_VERSION,
    compute_module_key,
    jir_matches_source,
    PRECOMPILE_SENTINEL
}
import from jaclang.jac0core.sealed {
    MANIFEST_NAME,
    MANIFEST_FORMAT,
    JIR_FORMAT_VERSION as SEALED_JIR_FORMAT_VERSION
}

def find_package_dir(source_dir: str) -> str | None {
    src = Path(source_dir).resolve();
    if not src.is_dir() {
        console.error(f"Error: {source_dir} is not a directory");
        return None;
    }
    excluded: list = [
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
    result: list[str] = [];
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
        result.append(str(jac_file));
    }
    return result;
}

def precompile_unit(
    jac_path: str, pkg_root: str, embed_src: bool = False
) -> bytes | None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.program { JacProgram }

    compiler = Jac.get_compiler();

    program = JacProgram();
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    compiler.internal_program.release_compile_closure();
    program.release_compile_closure();
    if code is None {
        return None;
    }
    patched = patch_co_filenames_bytes(
        marshal.dumps(code), pkg_root, PRECOMPILE_SENTINEL
    );
    extra: dict[int, bytes] | None = None;
    if embed_src {
        extra = {SEC_DEBUG_SRC: zlib.compress(Path(jac_path).read_bytes(), 9)};
    }
    return write_precompiled_jir(
        patched, compute_module_key(jac_path), FLAG_PRECOMPILED, extra
    );
}

def _annex_files(jac_path: str) -> list[str] {
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files,
        discover_style_annex
    }
    out: list[str] = [];
    out.extend(discover_annex_files(jac_path, ext_registry.IMPL_SUFFIX));
    out.extend(discover_annex_files(jac_path, ext_registry.TEST_SUFFIX));
    out.extend(discover_variant_files(jac_path));
    style = discover_style_annex(jac_path);
    if style is not None {
        out.append(style);
    }
    return out;
}

def strip_sealed_sources(source_paths: list[str]) -> int {
    victims: set[str] = set();
    for jac_path in source_paths {
        victims.add(jac_path);
        victims.update(_annex_files(jac_path));
    }
    removed = 0;
    for p in sorted(victims) {
        try {
            if os.path.isfile(p) {
                os.remove(p);
                removed += 1;
            }
        } except OSError { }
    }
    return removed;
}

def seal_bootstrap(
    pkg_dir: Path, out_dir: Path, embed_src: bool
) -> tuple[list[str], int] {
    import from jaclang.jac0 {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    boot_dir = pkg_dir / "jac0core";
    boot_sources: list[str] = [];
    failed = 0;
    if not boot_dir.is_dir() {
        return (boot_sources, failed);
    }
    for jac_file in sorted(boot_dir.rglob("*.jac")) {
        if ext_registry.is_annex(str(jac_file)) {
            continue;
        }
        if any(
            part.startswith(".") or part == "__pycache__"
            for part in jac_file.relative_to(boot_dir).parts
        ) {
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
                extra = {SEC_DEBUG_SRC: zlib.compress(jac_file.read_bytes(), 9)};
            }
            jir_rel = jac_file.relative_to(pkg_dir).with_suffix(".jir");
            jir_path = out_dir / jir_rel;
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(write_precompiled_jir(bc, "", FLAG_BOOTSTRAP, extra));
            boot_sources.append(str(jac_file));
            boot_sources.extend(impl_paths);
        } except Exception as e {
            console.error(f"BOOTSTRAP FAIL: {jac_file.name} - {e}");
            failed += 1;
        }
    }
    return (boot_sources, failed);
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

def seal_finalize(
    pkg_path: Path, precompiled_dir: Path, pkg_name: str, pyver: str, embed_src: bool
) -> int {
    if SEALED_JIR_FORMAT_VERSION != FORMAT_VERSION {
        console.error(
            f"JIR format drift: jir.FORMAT_VERSION={FORMAT_VERSION} but "
            f"sealed.JIR_FORMAT_VERSION={SEALED_JIR_FORMAT_VERSION}. "
            "Update jaclang/jac0core/sealed.py."
        );
        return 1;
    }

    out_dir = precompiled_dir / pyver;

    stale_boot = precompiled_dir / "bootstrap";
    if stale_boot.is_dir() {
        shutil.rmtree(stale_boot, ignore_errors=True);
    }

    console.print("  Freezing jac0core bootstrap layer...");
    (boot_sources, boot_failed) = seal_bootstrap(pkg_path, out_dir, embed_src);
    if boot_failed > 0 {
        console.error(f"Seal aborted: {boot_failed} bootstrap module(s) failed.");
        return 1;
    }
    console.print(f"  Frozen {len(set(boot_sources))} bootstrap source files");

    manifest_modules: dict[str, dict] = {};
    sealed_sources: list[str] = list(boot_sources);
    n_boot = 0;
    for jir in sorted(out_dir.rglob("*.jir")) {
        rel_jir = jir.relative_to(out_dir).as_posix();
        (source_rel, fullname, is_pkg) = jir_to_module(pkg_name, rel_jir);
        entry = {
            "module": fullname,
            "jir": rel_jir,
            "package": is_pkg,
            "sha256": hashlib.sha256(jir.read_bytes()).hexdigest()
        };
        if rel_jir.startswith("jac0core/") {
            entry["bootstrap"] = True;
            n_boot += 1;
        }
        manifest_modules[source_rel] = entry;
        sealed_sources.append(str(pkg_path / source_rel));
    }
    console.print(f"  Manifest modules: {len(manifest_modules)} ({n_boot} bootstrap)");

    write_manifest(precompiled_dir, pkg_name, pyver, manifest_modules);
    console.print(f"  Manifest: {precompiled_dir / MANIFEST_NAME}");

    removed = strip_sealed_sources(sealed_sources);
    console.print(f"  Stripped {removed} sealed .jac source files");
    return 0;
}

def write_manifest(
    precompiled_dir: Path, pkg_name: str, pyver: str, modules: dict[str, dict]
) {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version("jaclang");
    } except Exception {
        jac_ver = "0.0.0";
    }
    manifest = {
        "format": MANIFEST_FORMAT,
        "package": pkg_name,
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": jac_ver,
        "modules": modules
    };
    (precompiled_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
}

def main {
    args = sys.argv[1:];
    seal = "--seal" in args;
    seal_compile = "--seal-compile" in args;
    finalize_only = "--seal-finalize" in args;
    embed_src = "--debug-src" in args;
    exclude_jac0core = seal or seal_compile;
    args = [
        a
        for a in args
        if not a.startswith("--")
    ];
    if not args {
        console.print(
            "Usage: jac run utils/precompile_bytecode.jac<package-source-dir> [--seal|--seal-finalize] [--debug-src]"
        );
        console.print("\nExamples:");
        console.print("  jac run utils/precompile_bytecode.jac./jac");
        console.print("  jac run utils/precompile_bytecode.jac./jac/jaclang/scale");
        console.print(
            "\n--seal: precompile, freeze the jac0core bootstrap, emit MANIFEST.json,"
        );
        console.print("        and strip the sealed .jac sources (source-free image).");
        console.print(
            "--seal-compile: compile only (exclude jac0core), no finalize -- the"
        );
        console.print("        payload build's crash-tolerant first pass.");
        console.print(
            "--seal-finalize: run ONLY the seal step over an already-precompiled tree"
        );
        console.print(
            "        (build the manifest from the JIRs, freeze, strip) -- resilient to"
        );
        console.print("        the best-effort compile crashing on a native module.");
        console.print(
            "--debug-src: embed zlib source text in each .jir (dev tracebacks)."
        );
        sys.exit(1);
    }

    source_dir = args[0];
    package_dir = find_package_dir(source_dir);
    if package_dir is None {
        console.error(f"Could not find a Python package in {source_dir}");
        sys.exit(1);
    }

    pkg_name = Path(package_dir).name;
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    precompiled_dir = Path(package_dir) / "_precompiled";

    if finalize_only {
        console.print(f"Sealing {pkg_name} for {pyver} (finalize)...");
        sys.exit(
            seal_finalize(
                Path(package_dir), precompiled_dir, pkg_name, pyver, embed_src
            )
        );
    }

    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");

    jac_files = find_jac_files(package_dir);
    if exclude_jac0core {
        boot_prefix = str(Path(package_dir) / "jac0core") + os.sep;
        nested = _nested_project_dirs(package_dir);
        jac_files = [
            p
            for p in jac_files
            if not p.startswith(boot_prefix)
            and not ext_registry.is_native_module(p)
            and not ext_registry.is_client_module(p)
            and not any(p.startswith(n) for n in nested)
        ];
    }
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files and not exclude_jac0core {
        console.print("  No .jac files to precompile.");
        sys.exit(0);
    }

    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);

    for stale_dir in sorted(precompiled_dir.iterdir()) {
        if stale_dir.is_dir() and stale_dir.name != pyver {
            shutil.rmtree(stale_dir, ignore_errors=True);
        }
    }
    pkg_path = Path(package_dir);
    expected: set[str] = {
        str(Path(p).relative_to(pkg_path).with_suffix(".jir")) for p in jac_files
    };
    for old_jir in sorted(out_dir.rglob("*.jir")) {
        if str(old_jir.relative_to(out_dir)) not in expected {
            old_jir.unlink();
        }
    }

    import from jaclang.jac0core.jir { read_debug_source }

    compiled = 0;
    reused = 0;
    failed = 0;

    for jac_path in jac_files {
        rel = Path(jac_path).relative_to(pkg_path);
        jir_rel = rel.with_suffix(".jir");
        jir_path = out_dir / jir_rel;

        done = compiled + reused + failed;
        label = str(rel)[:60].ljust(60);
        sys.stderr.write(f"\r  [{done + 1}/{len(jac_files)}] {label}");
        sys.stderr.flush();

        try {
            if jir_path.is_file() {
                existing = jir_path.read_bytes();
                if jir_matches_source(existing, jac_path)
                and embed_src == (read_debug_source(existing) is not None) {
                    reused += 1;
                    continue;
                }
            }

            jir_bytes = precompile_unit(jac_path, package_dir, embed_src);
            if jir_bytes is None {
                console.print(f"  SKIP (no bytecode): {rel}");
                failed += 1;
                continue;
            }

            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(jir_bytes);
            compiled += 1;
        } except Exception as e {
            console.error(f"FAIL: {rel} - {e}");
            failed += 1;
        }
    }

    sys.stderr.write("\n");
    sys.stderr.flush();

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules" + f" ({reused} reused, {failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Python version: {pyver}");

    if seal {
        sys.exit(seal_finalize(pkg_path, precompiled_dir, pkg_name, pyver, embed_src));
    }
}

with entry:__main__ {
    main();
}
