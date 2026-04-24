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

"""Compile all discovered .na.jac modules and install native tokenize."""
def _compile_all(modules: dict[str, str]) {
    for (mod_name, na_file) in modules.items() {
        accelerate_module(mod_name, na_file);
    }
    _install_native_tokenize(modules);
    _acceleration_complete.set();
}

"""Build a fast native tokenize wrapper and install it on the parser module.

Compiles lexer.na.jac to LLVM, creates a wrapper that bulk-converts native
tokens to Python Token objects using direct ctypes struct access (bypassing
NativeStructView for speed), and sets parser._native_tokenize.
"""
def _install_native_tokenize(modules: dict[str, str]) {
    import ctypes;
    import sys;

    lexer_file = modules.get("jaclang.jac0core.parser.lexer");
    if lexer_file is None {
        return;
    }
    try {
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.jac0core.native_marshal {
            build_ctypes_classes,
            build_enum_maps,
            wrap_native_function
        }
        import from jaclang.jac0core.parser.tokens { Token, TokenKind, SourceLoc }

        prog = JacProgram();
        ir = prog.compile(file_path=lexer_file);
        if prog.errors_had or ir is None or ir.gen is None {
            return;
        }
        engine = ir.gen.native_engine;
        layout = ir.gen.native_layout;
        if engine is None or layout is None {
            return;
        }
        # Initialize globals (tokens module first, then lexer)
        for init_name in ["__jac_glob_init_tokens_na", "__jac_glob_init"] {
            addr = engine.get_function_address(init_name);
            if addr {
                ctypes.CFUNCTYPE(None)(addr)();
            }
        }
        ct_classes = build_ctypes_classes(layout);
        lexer_mod = sys.modules.get("jaclang.jac0core.parser.lexer");
        ns = lexer_mod.__dict__ if lexer_mod else {};
        enum_maps = build_enum_maps(layout, ns);
        func_layout = layout.functions.get("tokenize");
        if func_layout is None {
            return;
        }
        na_tok_wrapper = wrap_native_function(
            engine, func_layout, ct_classes, enum_maps, {}, layout=layout
        );
        if na_tok_wrapper is None {
            return;
        }

        # Build enum ordinal→TokenKind map for fast conversion
        tk_map = enum_maps.get("TokenKind", []);
        tk_map_len = len(tk_map);

        # Define ctypes structs for direct memory access (bypasses NativeStructView)
        class _SL(ctypes.Structure) {
            has _fields_: list = [
                ("fp", ctypes.c_void_p), ("line", ctypes.c_int64),
                ("end_line", ctypes.c_int64), ("col_start", ctypes.c_int64),
                ("col_end", ctypes.c_int64), ("pos_start", ctypes.c_int64),
                ("pos_end", ctypes.c_int64)
            ];
        }
        class _NT(ctypes.Structure) {
            has _fields_: list = [
                ("kind", ctypes.c_int64), ("value", ctypes.c_void_p),
                ("loc", ctypes.c_void_p)
            ];
        }
        string_at = ctypes.string_at;

        def native_tokenize(source: str, file_path: str) -> list | None {
            """Tokenize natively and bulk-convert to Python Token objects."""
            try {
                (na_toks, errs) = na_tok_wrapper(source, file_path);
                if errs != 0 {
                    return None;
                }
                count = na_toks._count;
                if count == 0 {
                    return [];
                }
                arr = na_toks._arr;
                tokens: list = [None] * count;
                for i in range(count) {
                    ptr = arr[i];
                    nt = _NT.from_address(ptr);
                    kind_ord = nt.kind;
                    kind = tk_map[kind_ord] if kind_ord < tk_map_len else TokenKind.ERROR;
                    val_ptr = nt.value;
                    value = string_at(val_ptr).decode("utf-8") if val_ptr else "";
                    nloc = _SL.from_address(nt.loc);
                    loc = SourceLoc(
                        file_path=file_path, line=nloc.line,
                        end_line=nloc.end_line, col_start=nloc.col_start,
                        col_end=nloc.col_end, pos_start=nloc.pos_start,
                        pos_end=nloc.pos_end
                    );
                    tokens[i] = Token(kind=kind, value=value, loc=loc);
                }
                return tokens;
            } except Exception {
                return None;
            }
        }

        # Install on parser module
        parser_mod = sys.modules.get("jaclang.jac0core.parser.parser");
        if parser_mod is not None {
            parser_mod._native_tokenize = native_tokenize;
            # Keep engine alive
            parser_mod._native_engine_ref = engine;
            _logger.info("Native tokenize installed on parser");
        }
    } except Exception as e {
        _logger.debug(f"Failed to install native tokenize: {e}");
    }
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
