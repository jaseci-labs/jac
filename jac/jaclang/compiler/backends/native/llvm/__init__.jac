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
    shim_override = env_llvm_shim_override();
    if shim_override
        and (shim_override.strip().lower() in ("none", "off", "disabled")) {
        raise OSError(
            "LLVM shim disabled by JAC_LLVM_SHIM="
                + shim_override
                + "; the native pipeline is unavailable in this process."
        );
    }
    if shim_override {
        if not os.path.isfile(shim_override) {
            raise OSError(f"JAC_LLVM_SHIM={shim_override} is not a file");
        }
        return shim_override;
    }
    shim = _shim_name();

    here = os.path.dirname(os.path.abspath(__file__));
    cand = os.path.join(here, shim);
    if os.path.isfile(cand) {
        return cand;
    }

    raise OSError(
        f"Compiler image is missing LLVM shim '{shim}'. Rebuild with "
            + "`zig build compiler-image` or select a shim with JAC_LLVM_SHIM."
    );
}
