impl _decl_void_fn(name: str) -> str {
    return f'declare void @"{name}"()\n';
}

impl entry_preamble_ir(spec: GlueSpec) -> str {
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
    if spec.shared {
        decls.append(f"@{RC_THREADED_SYMBOL} = weak global i8 0\n");
        calls.insert(
            0, f"  store atomic i8 1, ptr @{RC_THREADED_SYMBOL} monotonic, align 1"
        );
    }
    if spec.shared and spec.platform == "pe" {
        calls.insert(0, "  call void @__jac_win_floor_init()");
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

impl rc_wrapper_ir(spec: GlueSpec) -> tuple[str, list[str]] {
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

impl atexit_shim_ir -> str {
    return (
        "declare i32 @__cxa_atexit(ptr, ptr, ptr)\n"
        "@__dso_handle = weak global i8 0\n"
        "define hidden i32 @atexit(ptr %f) {\nentry:\n"
        "  %r = call i32 @__cxa_atexit(ptr %f, ptr null, ptr @__dso_handle)\n"
        "  ret i32 %r\n}\n\n"
    );
}

impl region_hook_ir -> str {
    return (
        f"define void @{REGION_DIED_HOOK}(i64 %rgn) {{\n" "entry:\n  ret void\n}\n\n"
    );
}

impl argv_globals_ir -> str {
    return "@__jac_argc = weak global i32 0\n@__jac_argv = weak global ptr null\n\n";
}

impl _main_body -> str {
    return (
        "define i32 @main(i32 %argc, ptr %argv) {\n"
        "entry:\n"
        "    store i32 %argc, ptr @__jac_argc\n"
        "    store ptr %argv, ptr @__jac_argv\n"
        "    call void @jac_entry()\n"
        "    ret i32 0\n"
        "}\n\n"
    );
}

impl init_array_runner_ir -> str {
    """`__jac_libc_init`, the `init` argument `_start` hands
    `__libc_start_main`: it runs the executable's `.init_array` (bounded by
    the linker's `__init_array_start` / `__init_array_end`). glibc runs a
    non-null `init` instead of walking the array itself, so constructors run
    exactly once on every glibc, old or new.""";
    return (
        "@__init_array_start = external hidden global ptr\n"
        "@__init_array_end = external hidden global ptr\n\n"
        "define internal void @__jac_libc_init(i32 %argc, ptr %argv, ptr %envp) {\n"
        "entry:\n"
        "    br label %ia.cond\n"
        "ia.cond:\n"
        "    %slot = phi ptr [ @__init_array_start, %entry ], [ %next, %ia.body ]\n"
        "    %more = icmp ult ptr %slot, @__init_array_end\n"
        "    br i1 %more, label %ia.body, label %ia.done\n"
        "ia.body:\n"
        "    %fn = load ptr, ptr %slot\n"
        "    call void %fn(i32 %argc, ptr %argv, ptr %envp)\n"
        "    %next = getelementptr ptr, ptr %slot, i64 1\n"
        "    br label %ia.cond\n"
        "ia.done:\n"
        "    ret void\n"
        "}\n\n"
    );
}

impl entry_elf_ir -> str {
    return (
        "; --- ELF entry point ---\n"
        + argv_globals_ir()
        + init_array_runner_ir()
        + "declare void @exit(i32) noreturn\n\n"
        + "declare i32 @__libc_start_main(ptr, i32, ptr, ptr, ptr, ptr, ptr)\n\n"
        + "declare ptr @llvm.stacksave()\n\n"
        + _main_body()
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
        + "    %r = call i32 @__libc_start_main(ptr @main, i32 %bargc, ptr %bargv, ptr @__jac_libc_init, ptr null, ptr null, ptr %bstack)\n"
        + "    unreachable\n"
        + "}\n"
    );
}

impl entry_elf_static_ir -> str {
    """musl's crt1.o enters `__libc_start_main`, which runs `.init_array`
    itself before `main`.""";
    return "; --- ELF entry point (musl static) ---\n"
        + argv_globals_ir()
        + _main_body();
}

impl entry_macho_ir -> str {
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

impl entry_pe_ir -> str {
    return (
        "; --- PE entry point ---\n"
        + argv_globals_ir()
        + "declare void @exit(i32)\n\n"
        + "@_fltused = weak global i32 0\n\n"
        + "declare i32 @_configure_narrow_argv(i32)\n"
        + "declare i32 @_initialize_narrow_environment()\n"
        + "declare ptr @__p___argc()\n"
        + "declare ptr @__p___argv()\n\n"
        + "define i32 @main(i32 %argc, ptr %argv) {\n"
        + "entry:\n"
        + "    store i32 %argc, ptr @__jac_argc\n"
        + "    store ptr %argv, ptr @__jac_argv\n"
        + "    call void @jac_entry()\n"
        + "    ret i32 0\n"
        + "}\n\n"
        + "define void @_jac_win_start() {\n"
        + "entry:\n"
        + "    call void @__jac_win_floor_init()\n"
        + "    %cfg = call i32 @_configure_narrow_argv(i32 1)\n"
        + "    %env = call i32 @_initialize_narrow_environment()\n"
        + "    %argc.addr = call ptr @__p___argc()\n"
        + "    %argv.addr = call ptr @__p___argv()\n"
        + "    %ac = load i32, ptr %argc.addr\n"
        + "    %av = load ptr, ptr %argv.addr\n"
        + "    %r = call i32 @main(i32 %ac, ptr %av)\n"
        + "    call void @exit(i32 %r)\n"
        + "    ret void\n"
        + "}\n"
    );
}

impl shared_entry_symbol(spec: GlueSpec) -> str {
    if not spec.shared or spec.root_index < 0 {
        return "";
    }
    return spec.units[spec.root_index].entry_symbol;
}

impl shared_main_ir(spec: GlueSpec) -> str {
    """A shared library whose root module has an entry exports it as
    `jac_main(argc, argv)`: a host that loads the library (its initializers
    already ran) hands the process to the program, which reads that argv as
    `sys.argv` and starts single-threaded like an executable, with plain
    reference counts until it spawns a thread.""";
    root_entry = shared_entry_symbol(spec);
    if not root_entry {
        return "";
    }
    return (
        argv_globals_ir()
        + _decl_void_fn(root_entry)
        + f"define i32 @{SHARED_MAIN_SYMBOL}(i32 %argc, ptr %argv) {{\n"
        + "entry:\n"
        + f"    store atomic i8 0, ptr @{RC_THREADED_SYMBOL} monotonic, align 1\n"
        + "    store i32 %argc, ptr @__jac_argc\n"
        + "    store ptr %argv, ptr @__jac_argv\n"
        + f'    call void @"{root_entry}"()\n'
        + "    ret i32 0\n"
        + "}\n\n"
    );
}

impl platform_entry_ir(spec: GlueSpec) -> str {
    if spec.shared {
        return shared_main_ir(spec);
    }
    if spec.platform in ("jit", "wasm") {
        return "";
    }
    if spec.platform == "c" {
        return argv_globals_ir() + _main_body();
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

impl shared_init_registration_ir(spec: GlueSpec) -> str {
    """How the loader runs `__jac_shared_init` when it loads the library.
    ELF lists it in `.init_array` directly: LLVM, left to `llvm.global_ctors`,
    emits ELF constructors into `.ctors`, which only a crtbegin.o runs. The
    glue is the last input, so it runs after every constructor the inputs
    carry. Mach-O lists it as a module initializer. A PE DLL has no C runtime
    to run constructors, so its entry point calls it on
    DLL_PROCESS_ATTACH.""";
    if spec.platform == "pe" {
        return (
            f"define i32 @__jac_dll_main(ptr %module, i32 %reason, ptr %reserved) {{\n"
            "entry:\n"
            "    %attach = icmp eq i32 %reason, 1\n"
            "    br i1 %attach, label %init, label %done\n"
            "init:\n"
            f"    call void @{SHARED_INIT_SYMBOL}()\n"
            "    br label %done\n"
            "done:\n"
            "    ret i32 1\n"
            "}\n\n"
        );
    }
    if spec.platform == "elf" {
        return (
            f"@__jac_shared_init_entry = internal constant ptr @{SHARED_INIT_SYMBOL}, "
            "section \".init_array\", align 8\n"
            "@llvm.used = appending global [1 x ptr] [ptr @__jac_shared_init_entry], "
            "section \"llvm.metadata\"\n\n"
        );
    }
    if spec.platform == "macho" {
        return (
            "@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] "
            f"[{{ i32, ptr, ptr }} {{ i32 65535, ptr @{SHARED_INIT_SYMBOL}, ptr null }}]\n\n"
        );
    }
    return "";
}

impl link_glue_ir(spec: GlueSpec) -> tuple[str, list[str]] {
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
    floor_osarch = triple_osarch(spec.triple) if spec.triple else "";
    if spec.platform == "pe"
        or (spec.platform == "jit" and floor_osarch.startswith("windows")) {
        import from jaclang.compiler.backends.native.win_floor { win_floor_ir }
        parts.append(win_floor_ir());
    } elif spec.platform in ["elf", "macho", "c", "jit"] and floor_osarch {
        import from jaclang.compiler.backends.native.posix_floor { posix_floor_ir }
        parts.append(posix_floor_ir(floor_osarch));
    }
    if spec.shared {
        parts.append(shared_init_registration_ir(spec));
        exports.append(SHARED_INIT_SYMBOL);
    }
    if shared_entry_symbol(spec) {
        exports.append(SHARED_MAIN_SYMBOL);
    }
    return ("".join(parts), exports);
}

impl init_object_codegen {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    llvm.initialize_all_asmparsers();
}

impl bind_shared_callbacks(
    llvm_ir: str, bindings: list[InteropBinding]
) -> tuple[str, list[InteropBinding]] {
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

impl inject_heap_accounting(
    llvm_ir_str: str, managed: bool = False
) -> tuple[str, list[str]] {
    import re;

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
