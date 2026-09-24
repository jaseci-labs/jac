import type from jaclang.compiler.frontend.codeinfo { InteropBinding }
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
    if spec.platform == "c" {
        return argv_globals_ir()
            + init_array_globals_ir()
            + _main_body_with_init_array();
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
    if spec.platform != "c" {
        parts.append(aarch64_floor_atomics_ir(spec.triple, spec.clib_paths));
    }
    if spec.shared {
        exports.append(SHARED_INIT_SYMBOL);
    }
    return ("".join(parts), exports);
}

def aarch64_outline_atomics_ir -> str {
    ops: dict[str, str] = {
        "ldadd": "add",
        "ldclr": "bic",
        "ldeor": "eor",
        "ldset": "orr"
    };
    sizes: list[int] = [1, 2, 4, 8];
    orders: list[str] = ["relax", "acq", "rel", "acq_rel"];
    sfx: dict[int, str] = {1: "b", 2: "h", 4: "", 8: ""};
    widen: dict[int, str] = {1: "uxtb", 2: "uxth"};

    asm: list[str] = [
        "  .weak __aarch64_have_lse_atomics",
        "  .hidden __aarch64_have_lse_atomics",
        "  .type __aarch64_have_lse_atomics,%object",
        "  .data",
        "__aarch64_have_lse_atomics:",
        "  .byte 0",
        "  .size __aarch64_have_lse_atomics,1",
        "  .text"
    ];

    for order in orders {
        for size in sizes {
            r = "x" if size == 8 else "w";
            ld = ("ldaxr" if order in ["acq", "acq_rel"] else "ldxr") + sfx[size];
            st = ("stlxr" if order in ["rel", "acq_rel"] else "stxr") + sfx[size];

            for (op, insn) in ops.items() {
                nm = f"__aarch64_{op}{size}_{order}";
                asm += _lse_sym(nm)
                    + [
                        f"  mov {r}16, {r}0",
                        f".L{nm}:",
                        f"  {ld} {r}0, [x1]",
                        f"  {insn} {r}17, {r}0, {r}16",
                        f"  {st} w15, {r}17, [x1]",
                        f"  cbnz w15, .L{nm}",
                        "  ret",
                        f"  .size {nm},.-{nm}"
                    ];
            }

            nm = f"__aarch64_swp{size}_{order}";
            asm += _lse_sym(nm)
                + [
                    f"  mov {r}16, {r}0",
                    f".L{nm}:",
                    f"  {ld} {r}0, [x1]",
                    f"  {st} w15, {r}16, [x1]",
                    f"  cbnz w15, .L{nm}",
                    "  ret",
                    f"  .size {nm},.-{nm}"
                ];

            nm = f"__aarch64_cas{size}_{order}";
            wide = (
                f"  {widen[size]} {r}16, {r}0"
                    if size in widen
                    else f"  mov {r}16, {r}0"
            );
            asm += _lse_sym(nm)
                + [
                    wide,
                    f".L{nm}:",
                    f"  {ld} {r}0, [x2]",
                    f"  cmp {r}0, {r}16",
                    f"  b.ne .L{nm}_out",
                    f"  {st} w17, {r}1, [x2]",
                    f"  cbnz w17, .L{nm}",
                    f".L{nm}_out:",
                    "  ret",
                    f"  .size {nm},.-{nm}"
                ];
        }

        nm = f"__aarch64_cas16_{order}";
        ldp = "ldaxp" if order in ["acq", "acq_rel"] else "ldxp";
        stp = "stlxp" if order in ["rel", "acq_rel"] else "stxp";
        asm += _lse_sym(nm)
            + [
                "  mov x16, x0",
                "  mov x17, x1",
                f".L{nm}:",
                f"  {ldp} x0, x1, [x4]",
                "  cmp x0, x16",
                "  ccmp x1, x17, #0, eq",
                f"  b.ne .L{nm}_out",
                f"  {stp} w15, x2, x3, [x4]",
                f"  cbnz w15, .L{nm}",
                f".L{nm}_out:",
                "  ret",
                f"  .size {nm},.-{nm}"
            ];
    }
    head = (
        "\n; --- aarch64 LSE outline-atomics helpers: the C floor is built with"
        "\n; -moutline-atomics, so its objects call __aarch64_ldadd4_relax and"
        "\n; family, which live only in a static libgcc/compiler-rt -- libgcc_s"
        "\n; exports none of them and nothing in the floor set defines them, so"
        "\n; the artifact linked clean and failed its load canary. Our own"
        "\n; codegen never calls these (atomicrmw lowers to inline ldxr/stxr);"
        "\n; they are here purely for the vendored objects. Always LL/SC, so no"
        "\n; dispatch on __aarch64_have_lse_atomics is needed. Weak + hidden:"
        "\n; they must neither collide with a floor member's own copy nor reach"
        "\n; the dynamic symbol table. Only x0/x1/x15/x16/x17 are clobbered,"
        "\n; which is the contract callers assume and why this is not IR ---\n"
    );
    return head + "\n".join([f"module asm \"{ln}\"" for ln in asm]) + "\n";
}

def _lse_sym(nm: str) -> list[str] {
    return [f"  .weak {nm}", f"  .hidden {nm}", f"  .type {nm},%function", f"{nm}:"];
}

def init_object_codegen {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    llvm.initialize_all_asmparsers();
}

def aarch64_floor_atomics_ir(triple: str, clib_paths: list[str]) -> str {
    import from jaclang.runtime.graph_utils { triple_arch }
    if not clib_paths or triple_arch(triple) != "aarch64" {
        return "";
    }
    tl = triple.lower();
    is_pe = ("windows" in tl) or ("win32" in tl) or ("msvc" in tl) or ("mingw" in tl);
    is_macho = ("darwin" in tl) or ("apple" in tl) or ("macos" in tl) or ("ios" in tl);
    if is_pe or is_macho {
        return "";
    }
    return aarch64_outline_atomics_ir();
}

def bind_shared_callbacks(
    llvm_ir: str, bindings: list[InteropBinding]
) -> tuple[str, list[InteropBinding]] {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    import from jaclang.compiler.backends.native.llvm.ir.types { _wrapname }
    module = llvm.parse_assembly(llvm_ir);
    assert isinstance(module, llvm.ModuleRef);
    definitions: list[str] = [];
    callbacks: list[InteropBinding] = [];
    for binding in bindings {
        function = module.get_function(binding.name);
        assert isinstance(function, llvm.ValueRef);
        if not function.is_declaration {
            continue;
        }
        (result, parameters, variadic) = function.function_signature();
        if variadic {
            raise ValueError(
                f'Python callbacks cannot use a variadic ABI: {binding.name}'
            );
        }
        callbacks.append(binding);
        name = _wrapname(binding.name);
        slot = _wrapname('__jac_callback_' + binding.name);
        bind_function = _wrapname('__jac_bind_' + binding.name);
        arguments = ', '.join(
            f'{kind} %arg{index}' for (index, kind) in enumerate(parameters)
        );
        call = f'call {result} %function({arguments})';
        body = f'  {call}\n  ret void'
            if result == 'void'
            else f'  %result = {call}\n  ret {result} %result';
        definitions.extend(
            [
                f'@{slot} = internal global ptr null',
                f'define void @{bind_function}(ptr %callback) {{\n  store ptr %callback, ptr @{slot}\n  ret void\n}}',
                f'define {result} @{name}({arguments}) {{\n  %function = load ptr, ptr @{slot}\n{body}\n}}'
            ]
        );
    }
    if definitions {
        callback_module = llvm.parse_assembly('\n'.join(definitions));
        module.link_in(callback_module);
    }
    module.verify();
    return (str(module), callbacks);
}

def inject_heap_accounting(
    llvm_ir_str: str, managed: bool = False
) -> tuple[str, list[str]] {
    import re;
    import from jaclang.compiler.frontend.codeinfo { HDR_TOTAL }
    requested = [
        name
        for name in ("jac_heap_size", "jac_list_heap_size")
        if re.search(r'declare[^\n]*@"?' + name + r'"?\(', llvm_ir_str)
    ];
    if not requested {
        return (llvm_ir_str, []);
    }
    if not managed and not re.search(r'define[^\n]*@"?__rc_alloc"?\(', llvm_ir_str) {
        raise RuntimeError(
            "Native heap accounting requires allocation headers; a nogc-enforced "
            "unit under gc=none allocates without them"
        );
    }
    apple = re.search(r'target triple = "[^"\n]*(?:apple|darwin)', llvm_ir_str)
        is not None;
    allocator_size = "malloc_size" if apple else "malloc_usable_size";
    definitions: list[str] = [];
    if not re.search(
        r'(?:declare|define)[^\n]*@"?' + allocator_size + r'"?\(', llvm_ir_str
    ) {
        definitions.append("declare i64 @" + allocator_size + "(ptr)");
    }
    for name in requested {
        llvm_ir_str = re.sub(
            r'(?m)^declare[^\n]*@"?' + name + r'"?\([^\n]*\)[^\n]*$', "", llvm_ir_str
        );
        body = (
            "define i64 @"
            + name
            + "(i64 %address) {\nentry:\n"
            "  %empty = icmp eq i64 %address, 0\n"
            "  br i1 %empty, label %zero, label %measure\nzero:\n  ret i64 0\nmeasure:\n"
            "  %object = inttoptr i64 %address to ptr\n"
            "  %base = getelementptr i8, ptr %object, i64 -"
            + str(HDR_TOTAL)
            + "\n" "  %owned = call i64 @"
            + allocator_size
            + "(ptr %base)\n"
        );
        if name == "jac_list_heap_size" {
            body += (
                "  %slot = getelementptr { i64, i64, ptr }, ptr %object, i32 0, i32 2\n"
                "  %data = load ptr, ptr %slot\n"
                "  %buffer = call i64 @"
                + allocator_size
                + "(ptr %data)\n"
                "  %total = add i64 %owned, %buffer\n  ret i64 %total\n}"
            );
        } else {
            body += "  ret i64 %owned\n}";
        }
        definitions.append(body);
    }
    return (llvm_ir_str + "\n" + "\n".join(definitions) + "\n", requested);
}
