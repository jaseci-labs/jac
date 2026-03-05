"""Deferred native acceleration for bootstrap .na.jac modules.

After bootstrap completes and the full compiler is available, compiles
.na.jac modules with the full compiler pipeline (including NaIRGenPass)
and hot-swaps Python functions with native-backed wrappers via ctypes.

Gated by [run] autonative = true in jac.toml.
"""

import logging;
import os;
import sys;
import from pathlib { Path }
import from threading { Event }
import from concurrent.futures { Future }

glob _logger = logging.getLogger(__name__),
     _acceleration_complete: Event = Event(),
     _acceleration_future: (Future | None) = None;

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
def _compile_all(modules: dict[str, str]) -> None {
    for (mod_name, na_file) in modules.items() {
        accelerate_module(mod_name, na_file);
    }
    _acceleration_complete.set();
}

"""Schedule deferred native acceleration of bootstrap .na.jac modules.

Uses JacRuntime.thread_run (the runtime backing for Jac's flow keyword)
to compile in a background thread without blocking startup.
"""
def schedule_native_acceleration -> None {
    global _acceleration_future;
    modules = discover_bootstrap_na_modules();
    if not modules {
        _acceleration_complete.set();
        return;
    }
    import from jaclang.jac0core.runtime { JacRuntime }
    _acceleration_future = JacRuntime.thread_run(_compile_all, modules);
}
