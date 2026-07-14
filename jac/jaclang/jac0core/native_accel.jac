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
     _quiet_tls = threading.local();

def native_accel_warnings_suppressed -> bool {
    return getattr(_quiet_tls, "active", False);
}

def discover_bootstrap_na_modules -> dict[str, str] {
    jac0core_dir = Path(__file__).parent;
    result: dict[str, str] = {};
    for na_file in jac0core_dir.rglob("*.na.jac") {
        rel = na_file.relative_to(jac0core_dir.parent);

        stem = str(rel).replace(os.sep, ".").removesuffix(NATIVE_SUFFIX);
        mod_name = "jaclang." + stem;
        if mod_name in sys.modules {
            result[mod_name] = str(na_file);
        }
    }
    return result;
}

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

    _na_debug = bool(os.environ.get("JAC_NATIVE_DEBUG"));
    try {
        prog = JacProgram();

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

        init_native_globals(engine, ir.gen.interop_manifest);
        count = install_native_wrappers(module, engine, layout);
        if count > 0 {
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

def _compile_all(modules: dict[str, str]) {
    for (mod_name, na_file) in modules.items() {
        accelerate_module(mod_name, na_file);
    }
    _acceleration_complete.set();
}

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
