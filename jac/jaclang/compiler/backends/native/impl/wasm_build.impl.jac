impl _wasm_libc_dir -> (str | None) {
    found = resolve("wasm-libc").found;
    return found.path if found is not None else None;
}

impl _mod_functions(mod: ModuleRef) -> list[ValueRef] {
    fns = mod.functions;
    assert isinstance(fns, Iterator);
    return list(fns);
}

impl _mod_globals(mod: ModuleRef) -> list[ValueRef] {
    gvs = mod.global_variables;
    assert isinstance(gvs, Iterator);
    return list(gvs);
}

impl _load_libc_module(libc_dir: str, triple: str) -> (ModuleRef | None) {
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
            cached = llvm.parse_bitcode(f.read());
        }
        assert isinstance(cached, llvm.ModuleRef);
        cached.triple = triple;
        return cached;
    }
    merged: (ModuleRef | None) = None;
    for f in parts {
        with open(os.path.join(libc_dir, f), "rb") as fh {
            part = llvm.parse_bitcode(fh.read());
        }
        assert isinstance(part, llvm.ModuleRef);
        part.triple = triple;
        if merged is None {
            merged = part;
        } else {
            merged.link_in(part);
        }
    }
    assert merged is not None;
    try {
        import tempfile;
        (tmp_fd, tmp_path) = tempfile.mkstemp(dir=libc_dir, suffix=".merged.tmp");
        try {
            with os.fdopen(tmp_fd, "wb") as f {
                bitcode = merged.as_bitcode();
                assert isinstance(bitcode, bytes);
                f.write(bitcode);
            }
            os.replace(tmp_path, merged_path);
        } except OSError {
            try {
                os.unlink(tmp_path);
            } except OSError {}
        }
    } except OSError {}
    return merged;
}

impl _assert_abi64_adapters(
    needed: list[str], provided: set[str], libc_dir: str
) -> None {
    missing = sorted(
        set(
            [
                nm
                for nm in needed
                if ("__jac64_" + nm) not in provided
            ]
        )
    );
    if not missing {
        return;
    }
    adapters = ', '.join(['__jac64_' + nm for nm in missing]);
    raise RuntimeError(
        f"vendored wasm libc at {libc_dir} is stale: the native floor "
            + f"rewrites {', '.join(missing)} to {adapters}, which the linked "
            + "bitcode does not define (see _ABI64_ADAPTED and "
            + "wasm_rt/jac_abi64.c). The adapters exist in source; the compiled "
            + "bitcode predates them -- run `jac native build wasm-libc`."
    );
}

impl _link_wasm_libc(mod: ModuleRef) -> bool {
    found = require("wasm-libc").found;
    assert found is not None;
    libc_dir = found.path;
    libc = _load_libc_module(libc_dir, str(mod.triple));
    if libc is None {
        return False;
    }

    for fn in _mod_functions(libc) {
        if not fn.is_declaration and fn.name in WASM_HOST_ABI {
            fn.linkage = "internal";
        }
    }
    provided: set[str] = set();
    libc_sig: dict[str, str] = {};
    for fn in _mod_functions(libc) {
        if not fn.is_declaration {
            provided.add(str(fn.name));
            libc_sig[str(fn.name)] = str(fn.global_value_type);
        }
    }
    for gv in _mod_globals(libc) {
        if not gv.is_declaration {
            provided.add(str(gv.name));
        }
    }

    renames: list[ValueRef] = [];
    for fn in _mod_functions(mod) {
        if fn.is_declaration and fn.name in provided and fn.name not in WASM_HOST_ABI {
            if fn.name in _ABI64_ADAPTED {
                renames.append(fn);
            } elif str(fn.global_value_type) != libc_sig[str(fn.name)] {
                raise RuntimeError(
                    f"native floor declares '{fn.name}' as "
                        + f"{str(fn.global_value_type)} but the vendored wasm32 "
                        + f"libc defines {libc_sig[str(fn.name)]}; a mismatched "
                        + "direct call traps on wasm — add a widening adapter to "
                        + "wasm_rt/jac_abi64.c and _ABI64_ADAPTED"
                );
            }
        }
    }
    _assert_abi64_adapters([str(fn.name) for fn in renames], provided, libc_dir);
    for fn in renames {
        fn.name = "__jac64_" + str(fn.name);
    }
    mod.link_in(libc);
    for fn in _mod_functions(mod) {
        if fn.name in provided
            and not fn.is_declaration
            and fn.name not in _LATE_BOUND {
            fn.linkage = "internal";
        }
    }
    for gv in _mod_globals(mod) {
        if gv.name in provided and not gv.is_declaration {
            gv.linkage = "internal";
        }
    }
    return True;
}

impl _internalize_late_bound(mod: ModuleRef) {
    for fn in _mod_functions(mod) {
        if fn.name in _LATE_BOUND
            and fn.name not in _BACKEND_BOUND
            and not fn.is_declaration {
            fn.linkage = "internal";
        }
    }
}

impl prepare_wasm_module(llvm_ir_str: str) -> tuple[ModuleRef, TargetMachine, bool] {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(llvm_ir_str);
    mod.verify();
    libc_linked = _link_wasm_libc(mod);
    target = llvm.Target.from_triple("wasm32-unknown-unknown");
    assert isinstance(target, llvm.Target);
    tm = target.create_target_machine(opt=2);
    assert isinstance(tm, llvm.TargetMachine);

    optimize_unit(mod, tm, 2);
    if libc_linked {
        _internalize_late_bound(mod);
        optimize_unit(mod, tm, 2);
    }
    return (mod, tm, libc_linked);
}

impl emit_wasm_from_ir(
    llvm_ir_str: str, export_funcs: list[str] = [], app_imports: (set | None) = None
) -> bytes {
    (mod, tm, libc_linked) = prepare_wasm_module(llvm_ir_str);
    exports = list(export_funcs) or _exported_functions(mod);
    obj_bytes = tm.emit_object(mod);
    assert isinstance(obj_bytes, bytes);
    if not libc_linked {
        return link_wasm_object(obj_bytes, exports);
    }
    return link_wasm_object(
        obj_bytes,
        exports,
        host_abi=WASM_HOST_ABI,
        host_module=WASM_HOST_MODULE,
        app_imports=app_imports
    );
}

impl _exported_functions(mod: ModuleRef) -> list[str] {
    """Every function the module defines with external linkage and default
    visibility: a wasm module's host calls its functions by these names.""";
    names: list[str] = [];
    for fn in _mod_functions(mod) {
        if not fn.is_declaration
            and fn.linkage == llvm.Linkage.external
            and fn.visibility == llvm.Visibility.default
            and not str(fn.name).startswith("llvm.") {
            names.append(str(fn.name));
        }
    }
    return names;
}

impl link_wasm_object(
    obj_bytes: bytes,
    export_funcs: list[str],
    host_abi: (set | None) = None,
    host_module: str = "",
    app_imports: (set | None) = None
) -> bytes {
    """Link one wasm object into a module with wasm-ld. Its undefined
    functions become imports: the host ABI's are imported from
    `host_module`, and once the app's imports are known, any other import
    is an error.""";
    import tempfile;
    allowed: (list[str] | None) = None;
    if app_imports is not None {
        allowed = sorted(set(host_abi or set()) | set(app_imports));
    }
    (fd, out_path) = tempfile.mkstemp(suffix=".wasm");
    os.close(fd);
    try {
        link_wasm_module(
            WasmLinkJob(
                objects=[obj_bytes],
                output_path=out_path,
                export_funcs=export_funcs,
                allowed_imports=allowed
            )
        );
        with open(out_path, "rb") as f {
            content = f.read();
        }
    } except NativeLinkError as e {
        raise RuntimeError(_unexpected_import_message(str(e), host_module)) from None;
    } finally {
        os.unlink(out_path);
    }
    if host_abi is not None and host_module {
        content = rename_wasm_imports(content, set(host_abi), host_module);
    }
    return content;
}

impl _unexpected_import_message(link_error: str, host_module: str) -> str {
    import re;
    matched = re.search(r"undefined symbol: (\S+)", link_error);
    if matched is None {
        return link_error;
    }
    name = matched.group(1);
    if name.startswith("__jac64_") {
        return (
            f"wasm import '{name}' is a wasm_rt floor adapter, not "
            + "an app symbol: the vendored libc bitcode is stale and does "
            + "not define it. Rebuild the floor (`zig build "
            + "vendor-wasm-libc`) rather than adding it to "
            + "wasm_host_abi.jac -- the host ABI is syscalls only, and a "
            + "host-side allocator cannot return a linear-memory pointer."
        );
    }
    return (
        f"wasm import '{name}' is neither part of the "
        + f"{host_module or 'host'} ABI nor declared by the app; "
        + "the native floor references a symbol missing from the "
        + "vendored wasm_rt libc (compiler drift) -- add it to "
        + "wasm_rt or to wasm_host_abi.jac"
    );
}

impl app_declared_imports(ir_module: UniModule, plan: any = None) -> set[str] {
    names: set[str] = set();
    gen = ir_module.gen;
    sym_lib = gen._clib_symbol_lib;
    if sym_lib {
        names.update(sym_lib.keys());
    }
    if plan is not None {
        """A C declaration in any unit of the program is the application's
        import: the platform layer of a game declares the host calls its
        entry module never names.""";
        names.update(plan.clib_symbol_lib().keys());
    }
    manifest = gen.interop_manifest;
    bindings = manifest.bindings if manifest else None;
    if bindings {
        for binding in bindings.values() {
            if binding.native_callable and binding.symbol {
                names.add(binding.symbol);
            }
        }
    }
    return names;
}

impl _project_gc_settings -> tuple[str, list[str], list[str]] {
    gc_mode = "cycles";
    enf_mods: list[str] = [];
    enf_grand: list[str] = [];
    try {
        import from jaclang.project { get_config }
        cfg = get_config();
        if cfg {
            gc_mode = cfg.memory.gc_mode();
            enf_mods = list(cfg.memory.enforce);
            enf_grand = list(cfg.memory.exempt);
        }
    } except Exception {
        return ("cycles", [], []);
    }
    return (gc_mode, enf_mods, enf_grand);
}

impl _assert_ir_rc_free(llvm_ir_str: str, file_path: str) {
    import re;
    syms: set[str] = set();
    for m in re.finditer(r"__rc_[A-Za-z0-9_]*", llvm_ir_str) {
        syms.add(m.group(0));
    }
    probes: list[str] = [];
    for probe in ("JAC_GC", ) {
        if probe in llvm_ir_str {
            probes.append(probe);
        }
    }
    if syms or probes {
        raise RuntimeError(
            f"'{os.path.basename(file_path)}' compiled under [memory] profile ="
                + " \"nogc\" but its IR still carries RC machinery ("
                + ", ".join(sorted(syms) + probes)
                + "); this is a compiler bug: the ownership checker admitted code"
                + " that re-enters the reference-counted world"
        );
    }
}

impl compile_to_wasm(file_path: str, export_funcs: list[str] = []) -> bytes {
    return build_wasm(JacProgram(), file_path, export_funcs);
}
