import os;
import sys;


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
        return "" if target in ("", "host") else target;
    }

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
    kind = "shared" if shared else ("wasm" if is_wasm else "executable");
    request = native_build_request_for(
        [os.path.abspath(filename)], kind, options, output
    );
    request.link_mode = link_mode;
    request.library_api = shared;
    request.refuse_python_imports = not lib and not is_wasm;
    request.refuse_demoted = not lib;
    request.require_entry = not shared and not is_wasm;
    request.assert_no_rc = assert_no_rc;
    prog = JacProgram();
    try {
        result = kernel_native_build(prog, request);
    } except KernelError as e {
        console.error(f"Jac compilation failed: {e}");
        return 1;
    }
    for line in result.log {
        console.print(line);
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return 1;
    }

    if is_wasm and not result.root_native {
        console.error(
            "This .jac file is not compatible with native compilation.\n"
            "  It may use walkers, nodes, edges, async, lambdas, or other\n"
            "  constructs not supported by the native backend.\n"
            "  Remove the incompatible constructs it names."
        );
        for _warn in prog.warnings_had {
            console.print(_warn.pretty_print());
        }
        return 1;
    }
    console.print("  Auto-promoted to native compilation.");

    if request.refuse_python_imports and result.python_imports {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for name in result.python_imports {
            console.error(f"  - {name}");
        }
        return 1;
    }

    console.print(
        f"  Link plan: {len(result.units)} unit(s), mode={result.mode}, target={result.triple}"
    );

    if request.refuse_demoted and result.demoted {
        console.error(
            f"{len(result.demoted)} function(s) in the native closure were demoted to "
            "Python-only: "
                + ", ".join(result.demoted),
            hint="A self-contained binary cannot run a demoted function. Run `jac explain placement` on the file to see why each one failed to lower."
        );
        return 1;
    }

    if assert_no_rc {
        if result.rc_symbols or result.rc_probes {
            _parts: list[str] = [];
            if result.rc_symbols {
                _parts.append("RC/collector symbols: " + ", ".join(result.rc_symbols));
            }
            if result.rc_probes {
                _parts.append("entry-point env probes: " + ", ".join(result.rc_probes));
            }
            console.error(
                "nogc invariant violated (compiler bug): emitted IR contains "
                    + "; ".join(_parts)
                    + "\n  (module has managed heap types or RC-emitting code;"
                    + " see rc-stats coverage)"
            );
            return 1;
        }
        console.print(
            "  nogc invariant ok: 0 __rc_* symbols · 0 trace fns"
            " · no roots buffer · no entry-point env probes"
        );
    }

    if request.require_entry and not result.has_entry {
        console.error(
            "No entry point found. " "The file must have a 'with entry { }' block."
        );
        return 1;
    }

    if not result.linked {
        console.error(f"Native link of {filename} did not run.");
        return 1;
    }

    file_size = os.path.getsize(output);
    console.print(
        f"  Recompiled {result.recompiled} unit(s); reused {len(result.units) - result.recompiled}."
    );
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
