import from jaclang.compiler.passes.native.linker_common {
    collect_floor_archives,
    floor_lib_dir,
    resolve_floor_dir,
    clib_to_archive_name
}
import os;
import sys;

import from jaclang.cli.console { console }


enum NativeLinkTarget { STANDALONE_EXE = 'standalone_exe', SHARED_LIB = 'shared_lib' }


obj NativeTargetPlan {
    has raw: str = "",
        is_wasm: bool = False,
        is_windows: bool = False,
        is_macos_target: bool = False,
        is_linux_target: bool = False,
        env_triple: str = "";

    def link_is_macos -> bool {
        """Mach-O linkage applies for an explicit macOS target or a darwin host.""";
        import sys;
        return self.is_macos_target
            or ((sys.platform == "darwin") and not self.is_windows);
    }
}


def _parse_native_target(target: str) -> NativeTargetPlan {
    """Single resolution point for target/platform flags.

    Both the ``nacompile`` prologue and ``_link_native_artifact`` consume
    this so platform predicates cannot drift apart.
    """;
    is_wasm = target in ["wasm", "wasm32", "wasm32-unknown-unknown"];
    is_windows = (sys.platform == "win32")
        or ("windows" in target)
        or (target in ["win", "win64", "mingw"]);
    is_macos_target = (target in ["macos", "darwin", "osx", "macosx"])
        or ("apple" in target)
        or ("darwin" in target);
    is_linux_target = (target in ["linux", "elf"])
        or ("linux-gnu" in target)
        or ("linux-musl" in target);

    env_triple = "";
    if is_wasm {
        env_triple = "wasm32-unknown-unknown";
    } elif is_windows {
        env_triple = target if "-" in target else "x86_64-pc-windows-msvc";
    } elif is_macos_target {
        env_triple = target if "-" in target else "arm64-apple-darwin";
    } elif is_linux_target {
        env_triple = target if "-" in target else "x86_64-unknown-linux-gnu";
    }
    return NativeTargetPlan(
        raw=target,
        is_wasm=is_wasm,
        is_windows=is_windows,
        is_macos_target=is_macos_target,
        is_linux_target=is_linux_target,
        env_triple=env_triple
    );
}


obj NativeLinkCtx {
    has ir_module: any,
        options: any,
        base_llvm_ir: str,
        auto_promote: bool,
        plan: NativeTargetPlan;
}


obj NativeCompilePrep {
    has gc: str,
        gc_cfg: any,
        prog: any;
}


def _prepare_native_compile(filename: str, gc: str = "") -> (NativeCompilePrep | None) {
    """Validate input, resolve GC config, print the banner, build a program.

    Common prologue for ``nacompile`` and ``nacompile_sealed_pair``.
    """;
    import from jaclang.jac0core.ext_registry { is_jac }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.project { get_config }

    if not is_jac(filename) {
        console.error("Input must be a .jac file.");
        return None;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return None;
    }
    _gc_cfg = None;
    _cfg = get_config();
    if _cfg {
        _gc_cfg = _cfg.gc;
    }
    if not gc {
        gc = _gc_cfg.`default if _gc_cfg else "cycles";
    }
    if gc not in ("cycles", "rc", "none") {
        console.error(f"Invalid --gc mode '{gc}' (expected: cycles, rc, none)");
        return None;
    }
    console.print(f"Compiling {filename} to native binary");
    return NativeCompilePrep(gc=gc, gc_cfg=_gc_cfg, prog=JacProgram());
}


def _native_import_names(ir_module: object) -> list {
    mf = ir_module.gen.interop_manifest;
    if mf {
        return list(mf.native_imports);
    }
    return [];
}


def _scan_rc_machinery(llvm_ir_str: str) -> tuple[list[str], list[str]] {
    import re;
    syms: set = set();
    for m in re.finditer(r"__rc_[A-Za-z0-9_]*", llvm_ir_str) {
        syms.add(m.group(0));
    }
    probes: list[str] = [];
    for probe in ["JAC_NO_GC", "JAC_GC_CYCLES"] {
        if probe in llvm_ir_str {
            probes.append(probe);
        }
    }
    return (sorted(syms), probes);
}


def _inject_entry_elf(llvm_ir_str: str, triple: str = "") -> str {
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
    ir = (
        '\n; --- injected entry point ---\n'
        + globals_ir
        + initarr_ir
        + exit_decl
        + lsm_decl
        + dso_def
        + atexit_def
        + 'declare ptr @llvm.stacksave()\n\n'
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
        + '}\n\n'
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
        + '}\n'
    );
    return llvm_ir_str + ir;
}


def _inject_entry_macho(llvm_ir_str: str) -> str {
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    ir = '\n; --- injected entry point ---\n'
        + globals_ir
        + 'define i32 @main(i32 %argc, ptr %argv) {\n'
        + 'entry:\n'
        + '    store i32 %argc, ptr @__jac_argc\n'
        + '    store ptr %argv, ptr @__jac_argv\n'
        + '    call void @jac_entry()\n'
        + '    ret i32 0\n'
        + '}\n';
    return llvm_ir_str + ir;
}


def _inject_entry_elf_static(llvm_ir_str: str) -> str {
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
        '\n; --- injected entry point (musl static) ---\n'
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
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    has_exit = "@exit" in llvm_ir_str or '@"exit"' in llvm_ir_str;
    exit_decl = "" if has_exit else 'declare void @exit(i32)\n\n';
    fltused = "" if "@_fltused" in llvm_ir_str else '@_fltused = global i32 0\n\n';
    ir = (
        '\n; --- injected PE entry ---\n'
        + globals_ir
        + exit_decl
        + fltused
        + 'declare i32 @__getmainargs(ptr, ptr, ptr, i32, ptr)\n\n'
        + 'define i32 @main(i32 %argc, ptr %argv) {\n'
        + 'entry:\n'
        + '    store i32 %argc, ptr @__jac_argc\n'
        + '    store ptr %argv, ptr @__jac_argv\n'
        + '    call void @jac_entry()\n'
        + '    ret i32 0\n'
        + '}\n\n'
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
        + '}\n'
    );
    return llvm_ir_str + ir;
}


def _compile_native_link_ctx(
    filename: str,
    prep: NativeCompilePrep,
    enforce_nogc: bool,
    auto_promote: bool,
    scrub: bool = False,
    target: NativeLinkTarget = NativeLinkTarget.STANDALONE_EXE,
    plan: NativeTargetPlan | None = None
) -> (NativeLinkCtx | None) {
    import from jaclang.jac0core.ext_registry { base_stem }
    import from jaclang.jac0core.compile_options { CompileOptions }

    gc = prep.gc;
    _gc_cfg = prep.gc_cfg;
    prog = prep.prog;

    try {
        options = CompileOptions(
            aot_mode=True,
            type_check=False,
            default_codespace=('native' if auto_promote else ''),
            force_target_program=True,
            na_gc_mode=gc,
            no_ir_cache=scrub,
            nogc_cli_target=(base_stem(filename) if enforce_nogc else ""),
            nogc_enforce_modules=(_gc_cfg.enforce.modules if _gc_cfg else []),
            nogc_grandfathered=(_gc_cfg.enforce.grandfathered if _gc_cfg else [])
        );
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return None;
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return None;
    }

    if ir_module is None or ir_module.gen.llvm_ir is None {
        if auto_promote
            and not (ir_module and ir_module.decided_codespace == 'native') {
            console.error(
                "This .jac file is not compatible with native compilation.\n"
                "  It may use walkers, nodes, edges, async, lambdas, or other\n"
                "  constructs not supported by the native backend.\n"
                "  Remove the incompatible constructs it names."
            );
        } else {
            console.error(
                f"Native compilation produced no LLVM IR for {filename} and no\n"
                "  diagnostic explains why; this is a compiler bug -- please report it."
            );
        }
        for _warn in prog.warnings_had {
            console.print(_warn.pretty_print());
        }
        return None;
    }

    if _native_import_names(ir_module) and target == NativeLinkTarget.STANDALONE_EXE {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for binding in ir_module.gen.interop_manifest.native_imports {
            console.error(f"  - {binding.name}");
        }
        return None;
    }

    return NativeLinkCtx(
        ir_module=ir_module,
        options=options,
        base_llvm_ir=str(ir_module.gen.llvm_ir),
        auto_promote=auto_promote,
        plan=plan if plan is not None else _parse_native_target("")
    );
}


def _link_native_artifact(
    ctx: NativeLinkCtx,
    output: str,
    shared: bool,
    entry_lib: bool,
    assert_no_rc: bool = False,
    strict: bool = False
) -> int {
    ir_module = ctx.ir_module;
    options = ctx.options;
    llvm_ir_str = ctx.base_llvm_ir;
    auto_promote = ctx.auto_promote;
    plan = ctx.plan;

    if strict {
        import from jaclang.compiler.passes.native.na_compile_pass {
            native_demoted_ir_symbols as _demoted_syms
        }
        _demoted = _demoted_syms(llvm_ir_str);
        if _demoted {
            console.error(
                f"{len(
                    _demoted
                )} function(s) in the native closure were demoted to Python-only: "
                    + ", ".join(_demoted),
                hint="A self-contained binary cannot run a demoted function. Rerun with JAC_NA_DEBUG=1 to see why each one failed to lower."
            );
            return 1;
        }
    }

    if auto_promote {
        console.print("  Auto-promoted to native compilation.");
    }

    if assert_no_rc {
        (_rc_syms, _rc_probes) = _scan_rc_machinery(llvm_ir_str);
        if _rc_syms or _rc_probes {
            _parts: list[str] = [];
            if _rc_syms {
                _parts.append("RC/collector symbols: " + ", ".join(_rc_syms));
            }
            if _rc_probes {
                _parts.append("entry-point env probes: " + ", ".join(_rc_probes));
            }
            console.error(
                "assert-no-rc: emitted IR contains "
                    + "; ".join(_parts)
                    + "\n  (module has managed heap types or RC-emitting code;"
                    + " see rc-stats coverage)"
            );
            return 1;
        }
        console.print(
            "  assert-no-rc ok: 0 __rc_* symbols · 0 trace fns"
            " · no roots buffer · no entry-point env probes"
        );
    }

    import jaclang.compiler.passes.native.llvm.binding as llvm;
    import jaclang.compiler.passes.native.shared_emit as _shared_emit;

    if not shared and not _shared_emit.jac_entry_defined(llvm_ir_str) {
        console.error(
            "No entry point found. " "The file must have a 'with entry { }' block."
        );
        return 1;
    }

    console.print("  LLVM IR generated successfully.");

    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();

    triple = (options.native_target or "") or llvm.get_default_triple();
    console.print(f"  Target: {triple}");

    export_symbols: list[str] = [];
    init_funcs: list[str] = [];

    is_windows = plan.is_windows;
    is_macos = plan.link_is_macos();

    clib_paths = ir_module.gen._clib_paths;
    (archive_members, _floor_handled) = collect_floor_archives(
        clib_paths or [], ir_module.gen._clib_symbol_lib, triple, is_macos
    );
    if archive_members {
        console.print(
            f"  Static-linking {len(archive_members)} floor archive member(s)."
        );
    }

    if is_windows {
        needed_libs: list[str] = ["msvcrt.dll"];
    } elif is_macos {
        needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"];
    } else {
        needed_libs: list[str] = [];
    }
    _lib_norm: dict[str, str] = {};
    if clib_paths {
        for lib_path in clib_paths {
            if lib_path in _floor_handled {
                continue;
            }
            _needed = lib_path;
            if (not os.path.isabs(lib_path))
                and (not lib_path.startswith("$"))
                and (not lib_path.startswith("@"))
                and ("/" in lib_path or "\\" in lib_path) {
                _needed = os.path.basename(lib_path);
            }
            _needed_base = os.path.basename(_needed);
            if _needed_base == "libc.so" {
                _needed = "libc.so.6";
            } elif _needed_base == "libm.so" {
                _needed = "libm.so.6";
            }
            if _needed not in needed_libs {
                needed_libs.append(_needed);
            }
            _lib_norm[lib_path] = _needed;
        }
    }

    _is_linux_exec = (not shared) and (not is_windows) and (not is_macos);
    _static_musl = _is_linux_exec and (len(needed_libs) == 0);

    if shared {
        _mf = ir_module.gen.interop_manifest;
        _sh_imports = [b.name for b in _mf.native_imports] if _mf else [];
        if _sh_imports {
            console.warning(
                f"Shared library keeps {len(_sh_imports)} Python "
                "interop symbol(s) unresolved ("
                    + ", ".join(_sh_imports)
                    + "); the loading host must resolve them."
            );
        }
        _had_entry = _shared_emit.jac_entry_defined(llvm_ir_str);
        (llvm_ir_str, _extra_exports) = _shared_emit.inject_shared_init(
            llvm_ir_str, _mf, emit_entry_stub=entry_lib
        );
        if entry_lib and not _had_entry {
            console.print(
                "  No 'with entry { }' block; synthesized an empty jac_entry"
                " for the entry-lib host protocol."
            );
        }
        init_funcs = [] if entry_lib else ["__jac_shared_init"];
        for _s in ir_module.gen._exported_symbols {
            if _s not in export_symbols {
                export_symbols.append(_s);
            }
        }
        for _s in _extra_exports {
            if _s not in export_symbols {
                export_symbols.append(_s);
            }
        }
        if entry_lib {
            if "@__jac_argc = global" not in llvm_ir_str {
                llvm_ir_str += (
                    "\n@__jac_argc = global i32 0\n" + "@__jac_argv = global ptr null\n"
                );
            }
            for _s in ["jac_entry", "__jac_argc", "__jac_argv", "__jac_shared_init"] {
                if _s not in export_symbols {
                    export_symbols.append(_s);
                }
            }
        }
        if not export_symbols {
            console.error(
                "Nothing to export from a shared library: no `:pub` functions "
                "or globals found. Mark exports with `def:pub` / `glob:pub`."
            );
            return 1;
        }
        console.print(
            f"  Exporting {len(export_symbols)} C-ABI symbol(s): "
                + ", ".join(export_symbols)
        );
    } elif is_windows {
        llvm_ir_str = _inject_entry_pe(llvm_ir_str);
    } elif is_macos {
        llvm_ir_str = _inject_entry_macho(llvm_ir_str);
    } elif _static_musl {
        llvm_ir_str = _inject_entry_elf_static(llvm_ir_str);
    } else {
        llvm_ir_str = _inject_entry_elf(llvm_ir_str, triple);
    }

    if (shared or (_is_linux_exec and not _static_musl))
        and not is_macos
        and not is_windows {
        if "libc.so.6" not in needed_libs {
            needed_libs.append("libc.so.6");
        }
        if "libm.so.6" not in needed_libs {
            needed_libs.append("libm.so.6");
        }
    }

    symbol_lib_map: dict[str, str] = {};
    for (_sym, _raw) in ir_module.gen._clib_symbol_lib.items() {
        if _raw in _floor_handled {
            continue;
        }
        symbol_lib_map[_sym] = _lib_norm.get(_raw, _raw);
    }

    try {
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
    } except Exception as e {
        console.error(f"LLVM IR verification failed: {e}");
        return 1;
    }

    _target_ovr = options.native_target or "";
    if _target_ovr {
        target = llvm.Target.from_triple(_target_ovr);
    } else {
        target = llvm.Target.from_default_triple();
    }

    if shared {
        target_machine = target.create_target_machine(
            opt=2, reloc="pic", codemodel="small"
        );
    } else {
        target_machine = target.create_target_machine(opt=2, codemodel="large");
    }

    _opt_level = int(options.opt_level or 0);
    _dump_path = options.dump_ir_path or "";

    if _opt_level > 0 {
        pto = llvm.create_pipeline_tuning_options(speed_level=_opt_level);
        pb = llvm.create_pass_builder(target_machine, pto);
        opt_mpm = pb.getModulePassManager();
        if not shared {
            opt_mpm.add_internalize_pass();
        }
        opt_mpm.run(mod, pb);
    }

    if _dump_path {
        with open(_dump_path, "w") as _df {
            _df.write(str(mod));
        }
    }

    obj_bytes = target_machine.emit_object(mod);
    console.print(f"  Object code emitted ({len(obj_bytes)} bytes).");

    if is_windows {
        import from jaclang.compiler.passes.native.pe_linker { PeLinker }

        try {
            success = PeLinker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                symbol_lib_map=symbol_lib_map,
                shared=shared,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output)
            );
        } except Exception as e {
            console.error(f"PE linking failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }

        if not success {
            console.error("PE linking failed: could not parse object file.");
            return 1;
        }
    } elif is_macos {
        import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
        try {
            success = MachOLinker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                symbol_lib_map=symbol_lib_map,
                shared=shared,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output),
                archive_members=archive_members
            );
        } except Exception as e {
            console.error(f"Mach-O linking failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
        if not success {
            console.error("Mach-O linking failed: could not parse object file.");
            return 1;
        }
    } else {
        import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
        _crt_objects: list[bytes] = [];
        if _static_musl {
            _musl = _collect_musl_static(obj_bytes, triple);
            if _musl is None {
                console.error(
                    "Static musl runtime not found. Expected a vendored musl "
                    "libc.a under .pbs-build/<arch>/musl/lib (run `zig build "
                    "vendor-musl`) or set JAC_NATIVE_MUSL_DIR."
                );
                return 1;
            }
            (_musl_members, _crt_objects) = _musl;
            archive_members = archive_members + _musl_members;
            console.print(
                f"  Static-linking musl: {len(_musl_members)} libc member(s) + "
                f"{len(_crt_objects)} crt object(s)."
            );
        }
        try {
            success = ElfLinker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                crt_objects=_crt_objects,
                shared=shared,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output),
                archive_members=archive_members,
                static_link=_static_musl
            );
        } except Exception as e {
            console.error(f"ELF linking failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
        if not success {
            console.error("ELF linking failed: could not parse object file.");
            return 1;
        }
    }

    file_size = os.path.getsize(output);
    if shared {
        console.print(f"  Shared library written to {output} ({file_size} bytes).");
        console.print(
            "  Load it from C/ctypes (dlopen + dlsym); the C ABI surface is the "
            "exported `:pub` symbols plus jac_retain/jac_release."
        );
    } else {
        console.print(f"  Binary written to {output} ({file_size} bytes).");
        console.print(f"  Run with: ./{output}");
    }
    return 0;
}


impl nacompile_sealed_pair(filename: str, exe_output: str, lib_output: str) -> int {
    import json;
    import from jaclang.runtimelib.sealed_serve { interop_record_path }

    prep = _prepare_native_compile(filename);
    if prep is None {
        return 1;
    }

    ctx = _compile_native_link_ctx(
        filename=filename,
        prep=prep,
        enforce_nogc=False,
        auto_promote=True,
        target=NativeLinkTarget.SHARED_LIB
    );
    if ctx is None {
        return 1;
    }

    _pair_imports = _native_import_names(ctx.ir_module);
    _interop_record = interop_record_path(lib_output);
    if _pair_imports {
        console.warning(
            "App calls from native code into Python (native_imports): "
            "dropping the standalone executable (it cannot be "
            "self-contained) and sealing the host-driven native library only."
        );
        _interop_record.parent.mkdir(parents=True, exist_ok=True);
        _interop_record.write_text(
            json.dumps(
                {"interop": True, "unresolved": [b.name for b in _pair_imports]},
                sort_keys=True
            )
                + "\n",
            encoding="utf-8"
        );
    } else {
        if _interop_record.exists() {
            _interop_record.unlink();
        }
        rc = _link_native_artifact(ctx, exe_output, shared=False, entry_lib=False);
        if rc != 0 {
            console.error("Native compilation failed; seal aborted.");
            return rc;
        }
    }

    console.print("  Compiling in-process native library", style="muted");
    lib_rc = _link_native_artifact(ctx, lib_output, shared=True, entry_lib=True);
    if lib_rc != 0 {
        console.warning(
            "In-process native library compilation failed; the sealed bundle "
            "will run via the standalone binary only."
        );
    }
    return 0;
}


impl nacompile(  # jac:ignore[W3030]
    filename: str,
    output: str = "",
    scrub: bool = False,
    target: str = "",
    shared: bool = False,
    entry_lib: bool = False,
    debug: bool = False,
    gc: str = "",
    assert_no_rc: bool = False,
    enforce_nogc: bool = False,
    strict: bool = False
) -> int {
    import from jaclang.jac0core.ext_registry {
        is_jac,
        is_retired_native_marker,
        base_stem
    }

    if entry_lib {
        shared = True;
    }

    _prev_native_debug = os.environ.get("JAC_NATIVE_DEBUG") if debug else None;
    if debug {
        os.environ["JAC_NATIVE_DEBUG"] = "1";
        scrub = True;
    }

    prep = _prepare_native_compile(filename, gc);
    if prep is None {
        return 1;
    }

    plan = _parse_native_target(target);
    import from jaclang.jac0core.compile_options {
        push_native_target_env,
        pop_native_target_env
    }
    _prev_target_env = (
        push_native_target_env(plan.env_triple) if plan.env_triple else None
    );
    is_wasm = plan.is_wasm;
    is_windows = plan.is_windows;

    if scrub {
        import from jaclang.jac0core.jir { scrub_cache_dirs }
        src_root = os.path.dirname(os.path.abspath(filename)) or ".";
        _scrubbed = scrub_cache_dirs(src_root);
        if _scrubbed {
            console.print(f"  Scrubbed {_scrubbed} cache dir(s).");
        }
    }

    if is_retired_native_marker(filename) {
        console.error(
            f"{filename}: the .na.jac marker was retired in 0.35 -- rename the "
            "file to .jac; 'jac nacompile' compiles plain .jac natively."
        );
        return 1;
    }
    auto_promote = is_jac(filename);

    if not output {
        output = base_stem(filename);
        if shared {
            import from jaclang.runtimelib.sealed_serve { native_lib_suffix }
            output = "lib" + output + native_lib_suffix();
        } elif is_wasm {
            output = output + ".wasm";
        } elif is_windows {
            output = output + ".exe";
        }
    }

    try {
        ctx = _compile_native_link_ctx(
            filename=filename,
            prep=prep,
            enforce_nogc=enforce_nogc,
            auto_promote=auto_promote,
            scrub=scrub,
            target=(
                NativeLinkTarget.SHARED_LIB
                    if shared
                    else NativeLinkTarget.STANDALONE_EXE
            ),
            plan=plan
        );
    } finally {
        if plan.env_triple {
            pop_native_target_env(_prev_target_env);
        }
        if debug {
            if _prev_native_debug is None {
                os.environ.pop("JAC_NATIVE_DEBUG", None);
            } else {
                os.environ["JAC_NATIVE_DEBUG"] = _prev_native_debug;
            }
        }
    }
    if ctx is None {
        return 1;
    }

    ir_module = ctx.ir_module;
    if is_wasm {
        import from jaclang.compiler.passes.native.wasm_build {
            emit_wasm_from_ir,
            app_declared_imports
        }
        try {
            wasm_bytes = emit_wasm_from_ir(
                str(ir_module.gen.llvm_ir), app_imports=app_declared_imports(ir_module),
            );
        } except Exception as e {
            console.error(f"Wasm emit/link failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
        with open(output, "wb") as _wf {
            _wf.write(wasm_bytes);
        }
        console.print(f"  Wasm module written to {output} ({len(wasm_bytes)} bytes).");
        console.print(
            "  Instantiate with the `jac_host1` host object (see @jac/wasm_host)"
            " plus an `env` object for any FFI the app declares."
        );
        return 0;
    }

    return _link_native_artifact(
        ctx,
        output,
        shared=shared,
        entry_lib=entry_lib,
        assert_no_rc=assert_no_rc,
        strict=strict
    );
}


def _resolve_ca_bundle(pkg_root: str) -> (str | None) {
    import os;

    cand = os.path.join(os.path.dirname(pkg_root), "python", "floor", "cacert.pem");
    if os.path.isfile(cand) {
        return cand;
    }

    import glob;
    hits = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root,
                ".pbs-build",
                "*",
                "python",
                "install",
                "lib",
                "python*",
                "site-packages",
                "pip",
                "_vendor",
                "certifi",
                "cacert.pem"
            )
        )
    );
    return hits[0] if hits else None;
}


def _floor_ca_bundle -> (str | None) {
    import os;
    env = os.environ.get("JAC_NATIVE_CA_BUNDLE", "");
    if env and os.path.isfile(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    return _resolve_ca_bundle(pkg_root);
}


def _musl_lib_dir(triple: str) -> (str | None) {
    import os;
    import from jaclang.runtimelib.utils { triple_arch }
    env = os.environ.get("JAC_NATIVE_MUSL_DIR", "");
    if env and os.path.isdir(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    want = triple_arch(triple);
    pbs = os.path.join(pkg_root, ".pbs-build");
    if os.path.isdir(pbs) {
        for d in sorted(os.listdir(pbs)) {
            libdir = os.path.join(pbs, d, "musl", "lib");
            if os.path.isdir(libdir)
                and os.path.isfile(os.path.join(libdir, "libc.a"))
                and (want in d) {
                return libdir;
            }
        }
    }

    import from jaclang.runtimelib.fused_binary { bundled_floor_roots }
    for floor in bundled_floor_roots(pkg_root) {
        if not os.path.isdir(floor) {
            continue;
        }
        for d in sorted(os.listdir(floor)) {
            cand = os.path.join(floor, d, "musl");
            if os.path.isdir(cand)
                and os.path.isfile(os.path.join(cand, "libc.a"))
                and (want in d) {
                return cand;
            }
        }
    }
    return None;
}


def _collect_musl_static(obj_bytes: bytes, triple: str) -> (tuple | None) {
    import os;
    import from jaclang.compiler.passes.native.linker_common {
        select_ar_members,
        _ar_member_undefs
    }
    lib_dir = _musl_lib_dir(triple);
    if lib_dir is None {
        return None;
    }
    libc_a = os.path.join(lib_dir, "libc.a");
    if not os.path.isfile(libc_a) {
        return None;
    }

    crt_objects: list[bytes] = [];
    _have_crt1 = False;
    for crt_name in ["crt1.o", "crti.o", "crtn.o"] {
        p = os.path.join(lib_dir, crt_name);
        if os.path.isfile(p) {
            with open(p, "rb") as _cf {
                crt_objects.append(_cf.read());
            }
            if crt_name == "crt1.o" {
                _have_crt1 = True;
            }
        }
    }
    if not _have_crt1 {
        return None;
    }

    archives_data: list[bytes] = [];
    for af in ["libc.a", "libzigc.a", "libcompiler_rt.a"] {
        p = os.path.join(lib_dir, af);
        if os.path.isfile(p) {
            with open(p, "rb") as _af {
                archives_data.append(_af.read());
            }
        }
    }

    work_roots: list[str] = [];
    known: set[str] = set();
    for blob in [obj_bytes] + crt_objects {
        for u in _ar_member_undefs(blob) {
            if u not in known {
                known.add(u);
                work_roots.append(u);
            }
        }
    }

    import hashlib;
    member_bytes: list[bytes] = [];
    seen_members: set[bytes] = set();
    changed = True;
    while changed {
        changed = False;
        for data in archives_data {
            for m in select_ar_members(data, work_roots) {
                key = hashlib.sha256(m.data).digest();
                if key in seen_members {
                    continue;
                }
                seen_members.add(key);
                member_bytes.append(m.data);
                changed = True;
                for u in _ar_member_undefs(m.data) {
                    if u not in known {
                        known.add(u);
                        work_roots.append(u);
                    }
                }
            }
        }
    }

    return (member_bytes, crt_objects);
}
