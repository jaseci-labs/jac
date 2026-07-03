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
import from jaclang.jac0core.sealed { MANIFEST_NAME, MANIFEST_FORMAT }

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

# (fullname, is_package) for a module file relative to its package dir.
def module_fullname(pkg_name: str, pkg_dir: Path, jac_path: str) -> tuple[str, bool] {
    rel = Path(jac_path).relative_to(pkg_dir);
    parts = [pkg_name] + list(rel.parts[:-1]);
    if rel.name in ext_registry.INIT_FILES {
        return (".".join(parts), True);
    }
    return (".".join(parts + [ext_registry.base_stem(rel.name)]), False);
}

# Annex (.impl.jac / .test.jac / variant / style) files belonging to a module,
# folded into its JIR at compile time and thus removable from a sealed image.
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

# Delete exactly the .jac sources that were sealed (module files + their annexes
# + frozen bootstrap sources/impls). Data/template .jac (e.g. project scaffolds)
# are never in the sealed set, so they survive. Runs last, after every jaclang
# module the precompiler needs is already imported and cached. Returns count.
def strip_sealed_sources(
    module_paths: list[str], bootstrap_srcs: list[str]
) -> int {
    import from jaclang.jac0 { discover_impl_files as jac0_impls }
    victims: set[str] = set();
    for jac_path in module_paths {
        victims.add(jac_path);
        victims.update(_annex_files(jac_path));
    }
    for src in bootstrap_srcs {
        victims.add(src);
        victims.update(jac0_impls(src));
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

# jac0-compile every jac0core bootstrap module to a sentinel-patched marshalled
# .jbc under _precompiled/bootstrap/. Returns (manifest entries keyed by
# fullname, failure count). Mirrors meta_importer._bootstrap_compile so frozen
# and live bootstrap semantics are identical.
def freeze_bootstrap(
    pkg_dir: Path, precompiled_dir: Path
) -> tuple[dict[str, dict], int] {
    import from jaclang.jac0 {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    boot_dir = pkg_dir / "jac0core";
    out_dir = precompiled_dir / "bootstrap";
    entries: dict[str, dict] = {};
    failed = 0;
    if not boot_dir.is_dir() {
        return (entries, failed);
    }
    if out_dir.is_dir() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);
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
        (fullname, _) = module_fullname(pkg_dir.name, pkg_dir, str(jac_file));
        try {
            impl_sources: list[tuple[str, str]] = [];
            for impl_path in jac0_impls(str(jac_file)) {
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
            raw = patch_co_filenames_bytes(
                marshal.dumps(code), str(pkg_dir), PRECOMPILE_SENTINEL
            );
            src_rel = jac_file.relative_to(pkg_dir).as_posix();
            jbc_name = fullname.removeprefix(pkg_dir.name + ".") + ".jbc";
            (out_dir / jbc_name).write_bytes(raw);
            entries[fullname] = {
                "path": f"bootstrap/{jbc_name}",
                "src": src_rel,
                "sha256": hashlib.sha256(raw).hexdigest()
            };
        } except Exception as e {
            console.error(f"BOOTSTRAP FAIL: {jac_file.name} - {e}");
            failed += 1;
        }
    }
    return (entries, failed);
}

def write_manifest(
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    modules: dict[str, dict],
    bootstrap: dict[str, dict]
) -> None {
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
        "modules": modules,
        "bootstrap": bootstrap
    };
    (precompiled_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
}

def main {
    args = sys.argv[1:];
    seal = "--seal" in args;
    embed_src = "--debug-src" in args;
    strip_sources = "--strip-sources" in args;
    args = [a for a in args if not a.startswith("--")];
    if not args {
        console.print(
            "Usage: jac run utils/precompile_bytecode.jac<package-source-dir> [--seal] [--debug-src]"
        );
        console.print("\nExamples:");
        console.print("  jac run utils/precompile_bytecode.jac./jac");
        console.print("  jac run utils/precompile_bytecode.jac./jac/jaclang/scale");
        console.print(
            "\n--seal: freeze the jac0core bootstrap layer, emit MANIFEST.json,"
        );
        console.print(
            "        and fail (exit 1) unless every module precompiles."
        );
        console.print("--debug-src: embed zlib source text in each .jir (dev tracebacks).");
        console.print("--strip-sources: after a clean seal, delete the sealed .jac sources.");
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
    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");

    jac_files = find_jac_files(package_dir);
    if seal {
        # The jac0core bootstrap layer never routes through the full compiler
        # at runtime (meta_importer execs it via jac0); in sealed images it is
        # frozen as .jbc bootstrap entries instead of .jir modules.
        boot_prefix = str(Path(package_dir) / "jac0core") + os.sep;
        jac_files = [p for p in jac_files if not p.startswith(boot_prefix)];
    }
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files and not seal {
        console.print("  No .jac files to precompile.");
        sys.exit(0);
    }

    precompiled_dir = Path(package_dir) / "_precompiled";
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
    manifest_modules: dict[str, dict] = {};

    for jac_path in jac_files {
        rel = Path(jac_path).relative_to(pkg_path);
        jir_rel = rel.with_suffix(".jir");
        jir_path = out_dir / jir_rel;

        done = compiled + reused + failed;
        label = str(rel)[:60].ljust(60);
        sys.stderr.write(f"\r  [{done + 1}/{len(jac_files)}] {label}");
        sys.stderr.flush();

        (fullname, is_pkg) = module_fullname(pkg_name, pkg_path, jac_path);
        try {
            if jir_path.is_file() {
                existing = jir_path.read_bytes();
                if jir_matches_source(existing, jac_path)
                and embed_src == (read_debug_source(existing) is not None) {
                    manifest_modules[rel.as_posix()] = {
                        "module": fullname,
                        "jir": jir_rel.as_posix(),
                        "package": is_pkg,
                        "sha256": hashlib.sha256(existing).hexdigest()
                    };
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
            manifest_modules[rel.as_posix()] = {
                "module": fullname,
                "jir": jir_rel.as_posix(),
                "package": is_pkg,
                "sha256": hashlib.sha256(jir_bytes).hexdigest()
            };
            compiled += 1;
        } except Exception as e {
            console.error(f"FAIL: {rel} - {e}");
            failed += 1;
        }
    }

    sys.stderr.write("\n");
    sys.stderr.flush();

    bootstrap_entries: dict[str, dict] = {};
    boot_failed = 0;
    if seal {
        console.print("  Freezing jac0core bootstrap layer...");
        (bootstrap_entries, boot_failed) = freeze_bootstrap(
            pkg_path, precompiled_dir
        );
        console.print(
            f"  Frozen {len(bootstrap_entries)} bootstrap modules ({boot_failed} failed)"
        );
        write_manifest(
            precompiled_dir, pkg_name, pyver, manifest_modules, bootstrap_entries
        );
        console.print(f"  Manifest: {precompiled_dir / MANIFEST_NAME}");
        if strip_sources and failed == 0 and boot_failed == 0 {
            boot_srcs = [
                str(pkg_path / e["src"]) for e in bootstrap_entries.values()
            ];
            removed = strip_sealed_sources(jac_files, boot_srcs);
            console.print(f"  Stripped {removed} sealed .jac source files");
        } elif strip_sources {
            console.error("Refusing to strip sources: seal had failures.");
        }
    }

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules" + f" ({reused} reused, {failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Python version: {pyver}");

    if seal and (failed > 0 or boot_failed > 0) {
        console.error(
            f"Seal is strict: {failed} module + {boot_failed} bootstrap failures."
        );
        sys.exit(1);
    }
}

with entry:__main__ {
    main();
}
