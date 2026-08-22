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
    import from jaclang.jac0core.codeinfo { native_glob_init_name }
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
    extra_exports: list[str] = [];

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

def emit_shared_library(
    llvm_ir_str: str,
    manifest: any,
    export_symbols: list[str],
    output_path: str,
    opt_level: int = 2,
    auto_init: bool = False,
    clib_paths: (list | None) = None,
    clib_symbol_lib: (dict | None) = None
) -> tuple[bool, str] {
    import os;
    import sys;

    (ir_str, extra_exports) = inject_shared_init(llvm_ir_str, manifest);
    is_elf = not sys.platform.startswith("win") and sys.platform != "darwin";
    if is_elf and clib_paths and "@atexit(" not in ir_str {
        ir_str += (
            "\n; --- atexit shim: glibc exports __cxa_atexit dynamically but "
            "keeps atexit\n; in libc_nonshared.a, so a floor-archive member "
            "that calls it would leave\n; the artifact with an unresolvable "
            "reference at dlopen ---\n"
            "declare i32 @__cxa_atexit(ptr, ptr, ptr)\n"
            "define hidden i32 @atexit(ptr %f) {\nentry:\n"
            "  %r = call i32 @__cxa_atexit(ptr %f, ptr null, ptr null)\n"
            "  ret i32 %r\n}\n"
        );
    }
    import platform;
    if is_elf and clib_paths and platform.machine() in ["aarch64", "arm64"] {
        ir_str += aarch64_outline_atomics_ir();
    }
    exports: list[str] = [];
    for _s in list(export_symbols) + extra_exports + ["__jac_shared_init"] {
        if _s and _s not in exports {
            exports.append(_s);
        }
    }
    init_funcs: list[str] = ["__jac_shared_init"] if auto_init else [];

    import jaclang.compiler.passes.native.llvm.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();

    llvm.initialize_native_asmparser();

    try {
        mod = llvm.parse_assembly(ir_str);
        mod.verify();
    } except Exception as e {
        return (False, f"LLVM IR verification failed: {e}");
    }

    target = llvm.Target.from_default_triple();
    triple = llvm.get_default_triple();
    target_machine = target.create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );

    if opt_level > 0 {
        pto = llvm.create_pipeline_tuning_options(speed_level=opt_level);
        pb = llvm.create_pass_builder(target_machine, pto);
        opt_mpm = pb.getModulePassManager();
        opt_mpm.run(mod, pb);
    }

    obj_bytes = target_machine.emit_object(mod);

    is_windows = sys.platform.startswith("win");
    is_macos = sys.platform == "darwin";
    soname = os.path.basename(output_path);
    try {
        if is_windows {
            import from jaclang.compiler.passes.native.pe_linker { PeLinker }
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
            import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
            import from jaclang.compiler.passes.native.linker_common {
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
            import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
            import from jaclang.compiler.passes.native.linker_common {
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
