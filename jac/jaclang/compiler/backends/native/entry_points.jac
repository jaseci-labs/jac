import type from jaclang.compiler.frontend.unitree { Module }

def validate_native_application(module: Module, shared: bool, memory: str) -> str {
    import from jaclang.compiler.backends.native.na_compile_pass {
        native_linked_ir_text,
        native_demoted_ir_symbols
    }
    import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
    manifest = module.gen.interop_manifest;
    if not shared and manifest.native_imports {
        names = ', '.join(binding.name for binding in manifest.native_imports);
        raise ValueError(
            'Cannot compile to a standalone binary: Python/server dependencies: '
                + names
        );
    }
    llvm_ir = native_linked_ir_text(module);
    demoted = sorted(
        set(native_demoted_ir_symbols(llvm_ir))
            | {issue.symbol for issue in native_lowering_issues(llvm_ir)}
    );
    if demoted and not shared {
        raise ValueError(
            'Declarations in the native closure could not lower: ' + ', '.join(demoted)
        );
    }
    if memory == 'nogc' {
        (symbols, probes) = _scan_rc_machinery(llvm_ir);
        if symbols or probes {
            raise ValueError(
                'nogc invariant violated: emitted managed runtime machinery: '
                    + ', '.join(symbols + probes)
            );
        }
    }
    if not shared and 'jac_entry' not in llvm_ir {
        raise ValueError(
            "No entry point found. The file must have a 'with entry { }' block."
        );
    }
    return llvm_ir;
}

def _scan_rc_machinery(llvm_ir_str: str) -> tuple[list[str], list[str]] {
    import re;
    syms: set = set();
    for m in re.finditer(r"__rc_[A-Za-z0-9_]*", llvm_ir_str) {
        syms.add(m.group(0));
    }
    probes: list[str] = [];
    for probe in ["JAC_GC"] {
        if probe in llvm_ir_str {
            probes.append(probe);
        }
    }
    return (sorted(syms), probes);
}


def _inject_entry_elf(llvm_ir_str: str) -> str {
    has_exit = "@exit" in llvm_ir_str or '@"exit"' in llvm_ir_str;
    exit_decl = "" if has_exit else 'declare void @exit(i32) noreturn\n\n';

    lsm_decl = ""
        if "@__libc_start_main" in llvm_ir_str
        else 'declare i32 @__libc_start_main(ptr, i32, ptr, ptr, ptr, ptr, ptr)\n\n';

    dso_def = ""
        if "@__dso_handle" in llvm_ir_str
        else '@__dso_handle = global i8 0\n\n';
    atexit_def = ""
        if ("@atexit(" in llvm_ir_str or '@"atexit"' in llvm_ir_str)
        else (
            'declare i32 @__cxa_atexit(ptr, ptr, ptr)\n'
            + 'define i32 @atexit(ptr %atx_fn) {\nentry:\n'
            + '    %atx_r = call i32 @__cxa_atexit(ptr %atx_fn, ptr null, ptr @__dso_handle)\n'
            + '    ret i32 %atx_r\n}\n\n'
        );
    return inject_main(llvm_ir_str)
        + exit_decl
        + lsm_decl
        + dso_def
        + atexit_def
        + 'declare ptr @llvm.stacksave()\n\n'
        + 'define void @_start() naked noreturn {\n'
        + 'entry:\n'
        + '    %sp = call ptr @llvm.stacksave()\n'
        + '    %argc = load i32, ptr %sp\n'
        + '    %argv = getelementptr i8, ptr %sp, i64 8\n'
        + '    call void @_jac_boot(i32 %argc, ptr %argv, ptr %sp)\n'
        + '    unreachable\n'
        + '}\n\n'
        + 'define internal void @_jac_boot(i32 %bargc, ptr %bargv, ptr %bstack) noreturn {\n'
        + 'entry:\n'
        + '    %r = call i32 @__libc_start_main(ptr @main, i32 %bargc, ptr %bargv, ptr null, ptr null, ptr null, ptr %bstack)\n'
        + '    unreachable\n'
        + '}\n';
}

def inject_main(llvm_ir_str: str) -> str {
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    initarr_ir = ""
        if "__jac_init_array" in llvm_ir_str
        else (
            '@__jac_init_array = global ptr null\n'
            + '@__jac_init_count = global i64 0\n\n'
        );
    ir = (
        '\n; --- native application entry point ---\n'
        + globals_ir
        + initarr_ir
        + 'define i32 @main(i32 %argc, ptr %argv) {\n'
        + 'entry:\n'
        + '    store i32 %argc, ptr @__jac_argc\n'
        + '    store ptr %argv, ptr @__jac_argv\n'
        + '    %ia = load ptr, ptr @__jac_init_array\n'
        + '    %ic = load i64, ptr @__jac_init_count\n'
        + '    br label %ia.cond\n'
        + 'ia.cond:\n'
        + '    %i = phi i64 [ 0, %entry ], [ %inext, %ia.body ]\n'
        + '    %more = icmp ult i64 %i, %ic\n'
        + '    br i1 %more, label %ia.body, label %ia.done\n'
        + 'ia.body:\n'
        + '    %slot = getelementptr ptr, ptr %ia, i64 %i\n'
        + '    %fn = load ptr, ptr %slot\n'
        + '    call void %fn()\n'
        + '    %inext = add i64 %i, 1\n'
        + '    br label %ia.cond\n'
        + 'ia.done:\n'
        + '    call void @jac_entry()\n'
        + '    ret i32 0\n'
        + '}\n'
    );
    return llvm_ir_str + ir;
}


def _inject_entry_pe(llvm_ir_str: str) -> str {
    has_exit = "@exit" in llvm_ir_str or '@"exit"' in llvm_ir_str;
    exit_decl = "" if has_exit else 'declare void @exit(i32)\n\n';
    fltused = "" if "@_fltused" in llvm_ir_str else '@_fltused = global i32 0\n\n';
    return inject_main(llvm_ir_str)
        + exit_decl
        + fltused
        + 'declare i32 @__getmainargs(ptr, ptr, ptr, i32, ptr)\n\n'
        + 'define void @_jac_win_start() {\n'
        + 'entry:\n'
        + '    %argc.addr = alloca i32\n'
        + '    %argv.addr = alloca ptr\n'
        + '    %env.addr = alloca ptr\n'
        + '    %si = alloca i32\n'
        + '    store i32 0, ptr %si\n'
        + '    %gr = call i32 @__getmainargs(ptr %argc.addr, ptr %argv.addr, ptr %env.addr, i32 0, ptr %si)\n'
        + '    %ac = load i32, ptr %argc.addr\n'
        + '    %av = load ptr, ptr %argv.addr\n'
        + '    %r = call i32 @main(i32 %ac, ptr %av)\n'
        + '    call void @exit(i32 %r)\n'
        + '    ret void\n'
        + '}\n';
}

def finalize_native_ir(
    llvm_ir_str: str,
    triple: str,
    clib_paths: list[str],
    manifest: any,
    shared: bool,
    is_windows: bool,
    is_macos: bool,
    static_musl: bool,
    emit_entry_stub: bool = False
) -> tuple[str, list[str]] {
    import from jaclang.compiler.backends.native.shared_emit {
        aarch64_floor_atomics_ir,
        inject_shared_init
    }
    extra_exports: list[str] = [];
    if shared {
        (llvm_ir_str, extra_exports) = inject_shared_init(
            llvm_ir_str, manifest, emit_entry_stub=emit_entry_stub
        );
    } elif is_windows {
        llvm_ir_str = _inject_entry_pe(llvm_ir_str);
    } elif is_macos {
        llvm_ir_str = inject_main(llvm_ir_str);
    } elif static_musl {
        llvm_ir_str = inject_main(llvm_ir_str);
    } else {
        llvm_ir_str = _inject_entry_elf(llvm_ir_str);
    }
    return (llvm_ir_str + aarch64_floor_atomics_ir(triple, clib_paths), extra_exports);
}
