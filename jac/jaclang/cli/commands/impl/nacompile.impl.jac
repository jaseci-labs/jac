"""Implementation of the nacompile command.

Compiles a .na.jac file to a standalone native binary:
1. Compile .na.jac through Jac pipeline to get LLVM IR
2. Inject main() (+ _start on Linux, _jac_win_start on Windows) as pure LLVM IR
3. Emit object code via llvmlite
4. Link into executable via pure Python linker (ELF on Linux, Mach-O on macOS,
   PE/COFF .exe on Windows)
"""

import os;
import sys;

import from jaclang.cli.console { console }


"""Inject main() and _start into the LLVM IR for ELF (Linux).

main() stores argc/argv into globals, calls jac_entry(), and returns 0.
_start is the ELF entry point. It uses the naked attribute with
@llvm.stacksave() to read the raw stack pointer without a prologue,
then loads argc and argv from the kernel-placed stack layout:
[sp]=argc, [sp+8..]=argv array. No inline assembly needed.
"""
def _inject_entry_elf(llvm_ir_str: str, triple: str = "") -> str {
    # Declare __jac_argc/__jac_argv only if the IR gen pass didn't already
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    # Only declare exit() if sys.exit() didn't already declare it
    # llvmlite quotes the name as @"exit", so check both forms
    has_exit = "@exit" in llvm_ir_str or '@"exit"' in llvm_ir_str;
    exit_decl = "" if has_exit else 'declare void @exit(i32) noreturn\n\n';
    ir = (
        '\n; --- injected entry point ---\n' + globals_ir + exit_decl + 'declare ptr @llvm.stacksave()\n\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n\n' + 'define void @_start() naked noreturn {\n' + 'entry:\n' + '    %sp = call ptr @llvm.stacksave()\n' + '    %argc = load i32, ptr %sp\n' + '    %argv = getelementptr i8, ptr %sp, i64 8\n' + '    %ret = call i32 @main(i32 %argc, ptr %argv)\n' + '    call void @exit(i32 %ret)\n' + '    unreachable\n' + '}\n'
    );
    return llvm_ir_str + ir;
}


"""Inject main() into the LLVM IR for Mach-O (macOS).

Only main() is needed - dyld handles entry via LC_MAIN, and the
system CRT manages _start. No exit() declaration needed since
returning from main() is handled by dyld.
"""
def _inject_entry_macho(llvm_ir_str: str) -> str {
    # Declare __jac_argc/__jac_argv only if the IR gen pass didn't already
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    ir = '\n; --- injected entry point ---\n' + globals_ir + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n';
    return llvm_ir_str + ir;
}


"""Inject main() and _jac_win_start into the LLVM IR for PE (Windows).

_jac_win_start is the PE entry point (AddressOfEntryPoint). Unlike the ELF
_start, the Windows loader calls the entry as an ordinary function (no
argc/argv on the stack), so we recover them via msvcrt's __getmainargs and
forward to main(), then exit() cleanly. _fltused is defined locally because
it is an MSVC CRT marker symbol (not exported by msvcrt); defining it keeps
the backend's floating-point-use reference from becoming a failed import.
"""
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


"""Inject __jac_shared_init() and the public RC wrappers for a shared library.

A .so/.dylib/.dll has no jac_entry; instead the platform loader runs
__jac_shared_init via the init mechanism (ELF DT_INIT_ARRAY, Mach-O
__mod_init_func, PE DllMain) on load. It calls this module's
__jac_glob_init() and each imported module's __jac_glob_init_<safe>()
(dependency order, mirroring jac_entry) so every global is initialised before
any export is called. We also export jac_retain/jac_release as public wrappers
over the private reference-counting primitives, so a C host can manage the
lifetime of Jac object/string handles that cross the boundary.

Returns (new_ir, extra_export_names).
"""
def _inject_shared_init(
    llvm_ir_str: str, transitive_sources: list[str]
) -> tuple[str, list[str]] {
    import re;
    init_calls: list[str] = [];
    # This module's own glob-init (NaIRGenPass always emits it when present).
    if ('@"__jac_glob_init"' in llvm_ir_str)
    or ("@__jac_glob_init(" in llvm_ir_str)
    or ("define void @__jac_glob_init(" in llvm_ir_str) {
        init_calls.append("  call void @__jac_glob_init()");
    }
    _seen: set = set();
    for _src in transitive_sources {
        if _src is None or _src in _seen {
            continue;
        }
        _seen.add(_src);
        _safe = re.sub(r'[^a-zA-Z0-9_]', '_', _src);
        _nm = f"__jac_glob_init_{_safe}";
        if (f'@"{_nm}"' in llvm_ir_str) or (f"@{_nm}(" in llvm_ir_str) {
            init_calls.append(f"  call void @{_nm}()");
        }
    }
    parts: list[str] = ["\n; --- injected shared-library init + RC wrappers ---"];
    _body = "\n".join(init_calls);
    if _body {
        _body = _body + "\n";
    }
    parts.append(
        "define void @__jac_shared_init() {\nentry:\n" + _body + "  ret void\n}"
    );
    extra_exports: list[str] = [];
    # Public retain/release over the private RC primitives, when RC is in use.
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


"""Compile a .na.jac file to a standalone native binary."""
impl nacompile(
    filename: str,
    output: str = "",
    scrub: bool = False,
    target: str = "",
    shared: bool = False,
    debug: bool = False
) -> int {
    import from jaclang.jac0core.ext_registry { is_jac, is_native_module, base_stem }
    # Validate input
    if not is_jac(filename) {
        console.error("Input must be a .jac or .na.jac file.");
        return 1;
    }

    # -g/--debug: emit DWARF line tables, DISubprograms and a .symtab so the
    # ELF linker preserves them into a section-header table (gated on the IR
    # carrying debug metadata). NaIRGenPass and the linker both gate on this
    # env var, so set it before compiling. The metadata only appears on a fresh
    # compile, so imply --scrub: a cached non-debug build would otherwise be
    # reused and silently yield a binary GDB can't read.
    _prev_native_debug = os.environ.get("JAC_NATIVE_DEBUG") if debug else None;
    if debug {
        os.environ["JAC_NATIVE_DEBUG"] = "1";
        scrub = True;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }

    # wasm32 target: emit a browser-loadable wasm module instead of a host binary.
    # The native LLVM backend already targets wasm32; we set the triple before
    # compiling so NaIRGenPass picks it up (data layout + ABI), then link the
    # single relocatable object into a module with the pure-Jac wasm linker.
    is_wasm = target in ["wasm", "wasm32", "wasm32-unknown-unknown"];
    if is_wasm {
        os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    }

    # windows target: emit a PE/COFF .exe instead of a host binary. Set the
    # triple before compiling so NaIRGenPass picks it up (data layout + ABI),
    # then link the COFF object with the pure-Jac PE linker. Mirrors is_wasm.
    # A bare alias ("windows"/"win64") maps to the msvc triple; a full triple
    # the user passed ("x86_64-pc-windows-gnu") is used verbatim.
    is_windows = ("windows" in target) or (target in ["win", "win64", "mingw"]);
    if is_windows {
        os.environ["JAC_NATIVE_TARGET"] = (
            target if "-" in target else "x86_64-pc-windows-msvc"
        );
    }

    # macos/darwin target: emit a Mach-O binary (and, with --shared, a .dylib)
    # via the pure-Jac Mach-O linker. Lets a non-macOS host cross-build a dylib;
    # on a macOS host the default path already routes through MachOLinker. A bare
    # alias maps to arm64-apple-darwin; a full triple is used verbatim.
    is_macos_target = (target in ["macos", "darwin", "osx", "macosx"])
    or ("apple" in target)
    or ("darwin" in target);
    if is_macos_target {
        os.environ["JAC_NATIVE_TARGET"] = (
            target if "-" in target else "arm64-apple-darwin"
        );
    }

    # Scrub: wipe cached compilation artifacts under the source tree
    if scrub {
        import from jaclang.jac0core.jir { scrub_cache_dirs }
        src_root = os.path.dirname(os.path.abspath(filename)) or ".";
        _scrubbed = scrub_cache_dirs(src_root);
        if _scrubbed {
            console.print(f"  Scrubbed {_scrubbed} cache dir(s).");
        }
    }

    auto_promote = is_jac(filename) and not is_native_module(filename);

    # Detect platform (host darwin, or an explicit macOS cross-target)
    is_macos = (sys.platform == "darwin") or is_macos_target;

    # Determine output path
    if not output {
        output = base_stem(filename);
        if shared {
            # Conventional shared-library name: lib<stem>.<ext> per platform.
            _so_ext = ".dll" if is_windows else (".dylib" if is_macos else ".so");
            output = "lib" + output + _so_ext;
        } elif is_wasm {
            output = output + ".wasm";
        } elif is_windows {
            output = output + ".exe";
        }
    }

    console.print(f"Compiling {filename} to native binary...");

    # Step 1: Compile through Jac pipeline to get LLVM IR
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }

    try {
        prog = JacProgram();
        if auto_promote {
            prog._auto_promote_native = True;
            prog._auto_promote_target = os.path.abspath(filename);
        }
        # aot_mode=True: NativeCompilePass links all cross-module imports at IR
        # level and runs the optimization pipeline, but skips MCJIT engine
        # creation (which would consume the module). The resulting linked+optimised
        # module is stored in ir_module.gen.llvm_ir for us to emit as object code.
        #
        # type_check=False: native compilation has its own type discipline (the
        # backend treats `int`, `str`, function refs and `obj` instances as
        # 64-bit pointers), so the strict Jac type checker produces false
        # positives that would otherwise abort the build at the errors_had
        # gate below. This matches the JIT native path (`prog.compile` without
        # options also defaults type_check off); `jac check` remains the way to
        # type-check a native module strictly.
        options = CompileOptions(aot_mode=True, type_check=False);
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    } finally {
        # Contain the JAC_NATIVE_DEBUG side-effect: restore the prior value once the
        # IR is generated (NaIRGenPass only reads the env var during compile; the
        # ELF linker keys off the .debug_* sections already baked into the IR). This
        # keeps a later same-process nacompile() call without -g byte-identical to a
        # standalone non-debug build.
        if debug {
            if _prev_native_debug is None {
                os.environ.pop("JAC_NATIVE_DEBUG", None);
            } else {
                os.environ["JAC_NATIVE_DEBUG"] = _prev_native_debug;
            }
        }
    }

    # Abort immediately if the pass infrastructure recorded any ERROR-level
    # diagnostics (e.g. E5020 from a failing imported .na.jac module).
    # Without this check, nacompile would silently link stale cached IR and
    # write a broken binary while printing no error.
    if prog.errors_had {
        for _err in prog.errors_had {
            # `pretty_print` (not `str`) renders the source-location span AND
            # the diagnostic's `help_text` — the same renderer `jac check` /
            # `jac run` use. `str(_err)` drops help, so native E5090 guidance
            # (unsupported import / cross-module OSP) never reached the user.
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

    # wasm32 path: emit one relocatable object and link it into a module.
    # Undefined externs (raylib, malloc/free/memcpy, __multi3, ...) stay as wasm
    # imports for the JS host. No entry injection / DT_NEEDED - JS calls the
    # exported functions directly.
    if is_wasm {
        # Emit one relocatable wasm object and link it into a module. Undefined
        # externs (raylib, malloc/free/memcpy, __multi3, ...) stay as wasm
        # imports for the JS host; no entry injection / DT_NEEDED.
        import from jaclang.compiler.passes.native.wasm_build { emit_wasm_from_ir }
        try {
            wasm_bytes = emit_wasm_from_ir(str(ir_module.gen.llvm_ir));
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
        console.print(f"  Instantiate in a browser/Node with an `env` import object.");
        return 0;
    }

    # Step 2: Check for Python/server interop (can't compile standalone)
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

    # Check that jac_entry exists (requires with entry {} block). A shared
    # library has no entry point — it exports `:pub` symbols instead — so this
    # requirement is skipped under --shared.
    if not shared and "jac_entry" not in llvm_ir_str {
        console.error(
            "No entry point found. "
            "The .na.jac file must have a 'with entry { }' block."
        );
        return 1;
    }

    console.print("  LLVM IR generated successfully.");

    # Step 3: Initialize llvmlite
    import llvmlite.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();

    triple = os.environ.get("JAC_NATIVE_TARGET", "") or llvm.get_default_triple();
    console.print(f"  Target: {triple}");

    # Step 4: Inject entry point (executable) or the shared-library init.
    export_symbols: list[str] = [];
    init_funcs: list[str] = [];
    if shared {
        _transitive: list[str] = [];
        _mf = ir_module.gen.interop_manifest;
        if _mf {
            _transitive = _mf.native_transitive_sources;
        }
        (llvm_ir_str, _extra_exports) = _inject_shared_init(llvm_ir_str, _transitive);
        init_funcs = ["__jac_shared_init"];
        # Export set: `:pub` symbols recorded during IR gen (root module +
        # AOT-propagated imports) plus the injected runtime wrappers.
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
    } else {
        llvm_ir_str = _inject_entry_elf(llvm_ir_str, triple);
    }

    # Step 5: Determine needed libraries
    # Note: libgc (Boehm GC) no longer needed - using reference counting
    if is_windows {
        # msvcrt.dll ships on every Windows and exports the classic C runtime
        # (printf, malloc, free, memcpy, math, ...). Undefined externals bind
        # here unless symbol_lib_map names a different DLL (e.g. a clib import).
        needed_libs: list[str] = ["msvcrt.dll"];
    } elif is_macos {
        # libm is part of libSystem on macOS.
        needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"];
    } else {
        # User-specified libraries are appended below; libc/libm are added last
        # so they appear AFTER user imports in NEEDED. This matters for libraries
        # like libcef.so whose .init_array calls dlsym(RTLD_NEXT, "close") etc.:
        # RTLD_NEXT searches the link map AFTER the calling library, so libc must
        # be after libcef.so in the map for those lookups to resolve (issue #6572).
        needed_libs: list[str] = [];
    }

    # Add C shared libraries discovered during compilation (e.g. libuv.so.1)
    # These come from `import from "/path/to/lib.so" { ... }` declarations
    # in the compiled module and its transitive dependencies.
    # _clib_paths is accumulated by _compile_and_link_native_imports.
    clib_paths = ir_module.gen._clib_paths;
    # Maps a raw clib path to the soname actually recorded in needed_libs, so
    # the per-symbol library attribution below lines up with the linker's
    # LC_LOAD_DYLIB ordinals.
    _lib_norm: dict[str, str] = {};
    if clib_paths {
        for lib_path in clib_paths {
            # A relative path with a directory component (e.g. "./libfoo.so")
            # names a library shipped beside the binary. Record only its soname
            # so the linker's DT_RUNPATH=$ORIGIN entry resolves it relative to
            # the executable rather than the launch directory. Absolute paths
            # (system libraries) and bare sonames are recorded verbatim.
            #
            # A name that already carries a loader token ($ORIGIN/... on ELF,
            # @loader_path/... on Mach-O) is a per-platform logical import
            # resolved by the native backend (issue #6387): keep it verbatim so
            # the sub-directory and origin-relative semantics survive.
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

    # Append libc/libm after all user-specified libraries so the dynamic
    # linker's link map puts libc AFTER any user library that needs RTLD_NEXT
    # to resolve libc symbols from its .init_array (issue #6572).
    if not is_macos and not is_windows {
        if "libc.so.6" not in needed_libs {
            needed_libs.append("libc.so.6");
        }
        if "libm.so.6" not in needed_libs {
            needed_libs.append("libm.so.6");
        }
    }

    # Build the symbol -> soname map the Mach-O linker uses to emit two-level
    # dylib ordinals (e.g. "InitWindow" -> "libraylib.dylib"). On ELF this is
    # unused (the loader searches all DT_NEEDED libs flatly).
    symbol_lib_map: dict[str, str] = {};
    for (_sym, _raw) in ir_module.gen._clib_symbol_lib.items() {
        symbol_lib_map[_sym] = _lib_norm.get(_raw, _raw);
    }

    # Step 6: Emit object code via llvmlite
    try {
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
    } except Exception as e {
        console.error(f"LLVM IR verification failed: {e}");
        return 1;
    }

    # JAC_NATIVE_TARGET cross-compiles for another triple; the parsed module
    # already carries that triple/data layout from NaIRGenPass.postinit, so the
    # emitted object matches. The pure-Python linker selects ELF arch from the
    # object's e_machine, so the resulting binary targets the requested ISA.
    _target_ovr = os.environ.get("JAC_NATIVE_TARGET", "");
    if _target_ovr {
        target = llvm.Target.from_triple(_target_ovr);
    } else {
        target = llvm.Target.from_default_triple();
    }
    # A shared library must be position-independent so the loader can map it at
    # any base address; an executable keeps the default (fixed-base) model. The
    # small code model keeps code/GOT references PC-relative (no .ltext /
    # GOTPC64 large-model relocations), which the pure-Python linker resolves.
    if shared {
        target_machine = target.create_target_machine(
            opt=2, reloc="pic", codemodel="small"
        );
    } else {
        target_machine = target.create_target_machine(opt=2);
    }

    # Read native build settings from jac.toml [build.native] (env vars as fallback)
    import from jaclang.project { get_config, NativeBuildConfig }
    _native_cfg = NativeBuildConfig();
    _jac_config = get_config();
    if _jac_config {
        _native_cfg = _jac_config.build.native;
    }
    _opt_level = int(os.environ.get("JAC_OPT_LEVEL", str(_native_cfg.opt_level)));
    _dump_path = os.environ.get("JAC_DUMP_IR", _native_cfg.dump_ir);

    # Run LLVM optimization pipeline before emitting object code.
    # Internalize pass marks non-entry functions as internal so LLVM
    # can aggressively inline them (jac_entry/main/_start are preserved).
    # In --shared mode we must NOT internalize: the exported `:pub` symbols and
    # the RC wrappers have to survive as externally-visible definitions.
    if _opt_level > 0 {
        pto = llvm.create_pipeline_tuning_options(speed_level=_opt_level, size_level=0);
        pb = llvm.create_pass_builder(target_machine, pto);
        opt_mpm = pb.getModulePassManager();
        if not shared {
            opt_mpm.add_internalize_pass();
        }
        opt_mpm.run(mod, pb);
    }

    # Debug: dump optimized IR
    if _dump_path {
        with open(_dump_path, "w") as _df {
            _df.write(str(mod));
        }
    }

    obj_bytes = target_machine.emit_object(mod);
    console.print(f"  Object code emitted ({len(obj_bytes)} bytes).");

    # Step 7: Link into native executable (platform-specific)
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
                soname=os.path.basename(output)
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
        try {
            success = ElfLinker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                shared=shared,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output)
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
