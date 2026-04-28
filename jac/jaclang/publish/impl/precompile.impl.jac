"""Implementation of precompile_package."""

import hashlib;
import json;
import marshal;
import sys;
import from pathlib { Path }
import from jaclang.jac0core.bccache { discover_annex_files }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir { write_precompiled_jir, FLAG_PRECOMPILED }

impl precompile_package(pkg_dir: Path) -> int {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    precompiled_dir = pkg_dir / "_precompiled";
    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);

    jac_files: list[Path] = [];
    for jac_path in sorted(pkg_dir.rglob("*.jac")) {
        rel = str(jac_path.relative_to(pkg_dir)).replace("\\", "/");
        # Mirrors find_jac_files() in scripts/precompile_bytecode.jac
        if (
            ".test." in rel
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or rel.startswith(".")
            or ".impl." in jac_path.name
        ) {
            continue;
        }
        # Skip any file whose path contains an excluded directory component
        in_excluded_dir: bool = False;
        for part in rel.split("/") {
            if part in SKIP_FRAGMENTS {
                in_excluded_dir = True;
                break;
            }
        }
        if not in_excluded_dir {
            jac_files.append(jac_path);
        }
    }

    compiler = Jac.get_compiler();
    program = Jac.get_program();
    entries: dict[str, object] = {};
    compiled: int = 0;
    failed: int = 0;

    for jac_path in jac_files {
        rel_path = jac_path.relative_to(pkg_dir);
        jir_path = out_dir / rel_path.with_suffix(".jir");
        try {
            code = compiler.get_bytecode(
                full_target=str(jac_path), target_program=program
            );
            if code is None {
                continue;
            }
            raw = marshal.dumps(code);
            patched = patch_co_filenames_bytes(raw, str(pkg_dir), SENTINEL);
            jir_bytes = write_precompiled_jir(patched, 0, FLAG_PRECOMPILED);
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(jir_bytes);

            entry: dict[str, object] = {
                "source_hash": hashlib.sha256(jac_path.read_bytes()).hexdigest()
            };
            impl_files = discover_annex_files(str(jac_path));
            if impl_files {
                impl_hashes: dict[str, str] = {};
                for impl_f in impl_files {
                    k = str(Path(impl_f).relative_to(pkg_dir)).replace("\\", "/");
                    impl_hashes[k] = hashlib.sha256(
                        Path(impl_f).read_bytes()
                    ).hexdigest();
                }
                entry["impl_hashes"] = impl_hashes;
            }
            entries[str(rel_path).replace("\\", "/")] = entry;
            compiled += 1;
        } except Exception as _e {
            failed += 1;
        }
    }

    manifest: dict[str, object] = {
        "version": 1,
        "filename_sentinel": SENTINEL,
        "entries": entries
    };
    (precompiled_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8"
    );
    return compiled;
}
