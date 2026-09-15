import from jaclang.compiler.backends.native.floor {
    collect_floor_archives,
    floor_lib_dir,
    resolve_floor_dir,
    clib_to_archive_name,
    clib_needed_libs,
    clib_symbol_lib_map
}
import os;
import sys;

import from jaclang.cli.console { console }

import from jaclang.compiler.backends.native.entry_points {
    finalize_native_ir,
    validate_native_application
}

impl native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> int {
    import from jaclang.jac0core.ext_registry {
        is_jac,
        is_retired_native_marker,
        base_stem
    }
    import from jaclang.project { get_config }

    _cfg = get_config();
    _mem_cfg = _cfg.memory if _cfg else None;
    if not memory {
        memory = _mem_cfg.profile if _mem_cfg else "managed";
    }
    if memory not in ("managed", "rc", "nogc") {
        console.error(
            f"Invalid --memory profile '{memory}' (expected: managed, rc, nogc)"
        );
        return 1;
    }
    shared = lib;
    if not is_jac(filename) {
        console.error("Input must be a .jac file.");
        return 1;
    }

    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }

    is_wasm = target in ["wasm", "wasm32", "wasm32-unknown-unknown"];
    _triple = "wasm32-unknown-unknown" if is_wasm else "";

    is_windows = (sys.platform == "win32")
        or ("windows" in target)
        or (target in ["win", "win64", "mingw"]);
    if is_windows {
        _triple = target if "-" in target else "x86_64-pc-windows-msvc";
    }

    is_macos_target = (target in ["macos", "darwin", "osx", "macosx"])
        or ("apple" in target)
        or ("darwin" in target);
    if is_macos_target {
        _triple = target if "-" in target else "arm64-apple-darwin";
    }

    is_linux_target = (target in ["linux", "elf"])
        or ("linux-gnu" in target)
        or ("linux-musl" in target);
    if is_linux_target {
        _triple = target if "-" in target else "x86_64-unknown-linux-gnu";
    }

    if is_retired_native_marker(filename) {
        console.error(
            f"{filename}: the .na.jac marker was retired in 0.35 -- rename the "
            "file to .jac; 'jac build --native' compiles plain .jac natively."
        );
        return 1;
    }
    auto_promote = is_jac(filename);

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

    console.print(f"Compiling {filename} to native binary");

    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.backends.native.na_compile_pass {
        native_linked_ir_text
    }

    try {
        prog = JacProgram();
        import from jaclang.compiler.driver.pipeline_runner { native_application }
        (ir_module, options) = native_application(
            prog, filename, _triple or '', memory, debug, no_ir_cache
        );
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return 1;
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
        return 1;
    }

    if auto_promote {
        console.print("  Auto-promoted to native compilation.");
    }

    if is_wasm {
        import from jaclang.compiler.backends.native.wasm_build {
            emit_wasm_from_ir,
            app_declared_imports
        }
        try {
            wasm_bytes = emit_wasm_from_ir(
                native_linked_ir_text(ir_module),
                app_imports=app_declared_imports(ir_module),
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

    try {
        llvm_ir_str = validate_native_application(ir_module, shared, memory);
    } except ValueError as error {
        console.error(str(error));
        return 1;
    }

    console.print("  LLVM IR generated successfully.");

    import jaclang.compiler.backends.native.llvm.binding as llvm;
    import from jaclang.compiler.backends.native.shared_emit { init_object_codegen }
    init_object_codegen();

    triple = (options.native_target or "") or str(llvm.get_default_triple());
    console.print(f"  Target: {triple}");

    export_symbols: list[str] = [];
    init_funcs: list[str] = [];

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
    _lib_norm = clib_needed_libs(needed_libs, clib_paths or [], _floor_handled);

    _is_linux_exec = (not shared) and (not is_windows) and (not is_macos);
    _static_musl = _is_linux_exec and (len(needed_libs) == 0);

    (llvm_ir_str, _extra_exports) = finalize_native_ir(
        llvm_ir_str,
        triple,
        clib_paths or [],
        ir_module.gen.interop_manifest,
        shared,
        is_windows,
        is_macos,
        _static_musl
    );
    if shared {
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
            f"  Exporting {len(export_symbols)} C-ABI symbol(s): "
                + ", ".join(export_symbols)
        );
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

    symbol_lib_map = clib_symbol_lib_map(
        ir_module.gen._clib_symbol_lib, _floor_handled, _lib_norm, shared, is_macos
    );

    try {
        mod = llvm.parse_assembly(llvm_ir_str);
        if shared {
            import from jaclang.compiler.backends.native.shared_emit {
                internalize_native_implementation
            }
            internalize_native_implementation(
                mod, export_symbols + ["__jac_shared_init"]
            );
        }
        mod.verify();
    } except Exception as e {
        console.error(f"LLVM IR verification failed: {e}");
        return 1;
    }

    _target_ovr = options.native_target or "";
    _llvm_target = (
        llvm.Target.from_triple(_target_ovr)
            if _target_ovr
            else llvm.Target.from_default_triple()
    );
    assert isinstance(_llvm_target, llvm.Target);

    if shared {
        _tm = _llvm_target.create_target_machine(opt=2, reloc="pic", codemodel="small");
    } else {
        _tm = _llvm_target.create_target_machine(opt=2, codemodel="large");
    }
    assert isinstance(_tm, llvm.TargetMachine);
    target_machine = _tm;

    _opt_level = int(options.opt_level or 0);
    _dump_path = options.dump_ir_path or "";

    if _opt_level > 0 {
        pto = llvm.create_pipeline_tuning_options(speed_level=_opt_level);
        pb = llvm.create_pass_builder(target_machine, pto);
        assert isinstance(pb, llvm.PassBuilder);
        opt_mpm = pb.getModulePassManager();
        assert isinstance(opt_mpm, llvm.ModulePassManager);
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
    assert isinstance(obj_bytes, bytes);
    console.print(f"  Object code emitted ({len(obj_bytes)} bytes).");

    if is_windows {
        import from jaclang.compiler.backends.native.pe_linker { PeLinker }

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
        import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
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
        import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
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
        if ir_module.gen.jc_layout is not None {
            _lay_path = f"{output}.layout.json";
            with open(_lay_path, "w") as _lf {
                _lf.write(ir_module.gen.jc_layout);
            }
            console.print(f"  Class layout written to {_lay_path}.");
        }
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


def _resolve_ca_bundle(pkg_root: str) -> (str | None) {
    import os;

    cand = os.path.join(os.path.dirname(pkg_root), "python", "floor", "cacert.pem");
    if os.path.isfile(cand) {
        return cand;
    }

    import glob;
    bundles = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root, ".python-build", "*", "*", "python", "build", "cacert.pem"
            )
        )
    );
    if bundles {
        return bundles[0];
    }
    source_bundles = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root, ".python-build", "*", "python", "build", "cacert.pem"
            )
        )
    );
    if source_bundles {
        return source_bundles[0];
    }
    hits = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root,
                ".python-build",
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
    import from jaclang.runtime.graph_utils { triple_arch }
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

    import from jaclang.dist.fused_binary { bundled_floor_roots }
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


def _collect_musl_static(
    obj_bytes: bytes, triple: str
) -> (tuple[list[bytes], list[bytes]] | None) {
    import os;
    import from jaclang.compiler.backends.native.linker_common {
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
