import json;
import os;
import posixpath;
import re;
import shutil;
import socket;
import subprocess;
import sys;
import tempfile;
import time;
import from contextlib { suppress }
import from pathlib { Path }
import from jaclang.cli.console { console }

impl compile_cl_module(filepath: str) -> tuple[str, list, dict, list] {
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

    runtime_src = resolve_jac_virtual_module_path("@jac/runtime");
    if (not runtime_src) or (not Path(runtime_src).exists()) {
        raise RuntimeError("could not resolve @jac/runtime to a client runtime source");
    }
    (js, _tests, _imports, _server_imports) = compile_cl_module(runtime_src);
    return js;
}

impl _compile_runtime_core_js -> str {
    import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_path }

    runtime_src = resolve_jac_virtual_module_path("@jac/runtime");
    if (not runtime_src) or (not Path(runtime_src).exists()) {
        raise RuntimeError("could not resolve @jac/runtime to a client runtime source");
    }
    core_path = Path(runtime_src).parent / "client_runtime_core.jac";
    if not core_path.exists() {
        raise RuntimeError("could not resolve client_runtime_core sibling source");
    }
    (js, _tests, _imports, _server_imports) = compile_cl_module(str(core_path));
    return js;
}

impl _scan_all_specs(js: str) -> dict[str, dict] {
    uses: dict[str, dict] = {};

    def record(spec: str) -> dict {
        if spec not in uses {
            uses[spec] = {"named": set(), "default": False, "star": False};
        }
        return uses[spec];
    }

    def collect(use: dict, clause: str) {
        brace = re.search(r"\{([^}]*)\}", clause);
        if brace {
            for ident in _NAMED_BINDING.findall(brace.group(1)) {
                if ident and (ident != "as") {
                    use["named"].add(ident);
                }
            }
        }
    }

    for m in _IMPORT_FROM.finditer(js) {
        use = record(m.group("spec"));
        clause = str(m.group("clause")).strip();
        collect(use, clause);
        head = clause.split("{")[0].split(",")[0].strip();
        if head and (not head.startswith("*")) {
            use["default"] = True;
        }
    }
    for m in _EXPORT_FROM.finditer(js) {
        use = record(m.group("spec"));
        clause = str(m.group("clause")).strip();
        collect(use, clause);

        if clause.startswith("*") and (" as " not in clause) {
            use["star"] = True;
        }
    }
    for m in _BARE_IMPORT.finditer(js) {
        record(m.group("spec"));
    }
    for m in _DYNAMIC_IMPORT.finditer(js) {
        record(m.group("spec"));
    }
    for m in _REQUIRE_CALL.finditer(js) {
        record(m.group("spec"));
    }
    return uses;
}

impl _scan_import_specs(js: str) -> dict[str, dict] {
    bare: dict[str, dict] = {};
    for (spec, use) in _scan_all_specs(js).items() {
        if spec.startswith(".") or spec.startswith(_NATIVE_PREFIXES) {
            continue;
        }
        bare[spec] = use;
    }
    return bare;
}

impl _scan_relative_specs(js: str) -> list[str] {
    found: list[str] = [];
    for spec in _scan_all_specs(js).keys() {
        if spec.startswith(".") {
            found.append(spec);
        }
    }
    return sorted(found);
}

impl _resolve_relative_source(base_dir: str, spec: str) -> (str | None) {
    base = Path(base_dir);
    direct = base / spec;
    cands: list[Path] = [direct];
    for ext in _REL_EXTS {
        cands.append(base / (spec + ext));
        cands.append(direct / ("index" + ext));
    }
    for cand in cands {
        if cand.is_file() {
            return str(cand.resolve());
        }
    }
    return None;
}

impl _mock_target(spec: str) -> str {
    return "./" + _MOCKS_DIR + "/" + spec.strip("/") + ".js";
}

impl _client_test_settings(
    source_path: (str | None)
) -> tuple[str, dict, (str | None)] {
    import from jaclang.project.config { get_config_for_path }

    if not source_path {
        return ("note", {}, None);
    }
    start = Path(source_path).resolve().parent;
    config = get_config_for_path(start);
    if config is None {
        return ("note", {}, None);
    }
    client = config.`test.client;
    base_dir = start if config.toml_path is None else config.toml_path.parent;
    return (client.on_stub or "note", dict(client.mocks or {}), str(base_dir));
}

impl _mock_sources_for(source_path: (str | None)) -> dict[str, str] {
    (_on_stub, mocks, base_str) = _client_test_settings(source_path);
    if base_str is None {
        return {};
    }
    base_dir = Path(base_str);
    found: dict[str, str] = {};

    search_root = base_dir.joinpath(*_MOCK_SEARCH_DIR);
    if search_root.is_dir() {
        for cand in sorted(search_root.rglob("*")) {
            if (not cand.is_file()) or (cand.suffix not in (".js", ".jac")) {
                continue;
            }
            spec = cand.relative_to(search_root).with_suffix("").as_posix();
            found[spec] = str(cand.resolve());
        }
    }

    for (spec, rel) in mocks.items() {
        cand = Path(rel);
        if not cand.is_absolute() {
            cand = base_dir / cand;
        }
        if cand.suffix not in (".js", ".jac") {
            raise RuntimeError(
                f"[test.client.mocks] '{spec}' points at '{rel}': a mock must "
                "be a .js or .jac module"
            );
        }
        if not cand.is_file() {
            raise RuntimeError(
                f"[test.client.mocks] '{spec}' points at '{rel}', which does "
                f"not exist (resolved against {base_dir} to {cand})"
            );
        }
        found[spec] = str(cand.resolve());
    }
    return found;
}

impl _render_tsconfig(paths: dict[str, str]) -> str {
    entries: dict[str, list] = {};
    for spec in sorted(paths.keys()) {
        entries[spec] = [paths[spec]];
    }
    return json.dumps({"compilerOptions": {"baseUrl": ".", "paths": entries}}, indent=2)
        + "\n";
}

impl _render_npm_stub(named: set, needs_default: bool) -> str {
    lines = ["const __jacNpmStub = new Proxy(function () {}, {"];
    lines.append("  get: () => __jacNpmStub, apply: () => __jacNpmStub,");
    lines.append("});");
    if needs_default {
        lines.append("export default __jacNpmStub;");
    }
    for name in sorted(named) {
        lines.append(f"export const {name} = __jacNpmStub;");
    }
    return "\n".join(lines) + "\n";
}

impl _report_stubbed(source_path: (str | None), plan: ClImportPlan) -> None {
    if not plan.stubbed {
        return;
    }
    (on_stub, _mocks, _base) = _client_test_settings(source_path);
    listed = ", ".join(sorted(plan.stubbed));
    label = Path(source_path).name if source_path else "cl test";
    message = (
        f"{label}: stubbed npm imports with the universal proxy: {listed}. "
        "Assertions against these are vacuous; supply a mock to make them real."
    );
    if plan.star_stubbed {
        starred = ", ".join(sorted(plan.star_stubbed));
        message += (
            " A proxy stub also cannot forward names through 'export * from' "
            f"({starred}); importing a name that way fails at load time, so "
            "those specs need a mock rather than a stub."
        );
    }
    if on_stub == "error" {
        raise RuntimeError(message);
    }
    if on_stub == "warn" {
        console.warning(message);
    } else {
        console.info(message);
    }
}

impl _resolve_client_imports(
    source_path: (str | None), entry_js: str, dep_files: dict[str, str]
) -> ClImportPlan {
    import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_path }

    plan = ClImportPlan();
    mocks = _mock_sources_for(source_path);
    uses: dict[str, dict] = {};

    pending: list[tuple] = [(entry_js, None, None)];
    seen_sources: set = set();
    for (_dep_name, dep_js) in dep_files.items() {
        pending.append((dep_js, None, None));
    }

    def merge(spec: str, use: dict) {
        if spec not in uses {
            uses[spec] = {"named": set(), "default": False, "star": False};
        }
        uses[spec]["named"] |= use["named"];
        uses[spec]["default"] = uses[spec]["default"] or use["default"];
        uses[spec]["star"] = uses[spec]["star"] or use["star"];
    }

    def stage_relatives(js: str, src_file: str, staged_path: str) {
        base_dir = str(Path(src_file).parent);
        staged_dir = posixpath.dirname(staged_path);
        for spec in _scan_relative_specs(js) {
            dep_src = _resolve_relative_source(base_dir, spec);
            if dep_src is None {
                raise RuntimeError(
                    f"mock '{staged_path}' imports '{spec}', which does not "
                    f"resolve to a file next to {src_file}"
                );
            }

            rel = os.path.relpath(dep_src, base_dir).replace(os.sep, "/");
            dep_staged = posixpath.normpath(posixpath.join(staged_dir, rel));
            if dep_staged.startswith("..") {
                raise RuntimeError(
                    f"mock '{staged_path}' imports '{spec}', which resolves "
                    "outside the harness directory; keep the files a mock "
                    "needs beside it"
                );
            }
            if (dep_src, dep_staged) in seen_sources {
                continue;
            }
            seen_sources.add((dep_src, dep_staged));
            dep_js = Path(dep_src).read_text(encoding="utf-8");
            plan.staged[dep_staged] = dep_js;
            pending.append((dep_js, dep_src, dep_staged));
        }
    }

    def stage_virtual(spec: str) {
        src = resolve_jac_virtual_module_path(spec);
        if (not src) or (not Path(src).exists()) {
            raise RuntimeError(
                f"cl test harness could not resolve virtual module '{spec}' to "
                "a client source"
            );
        }
        if spec == _RUNTIME_SPEC {
            plan.uses_runtime = True;
            js = _compile_runtime_js();
            core_match = re.search(
                r'from\s+[\'\"]([^\'\"]*client_runtime_core\.js)[\'\"]', js
            );
            if core_match {
                js = js.replace(core_match.group(1), "./client_runtime_core.js");
                core_js = _compile_runtime_core_js();
                plan.staged["client_runtime_core.js"] = core_js;
                pending.append((core_js, None, None));
            }
            plan.staged["jac_runtime.js"] = js;
            plan.paths[spec] = "./jac_runtime.js";
            pending.append((js, None, None));
            return;
        }
        (js, _t, _i, _s) = compile_cl_module(src);
        target = "jac_" + spec[len(_VIRTUAL_PREFIX):].replace("/", "_") + ".js";
        plan.staged[target] = js;
        plan.paths[spec] = "./" + target;
        pending.append((js, None, None));
    }

    def stage_mock(spec: str, path: str) {
        target = _mock_target(spec);
        staged_path = target[2:];
        if path.endswith(".jac") {
            (js, _t, _i, _s) = compile_cl_module(path);
            if not js.strip() {
                raise RuntimeError(
                    f"mock for '{spec}' ({path}) compiled to no client code, so "
                    "it cannot stand in for an npm module; add a "
                    "[placement.pins] entry setting it to 'client'"
                );
            }
            siblings = _scan_relative_specs(js);
            if siblings {
                raise RuntimeError(
                    f"mock for '{spec}' ({path}) imports "
                    f"{', '.join(siblings)}; a .jac mock that pulls in sibling "
                    "modules is not supported yet -- inline what it needs, or "
                    "write the mock in JavaScript"
                );
            }
            plan.staged[staged_path] = js;
            plan.paths[spec] = target;
            pending.append((js, None, None));
            return;
        }
        js = Path(path).read_text(encoding="utf-8");
        resolved = str(Path(path).resolve());
        seen_sources.add((resolved, staged_path));
        plan.staged[staged_path] = js;
        plan.paths[spec] = target;
        pending.append((js, resolved, staged_path));
    }

    while pending {
        (js, src_file, staged_path) = pending.pop(0);
        if src_file is not None {
            stage_relatives(js, src_file, staged_path);
        }
        for (spec, use) in _scan_import_specs(js).items() {
            already = spec in uses;
            merge(spec, use);
            if already {
                continue;
            }
            if spec in mocks {
                stage_mock(spec, mocks[spec]);
            } elif spec.startswith(_VIRTUAL_PREFIX) {
                stage_virtual(spec);
            } else {
                plan.paths[spec] = "./" + _NPM_STUB_FILE;
                plan.stubbed.append(spec);
            }
        }
    }

    stub_named: set = set();
    stub_default = False;
    for spec in plan.stubbed {
        stub_named |= uses[spec]["named"];
        stub_default = stub_default or uses[spec]["default"];
        if uses[spec]["star"] {
            plan.star_stubbed.append(spec);
        }
    }
    if plan.stubbed {
        plan.staged[_NPM_STUB_FILE] = _render_npm_stub(stub_named, stub_default);
    }
    return plan;
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
            "  ["
                + json.dumps(t["name"])
                + ", "
                + json.dumps(t.get("description", t["name"]))
                + ", "
                + t["name"]
                + "]"
        );
    }
    fn_entries = ",\n".join(entries);
    epilogue = _EPILOGUE_TEMPLATE.replace("%%FN_ENTRIES%%", fn_entries).replace(
        "%%SENTINEL%%", _RESULT_SENTINEL
    );

    return imports + "\n" + prelude + "\n" + body + "\n" + epilogue;
}

impl _collect_local_imports(
    module_js: str, source_dir: str, entry_path: str
) -> dict[str, str] {
    staged: dict[str, str] = {};
    requested: dict = {};
    pending: list[str] = [module_js];
    while pending {
        js = pending.pop(0);
        for m in _IMPORT_FROM.finditer(js) {
            spec = m.group("spec");
            if (not spec.startswith(".")) or (not spec.endswith(".js")) {
                continue;
            }
            name = spec[2:] if spec.startswith("./") else spec;
            if name == _NPM_STUB_FILE {
                continue;
            }
            if (not spec.startswith("./")) or ("/" in name) {
                raise RuntimeError(
                    f"cl test harness cannot stage local import '{spec}': only "
                    "same-directory './module.js' imports are supported"
                );
            }
            if name in ("jac_runtime.js", "client_runtime_core.js") {
                raise RuntimeError(
                    f"cl test harness cannot stage local import '{spec}': the "
                    "name is reserved for the staged client runtime"
                );
            }
            wanted = requested.setdefault(name, set());
            brace = re.search(r"\{([^}]*)\}", m.group("clause"));
            if brace {
                for ident in _NAMED_BINDING.findall(brace.group(1)) {
                    if ident and (ident != "as") {
                        wanted.add(ident);
                    }
                }
            }
            if name in staged {
                continue;
            }
            src_jac = os.path.join(source_dir, name[:-3] + ".jac");
            if os.path.abspath(src_jac) == os.path.abspath(entry_path) {
                raise RuntimeError(
                    f"cl test harness cannot stage local import '{spec}': it "
                    f"resolves back to the test module itself ({entry_path})"
                );
            }
            if not os.path.isfile(src_jac) {
                raise RuntimeError(
                    f"cl test harness could not stage local import '{spec}': "
                    f"expected sibling source {src_jac}"
                );
            }
            (dep_js, _dep_tests, _dep_imports, _dep_server) = compile_cl_module(
                src_jac
            );
            staged[name] = dep_js;
            pending.append(dep_js);
        }
    }
    for (dep_name, wanted_names) in requested.items() {
        if dep_name not in staged {
            continue;
        }
        already = _exported_names(staged[dep_name]);
        missing = sorted(
            [
                n
                for n in wanted_names
                if n not in already
            ]
        );
        if missing {
            staged[dep_name] = (
                staged[dep_name] + "\nexport { " + ", ".join(missing) + " };\n"
            );
        }
    }
    return staged;
}

impl _exported_names(js: str) -> set {
    names: set = set();
    for m in re.finditer(r"export\s*\{([^}]*)\}", js) {
        for part in m.group(1).split(",") {
            `entry = part.strip();
            if not `entry {
                continue;
            }
            names.add(`entry.split(" as ")[-1].strip());
        }
    }
    decl_pat = (
        r"export\s+(?:async\s+)?(?:const|let|var|function|class)\s+"
        r"([A-Za-z_$][\w$]*)"
    );
    for m in re.finditer(decl_pat, js) {
        names.add(m.group(1));
    }
    return names;
}

impl find_server_entry(
    test_filepath: str, server_imports: (list[str] | None) = None
) -> (str | None) {
    test_dir = Path(test_filepath).resolve().parent;
    `override = os.environ.get("JAC_CL_TEST_SERVER");
    if `override {
        cand = Path(`override);
        if not cand.is_absolute() {
            cand = test_dir / `override;
        }
        return str(cand) if cand.exists() else None;
    }

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
    sock = socket.socket();
    sock.bind(("127.0.0.1", 0));
    port = sock.getsockname()[1];
    sock.close();

    env = dict(os.environ);
    env["JAC_DATA_PATH"] = base_path;

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
        with suppress(Exception) {
            proc.terminate();
            try {
                proc.`wait(timeout=5);
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
                        api_base_url=f"http://127.0.0.1:{port}",
                        storage=storage,
                        timeout=timeout,
                        source_path=filepath
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
        api_base_url=api_base_url or "",
        storage=storage,
        timeout=timeout,
        source_path=filepath
    );
}

impl _run_harness(
    module_js: str,
    tests: list,
    api_base_url: str,
    storage: (dict | None),
    timeout: float,
    source_path: (str | None) = None
) -> list[ClTestResult] {
    import from jaclang.runtimelib.client.bun_installer { get_bun }

    bun = get_bun();
    if bun is None {
        raise RuntimeError(
            "bun is required to run client (cl) tests but could not be located "
            "or installed."
        );
    }

    work_dir = Path(tempfile.mkdtemp(prefix="jac_cl_test_"));
    try {
        dep_files: dict[str, str] = {};
        if source_path is not None {
            `entry = Path(source_path).resolve();
            dep_files = _collect_local_imports(
                module_js, str(`entry.parent), str(`entry)
            );
        }

        plan = _resolve_client_imports(source_path, module_js, dep_files);

        if plan.uses_runtime {
            import from jaclang.runtimelib.client_surface {
                prepend_active_runtime_globals
            }
            module_js = prepend_active_runtime_globals(module_js);
        }

        staged: dict[str, str] = dict(plan.staged);
        for (dep_name, dep_js) in dep_files.items() {
            staged[dep_name] = dep_js;
        }

        for (staged_name, staged_js) in staged.items() {
            target = work_dir / staged_name;
            target.parent.mkdir(parents=True, exist_ok=True);
            target.write_text(staged_js, encoding="utf-8");
        }
        (work_dir / _TSCONFIG_FILE).write_text(
            _render_tsconfig(plan.paths), encoding="utf-8"
        );
        _report_stubbed(source_path, plan);

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

impl module_is_client(filepath: str) -> bool {
    path = os.path.abspath(str(filepath));
    if path in _COLOR_CACHE {
        return _COLOR_CACHE[path];
    }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.constant { CodeContext }
    import from jaclang.jac0core.program { JacProgram }
    result = False;
    try {
        mod = JacProgram().compile(
            path, options=CompileOptions(symtab_ir_only=True, type_check=False)
        );
        result = mod is not None
            and mod.declares_codespace(CodeContext.CLIENT, path_hint=path);
    } except Exception as probe_exc {
        import from jaclang.jac0core.compiler {
            CompilerSourceError,
            compiler_source_failure_origin
        }
        origin = compiler_source_failure_origin(probe_exc);
        if origin is not None {
            raise CompilerSourceError(
                f"the client-codespace probe for {path} failed inside the "
                f"compiler's own source ({origin}), so the module's codespace "
                f"is unknown; refusing to degrade it to the server codespace: "
                f"{type(probe_exc).__name__}: {probe_exc}"
            ) from probe_exc;
        }
        try {
            os.write(
                2,
                (
                    f"jac: client-codespace probe failed for {path}; "
                    f"treating as server: {type(probe_exc).__name__}: "
                    f"{probe_exc}\n"
                ).encode(
                    "utf-8", "replace"
                )
            );
        } except OSError { }
        result = False;
    }
    _COLOR_CACHE[path] = result;
    return result;
}

impl is_cl_test_file(filepath: str) -> bool {
    return module_is_client(filepath);
}

impl is_cl_test_file_for_discovery(filepath: str) -> bool {
    name = os.path.basename(str(filepath));
    if not name.startswith("test_") {
        return False;
    }
    return module_is_client(filepath);
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
