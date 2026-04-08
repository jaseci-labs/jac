"""Deferred native acceleration for bootstrap .na.jac modules.

After bootstrap completes and the full compiler is available, compiles
.na.jac modules with the full compiler pipeline (including NaIRGenPass)
and hot-swaps Python functions with native-backed wrappers via ctypes.

schedule_native_acceleration(): Gated by [run] autonative = true in jac.toml.
schedule_bootstrap_native_caching(): Always runs — caches native bitcode for
    .na.jac bootstrap modules so they load natively on subsequent invocations.
"""

import logging;
import os;
import sys;
import from pathlib { Path }
import from threading { Event }
import from concurrent.futures { Future }

glob _logger = logging.getLogger(__name__),
     _acceleration_complete: Event = Event(),
     _acceleration_future: (Future | None) = None,
     _caching_future: (Future | None) = None;

"""Find all .na.jac files in jac0core/ that have loaded Python modules."""
def discover_bootstrap_na_modules -> dict[str, str] {
    jac0core_dir = Path(__file__).parent;
    result: dict[str, str] = {};
    for na_file in jac0core_dir.rglob("*.na.jac") {
        # Derive module name from file path relative to jaclang/
        rel = na_file.relative_to(jac0core_dir.parent);
        # Strip .na.jac suffix (two suffixes)
        stem = str(rel).replace(os.sep, ".").removesuffix(".na.jac");
        mod_name = "jaclang." + stem;
        if mod_name in sys.modules {
            result[mod_name] = str(na_file);
        }
    }
    return result;
}

"""Find all .na.jac files in jac0core/ by filesystem scan (no sys.modules check).

Used for bitcode caching — the module doesn't need to be loaded yet since we're
just compiling and caching for future invocations.
"""
def discover_bootstrap_na_files -> dict[str, str] {
    jac0core_dir = Path(__file__).parent;
    result: dict[str, str] = {};
    for na_file in jac0core_dir.rglob("*.na.jac") {
        rel = na_file.relative_to(jac0core_dir.parent);
        stem = str(rel).replace(os.sep, ".").removesuffix(".na.jac");
        mod_name = "jaclang." + stem;
        result[mod_name] = str(na_file);
    }
    return result;
}

"""Compile a single bootstrap module natively and install wrappers.

Returns number of functions wrapped, or -1 on error.
"""
def accelerate_module(mod_name: str, na_file: str) -> int {
    import from jaclang.jac0core.native_marshal { install_native_wrappers }
    import from jaclang.jac0core.program { JacProgram }

    module = sys.modules.get(mod_name);
    if module is None {
        return -1;
    }
    try {
        prog = JacProgram();
        ir = prog.compile(file_path=na_file);
        if prog.errors_had {
            _logger.debug(
                f"Native compilation errors for {mod_name}: {prog.errors_had}"
            );
            return -1;
        }
        engine = ir.gen.native_engine;
        layout = ir.gen.native_layout;
        if engine is None or layout is None {
            return 0;
        }
        count = install_native_wrappers(module, engine, layout);
        if count > 0 {
            # Keep engine alive on the module to prevent GC
            module.__jac_native_engine__ = engine;
            module.__jac_native_layout__ = layout;
            _logger.info(
                f"Native acceleration: {count} functions wrapped for {mod_name}"
            );
        }
        return count;
    } except Exception as e {
        _logger.debug(f"Native acceleration failed for {mod_name}: {e}");
        return -1;
    }
}

"""Compile all discovered .na.jac modules."""
def _compile_all(modules: dict[str, str]) {
    for (mod_name, na_file) in modules.items() {
        accelerate_module(mod_name, na_file);
    }
    _acceleration_complete.set();
}

"""Schedule deferred native acceleration of bootstrap .na.jac modules.

Compiles in a background thread without blocking startup.
"""
def schedule_native_acceleration -> None {
    global _acceleration_future;
    modules = discover_bootstrap_na_modules();
    if not modules {
        _acceleration_complete.set();
        return;
    }
    import from jaclang.jac0core.runtime { JacRuntime }
    _acceleration_future = JacRuntime.pool.submit(_compile_all, modules);
}

# ─── Bootstrap native bitcode caching ────────────────────────────
"""Compile bootstrap .na.jac modules and persist native bitcode in their JIR cache.

On the next startup, _exec_bootstrap will find the cached bitcode and load
the MCJIT engine immediately, so these modules run natively from boot.
"""
def _cache_all_bootstrap_native(modules: dict[str, str]) {
    import hashlib;
    import struct as _struct;
    import zlib;

    for (mod_name, na_file) in modules.items() {
        try {
            import from jaclang.jac0core.program { JacProgram }
            import from jaclang.jac0core.codeinfo { serialize_native_layout }

            # Compile with full compiler to get bitcode + layout
            prog = JacProgram();
            ir = prog.compile(file_path=na_file);
            if prog.errors_had {
                _logger.debug(
                    f"Bootstrap native cache: compilation errors for {mod_name}"
                );
                continue;
            }
            bitcode = ir.gen.native_bitcode;
            layout = ir.gen.native_layout;
            if bitcode is None or layout is None {
                _logger.debug(
                    f"Bootstrap native cache: no bitcode/layout for {mod_name}"
                );
                continue;
            }

            # Build SEC_NATIVE_OBJ: [triple_len:2LE][triple][bitcode]
            import llvmlite.binding as llvm;
            triple = llvm.get_default_triple().encode('utf-8');
            native_obj_section = _struct.pack('<H', len(triple)) + triple + bitcode;

            # Build SEC_NATIVE_LAYOUT: JSON-encoded layout
            layout_section = serialize_native_layout(layout);

            extra_sections: dict[int, bytes] = {
                0x06: native_obj_section,  # _BOOTSTRAP_SEC_NATIVE_OBJ
                0x08: layout_section  # _BOOTSTRAP_SEC_NATIVE_LAYOUT
            };

            # Recompute the bootstrap JIR cache key (same logic as _bootstrap_compile)
            import from jaclang.meta_importer {
                _get_bootstrap_cache_dir,
                _jac0_hash,
                _jac0_discover_impls,
                _write_bootstrap_jir,
                _read_bootstrap_jir
            }

            with open(na_file, encoding="utf-8") as f {
                jac_source = f.read();
            }
            impl_sources: list[tuple[str, str]] = [];
            for impl_path in _jac0_discover_impls(na_file) {
                with open(impl_path, encoding="utf-8") as f {
                    impl_sources.append((f.read(), impl_path));
                }
            }

            h = hashlib.sha256();
            h.update(sys.version.encode());
            h.update(_jac0_hash);
            h.update(jac_source.encode());
            for (src, path) in impl_sources {
                h.update(path.encode());
                h.update(src.encode());
            }
            digest = h.hexdigest()[:16];
            source_hash = zlib.crc32(jac_source.encode()) & 0xFFFFFFFF;

            base_name = os.path.splitext(os.path.basename(na_file))[0];
            cache_file = _get_bootstrap_cache_dir() / f"{base_name}.{digest}.jir";

            # Read existing JIR to get the bytecode section
            if cache_file.is_file() {
                data = cache_file.read_bytes();
                (bc, _) = _read_bootstrap_jir(data);
                if bc is not None {
                    # Rewrite with bytecode + native sections
                    import marshal;
                    jir_data = _write_bootstrap_jir(
                        bc, source_hash, extra_sections=extra_sections
                    );
                    tmp_path = cache_file.with_suffix('.tmp');
                    tmp_path.write_bytes(jir_data);
                    tmp_path.rename(cache_file);
                    _logger.info(
                        f"Bootstrap native cache: wrote bitcode for {mod_name}"
                    );
                }
            }
        } except Exception as e {
            _logger.debug(f"Bootstrap native cache failed for {mod_name}: {e}");
        }
    }
}

"""Schedule background native bitcode caching for bootstrap .na.jac modules.

This runs unconditionally (not gated by autonative) because .na.jac files
should always run natively. The first invocation caches bitcode; subsequent
invocations load it at bootstrap time via _exec_bootstrap.
"""
def schedule_bootstrap_native_caching -> None {
    global _caching_future;
    modules = discover_bootstrap_na_files();
    if not modules {
        return;
    }
    # Check if all bootstrap JIR caches already have native sections.
    # If so, _exec_bootstrap will load them -- no need to recompile.
    import hashlib;
    import struct as _st;
    import zlib;
    import from jaclang.meta_importer {
        _get_bootstrap_cache_dir,
        _jac0_hash,
        _jac0_discover_impls,
        _read_bootstrap_jir
    }
    all_cached = True;
    for (mod_name, na_file) in modules.items() {
        try {
            with open(na_file, encoding="utf-8") as f {
                jac_source = f.read();
            }
            impl_sources: list[tuple[str, str]] = [];
            for impl_path in _jac0_discover_impls(na_file) {
                with open(impl_path, encoding="utf-8") as f {
                    impl_sources.append((f.read(), impl_path));
                }
            }
            h = hashlib.sha256();
            h.update(sys.version.encode());
            h.update(_jac0_hash);
            h.update(jac_source.encode());
            for (src, path) in impl_sources {
                h.update(path.encode());
                h.update(src.encode());
            }
            digest = h.hexdigest()[:16];
            base_name = os.path.splitext(os.path.basename(na_file))[0];
            cache_file = _get_bootstrap_cache_dir() / f"{base_name}.{digest}.jir";
            if cache_file.is_file() {
                data = cache_file.read_bytes();
                (_, sections) = _read_bootstrap_jir(data);
                if 0x06 in sections and 0x08 in sections {
                    continue;  # This module already has native sections
                }
            }
            all_cached = False;
            break;
        } except Exception {
            all_cached = False;
            break;
        }
    }
    if all_cached {
        return;
    }
    import from jaclang.jac0core.runtime { JacRuntime }
    _caching_future = JacRuntime.pool.submit(_cache_all_bootstrap_native, modules);
}
