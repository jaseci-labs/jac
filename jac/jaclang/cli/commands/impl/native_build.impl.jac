import hashlib;
import os;
import sys;


def _scan_rc_machinery(llvm_ir_str: str) -> tuple[list[str], list[str]];
def _application_ir(plan: LinkPlan) -> str;
def _target_triple(target: str) -> str;
def _sealed_native_plan(
    filename: str,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> (LinkPlan | None);

def _link_kind_artifact(
    plan: LinkPlan, output: str, kind: ArtifactKind, label: str
) -> int;

def _callback_source_path(stored: str, unit_path: str, image_root: str) -> str;


impl _target_triple(target: str) -> str {
    if target in ["wasm", "wasm32", "wasm32-unknown-unknown"] {
        return "wasm32-unknown-unknown";
    }
    if ("windows" in target) or (target in ["win", "win64", "mingw"]) {
        return target if "-" in target else "x86_64-pc-windows-msvc";
    }
    if (target in ["macos", "darwin", "osx", "macosx"])
        or ("apple" in target)
        or ("darwin" in target) {
        return target if "-" in target else "arm64-apple-darwin";
    }
    if (target in ["linux", "elf"])
        or ("linux-gnu" in target)
        or ("linux-musl" in target) {
        return target if "-" in target else "x86_64-unknown-linux-gnu";
    }
    return "" if target in ("", "host") else target;
}


impl native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    link_mode: str = "",
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> int {
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
    if link_mode and link_mode not in NATIVE_LINK_MODES {
        console.error(
            f"Invalid --link-mode '{link_mode}' (expected: {', '.join(
                NATIVE_LINK_MODES
            )})"
        );
        return 1;
    }
    shared = lib;
    assert_no_rc = memory == "nogc";
    if not is_jac(filename) {
        console.error("Input must be a .jac file.");
        return 1;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }
    if is_retired_native_marker(filename) {
        console.error(
            f"{filename}: the .na.jac marker was retired in 0.35 -- rename the "
            "file to .jac; 'jac build --native' compiles plain .jac natively."
        );
        return 1;
    }

    triple = _target_triple(target or (_cfg.native.target if _cfg else ""));
    is_wasm = triple.startswith("wasm32");
    is_windows = (sys.platform == "win32" and not triple) or ("windows" in triple);
    is_macos = (
        (sys.platform == "darwin" and not triple)
        or ("apple" in triple)
        or ("darwin" in triple)
    );
    _prev_target = push_native_target(triple);

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

    try {
        prog = JacProgram();
        options = CompileOptions(
            aot_mode=True,
            default_codespace="native",
            skip_native_engine=True,
            memory_profile=memory,
            native_target=triple,
            native_debug=(True if debug else None),
            native_link_mode=(link_mode or None),
            no_ir_cache=debug or no_ir_cache
        );
        prog.options = options;
        ir_module = (
            prog.compile(file_path=os.path.abspath(filename), options=options)
                if is_wasm
                else None
        );
        plan = build_link_plan(
            prog, [os.path.abspath(filename)], options, mode=link_mode
        );
    } except LinkPlanError as e {
        console.print(str(e));
        _restore_target(_prev_target);
        return 1;
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        _restore_target(_prev_target);
        return 1;
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        _restore_target(_prev_target);
        return 1;
    }

    if is_wasm and (ir_module is None or ir_module.gen.native_iface is None) {
        if not (ir_module and ir_module.decided_codespace == 'native') {
            console.error(
                "This .jac file is not compatible with native compilation.\n"
                "  It may use walkers, nodes, edges, async, lambdas, or other\n"
                "  constructs not supported by the native backend.\n"
                "  Remove the incompatible constructs it names."
            );
        } else {
            console.error(
                f"Native compilation produced no native unit for {filename} and no\n"
                "  diagnostic explains why; this is a compiler bug -- please report it."
            );
        }
        for _warn in prog.warnings_had {
            console.print(_warn.pretty_print());
        }
        _restore_target(_prev_target);
        return 1;
    }
    console.print("  Auto-promoted to native compilation.");

    python_imports = sorted(
        {name for unit in plan.units for name in unit.iface.python_imports}
    );
    if not lib and not is_wasm and python_imports {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for name in python_imports {
            console.error(f"  - {name}");
        }
        _restore_target(_prev_target);
        return 1;
    }

    console.print(
        f"  Link plan: {len(plan.units)} unit(s), mode={plan.mode}, target={plan.triple}"
    );

    if not lib {
        _demoted = plan.demoted_symbols();
        if _demoted {
            console.error(
                f"{len(_demoted)} function(s) in the native closure were demoted to "
                "Python-only: "
                    + ", ".join(_demoted),
                hint="A self-contained binary cannot run a demoted function. Run `jac explain placement` on the file to see why each one failed to lower."
            );
            _restore_target(_prev_target);
            return 1;
        }
    }

    if assert_no_rc {
        (_rc_syms, _rc_probes) = _scan_rc_machinery(_application_ir(plan));
        if _rc_syms or _rc_probes {
            _parts: list[str] = [];
            if _rc_syms {
                _parts.append("RC/collector symbols: " + ", ".join(_rc_syms));
            }
            if _rc_probes {
                _parts.append("entry-point env probes: " + ", ".join(_rc_probes));
            }
            console.error(
                "nogc invariant violated (compiler bug): emitted IR contains "
                    + "; ".join(_parts)
                    + "\n  (module has managed heap types or RC-emitting code;"
                    + " see rc-stats coverage)"
            );
            _restore_target(_prev_target);
            return 1;
        }
        console.print(
            "  nogc invariant ok: 0 __rc_* symbols · 0 trace fns"
            " · no roots buffer · no entry-point env probes"
        );
    }

    if not shared and not is_wasm and not plan.root_unit().iface.entry_symbol {
        console.error(
            "No entry point found. " "The file must have a 'with entry { }' block."
        );
        _restore_target(_prev_target);
        return 1;
    }

    kind = ArtifactKind.SHARED
        if shared
        else (ArtifactKind.WASM if is_wasm else ArtifactKind.EXECUTABLE);
    plan.library_api = shared;
    app_imports: (set | None) = None;
    if is_wasm {
        import from jaclang.compiler.backends.native.wasm_build { app_declared_imports }
        assert ir_module is not None;
        app_imports = app_declared_imports(ir_module);
    }
    try {
        result = link_artifact(
            plan, output, kind, log=console.print, app_imports=app_imports
        );
    } except Exception as e {
        console.error(f"Native link failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    } finally {
        _restore_target(_prev_target);
    }

    file_size = os.path.getsize(output);
    lowered = len(prog.native_units().compiled_paths);
    compiled = set(prog.native_units().compiled_paths);
    reused_units = len(
        [
            u
            for u in plan.units
            if u.path not in compiled
        ]
    );
    console.print(f"  Recompiled {lowered} unit(s); reused {reused_units}.");
    if result.reused {
        console.print(f"  Up to date: {output} ({file_size} bytes).");
        return 0;
    }
    if is_wasm {
        console.print(f"  Wasm module written to {output} ({file_size} bytes).");
        console.print(
            "  Instantiate with the `jac_host1` host object (see @jac/wasm_host)"
            " plus an `env` object for any FFI the app declares."
        );
    } elif shared {
        console.print(f"  Shared library written to {output} ({file_size} bytes).");
        console.print(f"  Class layout written to {output}.layout.json.");
        console.print(f"  Plan digest: {result.plan_digest[:16]}");
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


def _restore_target(prev_target: (str | None));

impl _scan_rc_machinery(llvm_ir_str: str) -> tuple[list[str], list[str]] {
    import re;
    syms: set[str] = set();
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


impl _application_ir(plan: LinkPlan) -> str {
    registry = plan.prog.native_units();
    parts: list[str] = [];
    for u in plan.units {
        if is_toolchain_unit(u.path) {
            continue;
        }
        bc = registry.bitcode_for(u.path, plan.options);
        if bc is None {
            continue;
        }
        parts.append(str(llvm.parse_bitcode(bc)));
    }
    return "\n".join(parts);
}


impl _restore_target(prev_target: (str | None)) {
    pop_native_target(prev_target);
}


impl _sealed_native_plan(
    filename: str,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> (LinkPlan | None) {
    if not is_jac(filename) {
        console.error("Input must be a .jac file.");
        return None;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return None;
    }
    if is_retired_native_marker(filename) {
        console.error(
            f"{filename}: the .na.jac marker was retired in 0.35 -- rename the "
            "file to .jac; 'jac build --native' compiles plain .jac natively."
        );
        return None;
    }
    _cfg = get_config();
    if not memory {
        memory = _cfg.memory.profile if _cfg else "managed";
    }
    if memory not in ("managed", "rc", "nogc") {
        console.error(
            f"Invalid memory profile '{memory}' (expected: managed, rc, nogc)"
        );
        return None;
    }
    triple = _target_triple(target or (_cfg.native.target if _cfg else ""));
    prev = push_native_target(triple);
    try {
        prog = JacProgram();
        options = CompileOptions(
            aot_mode=True,
            default_codespace="native",
            skip_native_engine=True,
            memory_profile=memory,
            native_target=triple,
            native_debug=(True if debug else None),
            no_ir_cache=debug or no_ir_cache
        );
        prog.options = options;
        plan = build_link_plan(prog, [os.path.abspath(filename)], options);
    } except LinkPlanError as e {
        console.print(str(e));
        return None;
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return None;
    } finally {
        _restore_target(prev);
    }
    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return None;
    }
    return plan;
}


impl _link_kind_artifact(
    plan: LinkPlan, output: str, kind: ArtifactKind, label: str
) -> int {
    prev = push_native_target(plan.triple);
    try {
        link_artifact(plan, output, kind, log=console.print);
    } except LinkPlanError as e {
        console.error(str(e));
        return 1;
    } except Exception as e {
        console.error(f"{label} failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    } finally {
        _restore_target(prev);
    }
    return 0;
}


impl _callback_source_path(stored: str, unit_path: str, image_root: str) -> str {
    """The provider module of a callback, relative to the image root: the
    path the sealed image carries and the load lane imports from. The unit
    iface recorded it relative to the calling unit's directory; a dotted
    module name (the pre-iface fallback) resolves beside the unit too.""";
    if not stored or os.path.isabs(stored) {
        return stored;
    }
    unit_dir = os.path.dirname(unit_path);
    if stored.endswith(".jac") or ("/" in stored) {
        candidate = os.path.join(unit_dir, stored);
    } else {
        candidate = os.path.join(unit_dir, stored.replace(".", os.sep) + ".jac");
        if not os.path.isfile(candidate) {
            candidate = os.path.join(unit_dir, stored.replace(".", os.sep));
        }
    }
    try {
        return os.path.relpath(
            os.path.realpath(candidate), os.path.realpath(image_root)
        ).replace(
            os.sep, "/"
        );
    } except ValueError {
        return stored;
    }
}


impl native_build_sealed_pair(
    filename: str, exe_output: str, lib_output: str, image_root: str = ""
) -> int {
    """Seal one compile as the native payload pair of a jab.

    An app whose native code calls into Python (`native_imports`) cannot be
    self-contained: the pair is the host-driven entry library alone, and the
    callback contract -- symbol, wire signature, source module, per callee
    -- lands in `<lib>.interop.json` beside it. Any other app seals the
    standalone executable first and the entry library beside it as the
    in-process fallback lane (no interop record: absence of the record is
    what makes the runner go exe-first).""";
    import json;
    import from jaclang.server.sealed_serve { interop_record_path }

    plan = _sealed_native_plan(filename);
    if plan is None {
        return 1;
    }
    img_root = image_root or os.path.dirname(os.path.abspath(filename));
    bindings = [];
    for unit in plan.units {
        for cb in unit.iface.server_callbacks {
            """The iface carries the exact extern symbol each call site
            declared, so the collection cannot mismatch an aliased or
            same-named import -- and it survives registry cache hits, where
            the plan program's hub was never populated.""";
            source = _callback_source_path(cb.source, unit.path, img_root);
            if (
                not source
                or os.path.isabs(source)
                or source == ".."
                or source.startswith("../")
            ) {
                console.error(
                    f"callback provider for {cb.name!r} is not inside "
                    "the sealed image"
                );
                return 1;
            }
            bindings.append(
                InteropBinding(
                    name=cb.name,
                    source_context=InteropContext.SERVER,
                    ret_type=cb.ret_type,
                    param_types=list(cb.param_types),
                    source_module=source,
                    native_symbol=cb.native_symbol
                )
            );
        }
    }
    plan.callback_bindings = bindings;
    (resolved, _) = resolved_callback_bindings(plan);
    has_native_imports = any(unit.iface.python_imports for unit in plan.units)
        or bool(resolved);
    record = interop_record_path(lib_output);

    if has_native_imports {
        callback_records = [
            {
                "symbol": b.native_symbol or b.name,
                "name": b.name,
                "ret_type": b.ret_type,
                "param_types": list(b.param_types),
                "source": b.source_module or ""
            } for b in resolved
        ];
        console.print(
            "  App calls from native code into Python (native_imports): "
            "sealing the host-driven entry library only (a standalone "
            "executable cannot be self-contained)."
        );
        if _link_kind_artifact(
            plan, lib_output, ArtifactKind.ENTRY_LIB, "Entry-library link"
        )
            != 0 {
            console.error("Native compilation failed; seal aborted.");
            return 1;
        }
        h = hashlib.sha256();
        with open(lib_output, "rb") as f {
            h.update(f.read());
        }
        record.parent.mkdir(parents=True, exist_ok=True);
        record.write_text(
            json.dumps(
                {
                    "interop": True,
                    "version": 1,
                    "plan_digest": plan.plan_digest(),
                    "triple": plan.triple,
                    "sha256": h.hexdigest(),
                    "callbacks": callback_records
                },
                sort_keys=True
            )
                + "\n",
            encoding="utf-8"
        );
        return 0;
    }

    if record.exists() {
        record.unlink();
    }
    if not plan.root_unit().iface.entry_symbol {
        console.error(
            "No entry point found. The file must have a 'with entry { }' block."
        );
        return 1;
    }
    _demoted = plan.demoted_symbols();
    if _demoted {
        console.error(
            f"{len(_demoted)} function(s) in the native closure were demoted to "
            "Python-only: "
                + ", ".join(_demoted),
            hint="A self-contained binary cannot run a demoted function. Run `jac explain placement` on the file to see why each one failed to lower."
        );
        return 1;
    }
    if _link_kind_artifact(plan, exe_output, ArtifactKind.EXECUTABLE, "Native link")
        != 0 {
        console.error("Native compilation failed; seal aborted.");
        return 1;
    }
    if _link_kind_artifact(
        plan, lib_output, ArtifactKind.ENTRY_LIB, "Entry-library link"
    )
        != 0 {
        console.warning(
            "In-process entry library compilation failed; the sealed bundle "
            "will run via the standalone binary only."
        );
    }
    return 0;
}
