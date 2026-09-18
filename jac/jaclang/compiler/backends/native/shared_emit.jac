import type from jaclang.compiler.frontend.codeinfo { InteropBinding }
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    TargetMachine
}
import type from jaclang.compiler.backends.native.llvm.binding.value { ValueRef }


def internalize_native_implementation(module: ModuleRef, exports: list[str]) {
    import from jaclang.compiler.backends.native.llvm.binding.value { Visibility }
    public = set(exports);
    values: list[ValueRef] = list(module.functions);
    values.extend(module.global_variables);
    for value in values {
        if value.is_declaration
            or value.name in public
            or value.name.startswith("llvm.") {
            continue;
        }
        if value.visibility == Visibility.hidden {
            continue;
        }
        value.linkage = "internal";
    }
}


def inject_heap_accounting(llvm_ir_str: str) -> tuple[str, list[str]] {
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
    if not re.search(r'define[^\n]*@"?__rc_alloc"?\(', llvm_ir_str) {
        raise RuntimeError("Native heap accounting requires managed allocations");
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

def inject_shared_init(llvm_ir_str: str, manifest: any) -> tuple[str, list[str]] {
    init_calls: list[str] = [];
    transitive_sources: list[str] = [];
    if isinstance(manifest, list) {
        transitive_sources = list(manifest);
        manifest = None;
    } elif manifest {
        transitive_sources = list(manifest.native_transitive_sources);
    }

    if ('@"__jac_glob_init"' in llvm_ir_str) or ("@__jac_glob_init(" in llvm_ir_str) {
        init_calls.append("  call void @__jac_glob_init()");
    }
    import from jaclang.compiler.frontend.codeinfo { native_glob_init_name }
    import re as _re;

    _defined: list[str] = [];
    for _m in _re.finditer(
        r'define[^@\n]*@"?(__jac_glob_init_[A-Za-z0-9_]+)"?\s*\(', llvm_ir_str
    ) {
        _dn = _m.group(1);
        if _dn not in _defined {
            _defined.append(_dn);
        }
    }

    _seen: set = set();
    _ordered: list[str] = [];
    for _src in transitive_sources {
        if _src is None or _src in _seen {
            continue;
        }
        _seen.add(_src);
        _nm = native_glob_init_name(_src, manifest);
        if _nm in _defined and _nm not in _ordered {
            _ordered.append(_nm);
        }
    }
    for _dn in _defined {
        if _dn not in _ordered {
            _ordered.append(_dn);
        }
    }
    for _nm in _ordered {
        init_calls.append(f"  call void @{_nm}()");
    }
    parts: list[str] = ["\n; --- injected shared-library init + RC wrappers ---"];
    _body = ("\n".join(init_calls) + "\n") if init_calls else "";
    parts.append(
        "define void @__jac_shared_init() {\nentry:\n" + _body + "  ret void\n}"
    );
    (llvm_ir_str, extra_exports) = inject_heap_accounting(llvm_ir_str);

    if ("@__rc_retain(" in llvm_ir_str) or ('@"__rc_retain"(' in llvm_ir_str) {
        parts.append(
            "define void @jac_retain(ptr %p) {\nentry:\n"
            "  call void @__rc_retain(ptr %p)\n  ret void\n}"
        );
        extra_exports.append("jac_retain");
    }
    if ("@__rc_release_simple(" in llvm_ir_str)
        or ('@"__rc_release_simple"(' in llvm_ir_str) {
        parts.append(
            "define void @jac_release(ptr %p) {\nentry:\n"
            "  call void @__rc_release_simple(ptr %p)\n  ret void\n}"
        );
        extra_exports.append("jac_release");
    }
    if ("@__jac_str_new(" in llvm_ir_str) or ('@"__jac_str_new"(' in llvm_ir_str) {
        parts.append(
            "define ptr @jac_str_new(ptr %d, i64 %n) {\nentry:\n"
            "  %r = call ptr @__jac_str_new(ptr %d, i64 %n)\n  ret ptr %r\n}"
        );
        extra_exports.append("jac_str_new");
    }
    import sys;
    _is_elf = not sys.platform.startswith("win") and sys.platform != "darwin";
    _needs_atexit = (
        _is_elf
        and "define i32 @atexit" not in llvm_ir_str
        and "define hidden i32 @atexit" not in llvm_ir_str
    );
    if _needs_atexit {
        parts.append(
            "declare i32 @__cxa_atexit(ptr, ptr, ptr)\n"
            "define hidden i32 @atexit(ptr %f) {\nentry:\n"
            "  %r = call i32 @__cxa_atexit(ptr %f, ptr null, ptr null)\n"
            "  ret i32 %r\n}"
        );
    }
    return (llvm_ir_str + "\n".join(parts) + "\n", extra_exports);
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

def optimize_native_module(
    module: ModuleRef,
    target_machine: TargetMachine,
    opt_level: int,
    internalize: bool = False
) {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    if opt_level <= 0 {
        return;
    }
    tuning = llvm.create_pipeline_tuning_options(speed_level=opt_level);
    builder = llvm.create_pass_builder(target_machine, tuning);
    pipeline = builder.getModulePassManager();
    if internalize {
        pipeline.add_internalize_pass();
    }
    pipeline.run(module, builder);
}

obj SharedObject {
    has code: bytes,
        exports: list[str];
}

def emit_shared_object(
    llvm_ir_str: str,
    manifest: any,
    export_symbols: list[str],
    triple: str,
    opt_level: int = 2,
    clib_paths: (list[str] | None) = None
) -> SharedObject {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    (ir_str, extra_exports) = inject_shared_init(llvm_ir_str, manifest);
    exports: list[str] = [];
    for symbol in list(export_symbols) + extra_exports + ["__jac_shared_init"] {
        if symbol and symbol not in exports {
            exports.append(symbol);
        }
    }
    init_object_codegen();
    ir_str += aarch64_floor_atomics_ir(triple, list(clib_paths or []));
    module = llvm.parse_assembly(ir_str);
    internalize_native_implementation(module, exports);
    module.verify();
    target_machine = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    optimize_native_module(module, target_machine, opt_level);
    return SharedObject(code=target_machine.emit_object(module), exports=exports);
}

def emit_shared_library(
    llvm_ir_str: str,
    manifest: any,
    export_symbols: list[str],
    output_path: str,
    opt_level: int = 2,
    auto_init: bool = False,
    clib_paths: (list[str] | None) = None,
    clib_symbol_lib: (dict[str, str] | None) = None
) -> tuple[bool, str] {
    import os;
    import sys;
    import jaclang.compiler.backends.native.llvm.binding as llvm;

    triple = llvm.get_default_triple();
    try {
        shared = emit_shared_object(
            llvm_ir_str, manifest, export_symbols, triple, opt_level, clib_paths
        );
    } except Exception as e {
        return (False, f"LLVM IR verification failed: {e}");
    }
    obj_bytes = shared.code;
    exports = shared.exports;
    init_funcs: list[str] = ["__jac_shared_init"] if auto_init else [];

    is_windows = sys.platform.startswith("win");
    is_macos = sys.platform == "darwin";
    soname = os.path.basename(output_path);
    try {
        if is_windows {
            import from jaclang.compiler.backends.native.pe_linker { PeLinker }
            ok = PeLinker.link(
                obj_bytes=obj_bytes,
                output_path=output_path,
                needed_libs=["msvcrt.dll"],
                symbol_lib_map={},
                shared=True,
                export_symbols=exports,
                init_funcs=init_funcs,
                soname=soname
            );
        } elif is_macos {
            import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
            import from jaclang.compiler.backends.native.floor {
                collect_floor_archives
            }
            (_floor_members, _floor_handled) = collect_floor_archives(
                clib_paths or [], clib_symbol_lib or {}, triple, True
            );
            _proc_syms: dict[str, str] = {
                _cs: "@process" for _cs in (clib_symbol_lib or {}).keys()
            };
            ok = MachOLinker.link(
                obj_bytes=obj_bytes,
                output_path=output_path,
                needed_libs=["/usr/lib/libSystem.B.dylib"],
                symbol_lib_map=_proc_syms,
                shared=True,
                export_symbols=exports,
                init_funcs=init_funcs,
                soname=soname,
                archive_members=_floor_members
            );
        } else {
            import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
            import from jaclang.compiler.backends.native.floor {
                collect_floor_archives as _cfa_elf
            }
            (_floor_members_elf, _fh_elf) = _cfa_elf(
                clib_paths or [], clib_symbol_lib or {}, triple, False
            );
            ok = ElfLinker.link(
                obj_bytes=obj_bytes,
                output_path=output_path,
                needed_libs=["libc.so.6", "libm.so.6"],
                crt_objects=[],
                shared=True,
                export_symbols=exports,
                init_funcs=init_funcs,
                soname=soname,
                archive_members=_floor_members_elf,
                static_link=False
            );
        }
    } except Exception as e {
        return (False, f"shared-library link failed: {e}");
    }
    if not ok {
        return (False, "shared-library link failed: could not parse object file");
    }
    return (True, "");
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
