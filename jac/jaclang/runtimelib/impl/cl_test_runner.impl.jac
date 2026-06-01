"""Implementation of the client (`cl`) test runner."""

import json;
import os;
import re;
import shutil;
import socket;
import subprocess;
import tempfile;
import threading;
import importlib;
import from contextlib { suppress }
import from pathlib { Path }
import from collections.abc { Callable }

impl find_bun -> (str | None) {
    found = shutil.which("bun");
    if found {
        return found;
    }
    candidates = [
        Path.home() / ".bun" / "bin" / "bun",
        Path.cwd() / ".jac" / "bin" / "bun"
    ];
    for cand in candidates {
        if cand.is_file() and os.access(cand, os.X_OK) {
            return str(cand);
        }
    }
    return None;
}

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
    return (mod.gen.js, tests, imports);
}

impl _compile_runtime_js -> str {
    try {
        _plugin = importlib.import_module("jac_client.plugin");
    } except Exception as exc {
        raise RuntimeError(
            "client tests use @jac/runtime but the jac-client plugin is not "
            f"installed: {exc}"
        );
    }
    # jac_client.plugin is a namespace package (__file__ is None); resolve the
    # runtime source via the package search path.
    runtime_src = None;
    for pkg_dir in list(getattr(_plugin, "__path__", [])) {
        cand = Path(pkg_dir) / "client_runtime.cl.jac";
        if cand.exists() {
            runtime_src = cand;
            break;
        }
    }
    if runtime_src is None {
        raise RuntimeError(
            "could not locate client_runtime.cl.jac in the jac-client plugin"
        );
    }
    (js, _tests, _imports) = compile_cl_module(runtime_src);
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

impl find_server_entry(test_filepath: str) -> (str | None) {
    test_dir = Path(test_filepath).resolve().parent;
    override = os.environ.get("JAC_CL_TEST_SERVER");
    if override {
        cand = Path(override);
        if not cand.is_absolute() {
            cand = test_dir / override;
        }
        return str(cand) if cand.exists() else None;
    }
    for name in _SERVER_ENTRY_NAMES {
        cand = test_dir / name;
        if cand.exists() {
            return str(cand);
        }
    }
    return None;
}

impl _serve_in_background(server_entry: str, base_path: str) -> Iterator[int] {
    import from jaclang { JacRuntime as Jac }
    import from jaclang.runtimelib.server { JacAPIServer }

    sock = socket.socket();
    sock.bind(("127.0.0.1", 0));
    port = sock.getsockname()[1];
    sock.close();

    (base, mod) = os.path.split(server_entry);
    base = base or "./";
    if mod.endswith(".jac") {
        mod = mod[:-4];
    }

    Jac.set_base_path(base_path);
    ctx = Jac.create_j_context(
        user_root=None,
        base_path_dir=base_path,
        full_target_path=str(Path(server_entry).resolve())
    );
    Jac.set_context(ctx);
    Jac.jac_import(target=mod, base_path=base, lng="jac");

    server = JacAPIServer(module_name=mod, port=port, base_path=base_path);
    server.load_module();

    ready = threading.Event();
    error = {};

    def _on_ready(*a: any) {
        ready.set();
    }

    def _run {
        try {
            server.start(no_client=True, on_ready=_on_ready);
        } except Exception as exc {
            error["exc"] = exc;
            ready.set();
        }
    }

    thread = threading.Thread(target=_run, daemon=True);
    thread.start();
    if not ready.wait(timeout=30) {
        raise RuntimeError(f"cl test server ({server_entry}) failed to start");
    }
    if "exc" in error {
        raise RuntimeError(f"cl test server ({server_entry}) errored: {error['exc']}");
    }
    try {
        yield port;
    } finally {
        # Teardown must never mask test results.
        with suppress(Exception) {
            if server.server is not None {
                server.server.shutdown();
            }
        }
        thread.join(timeout=5);
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
    (module_js, tests, imports) = compile_cl_module(filepath);
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
        server_entry = find_server_entry(filepath);
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
    bun = find_bun();
    if bun is None {
        raise RuntimeError(
            "bun is required to run client (cl) tests but was not found on PATH "
            "or in ~/.bun/bin."
        );
    }

    work_dir = Path(tempfile.mkdtemp(prefix="jac_cl_test_"));
    try {
        if "@jac/runtime" in imports {
            runtime_js = _compile_runtime_js();
            module_js = module_js.replace('"@jac/runtime"', '"./jac_runtime.js"');
            module_js = module_js.replace("'@jac/runtime'", "'./jac_runtime.js'");
            # Redirect React/etc. npm imports (unused by the fetch/auth path) to
            # a generated stub so bun resolves without a real install.
            (rewritten, stub_js, changed) = _stub_npm_imports([module_js, runtime_js]);
            module_js = rewritten[0];
            runtime_js = rewritten[1];
            if changed {
                (work_dir / _NPM_STUB_FILE).write_text(stub_js, encoding="utf-8");
            }
            (work_dir / "jac_runtime.js").write_text(runtime_js, encoding="utf-8");
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
