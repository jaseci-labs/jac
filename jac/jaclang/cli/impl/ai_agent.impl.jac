import os;
import re;
import sys;
import time;
import signal;
import subprocess;
import threading;
import webbrowser;
import from pathlib { Path }

import from jaclang.byllm.lib { Model, IterationAction }
import from jaclang.byllm.config_loader { get_byllm_config }

import from jaclang.compiler.code_intel { CodeIntelligence }
import from jaclang.cli.console { console }
import from jaclang.cli.guide_store { list_guides as gs_list, get_guide as gs_get }
import from jaclang.cli.browser_engine {
    cmd_open as br_open,
    cmd_navigate as br_navigate,
    cmd_snapshot as br_snapshot,
    cmd_click as br_click,
    cmd_type as br_type,
    cmd_fill as br_fill,
    cmd_press as br_press,
    cmd_get as br_get,
    cmd_eval as br_eval,
    cmd_close as br_close
}


impl _byllm_config -> any {
    if agent.ws.cwd {
        return get_byllm_config(Path(agent.ws.cwd));
    }
    return get_byllm_config();
}

impl resolve_model_name(model_override: str = "") -> str {
    flag = model_override.strip();
    if flag {
        agent.cfg.model_source = "command line";
        return flag;
    }

    toml_model = "";
    try {
        raw = _byllm_config().get_jac_config().get_plugin_config("byllm");
        model_section = raw.get("model", {});
        if isinstance(model_section, dict) {
            toml_model = str(model_section.get("default_model", "")).strip();
        }
    } except Exception {
        toml_model = "";
    }
    if toml_model {
        agent.cfg.model_source = "jac.toml";
        return toml_model;
    }
    agent.cfg.model_source = "default";
    return "local:gemma-4-e4b";
}

impl build_model(model_override: str = "", n_ctx: int = 0) -> Model {
    name = resolve_model_name(model_override);
    cfg: dict[str, object] = {};
    is_local = name.startswith("local:");

    agent.cfg.threads = 0;

    agent.cfg.temperature = 0.3 if is_local else None;
    if is_local {
        try {
            cfg = dict(_byllm_config().get_local_config());
        } except Exception {
            cfg = {};
        }

        if not cfg.get("n_threads") {
            cores = os.cpu_count() or 2;
            cfg["n_threads"] = max(1, cores // 2);
        }
        agent.cfg.threads = int(cfg.get("n_threads") or 0);
    } else {
        if agent.cfg.api_key {
            cfg["api_key"] = agent.cfg.api_key;
        }
        if agent.cfg.base_url {
            cfg["base_url"] = agent.cfg.base_url;
        }
    }
    if n_ctx > 0 {
        cfg["n_ctx"] = n_ctx;
    }
    return Model(model_name=name, config=cfg);
}

impl _model_needs_key(name: str) -> tuple[bool, str] {
    if not name or name.startswith("local:") {
        return (False, "");
    }

    if agent.cfg.api_key {
        return (False, "");
    }
    try {
        toml_key = str(_byllm_config().get_model_config().get("api_key", "") or "");
        if toml_key {
            return (False, "");
        }
    } except Exception { }

    try {
        import litellm;

        ll: any = litellm;
        info: any = ll.validate_environment(name);
        if info.get("keys_in_environment") {
            return (False, "");
        }
        missing: list = list(info.get("missing_keys", []) or []);
        for k in missing {
            if str(k).endswith("_API_KEY") {
                return (True, str(k));
            }
        }
    } except Exception { }
    return (False, "");
}

impl _refresh_key_status -> None {
    name = "";
    try {
        name = str(agent_model.model_name);
    } except Exception {
        name = "";
    }
    (needs, env) = _model_needs_key(name);
    agent.bus.needs_key = needs;
    agent.bus.key_env = env;
    agent.bus.model_name = name;
}

impl Workspace.resolve(path: str) -> str {
    p = path or ".";
    if os.path.isabs(p) {
        return os.path.normpath(p);
    }
    base = self.cwd or os.getcwd();
    return os.path.normpath(os.path.join(base, p));
}

impl Workspace.set_cwd(new_dir: str) {
    real = os.path.normpath(new_dir);
    if not os.path.isdir(real) or real == self.cwd {
        return;
    }
    prev_root = _project_root_of(self.cwd) if self.cwd else "";
    self.cwd = real;
    new_root = _project_root_of(real);

    if self.ci is not None and new_root != prev_root {
        try {
            new_ci = CodeIntelligence(proj_dir=new_root, lazy=True);
            new_ci.on_event = self.ci.on_event;
            self.ci = new_ci;
            self.ci_dirty = False;
        } except Exception as e {
            _ = e;
        }
    }
}

impl Workspace.code_intel -> any {
    if self.ci is None {
        return None;
    }
    if self.ci_dirty {
        try {
            self.ci.refresh();
            self.ci_dirty = False;
        } except Exception { }
    }
    return self.ci;
}

impl Workspace.project_errors -> list {
    ci = self.code_intel();
    if ci is None or not ci.is_loaded() {
        return [];
    }
    try {
        return [
            d
            for d in ci.diagnostics()
            if d.severity == "error"
        ];
    } except Exception {
        return [];
    }
}

impl _project_root_of(start: str) -> str {
    import from jaclang.jac0core.modresolver { find_project_root }
    import from pathlib { Path }
    result = find_project_root(Path(start));
    return str(result[0]) if result else os.path.normpath(start);
}

impl truncate(text: str, limit: int = 12000) -> str {
    if len(text) > limit {
        extra = len(text) - limit;
        return text[:limit] + f"\n... [truncated, {extra} more chars]";
    }
    return text;
}

impl confirm(action: str) -> bool {
    if agent.cfg.yolo_mode {
        return True;
    }
    console.print(f"  needs approval: {action}", style="yellow");
    try {
        answer = input("  Allow this action? [y/N] ").strip().lower();
    } except EOFError {
        return False;
    }
    return answer in ("y", "yes");
}

impl _count_diags(diags: list) -> tuple[int, int] {
    n_err = len(
        [
            d
            for d in diags
            if d.severity == "error"
        ]
    );
    return (n_err, len(diags) - n_err);
}

impl FileTools.write_feedback(path: str) -> str {
    if self.ws.ci is None or not self.cfg.inline_feedback {
        if self.ws.ci is not None and not self.cfg.inline_feedback {
            self.ws.ci_dirty = True;
        }
        return "";
    }

    self.ws.ci_dirty = True;
    try {
        diags: list = list(self.ws.ci.refresh_and_diff(path));
    } except Exception {
        return "";
    }
    self.ws.ci_dirty = False;
    if not diags {
        return "";
    }
    (n_err, n_warn) = _count_diags(diags);
    lines = [
        f"\ncompiler feedback for editing {path} -- {n_err} error(s), "
        f"{n_warn} warning(s); fix what you introduced (some may be in other "
        "files your edit affects):"
    ];
    for d in diags[:20] {
        lines.append("  " + str(d.render()));
    }
    if len(diags) > 20 {
        lines.append(f"  ... and {len(diags) - 20} more");
    }
    return "\n".join(lines);
}

impl FileTools._js_drift_error(path: str, content: str) -> str {
    base = os.path.basename(path);

    for ext in [".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs"] {
        if base.endswith(ext) {
            return (
                f"REFUSED: '{base}' is a JavaScript/TypeScript file, but this is a "
                "Jac project -- all source is Jac. Write a .jac file instead "
                "(a client UI component goes in a .cl.jac file, e.g. "
                "components/Calculator.cl.jac), using Jac syntax (def:pub "
                "Name() -> JsxElement, has fields, def handlers). Do not create "
                ".js/.ts files."
            );
        }
    }

    if not base.endswith(".jac") {
        return "";
    }

    checks: list[tuple[str, str]] = [
        (
            "`import React` / a React import",
            "import\\s+React\\b|from\\s+['\"]react['\"]"
        ),
        (
            "`export` (Jac has no export -- a `def:pub` is the public form)",
            "(?m)^\\s*export\\b"
        ),
        ("`function` (use `def`)", "(?m)^\\s*(async\\s+)?function\\b"),
        (
            "an arrow function `=>` (use `lambda(x: T) -> R { ... }`)",
            "(\\w|\\)|\\]|\\})\\s*=>"
        ),
        (
            "`const`/`let`/`var` (declare typed: `x: int = 1`)",
            "(?m)^\\s*(const|let|var)\\s"
        ),
        ("`this.` (use `self.`; props are function params)", "\\bthis\\."),
        (
            "a `constructor(` (a component is `def:pub Name() -> JsxElement`)",
            "(?m)^\\s*constructor\\s*\\("
        ),
        ("`===` / `!==` (use `==` / `!=`)", "===|!==")
    ];
    hits: list[str] = [];
    for (label, pat) in checks {
        if re.search(pat, content) {
            hits.append(label);
        }
    }
    if not hits {
        return "";
    }
    found = "; ".join(hits);
    return (
        f"REFUSED: {base} contains JavaScript/React, not Jac. Found: {found}. "
        "Rewrite it in Jac: a UI component is `def:pub Name(prop: T) -> "
        "JsxElement { has state: int = 0; def on_click(e: MouseEvent) {...} "
        "return <div>...</div>; }`. Read read_guide(\"jac-cl-components\") for "
        "the exact shapes, then write the file again as Jac."
    );
}

sem FileTools.read_file = "Read and return the full text of a file.";
sem FileTools.read_file.path = "Path to the file to read, relative to the project.";
impl FileTools.read_file(path: str) -> str {
    try {
        return truncate(Path(self.ws.resolve(path)).read_text(encoding="utf-8"));
    } except Exception as e {
        return f"ERROR reading {path}: {e}";
    }
}

sem FileTools.write_file = "Create a file or overwrite it entirely with new content.";
sem FileTools.write_file.path = "Path of the file to write.";
sem FileTools.write_file.content = "The full new contents of the file.";
impl FileTools.write_file(path: str, content: str) -> str {
    drift = self._js_drift_error(path, content);
    if drift {
        return drift;
    }
    if not confirm(f"write {len(content)} chars to {path}") {
        return "DENIED: the user declined this write.";
    }
    try {
        rp = self.ws.resolve(path);
        p = Path(rp);
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text(content, encoding="utf-8");
        return f"OK: wrote {len(content)} chars to {path}" + self.write_feedback(rp);
    } except Exception as e {
        return f"ERROR writing {path}: {e}";
    }
}

sem FileTools.edit_file = "Replace one exact, unique occurrence of text in a file.";
sem FileTools.edit_file.path = "Path of the file to edit.";
sem FileTools.edit_file.old_text = "Exact text to find; must occur exactly once in the file.";
sem FileTools.edit_file.new_text = "Text to replace it with.";
impl FileTools.edit_file(path: str, old_text: str, new_text: str) -> str {
    rp = self.ws.resolve(path);
    if not os.path.isfile(rp) {
        return (
            f"ERROR: {path} does not exist, so there is nothing to edit. "
            "Create it with write_file(path, content) instead. (Paths resolve "
            f"against the current directory {self.ws.cwd or os.getcwd()}.)"
        );
    }
    try {
        original = Path(rp).read_text(encoding="utf-8");
    } except Exception as e {
        return f"ERROR reading {path}: {e}";
    }
    occurrences = original.count(old_text);
    if occurrences == 0 {
        return f"ERROR: old_text was not found in {path}. Read the file first.";
    }
    if occurrences > 1 {
        return (
            f"ERROR: old_text appears {occurrences} times in {path}; "
            "include more surrounding context so it matches exactly once."
        );
    }
    updated = original.replace(old_text, new_text);
    drift = self._js_drift_error(path, updated);
    if drift {
        return drift;
    }
    if not confirm(f"edit {path}") {
        return "DENIED: the user declined this edit.";
    }
    try {
        Path(rp).write_text(updated, encoding="utf-8");
        return f"OK: edited {path}" + self.write_feedback(rp);
    } except Exception as e {
        return f"ERROR writing {path}: {e}";
    }
}

sem FileTools.list_dir = "List the entries of a directory (hidden entries excluded).";
sem FileTools.list_dir.path = "Directory path; empty string means the current directory.";
impl FileTools.list_dir(path: str) -> str {
    try {
        target = Path(self.ws.resolve(path));
        names: list[str] = [];
        for entry in sorted(target.iterdir()) {
            if entry.name.startswith(".") {
                continue;
            }
            names.append(entry.name + ("/" if entry.is_dir() else ""));
        }
        return "\n".join(names) or "(empty directory)";
    } except Exception as e {
        return f"ERROR listing {path}: {e}";
    }
}

sem FileTools.grep = "Search for a regular expression across .jac files (or one file).";
sem FileTools.grep.pattern = "Python regular expression to search for.";
sem FileTools.grep.path = "File or directory to search; empty string means current directory.";
impl FileTools.grep(pattern: str, path: str) -> str {
    try {
        regex = re.compile(pattern);
    } except Exception as e {
        return f"ERROR: invalid regular expression: {e}";
    }
    search_root = Path(self.ws.resolve(path));
    if search_root.is_file() {
        files = [search_root];
    } elif search_root.is_dir() {
        files = [
            f
            for f in search_root.rglob("*.jac")
            if f.is_file()
        ];
    } else {
        return f"ERROR: no such path: {path}";
    }
    hits: list[str] = [];
    for f in files {
        try {
            text = f.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        for (line_no, line) in enumerate(text.splitlines(), 1) {
            if regex.search(line) {
                hits.append(f"{f}:{line_no}: {line.strip()}");
                if len(hits) >= 100 {
                    return "\n".join(hits) + "\n... [stopped at 100 matches]";
                }
            }
        }
    }
    return "\n".join(hits) or "(no matches)";
}

impl ProcessTools._proc_output(result: any) -> str {
    combined = (str(result.stdout or "") + str(result.stderr or "")).strip();
    return truncate(combined or f"(no output; exit code {result.returncode})");
}

impl ProcessTools.run_jac_cli(subcommand: str, path: str) -> str {
    try {
        return self._proc_output(
            subprocess.run(
                [sys.executable, "-m", "jaclang", subcommand, path],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=self.ws.cwd or None
            )
        );
    } except Exception as e {
        return f"ERROR running `jac {subcommand} {path}`: {e}";
    }
}

sem ProcessTools.run_command = "Run a shell command in the project directory and return its combined output. Use this to scaffold a new project (`jac create --kind web-app <name>`), install dependencies (`jac install`), run a file (`jac run <file>`), run tests, or any other shell task. `jac create --kind <kind>` kinds: cli (default), web-app, service, native-binary, py-package, and more (run `jac create --list` for the full list).";
sem ProcessTools.run_command.command = "The shell command to run.";
impl ProcessTools.run_command(command: str) -> str {
    stripped = command.strip();
    if re.search("\\bjac\\s+(start|serve)\\b", stripped) and "--help" not in stripped {
        return (
            "Don't start the server with run_command -- it blocks. Use the "
            "serve(entry_file) tool instead: it launches the dev server, waits "
            "until it is actually ready, and returns the URL to browse_open. "
            "Then exercise the page and call stop_server when done."
        );
    }
    if not confirm(f"run shell command: {command}") {
        return "DENIED: the user declined to run this command.";
    }

    env = dict(os.environ);
    bin_dir = os.path.dirname(sys.executable);
    if bin_dir {
        env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "");
    }
    work_dir = self.ws.cwd or os.getcwd();

    marker = "__JAC_AI_CWD__";
    wrapped = (
        command + f"\n__jac_ai_rc=$?\nprintf '\\n{marker}%s\\n' \"$(pwd)\"\n"
        "exit $__jac_ai_rc"
    );
    try {
        result = subprocess.run(
            wrapped,
            shell=True,
            capture_output=True,
            text=True,
            timeout=180,
            env=env,
            cwd=work_dir
        );
    } except subprocess.TimeoutExpired {
        return f"ERROR: `{command}` timed out after 180s.";
    } except Exception as e {
        return f"ERROR running `{command}`: {e}";
    }
    stdout = str(result.stdout or "");
    new_cwd = "";
    kept: list[str] = [];
    for ln in stdout.splitlines() {
        if ln.startswith(marker) {
            new_cwd = ln[len(marker):].strip();
        } else {
            kept.append(ln);
        }
    }
    if new_cwd and new_cwd != work_dir {
        self.ws.set_cwd(new_cwd);
    }
    combined = ("\n".join(kept) + str(result.stderr or "")).strip();
    out = truncate(combined or f"(no output; exit code {result.returncode})");

    if new_cwd and new_cwd != work_dir {
        out = f"(now in {new_cwd})\n" + out;
    }
    return out;
}

sem ProcessTools.jac_check = "Type-check and compile Jac code with `jac check`. Pass a single file, or a directory (`.` for the whole project) to check everything at once. Use this after writing or editing Jac code to confirm it is valid.";
sem ProcessTools.jac_check.path = "File or directory to check; '.' or empty string checks the whole project.";
impl ProcessTools.jac_check(path: str) -> str {
    return self.run_jac_cli("check", path or ".");
}

sem ProcessTools.start_app = "Start the app with `jac start` for ~12 seconds to confirm it boots, then stop it; returns the startup logs. Use this after building an app to catch errors that `jac check` cannot.";
sem ProcessTools.start_app.entry_file = "Entry .jac file to start; empty string means 'main.jac'.";
impl ProcessTools.start_app(entry_file: str) -> str {
    entry_path = entry_file or "main.jac";
    abs_entry = self.ws.resolve(entry_path);
    if not os.path.isfile(abs_entry) {
        return (
            f"ERROR: no such entry file '{entry_path}' (looked in "
            f"{self.ws.cwd or os.getcwd()}). Use list_dir to find the app's "
            "main .jac file, then pass its path."
        );
    }
    if not confirm(f"start the app with `jac start {entry_path}`") {
        return "DENIED: the user declined to start the app.";
    }

    work_dir = os.path.dirname(abs_entry) or ".";
    target = os.path.basename(abs_entry);
    try {
        proc = subprocess.Popen(
            [sys.executable, "-m", "jaclang", "start", target],
            cwd=work_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        );
    } except Exception as e {
        return f"ERROR launching `jac start {entry_path}`: {e}";
    }

    boot_wait = 12.0;
    try {
        raw = os.environ.get("JAC_AI_START_TIMEOUT");
        if raw {
            boot_wait = float(raw);
        }
    } except Exception as e {
        _ = e;
    }
    time.sleep(boot_wait);
    proc.terminate();
    try {
        output = proc.communicate(timeout=10)[0];
    } except Exception {
        proc.kill();
        output = proc.communicate()[0];
    }
    return truncate(str(output) if output else "(no startup output)");
}

sem ProcessTools.serve = "Start the web/full-stack dev server and wait until it is actually serving, returning the URL to open. The first start can take a while because it installs the client dependencies and builds the client; this tool blocks until the server is ready (or fails) so you do not have to guess. On success, call browse_open on the returned URL. On failure it returns the server log tail -- read it, go back to Build to fix the cause, and do not conclude the app works.";
sem ProcessTools.serve.entry_file = "Entry .jac file to serve; empty string means 'main.jac'.";

def _poll_for_server_url(proc: object, log_path: str, timeout: float) -> str {
    url_re = re.compile(
        "https?://(?:localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)(?::\\d+)?\\S*"
    );
    deadline = time.time() + timeout;
    url = "";
    while time.time() < deadline {
        if proc.poll() is not None {
            break;
        }
        try {
            log_text = Path(log_path).read_text();
        } except Exception {
            log_text = "";
        }
        m = url_re.search(log_text);
        if m {
            url = m.group(0).rstrip("/");
            break;
        }
        time.sleep(1.0);
    }
    return url;
}

impl ProcessTools.serve(entry_file: str) -> str {
    entry_path = entry_file or "main.jac";
    abs_entry = self.ws.resolve(entry_path);
    if not os.path.isfile(abs_entry) {
        return (
            f"ERROR: no such entry file '{entry_path}' (looked in "
            f"{self.ws.cwd or os.getcwd()}). Use list_dir to find the app's "
            "main .jac file (the one with the `cl`/`sv` mount), then pass its path."
        );
    }
    if not confirm(f"start the dev server with `jac start {entry_path}`") {
        return "DENIED: the user declined to start the server.";
    }

    self._serve_shutdown();
    work_dir = os.path.dirname(abs_entry) or ".";
    target = os.path.basename(abs_entry);
    log_path = "/tmp/jac_ai_serve.log";
    try {
        log_f = open(log_path, "w", encoding="utf-8");

        self.serve_proc = subprocess.Popen(
            [sys.executable, "-m", "jaclang", "start", target],
            cwd=work_dir,
            stdout=log_f,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True
        );

        log_f.close();
    } except Exception as e {
        return f"ERROR launching `jac start {entry_path}`: {e}";
    }

    timeout = 120.0;
    try {
        raw = os.environ.get("JAC_AI_SERVE_TIMEOUT");
        if raw {
            timeout = float(raw);
        }
    } except Exception as e {
        _ = e;
    }

    url = _poll_for_server_url(self.serve_proc, log_path, timeout);
    if url {
        return (
            f"OK: server ready at {url} (logs: {log_path}). "
            f"Open it with browse_open(\"{url}\"), exercise it, then stop_server."
        );
    }
    tail = "";
    try {
        tail = "\n".join(Path(log_path).read_text().splitlines()[-25:]);
    } except Exception {
        tail = "(no log output)";
    }
    self._serve_shutdown();
    return (
        f"ERROR: the server did not become ready within {int(timeout)}s. "
        f"Last log lines:\n{tail}"
    );
}

sem ProcessTools.stop_server = "Stop the dev server started by serve. Call this when finished with browser QA.";

impl ProcessTools.stop_server -> str {
    self._serve_shutdown();
    return "OK: dev server stopped.";
}

impl ProcessTools._serve_shutdown{
    if self.serve_proc is not None {
        try {
            os.killpg(os.getpgid(int(self.serve_proc.pid)), int(signal.SIGTERM));
        } except Exception {
            try {
                self.serve_proc.terminate();
            } except Exception { }
        }
        self.serve_proc = None;
    }
}

sem GuideTools.search_guides = "Search the bundled Jac reference guides; returns matching guide names and descriptions ranked by relevance. Matches any word in the query, so several keywords broaden the search.";
sem GuideTools.search_guides.keyword = "Keywords to search guide names, descriptions, and bodies for.";
impl GuideTools.search_guides(keyword: str) -> str {
    words = [
        w
        for w in keyword.lower().split()
        if w
    ];
    if not words {
        return "(empty search)";
    }
    scored: list[tuple[int, str]] = [];
    for g in gs_list() {
        haystack = f"{g.name}\n{g.description}\n{g.body}".lower();
        hits = sum(
            [
                1
                for w in words
                if w in haystack
            ]
        );
        if hits > 0 {
            scored.append((-hits, f"{g.name}: {g.description}"));
        }
    }
    if not scored {
        return f"(no guides match '{keyword}')";
    }
    scored.sort();
    return "\n".join([line for (_, line) in scored]);
}

sem GuideTools.read_guide = "Read a bundled Jac reference guide in full -- the authoritative spec for writing correct, idiomatic Jac.";
sem GuideTools.read_guide.name = "Exact guide name, e.g. 'jac-walker-patterns'.";
impl GuideTools.read_guide(name: str) -> str {
    guide = gs_get(name);
    if guide is None {
        available = ", ".join([g.name for g in gs_list()]);
        return f"ERROR: no guide named '{name}'. Available guides: {available}";
    }
    return truncate(guide.body, 16000);
}

sem SemanticTools.find_symbol = "Look up a Jac symbol (node, walker, edge, obj, enum, ability, ...) by name via the compiler's symbol table. Returns its exact definition site, fields, abilities, base classes, and every place it is used. This is precise -- unlike grep it never matches a comment or an unrelated identifier. Prefer this over grep whenever you know the name of the thing you are looking for.";
sem SemanticTools.find_symbol.name = "The symbol name to look up, e.g. 'User' or 'make_user'.";
impl SemanticTools.find_symbol(name: str) -> str {
    ci = self.ws.code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    hits = ci.lookup(name);
    if not hits {
        return f"No Jac symbol named '{name}' is defined in this project.";
    }
    out: list[str] = [];
    for info in hits {
        out.append(str(info.render()));
    }
    uses = [
        r
        for r in ci.references(name)
        if r.role == "use"
    ];
    if uses {
        out.append(f"\nused in {len(uses)} place(s):");
        for r in uses[:25] {
            out.append("  " + str(r.render()));
        }
    }
    return "\n".join(out);
}

sem SemanticTools.find_uses = "List every definition and use of a symbol across the whole project, computed from the compiler's def/use chains. Use this before renaming or changing a symbol to see exactly what it touches.";
sem SemanticTools.find_uses.name = "The symbol name whose references to list.";
impl SemanticTools.find_uses(name: str) -> str {
    ci = self.ws.code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    refs = ci.references(name);
    if not refs {
        return f"No definitions or uses of '{name}' were found.";
    }
    lines: list[str] = [];
    for r in refs {
        lines.append(f"{r.role}  {r.render()}");
    }
    return "\n".join(lines);
}

sem SemanticTools.project_map = "Show every node, walker, edge, and object archetype in the project with its location -- a structural overview built from the compiler, not a directory listing. Use this first to understand an unfamiliar project.";
impl SemanticTools.project_map -> str {
    ci = self.ws.code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    archs = ci.archetypes();
    if not archs {
        return "(no nodes, walkers, edges, or objects found in the project)";
    }
    rows: list[str] = [];
    for a in archs {
        rows.append(f"{a.kind:7} {a.name}    [{a.file}:{a.line}]");
    }
    return "\n".join(sorted(rows));
}

sem SemanticTools.find_walkers = "Find every walker entry point that traverses a given node type -- an Object-Spatial query the compiler answers from walker entry signatures. Use this to see how a node is visited.";
sem SemanticTools.find_walkers.node_type = "The node archetype name, e.g. 'User'.";
impl SemanticTools.find_walkers(node_type: str) -> str {
    ci = self.ws.code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    eps = ci.walkers_visiting(node_type);
    if not eps {
        return f"No walkers traverse a '{node_type}' node.";
    }
    lines: list[str] = [];
    for ep in eps {
        lines.append(str(ep.render()));
    }
    return "\n".join(lines);
}

sem SemanticTools.context_slice = "Get a typed context slice for a symbol: its definition, the types it depends on, and where it is used -- a focused, compiler-accurate neighbourhood to read instead of opening whole files.";
sem SemanticTools.context_slice.name = "The symbol to build a context slice around.";
impl SemanticTools.context_slice(name: str) -> str {
    ci = self.ws.code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    return str(ci.slice_for(name).render());
}

impl BrowseTools._browse_err(e: Exception) -> str {
    msg = str(e);
    if "no live browser" in msg {
        return "ERROR: no browser is open -- call browse_open(url) first.";
    }
    return f"ERROR: {msg}";
}

impl BrowseTools._browse(confirm_msg: str, run: any, clip: bool = False) -> str {
    if confirm_msg and not confirm(confirm_msg) {
        return f"DENIED: the user declined to {confirm_msg}.";
    }
    try {
        out = run();
        return truncate(str(out)) if clip else str(out);
    } except Exception as e {
        return self._browse_err(e);
    }
}

sem BrowseTools.browse_open = "Launch a headless browser (or reuse the one already open) and navigate to a URL. Use this to QA a running web app, then read the page with browse_snapshot. An empty URL opens a blank page.";
sem BrowseTools.browse_open.url = "URL to open, e.g. 'http://localhost:8000'. Empty string opens about:blank.";
impl BrowseTools.browse_open(url: str) -> str {
    return self._browse(
        f"open a browser at {url}" if url else "",
        lambda { br_open(self.session_id, url or None); }
    );
}

sem BrowseTools.browse_navigate = "Navigate the open browser to a different URL and wait for it to load.";
sem BrowseTools.browse_navigate.url = "The URL to navigate to.";
impl BrowseTools.browse_navigate(url: str) -> str {
    return self._browse(
        f"navigate the browser to {url}", lambda { br_navigate(self.session_id, url); }
    );
}

sem BrowseTools.browse_snapshot = "Read the current page as an accessibility tree. Interactive elements are tagged with @e1/@e2 refs that you pass to browse_click, browse_type, and browse_fill. Call this after navigating, and again after any action that changes the page, to see the new state.";
impl BrowseTools.browse_snapshot -> str {
    return self._browse("", lambda { br_snapshot(self.session_id); }, clip=True);
}

sem BrowseTools.browse_click = "Click an element with a real, trusted mouse event. Pass an @ref from browse_snapshot (e.g. '@e5') or a CSS selector (e.g. '#submit').";
sem BrowseTools.browse_click.target = "An @ref from browse_snapshot, or a CSS selector.";
impl BrowseTools.browse_click(target: str) -> str {
    return self._browse(
        f"click {target} in the browser", lambda { br_click(self.session_id, target); }
    );
}

sem BrowseTools.browse_type = "Focus an element and type text into it as real key events, appending to whatever is already there.";
sem BrowseTools.browse_type.target = "An @ref from browse_snapshot, or a CSS selector.";
sem BrowseTools.browse_type.text = "The text to type.";
impl BrowseTools.browse_type(target: str, text: str) -> str {
    return self._browse(
        f"type into {target} in the browser",
        lambda { br_type(self.session_id, target, text); }
    );
}

sem BrowseTools.browse_fill = "Clear a field and set its value to the given text. Prefer this over browse_type for form fields.";
sem BrowseTools.browse_fill.target = "An @ref from browse_snapshot, or a CSS selector.";
sem BrowseTools.browse_fill.text = "The text to set the field to.";
impl BrowseTools.browse_fill(target: str, text: str) -> str {
    return self._browse(
        f"fill {target} in the browser",
        lambda { br_fill(self.session_id, target, text); }
    );
}

sem BrowseTools.browse_press = "Press a single key in the browser, e.g. 'Enter', 'Tab', 'Escape', or a chord like 'Ctrl+A'.";
sem BrowseTools.browse_press.key = "The key or chord to press.";
impl BrowseTools.browse_press(key: str) -> str {
    return self._browse(
        f"press {key} in the browser", lambda { br_press(self.session_id, key); }
    );
}

sem BrowseTools.browse_get = "Read a property of the current page: 'url', 'title', or 'text' (the visible text of the element named by selector).";
sem BrowseTools.browse_get.what = "One of 'url', 'title', or 'text'.";
sem BrowseTools.browse_get.selector = "CSS selector for 'text'; empty string for 'url' or 'title'.";
impl BrowseTools.browse_get(what: str, selector: str) -> str {
    return self._browse(
        "", lambda { br_get(self.session_id, what, selector or None); }, clip=True
    );
}

sem BrowseTools.browse_eval = "Evaluate a JavaScript expression in the page and return its result. Use this to inspect page state or check for errors, e.g. \"document.querySelectorAll('.error').length\".";
sem BrowseTools.browse_eval.expression = "A JavaScript expression to evaluate.";
impl BrowseTools.browse_eval(expression: str) -> str {
    return self._browse(
        f"run JavaScript in the browser: {expression}",
        lambda { br_eval(self.session_id, expression); },
        clip=True
    );
}

sem BrowseTools.browse_close = "Close the browser and free its resources. Call this when finished with browser QA.";
impl BrowseTools.browse_close -> str {
    return self._browse("", lambda { br_close(self.session_id); });
}

impl BrowseTools._browse_shutdown{
    try {
        br_close(self.session_id);
    } except Exception { }
}

impl system_prompt -> str {
    index_lines: list[str] = [];
    for g in gs_list() {
        index_lines.append(f"- {g.name}: {g.description}");
    }
    guide_index = "\n".join(index_lines);
    return (
        AGENT_RULES + "\n## Reference guides available (open one with read_guide)\n\n" + guide_index
    );
}

impl reset_session{
    agent.ledger = Ledger();
}

impl AgentEventBus.emit(kind: str, fields: dict) -> None {
    if not self.active_feed {
        return;
    }

    ev = {"id": self._next_id, "kind": kind};
    ev.update(fields);
    self._next_id += 1;
    self.events.append(ev);

    if len(self.events) > self._cap {
        self.events = self.events[-self._cap:];
    }
    self.publish(ev);
}

impl AgentEventBus.emit_stream(kind: str, token: str) -> None {
    if not self.active_feed {
        return;
    }
    if (
        self.events
        and self.events[-1].get("kind") == kind
        and self.events[-1].get("streaming")
    ) {
        self.events[-1]["text"] = str(self.events[-1].get("text", "")) + token;

        self.publish(self.events[-1]);
    } else {
        ev = {"id": self._next_id, "kind": kind, "text": token, "streaming": True};
        self._next_id += 1;
        self.events.append(ev);
        if len(self.events) > self._cap {
            self.events = self.events[-self._cap:];
        }
        self.publish(ev);
    }
}

impl AgentEventBus.enter(phase: str) -> None {
    self.active = phase;
    self.path.append(phase);
    self.emit("phase", {"node": phase});
}

impl AgentEventBus.set_status(s: str) -> None {
    self.status = s;
    self.emit("status", {"status": s});
}

impl AgentEventBus.begin_turn -> None {
    self.active = "";
    self.path = [];
    self.cancel_requested = False;
}

impl AgentEventBus._state -> dict {
    return {
        "status": self.status,
        "active": self.active,
        "path": list(self.path),
        "stats": dict(self.last_stats),
        "needs_key": self.needs_key,
        "key_env": self.key_env,
        "model_name": self.model_name
    };
}

impl AgentEventBus.snapshot -> dict {
    snap = self._state();
    snap["events"] = list(self.events);
    snap["ledger"] = self.ledger_view();
    return snap;
}

impl AgentEventBus.ledger_view -> dict {
    led = agent.ledger;
    if led is None {
        return {"changes": [], "notes": []};
    }
    return {"changes": list(led.changes), "notes": list(led.notes)};
}

impl AgentEventBus.publish_ledger -> None {
    if not self.active_feed or not self._subscribers {
        return;
    }

    msg = self._state();
    msg["ledger"] = self.ledger_view();
    for q in list(self._subscribers) {
        try {
            q.put_nowait(msg);
        } except Exception { }
    }
}

impl AgentEventBus.subscribe -> any {
    import from queue { Queue }
    q = Queue();
    self._subscribers.append(q);
    return q;
}

impl AgentEventBus.unsubscribe(q: any) -> None {
    if q in self._subscribers {
        self._subscribers.remove(q);
    }
}

impl AgentEventBus.publish(ev: dict) -> None {
    if not self.active_feed or not self._subscribers {
        return;
    }

    msg = self._state();
    msg["ev"] = ev;
    for q in list(self._subscribers) {
        try {
            q.put_nowait(msg);
        } except Exception { }
    }
}

impl AgentEventBus.publish_full -> None {
    if not self._subscribers {
        return;
    }
    msg = self._state();
    msg["full"] = True;
    msg["events"] = list(self.events);
    msg["ledger"] = self.ledger_view();
    for q in list(self._subscribers) {
        try {
            q.put_nowait(msg);
        } except Exception { }
    }
}

glob _CALL_LOG_CAP = 500;

impl _san_msg(m: any) -> dict {
    import json;
    role_raw: any = m.get("role") if isinstance(m, dict) else (m?.role or "");
    role = str(role_raw or "");

    if "." in role {
        role = role.split(".")[-1];
    }
    role = role.lower();
    content = m.get("content") if isinstance(m, dict) else (m?.content or "");
    content = "" if content is None else str(content);
    tcs: any = m.get("tool_calls") if isinstance(m, dict) else m?.tool_calls;
    tools: list[str] = [];
    if tcs {
        for tc in tcs {
            fn: any = tc?.function;
            if fn is None and isinstance(tc, dict) {
                fn = tc.get("function");
            }
            name: any = fn?.name;
            if name is None and isinstance(fn, dict) {
                name = fn.get("name");
            }
            raw: any = fn?.arguments;
            if raw is None and isinstance(fn, dict) {
                raw = fn.get("arguments");
            }
            args_str = "";
            try {
                parsed = json.loads(raw) if isinstance(raw, str) else (raw or {});
                args_str = json.dumps(parsed) if isinstance(parsed, dict) else str(raw);
            } except Exception {
                args_str = str(raw);
            }
            tools.append(f"{name or '?'}({args_str})");
        }
    }
    return {"role": role, "content": content, "tools": tools};
}

def _remember_convo(snap: list) {
    cur = agent.bus.convos.get(agent.bus._cur_convo, []);
    if len(snap) > len(cur) {
        agent.bus.convos[agent.bus._cur_convo] = snap;
    }
}

impl AgentEventBus.open_convo(msgs: any) -> None {
    if not self.active_feed {
        return;
    }
    self._convo_seq += 1;
    self._cur_convo = self._convo_seq;
    self.convos[self._cur_convo] = [_san_msg(m) for m in msgs];
}

impl AgentEventBus.set_pending(msgs: any) -> None {
    if self.active_feed {
        _remember_convo([_san_msg(m) for m in msgs]);
    }
}

impl AgentEventBus.close_convo(msgs: any) -> None {
    if self.active_feed {
        _remember_convo([_san_msg(m) for m in msgs]);
    }
}

impl AgentEventBus.set_convo_tools(tools: list[Callable]) -> None {
    if not self.active_feed {
        return;
    }
    import json;
    import from jaclang.byllm.types { Tool }
    recs: list[dict] = [];
    for fn in tools {
        name = str(getattr(fn, "__name__", "?") or "?");
        try {
            schema: any = Tool(fn).get_json_schema();
            fdef: any = schema.get("function", {});
            recs.append(
                {
                    "name": str(fdef.get("name", "") or name),
                    "description": str(fdef.get("description", "")),
                    "schema": json.dumps(schema, indent=2)
                }
            );
        } except Exception as e {
            recs.append(
                {
                    "name": name,
                    "description": "",
                    "schema": f"(schema unavailable: {e})"
                }
            );
        }
    }
    self.convo_tools[self._cur_convo] = recs;
}

impl AgentEventBus.emit_call(fields: dict) -> None {
    if not self.active_feed {
        return;
    }

    cid = self._next_id;
    self.emit("call", fields);
    self.call_log.append(
        {
            "id": cid,
            "node": str(fields.get("node", "")),
            "convo": self._cur_convo,
            "tokens_in": int(fields.get("tokens_in", 0) or 0),
            "tokens_out": int(fields.get("tokens_out", 0) or 0)
        }
    );
    if len(self.call_log) > _CALL_LOG_CAP {
        self.call_log = self.call_log[-_CALL_LOG_CAP:];
        keep = {c["convo"] for c in self.call_log};
        self.convos = {
            k: v
            for (k, v) in self.convos.items()
            if k in keep
        };
        self.convo_tools = {
            k: v
            for (k, v) in self.convo_tools.items()
            if k in keep
        };
    }
}

impl _progress_guard(ctx: any) -> str {
    import json;

    if agent.bus.cancel_requested {
        return IterationAction.ABORT_WITH_SUMMARY;
    }

    agent.bus.set_pending(ctx.messages);
    counts: dict[str, int] = {};

    sigs: list[str] = [];
    for m in ctx.messages {
        tcs = m.get("tool_calls") if isinstance(m, dict) else m?.tool_calls;
        if not tcs {
            continue;
        }
        for tc in tcs {
            fn = tc?.function;
            if fn is None and isinstance(tc, dict) {
                fn = tc.get("function");
            }
            name = fn?.name;
            if name is None and isinstance(fn, dict) {
                name = fn.get("name");
            }
            raw = fn?.arguments;
            if raw is None and isinstance(fn, dict) {
                raw = fn.get("arguments");
            }
            args_str = "";
            try {
                parsed = json.loads(raw) if isinstance(raw, str) else (raw or {});
                args_str = json.dumps(parsed, sort_keys=True)
                    if isinstance(parsed, dict)
                    else str(raw);
                path = str(parsed.get("path", "")) if isinstance(parsed, dict) else "";
            } except Exception {
                args_str = str(raw);
                path = "";
            }
            sigs.append(f"{name}|{args_str}");
            if name in _WRITE_TOOLS and path {
                counts[path] = counts.get(path, 0) + 1;
            }
        }
    }

    if len(sigs) >= 3 and sigs[-1] == sigs[-2] and sigs[-2] == sigs[-3] {
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    worst = max(counts.values()) if counts else 0;
    if worst > _REWRITE_LIMIT {
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    return IterationAction.CONTINUE;
}

impl TurnRenderer.print_banner{
    console.print("");
    console.print("  Jac AI -- interactive coding agent", style="bold");
    console.print(
        f"  model: {agent_model.model_name}  (from {agent.cfg.model_source})",
        style="muted"
    );
    if agent.cfg.threads > 0 {
        console.print(f"  inference threads: {agent.cfg.threads}", style="muted");
    }
    if agent.cfg.yolo_mode {
        console.print(
            "  file writes and commands run without confirmation (use --safe to confirm each)",
            style="yellow"
        );
    }
    console.print("  type a request, /help for commands, /exit to quit", style="muted");
    console.print("");
}

impl TurnRenderer.print_help{
    console.print("  /help     show this help", style="muted");
    console.print("  /clear    reset the conversation", style="muted");
    console.print("  /guides   list the bundled Jac reference guides", style="muted");
    console.print("  /stats    toggle the per-turn stat line", style="muted");
    console.print(
        "  /verbose  toggle live reasoning, timings, and step detail", style="muted"
    );
    console.print(
        "  /feedback toggle inline compiler feedback after each write", style="muted"
    );
    console.print("  /exit     quit the session", style="muted");
}

impl TurnRenderer.fmt_tool_call(tool: str, args: object) -> str {
    parts: list[str] = [];
    if isinstance(args, dict) {
        for (key, value) in args.items() {
            sval = str(value).replace("\n", " ");
            if len(sval) > 60 {
                sval = sval[:60] + "...";
            }
            parts.append(f"{key}={sval}");
        }
    }
    return f"{tool}(" + ", ".join(parts) + ")";
}

impl TurnRenderer._short_num(n: int) -> str {
    return f"{n / 1000:.1f}k" if n >= 1000 else str(n);
}

impl TurnRenderer._estimate_cost(prompt_tokens: int, completion_tokens: int) -> float {
    try {
        import litellm;
        costs: any = litellm.cost_per_token(
            model=agent_model.model_name,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens
        );
        return float(str(costs[0])) + float(str(costs[1]));
    } except Exception {
        return 0.0;
    }
}

impl TurnRenderer._format_tokens(usage: dict[str, object]) -> str {
    prompt = int(usage.get("prompt_tokens", 0) or 0);
    completion = int(usage.get("completion_tokens", 0) or 0);
    if prompt == 0 and completion == 0 {
        return "";
    }
    text = f"{agent.view._short_num(prompt)} in / {agent.view._short_num(
        completion
    )} out";
    cost = agent.view._estimate_cost(prompt, completion);
    if cost > 0 {
        text += f" (~${cost:.4f})";
    }
    return text;
}

impl TurnRenderer._format_health -> str {
    ci = agent.ws.code_intel();
    if ci is None or not ci.is_loaded() {
        return "";
    }
    try {
        diags: list[any] = list(ci.diagnostics());
    } except Exception {
        return "";
    }
    (n_err, n_warn) = _count_diags(diags);
    if n_err == 0 and n_warn == 0 {
        return "project: clean";
    }
    return f"project: {n_err} error(s), {n_warn} warning(s)";
}

impl TurnRenderer.print_stats(
    elapsed: float,
    n_read: int,
    n_write: int,
    n_run: int,
    files: set[str],
    usage: dict[str, object]
) {
    parts: list[str] = [f"{elapsed:.1f}s"];
    n_tools = n_read + n_write + n_run;
    if n_tools > 0 {
        breakdown: list[str] = [];
        if n_read {
            breakdown.append(f"{n_read} read");
        }
        if n_write {
            breakdown.append(f"{n_write} write");
        }
        if n_run {
            breakdown.append(f"{n_run} run");
        }
        parts.append(f"{n_tools} tools (" + ", ".join(breakdown) + ")");
    }
    if files {
        suffix = "" if len(files) == 1 else "s";
        parts.append(f"{len(files)} file{suffix} changed");
    }
    tokens = agent.view._format_tokens(usage);
    if tokens {
        parts.append(tokens);
    }

    completion = int(usage.get("completion_tokens", 0) or 0);
    if completion > 0 and elapsed > 0 {
        parts.append(f"{completion / elapsed:.1f} tok/s");
    }
    health = agent.view._format_health();
    if health {
        parts.append(health);
    }
    console.print("  " + "  ·  ".join(parts), style="muted");
}

impl TurnRenderer._strip_control(text: str) -> str {
    import re;
    t = text.replace("<|\"|>", "\"").replace("<|'|>", "'");
    t = re.sub("<\\|[a-z_]+>[a-z]*", "", t);
    t = re.sub("<[a-z_]+\\|>", "", t);
    return t;
}

impl TurnRenderer._split_reasoning(raw: str) -> tuple[str, bool] {
    mark = "<tool_call>";
    idx = raw.find(mark);
    if idx >= 0 {
        return (raw[:idx], True);
    }
    hold = 0;
    k = min(len(raw), len(mark) - 1);
    while k > 0 {
        if mark.startswith(raw[len(raw) - k:]) {
            hold = k;
            break;
        }
        k -= 1;
    }
    return (raw[:len(raw) - hold], False);
}

impl TurnRenderer._result_snippet(text: str, max_lines: int) -> list[str] {
    stripped = text.strip();
    if not stripped {
        return ["(no output)"];
    }
    lines = stripped.splitlines();
    shown: list[str] = [];
    for ln in lines[:max_lines] {
        shown.append(ln[:100] + "..." if len(ln) > 100 else ln);
    }
    rest = len(lines) - min(len(lines), max_lines);
    if rest > 0 {
        shown.append(f"(+{rest} more lines)");
    }
    return shown;
}

impl TurnRenderer._fmt_ms(ms: float) -> str {
    return f"{int(ms)}ms" if ms < 1000 else f"{ms / 1000:.1f}s";
}

impl TurnRenderer._fmt_gen(ms: float, tokens: int) -> str {
    if ms <= 0 {
        return "";
    }
    if tokens > 0 {
        tps = tokens / (ms / 1000);
        return f"   ({agent.view._fmt_ms(ms)}, {tps:.0f} tps)";
    }
    return f"   ({agent.view._fmt_ms(ms)})";
}

impl TurnRenderer._ci_event(info: any) {
    op = str(info.get("op", "?"));
    recompiled = int(info.get("recompiled", 0));
    cached = int(info.get("cached", 0));
    total = int(info.get("total", 0));
    raw_ms = info.get("ms", 0.0);
    ms = raw_ms if isinstance(raw_ms, float) else 0.0;
    fname: str = str(info.get("file", ""));
    name = os.path.basename(fname);
    if op == "load" {
        what = f"load · compiled {recompiled} files";
        if cached {
            what += f" · {cached} from cache";
        }
    } else {
        what = f"{op} {name} · recompiled {recompiled}/{total}";
    }
    console.print(
        f"      ⚙ code intel · {what} · {agent.view._fmt_ms(ms)}", style="dim"
    );
}

impl TurnRenderer._emit_call_usage(data: any, phase: str) -> None {
    if not agent.bus.active_feed {
        return;
    }
    d = data if isinstance(data, dict) else {};
    tin = int(d.get("prompt_tokens", 0) or 0);
    tout = int(d.get("completion_tokens", 0) or 0);

    if tin == 0 and tout == 0 {
        return;
    }

    agent.bus.emit_call(
        {
            "node": phase,
            "tokens_in": tin,
            "tokens_out": tout,
            "cache_read": int(d.get("cache_read_input_tokens", 0) or 0),
            "cache_create": int(d.get("cache_creation_input_tokens", 0) or 0),
            "ms": float(d.get("duration_ms", 0) or 0)
        }
    );
}

impl TurnRenderer.render_stream(event_stream: any) -> dict {
    out: any = sys.stdout;

    is_tty = bool(out?.isatty) and bool(out.isatty());

    n_read = 0;
    n_write = 0;
    n_run = 0;
    files: set[str] = set();
    usage: dict[str, object] = {};
    answer = "";
    streamed = False;
    thought_raw = "";
    prose_shown = 0;
    step_t0 = 0.0;
    think_on = False;
    last_llm_ms = 0.0;
    last_llm_tokens = 0;
    pend_result: any = None;
    def clear_think {
        nonlocal think_on;
        if think_on and is_tty {
            out.write("\r" + (" " * _THINK_WIDTH) + "\r");
            out.flush();
        }
        think_on = False;
    }
    def end_line {
        nonlocal streamed;
        if streamed {
            out.write("\n");
            out.flush();
            streamed = False;
        }
    }
    def flush_result {
        nonlocal pend_result;
        if pend_result is None {
            return;
        }
        (result, ms) = (pend_result["result"], pend_result["ms"]);
        pend_result = None;
        agent.bus.emit("tool_result", {"text": truncate(str(result), 4000)});
        lines = agent.view._result_snippet(result, 3 if agent.cfg.verbose else 1);
        tail = f"   {agent.view._fmt_ms(ms)}"
            if (agent.cfg.verbose and ms is not None)
            else "";
        console.print(f"      ↳ {lines[0]}{tail}", style="dim");
        for ln in lines[1:] {
            console.print(f"        {ln}", style="dim");
        }
    }
    try {
        for event in event_stream {
            if agent.bus.cancel_requested {
                break;
            }
            kind = event.event_type;
            data = event.data;
            if kind == "thought" {
                if not agent.cfg.verbose {
                    continue;
                }
                tok = str(data.get("content", ""));
                if not tok {
                    continue;
                }
                if step_t0 == 0.0 {
                    step_t0 = time.time();
                }
                thought_raw += tok;
                (prose, hit) = agent.view._split_reasoning(thought_raw);
                new_raw = prose[prose_shown:];
                prose_shown = len(prose);
                cleaned = agent.view._strip_control(new_raw);
                if cleaned {
                    clear_think();
                    out.write(cleaned);
                    out.flush();
                    streamed = True;
                    agent.bus.emit_stream("reasoning", cleaned);
                }

                if hit and not streamed and is_tty {
                    out.write(f"\r  ● thinking… {time.time() - step_t0:.1f}s");
                    out.flush();
                    think_on = True;
                }
            } elif kind == "chunk" {
                clear_think();
                flush_result();
                tok = str(data.get("content", ""));
                answer += tok;
                out.write(tok);
                out.flush();
                streamed = True;
                agent.bus.emit_stream("answer", tok);
            } elif kind == "llm_timing" {
                last_llm_ms = float(data.get("duration_ms", 0) or 0);
                last_llm_tokens = int(data.get("completion_tokens", 0) or 0);
                agent.view._emit_call_usage(data, agent.bus.active);
            } elif kind == "tool_call" {
                clear_think();
                end_line();
                flush_result();
                tool = str(data.get("tool", "?"));
                args = data.get("args", {});
                if tool in _WRITE_TOOLS {
                    n_write += 1;
                    agent.turn_wrote = True;
                    if isinstance(args, dict) {
                        path = args.get("path");
                        if path {
                            files.add(str(path));
                        }
                    }
                } elif tool in _RUN_TOOLS {
                    n_run += 1;
                } else {
                    n_read += 1;
                }
                gen = agent.view._fmt_gen(last_llm_ms, last_llm_tokens)
                    if agent.cfg.verbose
                    else "";
                console.print(
                    f"  ⏺ {agent.view.fmt_tool_call(tool, args)}{gen}", style="cyan"
                );
                agent.bus.emit(
                    "tool", {"name": tool, "text": agent.view.fmt_tool_call(tool, args)}
                );
                last_llm_ms = 0.0;
                last_llm_tokens = 0;
                thought_raw = "";
                prose_shown = 0;
                step_t0 = 0.0;
            } elif kind == "tool_result" {
                clear_think();
                end_line();
                flush_result();
                pend_result = {"result": str(data.get("result", "")), "ms": None};
            } elif kind == "tool_timing" {
                if pend_result is not None {
                    pend_result["ms"] = float(data.get("duration_ms", 0) or 0);
                }
                flush_result();
            } elif kind == "usage" {
                total = data.get("total", {});
                if isinstance(total, dict) {
                    usage = total;
                }
            } elif kind == "steps_done" {
                clear_think();
                end_line();
                flush_result();
                console.print("");
            }
        }
        clear_think();
        end_line();
        flush_result();
    } except KeyboardInterrupt {
        console.print("\n  [interrupted]", style="yellow");
    } except Exception as e {
        console.print("");
        console.error(f"agent error: {e}");
        if os.environ.get("JAC_AI_DEBUG") {
            import traceback;
            traceback.print_exc();
        }
    }
    return {
        "n_read": n_read,
        "n_write": n_write,
        "n_run": n_run,
        "files": files,
        "usage": usage,
        "answer": answer.strip()
    };
}

impl Ledger.record(phase: str, summary: str) {
    self.changes.append({"phase": phase, "summary": truncate(summary, 400)});
}

impl Ledger.remember(text: str) {
    self.notes.append(text);
}

impl Ledger.render -> str {
    if not self.changes and not self.notes {
        return "(nothing done yet)";
    }
    lines: list = [];
    for c in self.changes {
        lines.append(f"- [{c['phase']}] {c['summary']}");
    }
    for n in self.notes {
        lines.append(f"- note: {n}");
    }
    return "\n".join(lines);
}

impl TurnStats.absorb(st: dict) {
    self.n_read += int(st["n_read"]);
    self.n_write += int(st["n_write"]);
    self.n_run += int(st["n_run"]);
    self.files |= set(st["files"]);
    for (k, v) in st["usage"].items() {
        try {
            self.usage[k] = self.usage.get(k, 0) + v;
        } except Exception {
            self.usage[k] = v;
        }
    }
}

impl Prompt.for_phase(state_ty: type, objective: str, ledger: Ledger) -> str {
    role = str(state_ty?._jac_semstr or "");
    return (
        system_prompt() + "\n\n## Current state\n\nYou are in " + role + "\n\n## Objective\n\n" + objective + "\n\n## Progress so far (shared across states)\n\n" + ledger.render()
    );
}

impl AgentRuntime.postinit -> None {
    self.files.ws = self.ws;
    self.files.cfg = self.cfg;
    self.proc.ws = self.ws;
    self.semantic.ws = self.ws;

    self.bus._lock = threading.Lock();
}

sem AgentRuntime.note = "Record a short note that stays visible to every later phase (Plan, Build, QA) and in later turns. Use it to flag a decision, an assumption, or something to verify.";
sem AgentRuntime.note.text = "The note to remember.";

impl AgentRuntime.note(text: str) -> str {
    if agent.active_session is not None {
        agent.active_session.ledger.remember(text);
        agent.bus.publish_ledger();
        return f"noted: {text}";
    }
    return "(no active session to note onto)";
}

impl PhaseState.tools -> list {
    return [t.fn for t in [self->:Exposes:->]];
}

sem Plan = "the PLANNING state: understand the request and the existing project before writing anything. Use project_map for an unfamiliar project, find_symbol / find_uses / context_slice to navigate by meaning, read_file to read what you will change, and the guides for unfamiliar Jac (read at least the one for the kind of code you will write -- e.g. jac-cl-components for a UI). Do not write or edit files here. Finish by stating a short, concrete plan: whether to scaffold (and which template -- web-static for a browser-only UI, web-app for server/data, default for a script), the files to create or change, and what each is for.";

sem Build = "the BUILDING state: carry out the plan. For a new app, scaffold it ONCE with `jac create --kind <kind> <name>` via run_command, then `cd <name>` so every later tool works inside the project (the cd persists). Pick the SIMPLEST kind that fits: `web-static` for a browser-only UI with no server or saved data (a calculator, a unit converter, a static page); `web-app` only when you need server endpoints or persistent/multi-user data; `cli` for a non-web script. To create a NEW file, call write_file with its FULL contents -- never create files with shell redirection (`echo >`, `cat <<EOF`, `touch`) and never try to edit a file that does not exist yet. Use edit_file only to change a file that already exists, and read it first. Every write reports the compiler errors it introduced; fix them before moving on. Keep files focused; split large archetypes into impl files.";

sem QA = "the QA state: verify the work end to end and fix what you find. Run `jac check .` (zero errors required). For a runnable app, start_app and confirm it boots cleanly. For a web or full-stack app, drive the built-in browser: call serve(entry) to start the dev server -- it waits until the server is actually ready and returns its URL (the first start is slow, as it installs client deps and builds the client). Then browse_open that URL, browse_snapshot to read the page, exercise the main flows with browse_click / browse_fill / browse_type / browse_press (snapshotting after each), check for errors with browse_eval, then browse_close and stop_server. If serve reports the server failed to start, read the log tail it returns and go back to Build to fix the cause -- do not conclude the app works until you have actually run and exercised it.";

impl PhaseState.directive -> str {
    return f"Carry out the {type(self).__name__} state now.";
}

impl PhaseState.step(visitor: AgentSession) -> dict {
    agent.active_session = visitor;
    label = type(self).__name__;
    console.print(f"\n  ● {label}", style="bold blue");

    agent.bus.enter(label);

    sysmsg = {
        "role": "system",
        "content": Prompt.for_phase(type(self), visitor.objective, visitor.ledger)
    };
    if not self.ctx {
        self.ctx.append(sysmsg);
    } else {
        self.ctx[0] = sysmsg;
    }

    agent.phase_tools = self.tools();
    agent.phase_ctx = self.ctx;

    agent.bus.open_convo(self.ctx);

    agent.bus.set_convo_tools(agent.phase_tools);
    result = agent.view.render_stream(run_phase(self.directive()));
    agent.bus.close_convo(self.ctx);
    visitor.stats.absorb(result);
    visitor.ledger.record(label, str(result.get("answer", "") or "(no summary)"));

    agent.bus.publish_ledger();
    return result;
}

impl PhaseState.halt(visitor: AgentSession) -> bool {
    if agent.bus.cancel_requested {
        return True;
    }

    visitor.steps += 1;
    if visitor.steps > visitor.max_steps {
        console.print("\n  ● step cap reached -- stopping", style="yellow");
        return True;
    }
    return False;
}

impl Plan.directive -> str {
    return (
        "Investigate the request and the existing project, then state a "
        "short, concrete plan. Do not write or edit files in this state."
    );
}

impl Build.directive -> str {
    return (
        "Build the requested feature NOW by writing real code: call "
        "write_file to create each new file with its full contents, and "
        "edit_file to change existing ones. Exploring or describing the "
        "plan is NOT building -- keep working until every file the task "
        "needs exists and the project compiles. After each write, read the "
        "compiler feedback it returns and fix the errors before moving on. "
        "Do not end this state with only reads."
    );
}

impl QA.directive -> str {
    return (
        "Verify the finished work end to end NOW. Run jac_check and require "
        "zero errors. For a web or full-stack app, serve it and drive the "
        "browser (browse_open, browse_snapshot, then click/type the real "
        "controls) to confirm the REQUESTED feature actually works on the "
        "page -- not just that the scaffold loads. If anything is missing, "
        "wrong, or broken, go back to Build to fix it; choose Done only "
        "after you have actually run and exercised the result."
    );
}

sem run_phase.directive = "A short instruction kicking off the current phase.";

impl Plan.run with AgentSession entry {
    if agent.bus.cancel_requested {
        return;
    }
    self.step(visitor);
    if self.halt(visitor) {
        return;
    }

    needs_code = True;
    try {
        needs_code = request_needs_code_changes(
            visitor.objective, visitor.ledger.render()
        );
    } except Exception as e {
        console.print(
            f"  ↳ classifier failed ({e}); defaulting to Build", style="yellow"
        );
    }
    if needs_code {
        visit [->:Flow:->][?:Build];
    } else {
        console.print(
            "  ↳ read-only request -- answered in Plan, skipping Build/QA",
            style="green"
        );
        visit [->:Flow:->][?:Done];
    }
}

impl Build.run with AgentSession entry {
    if agent.bus.cancel_requested {
        return;
    }
    result = self.step(visitor);
    if self.halt(visitor) {
        return;
    }
    if int(result.get("n_write", 0) or 0) == 0 and visitor.build_nudges < 2 {
        visitor.build_nudges += 1;
        self.ctx.append(
            {
                "role": "user",
                "content": (
                    "You ended Build having called write_file ZERO times -- you only "
                    "described code, pasted it into your reply, or left notes. That "
                    "is not building. Call write_file NOW with the COMPLETE Jac "
                    "contents of each file the task needs (for a UI, e.g. "
                    "components/Calculator.cl.jac as a `def:pub Calculator() -> "
                    "JsxElement` component, and edit main.jac to render it). Write "
                    "real Jac files this turn -- do not explain, just write them."
                )
            }
        );
        console.print(
            "  ↳ Build wrote no files -- re-entering Build to actually write code",
            style="yellow"
        );
        visit self;
    } else {
        visit [->:Flow:->];
    }
}

impl QA.run with AgentSession entry {
    if agent.bus.cancel_requested {
        return;
    }
    self.step(visitor);
    if self.halt(visitor) {
        return;
    }
    if agent.ws.project_errors() {
        n = len(agent.ws.project_errors());
        console.print(
            f"  ↳ project has {n} compile error(s) -- returning to Build",
            style="yellow"
        );
        visit [->:Flow:->][?:Build];
    } else {
        agent.bus.open_convo(
            [
                {
                    "role": "system",
                    "content": "Routing: pick the single next state along this node's out-edges (Build to fix, Plan to rethink, Done only once verified)."
                },
                {
                    "role": "user",
                    "content": f"Objective:\n{visitor.objective}\n\nProgress so far:\n{visitor.ledger.render()}\n\nStep: {visitor.steps} of at most {visitor.max_steps}"
                }
            ]
        );
        visit [->:Flow:->] by agent_model(
            stream=True,
            stream_handler=agent.view.route_stream_event,
            incl_info={
                "Objective": visitor.objective,
                "Progress so far": visitor.ledger.render(),
                "Step": f"{visitor.steps} of at most {visitor.max_steps}",
                "How to choose": "Pick the single next state. Choose Done only once you have actually verified the result; go back to Build to fix problems QA found, or to Plan to rethink the approach."
            }
        );
    }
}

impl TurnRenderer.route_stream_event(event: any) -> None {
    if agent.bus.cancel_requested {
        return;
    }

    if event.event_type == "llm_timing" {
        self._emit_call_usage(event.data, "route");
        return;
    }
    tok = str(event.data.get("content", "")) if event.data else "";
    if not tok {
        return;
    }

    if event.event_type == "thought" {
        cleaned = self._strip_control(tok);
        if cleaned {
            agent.bus.emit_stream("reasoning", cleaned);
        }
    }
}

sem Done = "the DONE state: the session is complete. Reach it from QA once the objective is fully built AND verified (type-checked, and for an app, run and exercised), or directly from Plan when the request was a pure question or read-only inspection that needed no file changes and has been answered. Ends the session.";
impl Done.finish{
    console.print("\n  ● Done", style="bold green");
    agent.bus.enter("Done");
}

impl build_pipeline -> Plan {
    plan = Plan();
    build = Build();
    qa = QA();
    done = Done();
    plan +>:Flow:+> build;

    plan +>:Flow:+> done;
    build +>:Flow:+> qa;
    qa +>:Flow:+> build;
    qa +>:Flow:+> plan;
    qa +>:Flow:+> done;

    for ph in [plan, build, qa] {
        for spec in TOOL_SPECS {
            if type(ph) in spec.phases {
                ph +>:Exposes:+> Tool(
                    fn=spec.fn, category=spec.category, serialize=spec.serialize
                );
            }
        }
    }
    return plan;
}

impl AgentSession.begin{
    visit build_pipeline();
}

impl run_turn(message: str) {
    agent.turn_wrote = False;

    ledger = agent.ledger;
    if ledger is None {
        ledger = Ledger();
        agent.ledger = ledger;
    }
    started = time.time();
    session = AgentSession(
        objective=message, ledger=ledger, stats=TurnStats()
    ) spawn root;
    if agent.cfg.show_stats {
        st = session.stats;
        agent.view.print_stats(
            time.time() - started, st.n_read, st.n_write, st.n_run, st.files, st.usage
        );
    }

    if agent.bus.active_feed {
        st2 = session.stats;
        elapsed = time.time() - started;
        usage = st2.usage;
        prompt = int(usage.get("prompt_tokens", 0) or 0);
        completion = int(usage.get("completion_tokens", 0) or 0);
        cost = (
            agent.view._estimate_cost(prompt, completion)
                if (prompt > 0 or completion > 0)
                else 0.0
        );
        tok_per_s = completion / elapsed if (completion > 0 and elapsed > 0) else 0.0;

        n_err = 0;
        n_warn = 0;
        health_loaded = False;
        ci = agent.ws.code_intel();
        if ci is not None and ci.is_loaded() {
            try {
                (n_err, n_warn) = _count_diags(list(ci.diagnostics()));
                health_loaded = True;
            } except Exception {
                health_loaded = False;
            }
        }
        agent.bus.last_stats = {
            "elapsed": round(elapsed, 1),
            "tools": st2.n_read + st2.n_write + st2.n_run,
            "reads": st2.n_read,
            "writes": st2.n_write,
            "runs": st2.n_run,
            "files": len(st2.files),
            "tokens_in": prompt,
            "tokens_out": completion,
            "cost": cost,
            "tok_per_s": round(tok_per_s, 1),
            "errors": n_err,
            "warnings": n_warn,
            "health_loaded": health_loaded,
            "has_run": True
        };
    }
}

impl verify_and_continue(max_rounds: int = 3) {
    if not agent.turn_wrote {
        return;
    }
    rnd = 0;
    prev_count = -1;
    while rnd < max_rounds {
        errs = agent.ws.project_errors();
        if not errs {
            break;
        }

        if prev_count >= 0 and len(errs) >= prev_count {
            break;
        }
        prev_count = len(errs);
        rnd += 1;
        shown = errs[:12];
        lines = [f"  {d.file}:{d.line}: {d.message}" for d in shown];
        more = (
            f"\n  ... and {len(errs) - len(shown)} more"
                if len(errs) > len(shown)
                else ""
        );
        console.print("");
        console.print(
            f"  build left {len(errs)} compile error(s); continuing to fix "
            f"(round {rnd}/{max_rounds})",
            style="yellow"
        );
        msg = (
            f"The project does not compile yet -- {len(errs)} error(s):\n" + "\n".join(
                lines
            ) + more + "\n\nFix these. Read each failing file, correct it, and re-run " + "jac_check until the whole project compiles cleanly. Do not finish " + "while errors remain."
        );
        run_turn(msg);
    }
}

impl run_agent(req: object) -> int {
    global agent_model;

    r: any = req;

    agent.ws.cwd = os.path.normpath(str(r?.cwd or os.getcwd()));

    if bool(r?.ui) {
        return _run_ui_server(r);
    }
    agent.cfg.yolo_mode = not r.safe;
    agent.cfg.verbose = not bool(r?.quiet);

    agent.ws.ci = r.code_intel;
    if agent.ws.ci is not None {
        agent.ws.ci.on_event = agent.view._ci_event;
    }
    initial_prompt = str(r.prompt);

    if r.model or r.n_ctx > 0 {
        agent_model = build_model(str(r.model), int(r.n_ctx));
    }
    agent.view.print_banner();
    reset_session();

    if initial_prompt {
        try {
            run_turn(initial_prompt);

            verify_and_continue();
        } except Exception as e {
            console.error(f"Turn failed: {e}");
        } finally {
            agent.web._browse_shutdown();
            agent.proc._serve_shutdown();
        }
        return 0;
    }

    while True {
        try {
            line = input("\n> ").strip();
        } except EOFError {
            console.print("");
            break;
        } except KeyboardInterrupt {
            console.print("");
            continue;
        }
        if not line {
            continue;
        }
        if line in ("/exit", "/quit") {
            break;
        }
        if line == "/help" {
            agent.view.print_help();
            continue;
        }
        if line == "/clear" {
            reset_session();
            console.success("Conversation cleared.");
            continue;
        }
        if line == "/guides" {
            for g in gs_list() {
                console.print(f"  {g.name}", style="bold");
                console.print(f"      {g.description}", style="muted");
            }
            continue;
        }
        if line == "/stats" {
            agent.cfg.show_stats = not agent.cfg.show_stats;
            console.success(
                "Turn stats on." if agent.cfg.show_stats else "Turn stats off."
            );
            continue;
        }
        if line == "/verbose" {
            agent.cfg.verbose = not agent.cfg.verbose;
            console.success(
                "Verbose: streaming reasoning, timings, and step detail."
                    if agent.cfg.verbose
                    else "Quiet: tool calls and the answer only."
            );
            continue;
        }
        if line == "/feedback" {
            agent.cfg.inline_feedback = not agent.cfg.inline_feedback;
            console.success(
                "Inline compiler feedback on: writes report errors they introduce."
                    if agent.cfg.inline_feedback
                    else "Inline compiler feedback off: use jac_check to compile."
            );
            continue;
        }
        try {
            run_turn(line);
        } except Exception as e {
            console.error(f"Turn failed: {e}");
        }
    }

    agent.web._browse_shutdown();
    agent.proc._serve_shutdown();
    console.print("Bye.");
    return 0;
}

impl ui_configure -> None {
    global agent_model;

    proj = os.environ.get("JAC_AI_UI_PROJECT") or os.getcwd();
    agent.ws.cwd = os.path.normpath(proj);

    agent.cfg.yolo_mode = True;
    agent.cfg.verbose = True;
    agent.cfg.show_stats = True;
    agent.bus.active_feed = True;
    model_flag = os.environ.get("JAC_AI_UI_MODEL") or "";
    n_ctx = 0;
    try {
        n_ctx = int(os.environ.get("JAC_AI_UI_NCTX") or "0");
    } except Exception { }

    agent.ws.ci = CodeIntelligence(proj_dir=agent.ws.cwd, lazy=True);
    reset_session();

    agent.cfg.n_ctx = n_ctx;
    try {
        agent_model = build_model(model_flag, n_ctx);
        agent.bus.emit(
            "system",
            {"text": f"Connected to {agent.ws.cwd} using {agent_model.model_name}."}
        );
    } except Exception as e {
        agent.bus.emit(
            "error",
            {"text": f"Connected to {agent.ws.cwd}, but the model failed to load: {e}"}
        );
    }

    _refresh_key_status();
    if agent.bus.needs_key {
        agent.bus.emit(
            "system",
            {
                "text": f"{agent_model.model_name} needs an API key ({agent.bus.key_env}). Open Settings (⚙) to add one."
            }
        );
    }
}

def _ui_turn_worker(prompt: str) {
    try {
        run_turn(prompt);

        if not agent.bus.cancel_requested {
            verify_and_continue();
        }
    } except Exception as e {
        agent.bus.emit("error", {"text": f"agent error: {e}"});

        msg = str(e).lower();
        if (
            "authenticationerror" in msg
            or "api key" in msg
            or "api_key" in msg
            or "401" in msg
            or "unauthorized" in msg
        ) {
            (_, env) = _model_needs_key(str(agent_model.model_name));
            agent.bus.needs_key = True;
            if env {
                agent.bus.key_env = env;
            }
            agent.bus.publish_full();
        }
    }
    if agent.bus.cancel_requested {
        agent.bus.emit("system", {"text": "Stopped."});
        agent.bus.cancel_requested = False;
        agent.bus.set_status("idle");
    } elif agent.bus.status != "done" {
        agent.bus.set_status("idle");
    }
}

impl ui_send(prompt: str) -> bool {
    text = prompt.strip();
    if not text {
        return False;
    }

    agent.bus._lock.acquire();
    try {
        if agent.bus.status == "running" or agent.bus.status == "stopping" {
            return False;
        }
        agent.bus.begin_turn();
        agent.bus.emit("user", {"text": text});
        agent.bus.set_status("running");
        threading.Thread(target=_ui_turn_worker, args=(text, ), daemon=True).start();
    } finally {
        agent.bus._lock.release();
    }
    return True;
}

impl ui_poll -> dict {
    return agent.bus.snapshot();
}

impl ui_call_detail(call_id: int) -> dict {
    log = list(agent.bus.call_log);
    entry: any = None;
    for c in log {
        if int(c["id"]) == call_id {
            entry = c;
        }
    }
    if entry is None {
        return {"found": False};
    }
    convo: int = int(entry["convo"]);
    msgs: list = agent.bus.convos.get(convo, []);

    same = [
        c
        for c in log
        if int(c["convo"]) == convo
    ];
    pos = 0;
    i = 0;
    for c in same {
        if int(c["id"]) == call_id {
            pos = i;
        }
        i += 1;
    }

    asst: list = [];
    j = 0;
    for m in msgs {
        if str(m.get("role", "")) == "assistant" {
            asst.append(j);
        }
        j += 1;
    }
    n = len(asst);

    a_k = int(asst[pos]) if pos < n else len(msgs);
    a_prev = int(asst[pos - 1]) if (pos > 0 and pos - 1 < n) else 0;
    a_next = int(asst[pos + 1]) if (pos + 1 < n) else len(msgs);
    prev_id = int(same[pos - 1]["id"]) if pos > 0 else -1;
    next_id = int(same[pos + 1]["id"]) if pos + 1 < len(same) else -1;
    out_slice = [
        m
        for m in msgs[a_k:a_next]
        if str(m.get("role", "")) in ("assistant", "tool")
    ];

    tools: list = agent.bus.convo_tools.get(convo, []);
    tool_chars = 0;
    for t in tools {
        td: any = t;
        tool_chars += len(str(td.get("schema", "")));
    }
    return {
        "found": True,
        "id": call_id,
        "node": str(entry["node"]),
        "input": msgs[:a_k],
        "new_input": msgs[a_prev:a_k],
        "output": out_slice,
        "shared": a_prev,
        "total": a_k,
        "tokens_in": int(entry.get("tokens_in", 0) or 0),
        "tokens_out": int(entry.get("tokens_out", 0) or 0),
        "tools": tools,
        "tool_chars": tool_chars,
        "prev_id": prev_id,
        "next_id": next_id
    };
}

impl ui_phase_context(phase: str) -> dict {
    log = list(agent.bus.call_log);

    convo = -1;
    for c in log {
        if str(c.get("node", "")) == phase {
            convo = int(c["convo"]);
        }
    }
    if convo < 0 {
        return {"phase": phase, "found": False, "messages": []};
    }
    return {"phase": phase, "found": True, "messages": agent.bus.convos.get(convo, [])};
}

impl ui_stream -> any {
    import from queue { Empty }
    q = agent.bus.subscribe();
    try {
        snap = agent.bus.snapshot();
        snap["full"] = True;
        yield snap;
        while True {
            try {
                yield q.get(timeout=10.0);
            } except Empty {
                yield {"heartbeat": True};
            }
        }
    } finally {
        agent.bus.unsubscribe(q);
    }
}

impl ui_graph -> dict {
    nodes = [];
    edges = [];
    seen = set();

    frontier: list = [build_pipeline()];
    while frontier {
        nd = frontier.pop(0);
        nid = type(nd).__name__;
        if nid in seen {
            continue;
        }
        seen.add(nid);

        tool_names = (
            [getattr(t, "__name__", "") for t in nd.tools()] if nd?.tools else []
        );
        nodes.append(
            {
                "id": nid,
                "label": nid,
                "desc": nd.desc,
                "sem": str(type(nd)?._jac_semstr or ""),
                "tools": tool_names
            }
        );

        for succ in [nd->:Flow:->] {
            edges.append({"source": nid, "target": type(succ).__name__});
            frontier.append(succ);
        }
    }
    return {"nodes": nodes, "edges": edges, "state": agent.bus.snapshot()};
}

impl ui_reset -> None {
    if agent.bus.status == "running" or agent.bus.status == "stopping" {
        agent.bus.cancel_requested = True;
        agent.bus.set_status("stopping");
        return;
    }
    reset_session();
    agent.bus.events = [];

    agent.bus.call_log = [];
    agent.bus.convos = {};
    agent.bus.convo_tools = {};
    agent.bus.begin_turn();
    agent.bus.set_status("idle");

    agent.bus.publish_full();
}

impl ui_stop -> None {
    if agent.bus.status == "running" {
        agent.bus.cancel_requested = True;
        agent.bus.set_status("stopping");
        agent.bus.emit("system", {"text": "Stopping…"});
    }
}

impl ui_settings -> dict {
    name = "";
    try {
        name = str(agent_model.model_name);
    } except Exception {
        name = "";
    }
    t = agent.cfg.temperature;
    return {
        "model": name,
        "api_key_set": bool(agent.cfg.api_key),
        "base_url": agent.cfg.base_url,
        "temperature": (float(t) if t is not None else -1.0),
        "n_ctx": agent.cfg.n_ctx,
        "model_source": agent.cfg.model_source,
        "needs_key": agent.bus.needs_key,
        "key_env": agent.bus.key_env,
        "presets": list(_MODEL_PRESETS)
    };
}

impl ui_apply_settings(
    model: str, api_key: str, base_url: str, temperature: str, n_ctx: str
) -> dict {
    global agent_model;

    if agent.bus.status == "running" or agent.bus.status == "stopping" {
        return {
            "ok": False,
            "error": "Cannot apply settings while a turn is running -- stop it first.",
            "needs_key": agent.bus.needs_key,
            "key_env": agent.bus.key_env
        };
    }
    if api_key.strip() {
        agent.cfg.api_key = api_key.strip();
    }
    agent.cfg.base_url = base_url.strip();
    nctx = 0;
    try {
        if n_ctx.strip() {
            nctx = max(0, int(n_ctx.strip()));
        }
    } except Exception {
        nctx = 0;
    }
    agent.cfg.n_ctx = nctx;

    temp_override: float | None = None;
    try {
        if temperature.strip() and float(temperature) >= 0.0 {
            temp_override = float(temperature);
        }
    } except Exception {
        temp_override = None;
    }
    try {
        agent_model = build_model(model.strip(), nctx);
        if temp_override is not None {
            agent.cfg.temperature = temp_override;
        }
        _refresh_key_status();
        agent.bus.emit(
            "system", {"text": f"Settings applied; using {agent_model.model_name}."}
        );
        agent.bus.publish_full();
        return {
            "ok": True,
            "error": "",
            "model": str(agent_model.model_name),
            "needs_key": agent.bus.needs_key,
            "key_env": agent.bus.key_env
        };
    } except Exception as e {
        _refresh_key_status();
        agent.bus.emit("error", {"text": f"Settings error: {e}"});
        agent.bus.publish_full();
        return {
            "ok": False,
            "error": str(e),
            "model": "",
            "needs_key": agent.bus.needs_key,
            "key_env": agent.bus.key_env
        };
    }
}

impl _run_ui_server(r: any) -> int {
    import jaclang;
    pkg_file = jaclang.__file__;
    if pkg_file is None {
        console.error("jaclang package location is unavailable");
        return 1;
    }
    ui_dir = str(Path(pkg_file).parent / "cli" / "ai_ui");
    entry = os.path.join(ui_dir, "main.jac");
    if not os.path.exists(entry) {
        console.error(f"bundled UI app not found at {entry}");
        return 1;
    }
    env = dict(os.environ);
    env["JAC_AI_UI_PROJECT"] = agent.ws.cwd;
    env["JAC_AI_UI_MODEL"] = str(r?.model or "");
    env["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    log_path = "/tmp/jac_ai_ui.log";
    console.print("");
    console.print("  Jac AI -- web UI", style="bold");
    console.print(f"  project: {agent.ws.cwd}", style="muted");
    console.print("  building the client (first run installs deps)…", style="muted");
    proc: any = None;
    try {
        log_f = open(log_path, "w", encoding="utf-8");
        proc = subprocess.Popen(
            [sys.executable, "-m", "jaclang", "start", "main.jac"],
            cwd=ui_dir,
            stdout=log_f,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            start_new_session=True
        );

        log_f.close();
    } except Exception as e {
        console.error(f"failed to launch the UI server: {e}");
        return 1;
    }
    timeout = 180.0;
    try {
        raw = os.environ.get("JAC_AI_UI_TIMEOUT");
        if raw {
            timeout = float(raw);
        }
    } except Exception { }
    url = _poll_for_server_url(proc, log_path, timeout);
    if not url {
        tail = "";
        try {
            tail = "\n".join(Path(log_path).read_text().splitlines()[-25:]);
        } except Exception {
            tail = "(no log output)";
        }
        try {
            os.killpg(os.getpgid(int(proc.pid)), int(signal.SIGTERM));
        } except Exception { }
        console.error(f"the UI server did not come up within {int(timeout)}s.\n{tail}");
        return 1;
    }
    console.success(f"  UI ready at {url}");
    console.print(f"  logs: {log_path}", style="muted");
    console.print("  press Ctrl-C to stop", style="muted");
    console.print("");
    try {
        webbrowser.open(url);
    } except Exception { }
    try {
        proc.wait();
    } except KeyboardInterrupt {
        console.print("\n  stopping the UI server…", style="muted");
    }
    try {
        os.killpg(os.getpgid(int(proc.pid)), int(signal.SIGTERM));
    } except Exception { }
    console.print("Bye.");
    return 0;
}
