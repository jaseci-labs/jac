import marshal;
import os;
import from pathlib { Path }
import from jaclang.bootstrap_manifest { seed_abs_entries, is_native_only_seed }
import from jaclang.jac0core { ext_registry }
import from jaclang.jac0core.cache_paths { atomic_write }
import from jaclang.compiler.driver.jir {
    SEC_BYTECODE,
    SEC_IFACE,
    FLAG_BOOTSTRAP,
    PRECOMPILE_SENTINEL,
    read_section_bytes,
    parse_header,
    precompiled_jir_matches_source,
    compute_precompile_module_key,
    patch_co_filenames_bytes,
    write_precompiled_jir,
    read_debug_source
}

def bootstrap_sources(package: Path) -> list[Path] {
    if package.name != "jaclang" {
        return [];
    }
    (directories, files) = seed_abs_entries(str(package));
    sources = {
        Path(path)
        for path in files
        if path.endswith(".jac")
    };
    for directory in directories {
        sources.update(Path(directory).rglob("*.jac"));
    }
    return sorted(
        path
        for path in sources
        if not ext_registry.is_annex(str(path))
            and not is_native_only_seed(path.relative_to(package).as_posix())
            and not any(
                part.startswith(".") or part == "__pycache__"
                for part in path.relative_to(package).parts
            )
    );
}

def seal_bootstrap(
    pkg_dir: Path,
    out_dir: Path,
    embed_src: bool,
    measurements: dict[str, int] | None = None
) -> int {
    import from jaclang.meta_importer { _bootstrap_compile }
    import from jaclang.jac0 { discover_impl_files }
    import from jaclang.dist.precompile_bytecode {
        precompile_unit_context,
        _unit_extra
    }
    import from jaclang.cli.console { console }
    counts = measurements if measurements is not None else {};
    counts.update({"compiled": 0, "reused": 0, "bytecode_reused": 0, "failed": 0});
    for source in bootstrap_sources(pkg_dir) {
        path = str(source);
        output = out_dir / source.relative_to(pkg_dir).with_suffix(".jir");
        try {
            key = compute_precompile_module_key(path);
            bytecode: bytes | None = None;
            if output.is_file() {
                existing = output.read_bytes();
                header = parse_header(existing);
                if header is not None
                    and header.flags & FLAG_BOOTSTRAP
                    and precompiled_jir_matches_source(
                        existing, path, package_root=str(pkg_dir)
                    ) {
                    bytecode = read_section_bytes(existing, SEC_BYTECODE);
                    if bytecode is not None {
                        counts["bytecode_reused"] += 1;
                    }
                    if bytecode is not None
                        and read_section_bytes(existing, SEC_IFACE) is not None
                        and embed_src == (read_debug_source(existing) is not None) {
                        with precompile_unit_context(path, str(pkg_dir)) as program {
                            reusable = program.iface_registry().dependencies_match(
                                path, existing, str(pkg_dir)
                            );
                        }
                        if reusable {
                            counts["reused"] += 1;
                            continue;
                        }
                    }
                }
            }
            if bytecode is None {
                annexes = [
                    (Path(impl_path).read_text(encoding="utf-8"), impl_path)
                    for impl_path in discover_impl_files(path)
                ];
                code = _bootstrap_compile(
                    path, source.read_text(encoding="utf-8"), annexes or None
                );
                bytecode = patch_co_filenames_bytes(
                    marshal.dumps(code), str(pkg_dir), PRECOMPILE_SENTINEL
                );
            }
            with precompile_unit_context(path, str(pkg_dir)) as program {
                program.iface_registry().ensure(path);
                program.iface_registry().publish_completed();
                found = program.iface_registry()._module_jir(path, (SEC_IFACE, ));
                extra = _unit_extra(path, str(pkg_dir), embed_src, found);
            }
            if compute_precompile_module_key(path) != key {
                raise RuntimeError(f"Source changed while freezing {source}");
            }
            atomic_write(
                output, write_precompiled_jir(bytecode, key, FLAG_BOOTSTRAP, extra)
            );
            counts["compiled"] += 1;
        } except Exception as error {
            console.error(f"BOOTSTRAP FAIL: {source.name} - {error}");
            counts["failed"] += 1;
        }
    }
    return counts["failed"];
}
