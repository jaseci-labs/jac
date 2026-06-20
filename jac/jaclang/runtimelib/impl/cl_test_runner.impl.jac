"""Implementation of the client (`cl`) test runner."""

import json;
import os;
import re;
import shutil;
import socket;
import subprocess;
import sys;
import tempfile;
import time;
import from contextlib { suppress }
import from pathlib { Path }
import from collections.abc { Callable }
import from jaclang.cli.console { console }

impl compile_cl_module(filepath: str) -> tuple[str, list, dict] {
    import from jaclang.jac0core.program { JacProgram }
    prog = JacProgram();
    mod = prog.compile(str(filepath));
    if prog.errors_had {
        errs = "\n".join([str(e) for e in prog.errors_had]);
        raise RuntimeError(f"Failed to compile {filepath}:\n{errs}");
    }
    manifest = mod.gen.client_manifest;
    tests = list(getattr(manifest, "tests", []) or []);
    imports = dict(getattr(manifest, "imports", {}) or {});
    server_imports = list(getattr(manifest, "server_imports", []) or []);
    return (mod.gen.js, tests, imports, server_imports);
}

impl _compile_runtime_js -> str {
    import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_path }
    # `@jac/runtime` is baked into the language and resolves to core's
    # client_runtime.cl.jac -- the same file the bundler and type checker use.
    # We compile that single source of truth rather than reaching into a plugin.
    runtime_src = resolve_jac_virtual_module_path("@jac/runtime");
    if (not runtime_src) or (not Path(runtime_src).exists()) {
        raise RuntimeError("could not resolve @jac/runtime to a client runtime source");
    }
    (js, _tests, _imports, _server_imports) = compile_cl_module(runtime_src);
    return js;
}

impl _compile_runtime_core_js -> str {
    import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_path }
    # The runtime shim re-exports `client_runtime_core.cl.jac`, a sibling of the
    # `@jac/runtime` source. Compile that sibling so the harness can emit it next
    # to `jac_runtime.js` -- the shim's compiled import resolves it by path.
    runtime_src = resolve_jac_virtual_module_path("@jac/runtime");
    if (not runtime_src) or (not Path(runtime_src).exists()) {
        raise RuntimeError("could not resolve @jac/runtime to a client runtime source");
    }
    core_path = Path(runtime_src).parent / "client_runtime_core.cl.jac";
    if not core_path.exists() {
        raise RuntimeError("could not resolve client_runtime_core sibling source");
    }
    (js, _tests, _imports, _server_imports) = compile_cl_module(str(core_path));
    return js;
}

impl _stub_npm_imports(js_sources: list[str]) -> tuple[list, str, bool] {
    named: set = set();
    state = {"needs_default": False, "changed": False};
    rewritten = [];

    def is_npm(spec: str) -> bool {
        return (not spec.startswith(".")) and (spec != "@jac/runtime");
    }

    def repl(mobj: any) -> str {
        spec = mobj.group("spec");
        if not is_npm(spec) {
            return mobj.group(0);
        }
        state["changed"] = True;
        clause = mobj.group("clause").strip();
        brace = re.search(r"\{([^}]*)\}", clause);
        if brace {
            for ident in _NAMED_BINDING.findall(brace.group(1)) {
                if ident and (ident != "as") {
                    named.add(ident);
                }
            }
        }
        # A leading bare identifier before any `{`/`*` is a default import.
        head = clause.split("{")[0].split(",")[0].strip();
        if head and (not head.startswith("*")) {
            state["needs_default"] = True;
        }
        return 'import ' + clause + ' from "./' + _NPM_STUB_FILE + '";';
    }

    for src in js_sources {
        rewritten.append(_IMPORT_FROM.sub(repl, src));
    }

    lines = ["const __jacNpmStub = new Proxy(function () {}, {"];
    lines.append("  get: () => __jacNpmStub, apply: () => __jacNpmStub,");
    lines.append("});");
    if state["needs_default"] {
        lines.append("export default __jacNpmStub;");
    }
    for name in sorted(named) {
        lines.append(f"export const {name} = __jacNpmStub;");
    }
    stub_js = "\n".join(lines) + "\n";
    return (rewritten, stub_js, state["changed"]);
}

impl _build_harness(
    module_js: str, tests: list, api_base_url: str = "", storage: (dict | None) = None
) -> str {
    imports = "\n".join([m.group(0).strip() for m in _IMPORT_LINE.finditer(module_js)]);
    body = _IMPORT_LINE.sub("", module_js);

    storage_json = json.dumps(storage or {});
    base_url_json = json.dumps(api_base_url or "");
    prelude = _PRELUDE_TEMPLATE.replace("%%BASE_URL%%", base_url_json).replace(
        "%%STORAGE%%", storage_json
    );

    entries = [];
    for t in tests {
        entries.append(
            "  [" + json.dumps(t["name"]) + ", " + json.dumps(
                t.get("description", t["name"])
            ) + ", " + t["name"] + "]"
        );
    }
    fn_entries = ",\n".join(entries);
    epilogue = _EPILOGUE_TEMPLATE.replace("%%FN_ENTRIES%%", fn_entries).replace(
        "%%SENTINEL%%", _RESULT_SENTINEL
    );

    return imports + "\n" + prelude + "\n" + body + "\n" + epilogue;
}

impl find_server_entry(
    test_filepath: str, server_imports: (list[str] | None) = None
) -> (str | None) {
    test_dir = Path(test_filepath).resolve().parent;
    override = os.environ.get("JAC_CL_TEST_SERVER");
    if override {
        cand = Path(override);
        if not cand.is_absolute() {
            cand = test_dir / override;
        }
        return str(cand) if cand.exists() else None;
    }
    # Explicit, in-code declaration wins: boot the backend the test `sv import`s.
    # Resolved by import path, so the test stays correct wherever it lives.
    existing = [
        p
        for p in (server_imports or [])
        if Path(p).exists()
    ];
    if existing {
        if len(set(existing)) > 1 {
            console.warning(
                f"{Path(test_filepath).name} sv-imports multiple backends; "
                f"booting {existing[0]} (ignoring {sorted(set(existing[1:]))})"
            );
        }
        return existing[0];
    }
    # Fallback: filename convention in the test's own directory. Announce it so a
    # rename can't silently swap which backend boots.
    for name in _SERVER_ENTRY_NAMES {
        cand = test_dir / name;
        if cand.exists() {
            console.warning(
                f"{Path(test_filepath).name} declares no `sv import` backend; "
                f"falling back to sibling {name}"
            );
            return str(cand);
        }
    }
    return None;
}

impl _serve_in_background(server_entry: str, base_path: str) -> Iterator[int] {
    # Pick a free ephemeral port for the child to bind.
    sock = socket.socket();
    sock.bind(("127.0.0.1", 0));
    port = sock.getsockname()[1];
    sock.close();

    # Isolate persistence to the throwaway base dir for both the base runtime
    # (honors JAC_DATA_PATH) and jac-scale (cwd-relative shelf db); never touch a
    # real Mongo the developer happens to have configured.
    env = dict(os.environ);
    env["JAC_DATA_PATH"] = base_path;
    env.pop("MONGODB_URI", None);

    log_path = Path(base_path) / "cl_test_server.log";
    logf = open(str(log_path), "w+", encoding="utf-8");
    proc = subprocess.Popen(
        [
            sys.executable,
            "-c",
            _SERVER_LAUNCHER,
            str(Path(server_entry).resolve()),
            str(port)
        ],
        cwd=base_path,
        env=env,
        stdout=logf,
        stderr=subprocess.STDOUT,
        text=True
    );

    def _server_log -> str {
        with suppress(Exception) {
            logf.flush();
            return Path(str(log_path)).read_text(
                encoding="utf-8", errors="replace"
            ).strip();
        }
        return "";
    }

    try {
        # Wait until the server accepts TCP connections (server-class agnostic),
        # failing fast if the child dies first. A cold-cache start compiles the
        # fixture and any uncached package modules through full type inference
        # (typed-tree contract), which can exceed 30s on slower CI runners, so
        # give the boot a generous budget; warm starts connect within seconds.
        boot_budget = 90.0;
        deadline = time.monotonic() + boot_budget;
        while True {
            if proc.poll() is not None {
                raise RuntimeError(
                    f"cl test server ({server_entry}) exited early "
                    f"(code {proc.returncode}):\n{_server_log() or 'no output'}"
                );
            }
            probe = socket.socket();
            probe.settimeout(0.5);
            connected = False;
            try {
                probe.connect(("127.0.0.1", port));
                connected = True;
            } except OSError {
                ;
            } finally {
                probe.close();
            }
            if connected {
                break;
            }
            if time.monotonic() > deadline {
                raise RuntimeError(
                    f"cl test server ({server_entry}) was not reachable within "
                    f"{boot_budget:.0f}s:\n{_server_log() or 'no output'}"
                );
            }
            time.sleep(0.1);
        }
        yield port;
    } finally {
        # Teardown must never mask test results. SIGTERM lets jac-scale drain
        # gracefully; fall back to a hard kill if it lingers.
        with suppress(Exception) {
            proc.terminate();
            try {
                proc.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                proc.kill();
            }
        }
        with suppress(Exception) {
            logf.close();
        }
    }
}

impl run_cl_test_file(
    filepath: str,
    api_base_url: (str | None) = None,
    test_name: (str | None) = None,
    storage: (dict | None) = None,
    serve: bool = True,
    timeout: float = 120.0
) -> list[ClTestResult] {
    (module_js, tests, imports, server_imports) = compile_cl_module(filepath);
    if test_name {
        tests = [
            t
            for t in tests
            if t["name"] == test_name
        ];
    }
    if not tests {
        return [];
    }

    needs_server = serve and (api_base_url is None) and ("@jac/runtime" in imports);
    if needs_server {
        server_entry = find_server_entry(filepath, server_imports);
        if server_entry is not None {
            server_base = tempfile.mkdtemp(prefix="jac_cl_test_srv_");
            try {
                with _serve_in_background(server_entry, server_base) as port {
                    return _run_harness(
                        module_js,
                        tests,
                        imports,
                        api_base_url=f"http://127.0.0.1:{port}",
                        storage=storage,
                        timeout=timeout
                    );
                }
            } finally {
                shutil.rmtree(server_base, ignore_errors=True);
            }
        }
    }

    return _run_harness(
        module_js,
        tests,
        imports,
        api_base_url=api_base_url or "",
        storage=storage,
        timeout=timeout
    );
}

impl _run_harness(
    module_js: str,
    tests: list,
    imports: dict,
    api_base_url: str,
    storage: (dict | None),
    timeout: float
) -> list[ClTestResult] {
    import from jaclang.runtimelib.client.bun_installer { get_bun }
    # Reuse core's bun resolver -- the same one the client bundler uses -- which
    # locates bun on PATH / in .jac/bin and auto-downloads it when missing.
    bun = get_bun();
    if bun is None {
        raise RuntimeError(
            "bun is required to run client (cl) tests but could not be located "
            "or installed."
        );
    }

    work_dir = Path(tempfile.mkdtemp(prefix="jac_cl_test_"));
    try {
        if "@jac/runtime" in imports {
            import from jaclang.runtimelib.client_surface {
                prepend_active_runtime_globals
            }
            runtime_js = _compile_runtime_js();
            # Add the runtime-global import the compiler relies on, the same way
            # every bundle path does -- so `root spawn` / JSX resolve here too.
            module_js = prepend_active_runtime_globals(module_js);
            # Point the `@jac/runtime` specifier at the runtime we just compiled
            # alongside the harness (both quote styles the codegen may emit).
            module_js = module_js.replace('"@jac/runtime"', '"./jac_runtime.js"');
            module_js = module_js.replace("'@jac/runtime'", "'./jac_runtime.js'");
            # The runtime shim re-exports a framework-agnostic core sibling, whose
            # compiled import resolves the core by dotted module path. Compile the
            # sibling, emit it flat next to jac_runtime.js, and rewrite the import
            # to the flat specifier so bun resolves it (mirrors the Vite bundler's
            # ViteCompiler.compile_runtime_utils).
            core_specifier = "./jaclang/runtimelib/client_runtime_core.js";
            core_js = None;
            if core_specifier in runtime_js {
                core_js = _compile_runtime_core_js();
                runtime_js = runtime_js.replace(
                    core_specifier, "./client_runtime_core.js"
                );
            }
            # Redirect React/etc. npm imports (unused by the fetch/auth path) to
            # a generated stub so bun resolves without a real install.
            sources = [module_js, runtime_js];
            if core_js is not None {
                sources.append(core_js);
            }
            (rewritten, stub_js, changed) = _stub_npm_imports(sources);
            module_js = rewritten[0];
            runtime_js = rewritten[1];
            if core_js is not None {
                core_js = rewritten[2];
            }
            if changed {
                (work_dir / _NPM_STUB_FILE).write_text(stub_js, encoding="utf-8");
            }
            (work_dir / "jac_runtime.js").write_text(runtime_js, encoding="utf-8");
            if core_js is not None {
                (work_dir / "client_runtime_core.js").write_text(
                    core_js, encoding="utf-8"
                );
            }
        }

        harness = _build_harness(
            module_js, tests, api_base_url=api_base_url, storage=storage
        );
        harness_path = work_dir / "harness.mjs";
        harness_path.write_text(harness, encoding="utf-8");

        proc = subprocess.run(
            [bun, "run", str(harness_path)],
            cwd=str(work_dir),
            capture_output=True,
            text=True,
            timeout=timeout
        );

        results = _parse_results(proc.stdout, tests);
        if results is None {
            # The harness never produced a result line -- treat as a hard
            # failure for every test, surfacing bun's stderr for diagnosis.
            detail = (proc.stderr or proc.stdout or "no output").strip();
            return [
                ClTestResult(
                    name=t["name"],
                    description=t.get("description", t["name"]),
                    ok=False,
                    error=f"cl test harness did not run (exit {proc.returncode}):\n{detail}"
                ) for t in tests
            ];
        }
        return results;
    } finally {
        shutil.rmtree(str(work_dir), ignore_errors=True);
    }
}

impl _parse_results(stdout: str, tests: list) -> (list[ClTestResult] | None) {
    for line in stdout.splitlines() {
        if line.startswith(_RESULT_SENTINEL) {
            payload = json.loads(line[len(_RESULT_SENTINEL):]);
            return [
                ClTestResult(
                    name=item["name"],
                    description=item.get("description", item["name"]),
                    ok=bool(item["ok"]),
                    error=item.get("error")
                ) for item in payload
            ];
        }
    }
    return None;
}

impl is_cl_test_file(filepath: str) -> bool {
    name = os.path.basename(str(filepath));
    return name.endswith(".cl.jac");
}

impl is_cl_test_file_for_discovery(filepath: str) -> bool {
    name = os.path.basename(str(filepath));
    if not name.endswith(".cl.jac") {
        return False;
    }
    return name.startswith("test_") or name.endswith(".test.cl.jac");
}

impl register_results_into_jactestcheck(filepath: str, results: list) -> None {
    import from jaclang.runtimelib.test { JacTestCheck }

    for res in results {
        def make_case(r: ClTestResult) -> Callable {
            def synthetic_case {
                if not r.ok {
                    raise AssertionError(r.error or "client test failed");
                }
            }
            synthetic_case.__name__ = r.name;
            synthetic_case.__qualname__ = r.name;
            return synthetic_case;
        }
        JacTestCheck.add_test(
            str(filepath), res.name, make_case(res), display_name=res.description
        );
    }
}
