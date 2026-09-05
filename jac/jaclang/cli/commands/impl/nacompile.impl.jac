import os;
import sys;

import from jaclang.cli.console { console }


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


"""The target triple `jac nacompile` selects from its `--target` spelling,
or "" for the host."""
def _target_triple(target: str) -> str {
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
    return "";
}


"""`jac nacompile`: compile one entry module and every native unit it
reaches, then link them through the plan into an executable, a shared
library or a wasm module."""
impl nacompile(
    filename: str,
    output: str = "",
    scrub: bool = False,
    link_mode: str = "",
    target: str = "",
    shared: bool = False,
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
    import from jaclang.project { get_config }
    import from jaclang.compiler.driver.compile_options {
        NATIVE_LINK_MODES,
        pop_native_target_env,
        push_native_target_env
    }

    _cfg = get_config();
    _gc_cfg = _cfg.gc if _cfg else None;
    if not gc {
        gc = _gc_cfg.`default if _gc_cfg else "cycles";
    }
    if gc not in ("cycles", "rc", "none") {
        console.error(f"Invalid --gc mode '{gc}' (expected: cycles, rc, none)");
        return 1;
    }
    if link_mode and link_mode not in NATIVE_LINK_MODES {
        console.error(
            f"Invalid --link-mode '{link_mode}' (expected: {', '.join(NATIVE_LINK_MODES)})"
        );
        return 1;
    }
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
            "file to .jac; 'jac nacompile' compiles plain .jac natively."
        );
        return 1;
    }

    _prev_native_debug = os.environ.get("JAC_NATIVE_DEBUG") if debug else None;
    if debug {
        os.environ["JAC_NATIVE_DEBUG"] = "1";
        scrub = True;
    }
    triple = _target_triple(target);
    is_wasm = triple.startswith("wasm32");
    is_windows = (sys.platform == "win32" and not triple) or ("windows" in triple);
    is_macos = (
        (sys.platform == "darwin" and not triple) or ("apple" in triple) or ("darwin" in triple)
    );
    _prev_target = push_native_target_env(triple) if triple else None;

    if scrub {
        import from jaclang.compiler.driver.jir { scrub_cache_dirs }
        src_root = os.path.dirname(os.path.abspath(filename)) or ".";
        _scrubbed = scrub_cache_dirs(src_root);
        if _scrubbed {
            console.print(f"  Scrubbed {_scrubbed} cache dir(s).");
        }
    }

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
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        LinkPlanError,
        build_link_plan,
        link_artifact,
        whole_program_module
    }

    try {
        prog = JacProgram();
        options = CompileOptions(
            aot_mode=True,
            default_codespace='native',
            force_target_program=True,
            skip_native_engine=True,
            na_gc_mode=gc,
            native_link_mode=(link_mode or None),
            nogc_cli_target=(base_stem(filename) if enforce_nogc else ""),
            nogc_enforce_modules=(_gc_cfg.enforce.modules if _gc_cfg else []),
            nogc_grandfathered=(_gc_cfg.enforce.grandfathered if _gc_cfg else [])
        );
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
        return 1;
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
        return 1;
    }

    if ir_module is None or ir_module.gen.native_iface is None {
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
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
        return 1;
    }
    console.print("  Auto-promoted to native compilation.");

    manifest = ir_module.gen.interop_manifest;
    if not is_wasm and manifest and manifest.native_imports {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for binding in manifest.native_imports {
            console.error(f"  - {binding.name}");
        }
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
        return 1;
    }

    try {
        plan = build_link_plan(prog, [ir_module.loc.mod_path], options, mode=link_mode);
    } except LinkPlanError as e {
        console.error(f"Link plan failed: {e}");
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
        return 1;
    }
    console.print(
        f"  Link plan: {len(plan.units)} unit(s), mode={plan.mode}, target={plan.triple}"
    );

    if strict {
        _demoted = plan.demoted_symbols();
        if _demoted {
            console.error(
                f"{len(_demoted)} function(s) in the native closure were demoted to "
                "Python-only: " + ", ".join(_demoted),
                hint="A self-contained binary cannot run a demoted function. Rerun with JAC_NA_DEBUG=1 to see why each one failed to lower."
            );
            _restore_env(debug, _prev_native_debug, triple, _prev_target);
            return 1;
        }
    }

    if assert_no_rc {
        spec = plan.glue_spec(ArtifactKind.EXECUTABLE, "elf", False);
        (merged, _exports) = whole_program_module(plan, spec);
        (_rc_syms, _rc_probes) = _scan_rc_machinery(str(merged));
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
            _restore_env(debug, _prev_native_debug, triple, _prev_target);
            return 1;
        }
        console.print(
            "  assert-no-rc ok: 0 __rc_* symbols · 0 trace fns"
            " · no roots buffer · no entry-point env probes"
        );
    }

    if not shared and not is_wasm and not plan.root_unit().iface.entry {
        console.error(
            "No entry point found. " "The file must have a 'with entry { }' block."
        );
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
        return 1;
    }

    kind = ArtifactKind.SHARED if shared else (ArtifactKind.WASM if is_wasm else ArtifactKind.EXECUTABLE);
    app_imports: (set | None) = None;
    if is_wasm {
        import from jaclang.compiler.backends.native.wasm_build { app_declared_imports }
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
        _restore_env(debug, _prev_native_debug, triple, _prev_target);
    }

    file_size = os.path.getsize(output);
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


def _restore_env(
    debug: bool, prev_native_debug: (str | None), triple: str, prev_target: (str | None)
) {
    import from jaclang.compiler.driver.compile_options { pop_native_target_env }
    if debug {
        if prev_native_debug is None {
            os.environ.pop("JAC_NATIVE_DEBUG", None);
        } else {
            os.environ["JAC_NATIVE_DEBUG"] = prev_native_debug;
        }
    }
    if triple {
        pop_native_target_env(prev_target);
    }
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
