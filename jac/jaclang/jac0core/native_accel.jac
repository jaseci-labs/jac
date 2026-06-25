"""Deferred native acceleration for bootstrap .na.jac modules.

After bootstrap completes and the full compiler is available, compiles
.na.jac modules with the full compiler pipeline (including NaIRGenPass)
and hot-swaps Python functions with native-backed wrappers via ctypes.

Gated by [run] autonative = true in jac.toml.
"""

import logging;
import os;
import sys;
import threading;
import from pathlib { Path }
import from threading { Event }
import from concurrent.futures { Future }
import from jaclang.jac0core.ext_registry { NATIVE_SUFFIX }

glob _logger = logging.getLogger(__name__),
     _acceleration_complete: Event = Event(),
     _acceleration_future: (Future | None) = None,
     # Thread-local "we are inside the best-effort background self-acceleration
     # compile" flag. The native codegen routes jaclang.* modules through the
     # compiler's internal_program (not the JacProgram we hold here), so a
     # program-instance flag can't reach the demotion site; a thread-local does,
     # because accelerate_module and the demotion run on the same worker thread.
     # NaIRGenPass._demote_method_if_unlowerable reads it via
     # native_accel_warnings_suppressed() to stay quiet. JAC_NATIVE_DEBUG overrides.
     _quiet_tls = threading.local();

"""True while a background native self-acceleration compile is running on this
thread, signalling NaIRGenPass to suppress its per-method "native seam --
demoting ..." stderr warnings (they are best-effort and not user-actionable)."""
def native_accel_warnings_suppressed -> bool {
    return getattr(_quiet_tls, "active", False);
}

"""Find all .na.jac files in jac0core/ that have loaded Python modules."""
def discover_bootstrap_na_modules -> dict[str, str] {
    jac0core_dir = Path(__file__).parent;
    result: dict[str, str] = {};
    for na_file in jac0core_dir.rglob("*.na.jac") {
        # Derive module name from file path relative to jaclang/
        rel = na_file.relative_to(jac0core_dir.parent);
        # Strip .na.jac suffix (two suffixes)
        stem = str(rel).replace(os.sep, ".").removesuffix(NATIVE_SUFFIX);
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
    import from jaclang.jac0core.native_marshal {
        install_native_wrappers,
        init_native_globals
    }
    import from jaclang.jac0core.program { JacProgram }

    module = sys.modules.get(mod_name);
    if module is None {
        return -1;
    }
    # Native acceleration is a best-effort optimization: failures fall back to
    # the Python module, so they are debug-logged rather than raised. That makes
    # the native pass hard to debug (a codegen bug looks like "nothing happened").
    # JAC_NATIVE_DEBUG=1 surfaces the compile errors / exception traceback to
    # stderr so the failure is visible while developing the backend (see #6435
    # item 6).
    _na_debug = bool(os.environ.get("JAC_NATIVE_DEBUG"));
    try {
        prog = JacProgram();
        # Quiet the per-method "native seam -- demoting ..." warnings for the
        # duration of this best-effort compile: its demotions are not
        # user-actionable, so they must not spam stderr on every import when
        # autonative is enabled. Scoped via a thread-local (see _quiet_tls)
        # because the codegen runs on the compiler's internal_program, not this
        # JacProgram. JAC_NATIVE_DEBUG still forces the warnings on.
        _quiet_tls.active = True;
        try {
            ir = prog.compile(file_path=na_file);
        } finally {
            _quiet_tls.active = False;
        }
        if prog.errors_had {
            _msg = f"Native compilation errors for {mod_name}: {prog.errors_had}";
            _logger.debug(_msg);
            if _na_debug {
                sys.stderr.write(_msg + "\n");
            }
            return -1;
        }
        engine = ir.gen.native_engine;
        layout = ir.gen.native_layout;
        if engine is None or layout is None {
            return 0;
        }
        # Initialize the module's (and its native imports') globals before any
        # wrapper can be called — otherwise reads of native globals segfault.
        init_native_globals(engine, ir.gen.interop_manifest);
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
        if _na_debug {
            import traceback;
            sys.stderr.write(f"Native acceleration failed for {mod_name}: {e}\n");
            traceback.print_exc(file=sys.stderr);
        }
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
