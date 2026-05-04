"""Implementation of precompile_package."""

import hashlib;
import json;
import marshal;
import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core.bccache { discover_annex_files }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir { write_precompiled_jir, FLAG_PRECOMPILED }

def _find_jac_files(pkg_dir: Path) -> list[Path] {
    result: list[Path] = [];
    for jac_path in sorted(pkg_dir.rglob("*.jac")) {
        if not jac_path.is_file() {
            continue;
        }
        parts = jac_path.relative_to(pkg_dir).parts;
        rel = "/".join(parts);
        if (
            ".test." in rel
            or ".impl." in jac_path.name
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or any(part.startswith(".") for part in parts)
            or any(part in SKIP_FRAGMENTS for part in parts)
        ) {
            continue;
        }
        result.append(jac_path);
    }
    return result;
}

def _compile_one(
    compiler: object, program: object, jac_path: Path, pkg_dir: Path, out_dir: Path,
) -> dict[str, object] | None {
    code = compiler.get_bytecode(full_target=str(jac_path), target_program=program);
    if code is None {
        return None;
    }
    raw = marshal.dumps(code);
    patched = patch_co_filenames_bytes(raw, str(pkg_dir), SENTINEL);
    jir_bytes = write_precompiled_jir(patched, 0, FLAG_PRECOMPILED);
    jir_path = out_dir / jac_path.relative_to(pkg_dir).with_suffix(".jir");
    jir_path.parent.mkdir(parents=True, exist_ok=True);
    jir_path.write_bytes(jir_bytes);

    entry: dict[str, object] = {
        "source_hash": hashlib.sha256(jac_path.read_bytes()).hexdigest()
    };
    impl_files = discover_annex_files(str(jac_path));
    if impl_files {
        entry["impl_hashes"] = {
            str(p.relative_to(pkg_dir)).replace("\\", "/"): hashlib.sha256(
                p.read_bytes()
            ).hexdigest() for f in impl_files for p in [Path(f)]
        };
    }
    return entry;
}

impl precompile_package(pkg_dir: Path) -> int {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    out_dir = pkg_dir / "_precompiled" / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);

    compiler = Jac.get_compiler();
    program = Jac.get_program();
    jac_files = _find_jac_files(pkg_dir);

    entries: dict[str, object] = {};
    compiled = 0;
    failed = 0;

    for jac_path in jac_files {
        rel_key = str(jac_path.relative_to(pkg_dir)).replace("\\", "/");
        try {
            entry = _compile_one(compiler, program, jac_path, pkg_dir, out_dir);
            if entry is None {
                console.warning(f"  ⚠ skipped (no bytecode): {rel_key}");
            } else {
                entries[rel_key] = entry;
                compiled += 1;
            }
        } except Exception as e {
            console.warning(f"  ✗ precompile failed: {rel_key}: {e}");
            failed += 1;
        }
    }

    if failed {
        raise RuntimeError(
            f"precompile_package: {failed} file(s) failed to compile "
            f"({compiled} succeeded). Aborting build."
        );
    }

    manifest: dict[str, object] = {
        "version": 1,
        "filename_sentinel": SENTINEL,
        "entries": entries,

    };
    (pkg_dir / "_precompiled" / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8"
    );
    return compiled;
}
