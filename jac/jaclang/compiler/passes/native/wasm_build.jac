import os;

def _wasm_libc_dir -> (str | None) {
    env = os.environ.get("JAC_NATIVE_WASM_LIBC_DIR", "");
    if env {
        return env if os.path.isdir(env) else None;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    dev = os.path.join(pkg_root, ".pbs-build", "wasm32", "libc");
    if os.path.isdir(dev) and os.listdir(dev) {
        return dev;
    }
    shipped = os.path.join(
        os.path.dirname(pkg_root), "python", "floor", "wasm32", "libc"
    );
    if os.path.isdir(shipped) and os.listdir(shipped) {
        return shipped;
    }
    return None;
}

def _load_libc_module(llvm: object, libc_dir: str, triple: str) -> object {
    parts = sorted(
        [
            f
            for f in os.listdir(libc_dir)
            if f.endswith(".bc") and f != "_merged.bc"
        ]
    );
    if not parts {
        return None;
    }
    merged_path = os.path.join(libc_dir, "_merged.bc");
    newest = max(( os.path.getmtime(os.path.join(libc_dir, f)) for f in parts ));
    if os.path.isfile(merged_path) and os.path.getmtime(merged_path) >= newest {
        with open(merged_path, "rb") as f {
            merged = llvm.parse_bitcode(f.read());
        }
        merged.triple = triple;
        return merged;
    }
    merged = None;
    for f in parts {
        with open(os.path.join(libc_dir, f), "rb") as fh {
            part = llvm.parse_bitcode(fh.read());
        }
        part.triple = triple;
        if merged is None {
            merged = part;
        } else {
            merged.link_in(part);
        }
    }
    try {
        with open(merged_path, "wb") as f {
            f.write(merged.as_bitcode());
        }
    } except OSError { }
    return merged;
}

glob _LATE_BOUND: set = {
         "memcpy",
         "memmove",
         "memset",
         "__multi3",
         "puts",
         "putchar",
         "strlen",
         "strcmp",
         "strncmp",
         "strchr",
         "strcpy",
         "stpcpy",
         "memcmp",
         "memchr",
         "calloc",
         "malloc",
         "free",
         "sqrt",
         "pow",
         "exp",
         "exp2",
         "log",
         "log2",
         "fabs",
         "fmod",
         "ldexp",
         "scalbn",

     },
     _BACKEND_BOUND: set = {"memcpy", "memmove", "memset", "__multi3"},
     _ABI64_ADAPTED: set = {
         "strlen",
         "malloc",
         "calloc",
         "realloc",
         "malloc_usable_size",
         "memcpy",
         "memmove",
         "memset",
         "memcmp",
         "memmem",
         "strncmp",
         "strtol",
         "snprintf",

     };

def _link_wasm_libc(mod: object, llvm: object) -> bool {
    libc_dir = _wasm_libc_dir();
    if libc_dir is None {
        import from jaclang.cli.console { console }
        console.warning(
            "vendored wasm libc not found (run `zig build vendor-wasm-libc`); " + "libc symbols stay as raw env imports and the jac_host1 import " + "contract is NOT enforced"
        );
        return False;
    }
    libc = _load_libc_module(llvm, libc_dir, mod.triple);
    if libc is None {
        return False;
    }
    import from jaclang.compiler.passes.native.wasm_host_abi { WASM_HOST_ABI }

    for fn in libc.functions {
        if not fn.is_declaration and fn.name in WASM_HOST_ABI {
            fn.linkage = "internal";
        }
    }
    provided = set();
    libc_sig = {};
    for fn in libc.functions {
        if not fn.is_declaration {
            provided.add(fn.name);
            libc_sig[fn.name] = str(fn.global_value_type);
        }
    }
    for gv in libc.global_variables {
        if not gv.is_declaration {
            provided.add(gv.name);
        }
    }

    renames = [];
    for fn in mod.functions {
        if fn.is_declaration and fn.name in provided and fn.name not in WASM_HOST_ABI {
            if fn.name in _ABI64_ADAPTED {
                renames.append(fn);
            } elif str(fn.global_value_type) != libc_sig[fn.name] {
                raise RuntimeError(
                    f"native floor declares '{fn.name}' as " + f"{str(
                        fn.global_value_type
                    )} but the vendored wasm32 " + f"libc defines {libc_sig[
                        fn.name
                    ]}; a mismatched direct " + "call traps on wasm — add a widening adapter to " + "wasm_rt/jac_abi64.c and _ABI64_ADAPTED"
                );
            }
        }
    }
    for fn in renames {
        fn.name = "__jac64_" + fn.name;
    }
    mod.link_in(libc);
    for fn in mod.functions {
        if fn.name in provided
        and not fn.is_declaration
        and fn.name not in _LATE_BOUND {
            fn.linkage = "internal";
        }
    }
    for gv in mod.global_variables {
        if gv.name in provided and not gv.is_declaration {
            gv.linkage = "internal";
        }
    }
    return True;
}

def _internalize_late_bound(mod: object) {
    for fn in mod.functions {
        if fn.name in _LATE_BOUND
        and fn.name not in _BACKEND_BOUND
        and not fn.is_declaration {
            fn.linkage = "internal";
        }
    }
}

def emit_wasm_from_ir(
    llvm_ir_str: str, export_funcs: list = [], app_imports: (set | None) = None
) -> bytes {
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    import from jaclang.compiler.passes.native.wasm_linker { WasmLinker }
    import from jaclang.compiler.passes.native.wasm_host_abi {
        WASM_HOST_ABI,
        WASM_HOST_MODULE
    }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(llvm_ir_str);
    mod.verify();
    libc_linked = _link_wasm_libc(mod, llvm);
    tm = llvm.Target.from_triple("wasm32-unknown-unknown").create_target_machine(opt=2);
    pto = llvm.create_pipeline_tuning_options(speed_level=2);
    pb = llvm.create_pass_builder(tm, pto);
    pb.getModulePassManager().run(mod, pb);
    if libc_linked {
        _internalize_late_bound(mod);
        pb2 = llvm.create_pass_builder(tm, pto);
        pb2.getModulePassManager().run(mod, pb2);
    }
    obj_bytes = tm.emit_object(mod);
    if not libc_linked {
        return WasmLinker.link(obj_bytes, export_funcs, 256);
    }
    return WasmLinker.link(
        obj_bytes,
        export_funcs,
        256,
        host_abi=WASM_HOST_ABI,
        host_module=WASM_HOST_MODULE,
        app_imports=app_imports,
    );
}

def wasm_import_map(wasm_bytes: bytes) -> dict {
    import from jaclang.compiler.passes.native.wasm_linker { _rd_uleb, _rd_name }
    out = {};
    o = 8;
    while o < len(wasm_bytes) {
        sid = wasm_bytes[o];
        o += 1;
        (size, o) = _rd_uleb(wasm_bytes, o);
        end = o + size;
        if sid == 2 {
            (cnt, o) = _rd_uleb(wasm_bytes, o);
            ci = 0;
            while ci < cnt and o < end {
                (mod_nm, o) = _rd_name(wasm_bytes, o);
                (fld, o) = _rd_name(wasm_bytes, o);
                kind = wasm_bytes[o];
                o += 1;
                if kind == 0 {
                    (_t, o) = _rd_uleb(wasm_bytes, o);
                    out.setdefault(mod_nm, []).append(fld);
                } else {
                    break;
                }
                ci += 1;
            }
            break;
        }
        o = end;
    }
    for k in out {
        out[k].sort();
    }
    return out;
}

def app_declared_imports(ir_module: object) -> set {
    names = set();
    gen = ir_module?.gen;
    if gen is None {
        return names;
    }
    sym_lib = gen?._clib_symbol_lib;
    if sym_lib {
        names.update(sym_lib.keys());
    }
    manifest = gen?.interop_manifest;
    bindings = manifest?.bindings if manifest else None;
    if bindings {
        names.update(bindings.keys());
    }
    return names;
}

def compile_to_wasm(file_path: str, export_funcs: list = []) -> (bytes | None) {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.abspath(file_path),
            options=CompileOptions(aot_mode=True, type_check=False)
        );
        if (ir is None) or (ir.gen.llvm_ir is None) {
            return None;
        }
        llvm_ir_str = str(ir.gen.llvm_ir);
        app_imports = app_declared_imports(ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
    return emit_wasm_from_ir(llvm_ir_str, export_funcs, app_imports=app_imports);
}
