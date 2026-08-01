def inject_shared_init(
    llvm_ir_str: str, transitive_sources: list[str]
) -> tuple[str, list[str]] {
    init_calls: list[str] = [];

    if ('@"__jac_glob_init"' in llvm_ir_str) or ("@__jac_glob_init(" in llvm_ir_str) {
        init_calls.append("  call void @__jac_glob_init()");
    }
    import from jaclang.jac0core.codeinfo { native_safe_sym }
    _seen: set = set();
    for _src in transitive_sources {
        if _src is None or _src in _seen {
            continue;
        }
        _seen.add(_src);

        _safe = native_safe_sym(_src);
        _nm = f"__jac_glob_init_{_safe}";
        if (f'@"{_nm}"' in llvm_ir_str) or (f"@{_nm}(" in llvm_ir_str) {
            init_calls.append(f"  call void @{_nm}()");
        }
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

def emit_shared_library(
    llvm_ir_str: str,
    transitive_sources: list[str],
    export_symbols: list[str],
    output_path: str,
    opt_level: int = 2,
    auto_init: bool = False
) -> tuple[bool, str] {
    import os;
    import sys;

    (ir_str, extra_exports) = inject_shared_init(llvm_ir_str, transitive_sources);
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

    try {
        mod = llvm.parse_assembly(ir_str);
        mod.verify();
    } except Exception as e {
        return (False, f"LLVM IR verification failed: {e}");
    }

    target = llvm.Target.from_default_triple();
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
            ok = MachOLinker.link(
                obj_bytes=obj_bytes,
                output_path=output_path,
                needed_libs=["/usr/lib/libSystem.B.dylib"],
                symbol_lib_map={},
                shared=True,
                export_symbols=exports,
                init_funcs=init_funcs,
                soname=soname,
                archive_members=[]
            );
        } else {
            import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
            ok = ElfLinker.link(
                obj_bytes=obj_bytes,
                output_path=output_path,
                needed_libs=["libc.so.6", "libm.so.6"],
                crt_objects=[],
                shared=True,
                export_symbols=exports,
                init_funcs=init_funcs,
                soname=soname,
                archive_members=[],
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
