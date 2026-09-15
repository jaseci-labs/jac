import os;
import sys;
import from jaclang.compiler.driver.compile_options { env_typed_pointers_enabled }

glob ir_layer_typed_pointers_enabled: bool = env_typed_pointers_enabled();


def _shim_name -> str {
    if os.name == 'posix' {
        if sys.platform == 'darwin' {
            return 'libjacllvm.dylib';
        }
        return 'libjacllvm.so';
    }
    return 'jacllvm.dll';
}


def _find_shim -> str {
    import from jaclang.compiler.driver.compile_options { env_llvm_shim_override }
    `override = env_llvm_shim_override();
    if `override and (`override.strip().lower() in ("none", "off", "disabled")) {
        raise OSError(
            "LLVM shim disabled by JAC_LLVM_SHIM="
                + `override
                + "; the native pipeline is unavailable in this process."
        );
    }
    if `override and os.path.isfile(`override) {
        return `override;
    }
    shim = _shim_name();

    here = os.path.dirname(os.path.abspath(__file__));
    cand = os.path.join(here, shim);
    if os.path.isfile(cand) {
        return cand;
    }

    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(
            p, 'jaclang', 'compiler', 'backends', 'native', 'llvm', shim
        );
        if os.path.isfile(alt) {
            return alt;
        }

        legacy = os.path.join(
            p, 'jaclang', 'compiler', 'passes', 'native', 'llvm', shim
        );
        if os.path.isfile(legacy) {
            return legacy;
        }
    }
    raise OSError(
        f"Could not locate the LLVM shim '{shim}'. Build it with "
            + "`zig build jacllvm` (artifact in jac/zig-out/lib/) and copy it next to "
            + "this package or set JAC_LLVM_SHIM; shipped binaries bundle it."
    );
}
