glob SHARED_INIT_SYMBOL: str = "__jac_shared_init",
     ENTRY_SYMBOL: str = "jac_entry",
     WASM_INIT_SYMBOL: str = "__jac_glob_init",
     REGION_DIED_HOOK: str = "__jac_region_died_hook",
     STR_NEW_SYMBOL: str = "__jac_str_new";

obj GlueUnit {
    has prefix: str,
        init_symbol: str = "",
        entry_symbol: str = "",
        probe: str = "",
        retain: bool = False,
        release: bool = False,
        str_new: str = "";
}

obj GlueSpec {
    has units: list[GlueUnit],
        root_index: int = -1,
        shared: bool = False,
        platform: str = "elf",
        static_musl: bool = False,
        triple: str = "",
        data_layout: str = "",
        clib_paths: list[str] = [],
        needs_atexit_shim: bool = False,
        needs_region_hook: bool = True;
}

def _decl_void_fn(name: str) -> str {
    return f'declare void @"{name}"()\n';
}

def entry_preamble_ir(spec: GlueSpec) -> str {
    decls: list[str] = [];
    calls: list[str] = [];
    root_unit = spec.units[spec.root_index] if spec.root_index >= 0 else None;
    if root_unit is not None and root_unit.probe {
        decls.append(_decl_void_fn(root_unit.probe));
        calls.append(f'  call void @"{root_unit.probe}"()');
    }
    for unit in spec.units {
        if unit.init_symbol {
            decls.append(_decl_void_fn(unit.init_symbol));
            calls.append(f'  call void @"{unit.init_symbol}"()');
        }
    }
    if not spec.shared and root_unit is not None and root_unit.entry_symbol {
        decls.append(_decl_void_fn(root_unit.entry_symbol));
        calls.append(f'  call void @"{root_unit.entry_symbol}"()');
    }
    name = SHARED_INIT_SYMBOL if spec.shared else ENTRY_SYMBOL;
    body = "\n".join(calls) + "\n" if calls else "";
    text = (
        "".join(decls)
        + f"define void @{name}() {{\nentry:\n"
        + body
        + "  ret void\n}\n\n"
    );
    if spec.platform == "wasm" and not spec.shared {
        """A wasm host initializes the module before it calls exported
        functions and may never run the entry: `__jac_glob_init` runs every
        unit's initializer, each of which runs once whoever calls first.""";
        init_calls = [
            f'  call void @"{unit.init_symbol}"()'
            for unit in spec.units
            if unit.init_symbol
        ];
        init_body = "\n".join(init_calls) + "\n" if init_calls else "";
        text += (
            f"define void @{WASM_INIT_SYMBOL}() {{\nentry:\n"
            + init_body
            + "  ret void\n}\n\n"
        );
    }
    return text;
}

def rc_wrapper_ir(spec: GlueSpec) -> tuple[str, list[str]] {
    parts: list[str] = [];
    exports: list[str] = [];
    if not spec.shared or spec.root_index < 0 {
        return ("", exports);
    }
    root_unit = spec.units[spec.root_index];
    if root_unit.retain {
        parts.append(
            f'declare void @"{root_unit.prefix}.jac_retain"(ptr)\n'
            "define void @jac_retain(ptr %p) {\nentry:\n"
            f'  call void @"{root_unit.prefix}.jac_retain"(ptr %p)\n  ret void\n}}\n'
        );
        exports.append("jac_retain");
    }
    if root_unit.release {
        parts.append(
            f'declare void @"{root_unit.prefix}.jac_release"(ptr)\n'
            "define void @jac_release(ptr %p) {\nentry:\n"
            f'  call void @"{root_unit.prefix}.jac_release"(ptr %p)\n  ret void\n}}\n'
        );
        exports.append("jac_release");
    }
    if root_unit.str_new {
        parts.append(
            f'declare ptr @"{root_unit.str_new}"(ptr, i64)\n'
            "define ptr @jac_str_new(ptr %d, i64 %n) {\nentry:\n"
            f'  %r = call ptr @"{root_unit.str_new}"(ptr %d, i64 %n)\n'
            "  ret ptr %r\n}\n"
        );
        exports.append("jac_str_new");
    }
    return ("\n".join(parts), exports);
}

def atexit_shim_ir -> str {
    return (
        "declare i32 @__cxa_atexit(ptr, ptr, ptr)\n"
        "@__dso_handle = weak global i8 0\n"
        "define hidden i32 @atexit(ptr %f) {\nentry:\n"
        "  %r = call i32 @__cxa_atexit(ptr %f, ptr null, ptr @__dso_handle)\n"
        "  ret i32 %r\n}\n\n"
    );
}

def region_hook_ir -> str {
    return (
        f"define void @{REGION_DIED_HOOK}(i64 %rgn) {{\n" "entry:\n  ret void\n}\n\n"
    );
}

def argv_globals_ir -> str {
    return "@__jac_argc = weak global i32 0\n@__jac_argv = weak global ptr null\n\n";
}

def init_array_globals_ir -> str {
    return "@__jac_init_array = weak global ptr null\n@__jac_init_count = weak global i64 0\n\n";
}

def _main_body_with_init_array -> str {
    return (
        "define i32 @main(i32 %argc, ptr %argv) {\n"
        "entry:\n"
        "    store i32 %argc, ptr @__jac_argc\n"
        "    store ptr %argv, ptr @__jac_argv\n"
        "    %ia = load ptr, ptr @__jac_init_array\n"
        "    %ic = load i64, ptr @__jac_init_count\n"
        "    br label %ia.cond\n"
        "ia.cond:\n"
        "    %i = phi i64 [ 0, %entry ], [ %inext, %ia.body ]\n"
        "    %more = icmp ult i64 %i, %ic\n"
        "    br i1 %more, label %ia.body, label %ia.done\n"
        "ia.body:\n"
        "    %slot = getelementptr ptr, ptr %ia, i64 %i\n"
        "    %fn = load ptr, ptr %slot\n"
        "    call void %fn()\n"
        "    %inext = add i64 %i, 1\n"
        "    br label %ia.cond\n"
        "ia.done:\n"
        "    call void @jac_entry()\n"
        "    ret i32 0\n"
        "}\n\n"
    );
}

def entry_elf_ir -> str {
    return (
        "; --- ELF entry point ---\n"
        + argv_globals_ir()
        + init_array_globals_ir()
        + "declare void @exit(i32) noreturn\n\n"
        + "declare i32 @__libc_start_main(ptr, i32, ptr, ptr, ptr, ptr, ptr)\n\n"
        + "declare ptr @llvm.stacksave()\n\n"
        + _main_body_with_init_array()
        + "define void @_start() naked noreturn {\n"
        + "entry:\n"
        + "    %sp = call ptr @llvm.stacksave()\n"
        + "    %argc = load i32, ptr %sp\n"
        + "    %argv = getelementptr i8, ptr %sp, i64 8\n"
        + "    call void @_jac_boot(i32 %argc, ptr %argv, ptr %sp)\n"
        + "    unreachable\n"
        + "}\n\n"
        + "define internal void @_jac_boot(i32 %bargc, ptr %bargv, ptr %bstack) noreturn {\n"
        + "entry:\n"
        + "    %r = call i32 @__libc_start_main(ptr @main, i32 %bargc, ptr %bargv, ptr null, ptr null, ptr null, ptr %bstack)\n"
        + "    unreachable\n"
        + "}\n"
    );
}

def entry_elf_static_ir -> str {
    return (
        "; --- ELF entry point (musl static) ---\n"
        + argv_globals_ir()
        + init_array_globals_ir()
        + _main_body_with_init_array()
    );
}

def entry_macho_ir -> str {
    return (
        "; --- Mach-O entry point ---\n"
        + argv_globals_ir()
        + "define i32 @main(i32 %argc, ptr %argv) {\n"
        + "entry:\n"
        + "    store i32 %argc, ptr @__jac_argc\n"
        + "    store ptr %argv, ptr @__jac_argv\n"
        + "    call void @jac_entry()\n"
        + "    ret i32 0\n"
        + "}\n"
    );
}

def entry_pe_ir -> str {
    return (
        "; --- PE entry point ---\n"
        + argv_globals_ir()
        + "declare void @exit(i32)\n\n"
        + "@_fltused = weak global i32 0\n\n"
        + "declare i32 @__getmainargs(ptr, ptr, ptr, i32, ptr)\n\n"
        + "define i32 @main(i32 %argc, ptr %argv) {\n"
        + "entry:\n"
        + "    store i32 %argc, ptr @__jac_argc\n"
        + "    store ptr %argv, ptr @__jac_argv\n"
        + "    call void @jac_entry()\n"
        + "    ret i32 0\n"
        + "}\n\n"
        + "define void @_jac_win_start() {\n"
        + "entry:\n"
        + "    %argc.addr = alloca i32\n"
        + "    %argv.addr = alloca ptr\n"
        + "    %env.addr = alloca ptr\n"
        + "    %si = alloca i32\n"
        + "    store i32 0, ptr %si\n"
        + "    %gr = call i32 @__getmainargs(ptr %argc.addr, ptr %argv.addr, ptr %env.addr, i32 0, ptr %si)\n"
        + "    %ac = load i32, ptr %argc.addr\n"
        + "    %av = load ptr, ptr %argv.addr\n"
        + "    %r = call i32 @main(i32 %ac, ptr %av)\n"
        + "    call void @exit(i32 %r)\n"
        + "    ret void\n"
        + "}\n"
    );
}

def platform_entry_ir(spec: GlueSpec) -> str {
    if spec.shared or spec.platform in ("jit", "wasm") {
        return "";
    }
    if spec.platform == "pe" {
        return entry_pe_ir();
    }
    if spec.platform == "macho" {
        return entry_macho_ir();
    }
    if spec.static_musl {
        return entry_elf_static_ir();
    }
    return entry_elf_ir();
}

def link_glue_ir(spec: GlueSpec) -> tuple[str, list[str]] {
    parts: list[str] = [];
    if spec.data_layout {
        parts.append(f'target datalayout = "{spec.data_layout}"\n');
    }
    if spec.triple {
        parts.append(f'target triple = "{spec.triple}"\n\n');
    }
    parts.append(entry_preamble_ir(spec));
    (rc_ir, exports) = rc_wrapper_ir(spec);
    if rc_ir {
        parts.append(rc_ir);
    }
    parts.append(platform_entry_ir(spec));
    if spec.needs_region_hook {
        parts.append(region_hook_ir());
    }
    if spec.needs_atexit_shim {
        parts.append(atexit_shim_ir());
    }
    if spec.shared {
        exports.append(SHARED_INIT_SYMBOL);
    }
    return ("".join(parts), exports);
}

def init_object_codegen {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    llvm.initialize_all_asmparsers();
}
