"""Precompile bytecode for a Jac package.

Generates _precompiled/ directory with .jir files for the current
Python version.  Run once per Python version during CI/release.

Usage:
    jac run utils/precompile_bytecode.jac<package-source-dir>

Examples:
    jac run utils/precompile_bytecode.jac./jac
    jac run utils/precompile_bytecode.jac./jac-scale
    jac run utils/precompile_bytecode.jac./jac-byllm
    jac run utils/precompile_bytecode.jac./jac-mcp
"""

import marshal;
import os;
import sys;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir {
    write_precompiled_jir,
    FLAG_PRECOMPILED,
    compute_module_key,
    PRECOMPILE_SENTINEL
}

"""Discover the Python package directory inside a source tree.

Looks for directories containing __init__.py or __init__.jac
at the top level of the given source directory.
"""
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
    # Find the package directory: a child with __init__.py or __init__.jac.
    # Every package fed to this script (jac -> jaclang, jac-scale -> jac_scale,
    # jac-byllm -> byllm, and the binary's assembled site dir) ships one.
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

"""Discover all .jac files in a package directory (excluding tests)."""
def find_jac_files(package_dir: str) -> list[str] {
    result: list[str] = [];
    pkg = Path(package_dir);
    for jac_file in sorted(pkg.rglob("*.jac")) {
        # rglob("*.jac") also matches directories named ".jac" (jaclang's
        # per-project build cache, e.g. created by a nested `jac build`).
        # Only real files can be hashed.
        if not jac_file.is_file() {
            continue;
        }
        rel_path = jac_file.relative_to(pkg);
        rel = str(rel_path);
        # Skip anything under a hidden/cache directory (".jac", "__pycache__",
        # ".git", ...). Checking only rel.startswith(".") misses these when the
        # dot-component is nested, e.g. "admin/ui/.jac/...".
        if any(
            part.startswith(".") or part == "__pycache__" for part in rel_path.parts
        ) {
            continue;
        }
        # Skip test files, impl files, and hidden files
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

"""Compile a single .jac file and extract its bytecode.

Triggers the full Jac compilation pipeline (or uses cached bytecode).
Returns the marshal'd bytecode bytes, or None on failure.
"""
def compile_and_extract(jac_path: str) -> bytes | None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.program { JacProgram }

    compiler = Jac.get_compiler();
    # Compile into a FRESH, isolated program (not the shared Jac.get_program()).
    # A handful of core modules (e.g. jac0core/jir.jac) intentionally cannot be
    # bytecode-precompiled and so emit diagnostics; routing them through the
    # global program would leave errors in `Jac.program.errors_had`, which
    # `jac run` inspects on exit and would then report a non-zero status even
    # though the precompile itself succeeded (those modules just compile at
    # runtime instead). An isolated program keeps that bookkeeping local.
    program = JacProgram();
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    if code is None {
        return None;
    }
    return marshal.dumps(code);
}

"""Run the precompilation pipeline."""
def main {
    args = sys.argv[1:];
    if not args {
        console.print(
            "Usage: jac run utils/precompile_bytecode.jac<package-source-dir>"
        );
        console.print("\nExamples:");
        console.print("  jac run utils/precompile_bytecode.jac./jac");
        console.print("  jac run utils/precompile_bytecode.jac./jac-scale");
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

    # Discover .jac files
    jac_files = find_jac_files(package_dir);
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files {
        console.print("  No .jac files to precompile.");
        sys.exit(0);
    }

    # Set up output directory
    precompiled_dir = Path(package_dir) / "_precompiled";
    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);

    # Compile each file and store bytecode
    compiled = 0;
    failed = 0;
    pkg_path = Path(package_dir);

    for jac_path in jac_files {
        rel = Path(jac_path).relative_to(pkg_path);
        jir_rel = rel.with_suffix(".jir");
        jir_path = out_dir / jir_rel;

        # Live, single-line progress (overwrites in place on a tty; harmless
        # plain lines through a pipe). Use stderr + explicit flush -- stderr is
        # line-buffered, so a \r without \n would otherwise never appear.
        done = compiled + failed;
        label = str(rel)[:60].ljust(60);
        sys.stderr.write(f"\r  [{done + 1}/{len(jac_files)}] {label}");
        sys.stderr.flush();

        try {
            bytecode = compile_and_extract(jac_path);
            if bytecode is None {
                console.print(f"  SKIP (no bytecode): {rel}");
                failed += 1;
                continue;
            }

            # Patch filenames to the build-time sentinel, then wrap in a JIR
            # stamped with the module key so it self-validates on load.
            patched = patch_co_filenames_bytes(
                bytecode, package_dir, PRECOMPILE_SENTINEL
            );
            jir_bytes = write_precompiled_jir(
                patched, compute_module_key(jac_path), FLAG_PRECOMPILED
            );

            # Write .jir file
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(jir_bytes);
            compiled += 1;
        } except Exception as e {
            console.error(f"FAIL: {rel} - {e}");
            failed += 1;
        }
    }

    # Close off the in-place progress line before the summary.
    sys.stderr.write("\n");
    sys.stderr.flush();

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules ({failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Python version: {pyver}");
}

with entry {
    main();
}
