import os;
import sys;

import from jaclang.cli.console { console }


def _inject_entry_elf(llvm_ir_str: str, triple: str = "") -> str {
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');

    initarr_ir = ""
        if "__jac_init_array" in llvm_ir_str
        else (
            '@__jac_init_array = global ptr null\n' + '@__jac_init_count = global i64 0\n\n'
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
            'declare i32 @__cxa_atexit(ptr, ptr, ptr)\n' + 'define i32 @atexit(ptr %atx_fn) {\nentry:\n' + '    %atx_r = call i32 @__cxa_atexit(ptr %atx_fn, ptr null, ptr @__dso_handle)\n' + '    ret i32 %atx_r\n}\n\n'
        );
    ir = (
        '\n; --- injected entry point ---\n' + globals_ir + initarr_ir + exit_decl + lsm_decl + dso_def + atexit_def + 'declare ptr @llvm.stacksave()\n\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    %ia = load ptr, ptr @__jac_init_array\n' + '    %ic = load i64, ptr @__jac_init_count\n' + '    br label %ia.cond\n' + 'ia.cond:\n' + '    %i = phi i64 [ 0, %entry ], [ %inext, %ia.body ]\n' + '    %more = icmp ult i64 %i, %ic\n' + '    br i1 %more, label %ia.body, label %ia.done\n' + 'ia.body:\n' + '    %slot = getelementptr ptr, ptr %ia, i64 %i\n' + '    %fn = load ptr, ptr %slot\n' + '    call void %fn()\n' + '    %inext = add i64 %i, 1\n' + '    br label %ia.cond\n' + 'ia.done:\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n\n' + 'define void @_start() naked noreturn {\n' + 'entry:\n' + '    %sp = call ptr @llvm.stacksave()\n' + '    %argc = load i32, ptr %sp\n' + '    %argv = getelementptr i8, ptr %sp, i64 8\n' + '    call void @_jac_boot(i32 %argc, ptr %argv, ptr %sp)\n' + '    unreachable\n' + '}\n\n' + 'define internal void @_jac_boot(i32 %bargc, ptr %bargv, ptr %bstack) noreturn {\n' + 'entry:\n' + '    %r = call i32 @__libc_start_main(ptr @main, i32 %bargc, ptr %bargv, ptr null, ptr null, ptr null, ptr %bstack)\n' + '    unreachable\n' + '}\n'
    );
    return llvm_ir_str + ir;
}


def _inject_entry_macho(llvm_ir_str: str) -> str {
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    ir = '\n; --- injected entry point ---\n' + globals_ir + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n';
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
            '@__jac_init_array = global ptr null\n' + '@__jac_init_count = global i64 0\n\n'
        );
    ir = (
        '\n; --- injected entry point (musl static) ---\n' + globals_ir + initarr_ir + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    %ia = load ptr, ptr @__jac_init_array\n' + '    %ic = load i64, ptr @__jac_init_count\n' + '    br label %ia.cond\n' + 'ia.cond:\n' + '    %i = phi i64 [ 0, %entry ], [ %inext, %ia.body ]\n' + '    %more = icmp ult i64 %i, %ic\n' + '    br i1 %more, label %ia.body, label %ia.done\n' + 'ia.body:\n' + '    %slot = getelementptr ptr, ptr %ia, i64 %i\n' + '    %fn = load ptr, ptr %slot\n' + '    call void %fn()\n' + '    %inext = add i64 %i, 1\n' + '    br label %ia.cond\n' + 'ia.done:\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n'
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
        '\n; --- injected PE entry ---\n' + globals_ir + exit_decl + fltused + 'declare i32 @__getmainargs(ptr, ptr, ptr, i32, ptr)\n\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n\n' + 'define void @_jac_win_start() {\n' + 'entry:\n' + '    %argc.addr = alloca i32\n' + '    %argv.addr = alloca ptr\n' + '    %env.addr = alloca ptr\n' + '    %si = alloca i32\n' + '    store i32 0, ptr %si\n' + '    %gr = call i32 @__getmainargs(ptr %argc.addr, ptr %argv.addr, ptr %env.addr, i32 0, ptr %si)\n' + '    %ac = load i32, ptr %argc.addr\n' + '    %av = load ptr, ptr %argv.addr\n' + '    %r = call i32 @main(i32 %ac, ptr %av)\n' + '    call void @exit(i32 %r)\n' + '    ret void\n' + '}\n'
    );
    return llvm_ir_str + ir;
}


def _inject_shared_init(
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

    if "__rc_retain" in llvm_ir_str {
        parts.append(
            "define void @jac_retain(ptr %p) {\nentry:\n"
            "  call void @__rc_retain(ptr %p)\n  ret void\n}"
        );
        extra_exports.append("jac_retain");
    }
    if "__rc_release_simple" in llvm_ir_str {
        parts.append(
            "define void @jac_release(ptr %p) {\nentry:\n"
            "  call void @__rc_release_simple(ptr %p)\n  ret void\n}"
        );
        extra_exports.append("jac_release");
    }
    return (llvm_ir_str + "\n".join(parts) + "\n", extra_exports);
}


impl nacompile(
    filename: str,
    output: str = "",
    scrub: bool = False,
    target: str = "",
    shared: bool = False,
    debug: bool = False
) -> int {
    import from jaclang.jac0core.ext_registry { is_jac, is_native_module, base_stem }

    if not is_jac(filename) {
        console.error("Input must be a .jac or .na.jac file.");
        return 1;
    }

    _prev_native_debug = os.environ.get("JAC_NATIVE_DEBUG") if debug else None;
    if debug {
        os.environ["JAC_NATIVE_DEBUG"] = "1";
        scrub = True;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }

    is_wasm = target in ["wasm", "wasm32", "wasm32-unknown-unknown"];
    if is_wasm {
        os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    }

    is_windows = (sys.platform == "win32")
    or ("windows" in target)
    or (target in ["win", "win64", "mingw"]);
    if is_windows {
        os.environ["JAC_NATIVE_TARGET"] = (
            target if "-" in target else "x86_64-pc-windows-msvc"
        );
    }

    is_macos_target = (target in ["macos", "darwin", "osx", "macosx"])
    or ("apple" in target)
    or ("darwin" in target);
    if is_macos_target {
        os.environ["JAC_NATIVE_TARGET"] = (
            target if "-" in target else "arm64-apple-darwin"
        );
    }

    is_linux_target = (target in ["linux", "elf"])
    or ("linux-gnu" in target)
    or ("linux-musl" in target);
    if is_linux_target {
        os.environ["JAC_NATIVE_TARGET"] = (
            target if "-" in target else "x86_64-unknown-linux-gnu"
        );
    }

    if scrub {
        import from jaclang.jac0core.jir { scrub_cache_dirs }
        src_root = os.path.dirname(os.path.abspath(filename)) or ".";
        _scrubbed = scrub_cache_dirs(src_root);
        if _scrubbed {
            console.print(f"  Scrubbed {_scrubbed} cache dir(s).");
        }
    }

    auto_promote = is_jac(filename) and not is_native_module(filename);

    is_macos = ((sys.platform == "darwin") and not is_windows and not is_linux_target)
    or is_macos_target;

    if not output {
        output = base_stem(filename);
        if shared {
            _so_ext = ".dll" if is_windows else (".dylib" if is_macos else ".so");
            output = "lib" + output + _so_ext;
        } elif is_wasm {
            output = output + ".wasm";
        } elif is_windows {
            output = output + ".exe";
        }
    }

    console.print(f"Compiling {filename} to native binary...");

    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }

    try {
        prog = JacProgram();
        if auto_promote {
            prog._auto_promote_native = True;
            prog._auto_promote_target = os.path.abspath(filename);
        }

        options = CompileOptions(aot_mode=True, type_check=False);
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    } finally {
        if debug {
            if _prev_native_debug is None {
                os.environ.pop("JAC_NATIVE_DEBUG", None);
            } else {
                os.environ["JAC_NATIVE_DEBUG"] = _prev_native_debug;
            }
        }
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return 1;
    }

    if ir_module is None or ir_module.gen.llvm_ir is None {
        if auto_promote and not (ir_module and ir_module.gen.native_compat) {
            console.error(
                "This .jac file is not compatible with native compilation.\n"
                "  It may use walkers, nodes, edges, async, lambdas, or other\n"
                "  constructs not supported by the native backend.\n"
                "  Use a .na.jac file or remove incompatible constructs."
            );
        } else {
            console.error("Native compilation produced no LLVM IR.");
        }
        if prog.errors_had {
            for err in prog.errors_had {
                console.error(err.pretty_print());
            }
        }
        return 1;
    }

    if auto_promote {
        console.print("  Auto-promoted to native compilation.");
    }

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

    manifest = ir_module.gen.interop_manifest;
    if manifest and manifest.native_imports {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for binding in manifest.native_imports {
            console.error(f"  - {binding.name}");
        }
        return 1;
    }

    llvm_ir_str = str(ir_module.gen.llvm_ir);

    if not shared and "jac_entry" not in llvm_ir_str {
        console.error(
            "No entry point found. "
            "The .na.jac file must have a 'with entry { }' block."
        );
        return 1;
    }

    console.print("  LLVM IR generated successfully.");

    import jaclang.compiler.passes.native.llvm.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();

    triple = os.environ.get("JAC_NATIVE_TARGET", "") or llvm.get_default_triple();
    console.print(f"  Target: {triple}");

    export_symbols: list[str] = [];
    init_funcs: list[str] = [];

    clib_paths = ir_module.gen._clib_paths;
    (archive_members, _floor_handled) = _collect_floor_archives(
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
            if _needed not in needed_libs {
                needed_libs.append(_needed);
            }
            _lib_norm[lib_path] = _needed;
        }
    }

    _is_linux_exec = (not shared) and (not is_windows) and (not is_macos);
    _static_musl = _is_linux_exec and (len(needed_libs) == 0);

    if shared {
        _transitive: list[str] = [];
        _mf = ir_module.gen.interop_manifest;
        if _mf {
            _transitive = _mf.native_transitive_sources;
        }
        (llvm_ir_str, _extra_exports) = _inject_shared_init(llvm_ir_str, _transitive);
        init_funcs = ["__jac_shared_init"];
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
        if not export_symbols {
            console.error(
                "Nothing to export from a shared library: no `:pub` functions "
                "or globals found. Mark exports with `def:pub` / `glob:pub`."
            );
            return 1;
        }
        console.print(
            f"  Exporting {len(export_symbols)} C-ABI symbol(s): " + ", ".join(
                export_symbols
            )
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

    _target_ovr = os.environ.get("JAC_NATIVE_TARGET", "");
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

    import from jaclang.project { get_config, NativeBuildConfig }
    _native_cfg = NativeBuildConfig();
    _jac_config = get_config();
    if _jac_config {
        _native_cfg = _jac_config.build.native;
    }
    _opt_level = int(os.environ.get("JAC_OPT_LEVEL", str(_native_cfg.opt_level)));
    _dump_path = os.environ.get("JAC_DUMP_IR", _native_cfg.dump_ir);

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


def _resolve_floor_dir(pkg_root: str, triple: str) -> (str | None) {
    import os;
    want = "aarch64" if ("aarch64" in triple or "arm64" in triple) else "x86_64";

    pbs = os.path.join(pkg_root, ".pbs-build");
    if os.path.isdir(pbs) {
        fallback: (str | None) = None;
        for d in sorted(os.listdir(pbs)) {
            libdir = os.path.join(pbs, d, "python", "build", "lib");
            if os.path.isdir(libdir) {
                if fallback is None {
                    fallback = libdir;
                }
                if want in d {
                    return libdir;
                }
            }
        }
        if fallback is not None {
            return fallback;
        }
    }

    floor = os.path.join(os.path.dirname(pkg_root), "python", "floor");
    if os.path.isdir(floor) {
        for d in sorted(os.listdir(floor)) {
            cand = os.path.join(floor, d);
            if os.path.isdir(cand) and (want in d) {
                return cand;
            }
        }
    }
    return None;
}


def _floor_lib_dir(triple: str) -> (str | None) {
    import os;
    env = os.environ.get("JAC_NATIVE_FLOOR_DIR", "");
    if env and os.path.isdir(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    return _resolve_floor_dir(pkg_root, triple);
}


def _resolve_ca_bundle(pkg_root: str) -> (str | None) {
    import os;

    cand = os.path.join(os.path.dirname(pkg_root), "python", "floor", "cacert.pem");
    if os.path.isfile(cand) {
        return cand;
    }

    import glob;
    hits = sorted(
        glob.glob(
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


def _clib_to_archive_name(clib_path: str) -> str {
    import os;
    return os.path.basename(clib_path).split(".")[0] + ".a";
}


def _collect_floor_archives(
    clib_paths: list, clib_symbol_lib: dict, triple: str, is_macos: bool
) -> tuple {
    import os;
    import from jaclang.compiler.passes.native.linker_common { select_ar_members }
    member_bytes: list = [];
    handled: set = set();

    tl = triple.lower();
    is_pe = ("windows" in tl) or ("win32" in tl) or ("msvc" in tl) or ("mingw" in tl);
    if is_pe or not clib_paths {
        return (member_bytes, handled);
    }
    lib_dir = _floor_lib_dir(triple);
    if lib_dir is None {
        return (member_bytes, handled);
    }

    syms_by_lib: dict = {};
    for (sym, raw) in clib_symbol_lib.items() {
        syms_by_lib.setdefault(raw, []).append(sym);
    }

    roots_by_archive: dict = {};
    paths_by_archive: dict = {};
    for clib_path in clib_paths {
        arch_file = os.path.join(lib_dir, _clib_to_archive_name(clib_path));
        if not os.path.isfile(arch_file) {
            continue;
        }
        paths_by_archive.setdefault(arch_file, []).append(clib_path);
        for s in syms_by_lib.get(clib_path, []) {
            roots_by_archive.setdefault(arch_file, []).append(
                ("_" + s) if is_macos else s
            );
        }
    }
    for (arch_file, roots) in roots_by_archive.items() {
        if not roots {
            continue;
        }
        with open(arch_file, "rb") as _f {
            data = _f.read();
        }
        members = select_ar_members(data, roots);
        if not members {
            continue;
        }
        for m in members {
            member_bytes.append(m.data);
        }
        for p in paths_by_archive.get(arch_file, []) {
            handled.add(p);
        }
    }
    return (member_bytes, handled);
}


def _musl_lib_dir(triple: str) -> (str | None) {
    import os;
    env = os.environ.get("JAC_NATIVE_MUSL_DIR", "");
    if env and os.path.isdir(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    want = "aarch64" if ("aarch64" in triple or "arm64" in triple) else "x86_64";
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

    floor = os.path.join(os.path.dirname(pkg_root), "python", "floor");
    if os.path.isdir(floor) {
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
