"""Implementations for the `jac ai` coding agent (see ai_agent.jac)."""

import os;
import re;
import sys;
import time;
import signal;
import subprocess;
import threading;
import webbrowser;
import from pathlib { Path }

import from byllm.lib { Model, IterationAction }
import from byllm.config_loader { get_byllm_config }

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


# byLLM resolves config from `jac.toml` relative to its project dir. Use the
# agent's working directory (the user's project) as the single source of truth,
# not the process cwd -- under `jac ai --ui` the process runs in the bundled web
# app's dir, so process cwd would read the wrong jac.toml. Empty `agent.cwd`
# (import time, before run_agent sets it) falls back to the default (cwd).
"""byLLM config rooted at the agent's working dir, not the process cwd.

The single source of truth for which `jac.toml` supplies the model and byLLM
settings: `agent.cwd` (the user's project). This matters under `jac ai --ui`,
where the process runs in the bundled web app's directory -- resolving against
process cwd there would read the wrong `jac.toml`. Falls back to the default
(process cwd) only before `agent.cwd` is set (import time).
"""
impl _byllm_config -> any {
    if agent.cwd {
        return get_byllm_config(Path(agent.cwd));
    }
    return get_byllm_config();
}

"""Pick which model `jac ai` should run.

Priority: the `--model` flag (`model_override`), then `[plugins.byllm.model]
default_model` in jac.toml, then the bundled local model so the command works
with no API key. Records the winning source in `agent.cfg.model_source`.
"""
impl resolve_model_name(model_override: str = "") -> str {
    flag = model_override.strip();
    if flag {
        agent.cfg.model_source = "command line";
        return flag;
    }
    # Read the raw table, not the defaults-merged config, so an unset
    # `default_model` is not mistaken for a choice.
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

"""Build the agent's LLM, supporting any byLLM-compatible model.

The model name is resolved by `resolve_model_name` (flag, then jac.toml, then
the bundled local default). Cloud models work out of the box: byLLM's `Model`
pulls `api_key`/`base_url` from `[plugins.byllm.model]` in jac.toml (or the
usual provider env vars). Local models additionally read the runtime knobs
(gpu layers, threads, auto-download) from `[plugins.byllm.local]`; a non-zero
`n_ctx` overrides the configured context window.
"""
impl build_model(model_override: str = "", n_ctx: int = 0) -> Model {
    name = resolve_model_name(model_override);
    cfg: dict[str, object] = {};
    is_local = name.startswith("local:");
    # Reset first: a rebuild may swap local for cloud; don't keep a stale count.
    agent.cfg.threads = 0;
    # Low temp for local determinism; cloud uses the provider default (newer
    # ones reject the param).
    agent.cfg.temperature = 0.3 if is_local else None;
    if is_local {
        try {
            cfg = dict(_byllm_config().get_local_config());
        } except Exception {
            cfg = {};
        }
        # Cap CPU so local inference doesn't peg the machine: configured
        # n_threads wins, else half the cores.
        if not cfg.get("n_threads") {
            cores = os.cpu_count() or 2;
            cfg["n_threads"] = max(1, cores // 2);
        }
        agent.cfg.threads = int(cfg.get("n_threads") or 0);
    } else {
        # Cloud model: inject a live-set key / endpoint when the `--ui` settings
        # panel provided one. byLLM passes these straight to the provider call,
        # overriding env/jac.toml. Empty leaves byLLM's own resolution intact.
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
    # A key we hold (set live) or one configured in jac.toml satisfies the model.
    if agent.cfg.api_key {
        return (False, "");
    }
    try {
        toml_key = str(_byllm_config().get_model_config().get("api_key", "") or "");
        if toml_key {
            return (False, "");
        }
    } except Exception { }
    # Otherwise ask litellm what the provider needs and whether the environment
    # already has it. Only a missing `*_API_KEY` is a key prompt -- a missing
    # base-url (ollama's `OLLAMA_API_BASE`) is configuration, not a credential.
    try {
        import litellm;
        # Untyped through `any`: litellm's stub signature trips the checker, and
        # its return is a plain dict we only `.get()` from.
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

"""Resolve a tool path against the session working directory.

Absolute paths pass through; relative paths are joined onto `agent.cwd` so
every file tool agrees on what `main.jac` means, regardless of where `jac ai`
was launched or which subfolder the model has `cd`'d into.
"""
impl _resolve(path: str) -> str {
    p = path or ".";
    if os.path.isabs(p) {
        return os.path.normpath(p);
    }
    base = agent.cwd or os.getcwd();
    return os.path.normpath(os.path.join(base, p));
}

"""The project root for a directory: nearest ancestor with a `jac.toml`, else it."""
impl _project_root_of(start: str) -> str {
    cur = os.path.normpath(start);
    while True {
        if os.path.isfile(os.path.join(cur, "jac.toml")) {
            return cur;
        }
        parent = os.path.dirname(cur);
        if parent == cur {
            return os.path.normpath(start);
        }
        cur = parent;
    }
}

"""Point the session (and its code intelligence) at a new working directory.

Called when a `run_command` changes the shell's directory. Re-roots the shared
CodeIntelligence at the new project root (the nearest ancestor holding a
`jac.toml`, else the directory itself) so semantic queries and the health line
reflect the project the model actually moved into -- e.g. a freshly scaffolded
app subfolder -- not the launch directory.
"""
impl _set_session_cwd(new_dir: str) {
    real = os.path.normpath(new_dir);
    if not os.path.isdir(real) or real == agent.cwd {
        return;
    }
    prev_root = _project_root_of(agent.cwd) if agent.cwd else "";
    agent.cwd = real;
    new_root = _project_root_of(real);
    # Only rebuild code intelligence when the *project* changed -- a `cd` within
    # the same project keeps the existing (warm) handle.
    if agent.ci is not None and new_root != prev_root {
        try {
            new_ci = CodeIntelligence(proj_dir=new_root, lazy=True);
            new_ci.on_event = agent.ci.on_event;
            agent.ci = new_ci;
            agent.ci_dirty = False;
        } except Exception as e {
            _ = e;
        }
    }
}

"""Clip oversized tool output so it does not blow the model's context."""
impl truncate(text: str, limit: int = 12000) -> str {
    if len(text) > limit {
        extra = len(text) - limit;
        return text[:limit] + f"\n... [truncated, {extra} more chars]";
    }
    return text;
}

"""Ask the user to approve a side-effecting action; honours `--yolo`."""
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

"""Count a diagnostics list as `(errors, warnings)` by severity."""
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

"""Rebuild the project model after a write and report the diagnostics it caused.

Returns, as a text block appended to the write tool's result, every compiler
error and warning now in `path` plus any newly introduced in other project
files the edit affects -- so the model gets compiler feedback, including
cross-file breakage, on every write without a separate `jac_check` call. A
dependent module's pre-existing error is not reported: only the delta this
edit caused. Warnings are included because an undefined name or unresolved
type surfaces as a warning, not an error. Empty string when the edit
introduced nothing (or no code intelligence is available).
"""
impl FileTools.write_feedback(path: str) -> str {
    if agent.ci is None or not agent.cfg.inline_feedback {
        # Feedback off: still flag dirty so the next semantic query refreshes.
        if agent.ci is not None and not agent.cfg.inline_feedback {
            agent.ci_dirty = True;
        }
        return "";
    }
    # Mark dirty up front so a failed refresh still rebuilds on the next query.
    agent.ci_dirty = True;
    try {
        # refresh_and_diff returns the diagnostics this edit caused (`path`
        # plus breakage in dependent modules).
        diags: list = list(agent.ci.refresh_and_diff(path));
    } except Exception {
        return "";
    }
    agent.ci_dirty = False;
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

"""Reject a write that is JavaScript/React rather than Jac, with a fix-it.

A weaker model often reverts to its React training and writes JS/TS syntax
into a `.jac` file (or tries to create a `.js`/`.ts` file outright). This
returns a non-empty error message naming the offending tokens and the Jac
form to use, or `""` when the content is clean Jac -- caught at write time so
one stray file does not cascade into dozens of compile errors. Only `.jac`
(and code-file extensions) are policed; `.css`/`.json`/`.md`/config writes
pass through.
"""
impl FileTools._js_drift_error(path: str, content: str) -> str {
    base = os.path.basename(path);
    # A code file in this project is always Jac. Block JS/TS source outright --
    # the right move is a .jac (or .cl.jac for a client component) file.
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
    # Only police Jac source for React/JS syntax the model slipped in.
    if not base.endswith(".jac") {
        return "";
    }
    # (label, regex) -- each pattern is syntax that is NEVER valid Jac.
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
        ("an arrow function `=>` (use `lambda(x: T) -> R { ... }`)", "=>"),
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
        return truncate(Path(_resolve(path)).read_text());
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
        rp = _resolve(path);
        p = Path(rp);
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text(content);
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
    rp = _resolve(path);
    if not os.path.isfile(rp) {
        # A new file has nothing to edit; steer the model to write_file rather
        # than letting it retry a doomed edit (the loop earlier sessions hit).
        return (
            f"ERROR: {path} does not exist, so there is nothing to edit. "
            "Create it with write_file(path, content) instead. (Paths resolve "
            f"against the current directory {agent.cwd or os.getcwd()}.)"
        );
    }
    try {
        original = Path(rp).read_text();
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
        Path(rp).write_text(updated);
        return f"OK: edited {path}" + self.write_feedback(rp);
    } except Exception as e {
        return f"ERROR writing {path}: {e}";
    }
}

sem FileTools.list_dir = "List the entries of a directory (hidden entries excluded).";
sem FileTools.list_dir.path = "Directory path; empty string means the current directory.";
impl FileTools.list_dir(path: str) -> str {
    try {
        target = Path(_resolve(path));
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
    search_root = Path(_resolve(path));
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
            text = f.read_text();
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

"""Combine a finished subprocess's stdout+stderr into a truncated result string."""
impl ProcessTools._proc_output(result: any) -> str {
    combined = (str(result.stdout or "") + str(result.stderr or "")).strip();
    return truncate(combined or f"(no output; exit code {result.returncode})");
}

"""Run a `jac` subcommand on a file and return its combined output."""
impl ProcessTools.run_jac_cli(subcommand: str, path: str) -> str {
    try {
        return agent.proc._proc_output(
            subprocess.run(
                [sys.executable, "-m", "jaclang", subcommand, path],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=agent.cwd or None
            )
        );
    } except Exception as e {
        return f"ERROR running `jac {subcommand} {path}`: {e}";
    }
}

sem ProcessTools.run_command = "Run a shell command in the project directory and return its combined output. Use this to scaffold a new project (`jac create --use fullstack <name>`), install dependencies (`jac install`), run a file (`jac run <file>`), run tests, or any other shell task. `jac create` templates: default, client, fullstack.";
sem ProcessTools.run_command.command = "The shell command to run.";
impl ProcessTools.run_command(command: str) -> str {
    # `jac start` / `jac serve` are long-lived servers: run through run_command
    # they would block until the 180s timeout. Redirect to the dedicated tools,
    # which start the server, wait for readiness, and hand back a URL.
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
    # Prepend the interpreter's bin dir to PATH so `jac` resolves even when the
    # session was launched without the env activated.
    env = dict(os.environ);
    bin_dir = os.path.dirname(sys.executable);
    if bin_dir {
        env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "");
    }
    work_dir = agent.cwd or os.getcwd();
    # Run the command, then echo the shell's final directory on its own line.
    # Because shell=True runs the whole thing in one shell, a `cd` inside
    # `command` changes that shell's cwd, and the trailing `pwd` captures it --
    # so we can carry the new directory into the next call and the file tools.
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
        _set_session_cwd(new_cwd);
    }
    combined = ("\n".join(kept) + str(result.stderr or "")).strip();
    out = truncate(combined or f"(no output; exit code {result.returncode})");
    # When the model changed directory, say so -- otherwise a `cd` looks like a
    # no-op in the transcript and the model repeats it.
    if new_cwd and new_cwd != work_dir {
        out = f"(now in {new_cwd})\n" + out;
    }
    return out;
}

sem ProcessTools.jac_check = "Type-check and compile Jac code with `jac check`. Pass a single file, or a directory (`.` for the whole project) to check everything at once. Use this after writing or editing Jac code to confirm it is valid.";
sem ProcessTools.jac_check.path = "File or directory to check; '.' or empty string checks the whole project.";
impl ProcessTools.jac_check(path: str) -> str {
    return agent.proc.run_jac_cli("check", path or ".");
}

sem ProcessTools.start_app = "Start the app with `jac start` for ~12 seconds to confirm it boots, then stop it; returns the startup logs. Use this after building an app to catch errors that `jac check` cannot.";
sem ProcessTools.start_app.entry_file = "Entry .jac file to start; empty string means 'main.jac'.";
impl ProcessTools.start_app(entry_file: str) -> str {
    entry_path = entry_file or "main.jac";
    abs_entry = _resolve(entry_path);
    if not os.path.isfile(abs_entry) {
        return (
            f"ERROR: no such entry file '{entry_path}' (looked in "
            f"{agent.cwd or os.getcwd()}). Use list_dir to find the app's "
            "main .jac file, then pass its path."
        );
    }
    if not confirm(f"start the app with `jac start {entry_path}`") {
        return "DENIED: the user declined to start the app.";
    }
    # Run in the entry file's own dir: `jac start` resolves the project and its
    # deps from there, which matters when the app was scaffolded into a subfolder.
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
    # Boot then stop -- we only want the startup diagnostics. The 12s window is
    # overridable via JAC_AI_START_TIMEOUT (seconds), mainly for tests.
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

sem ProcessTools.serve = "Start the web/fullstack dev server and wait until it is actually serving, returning the URL to open. The first start can take a while because it installs the client dependencies and builds the client; this tool blocks until the server is ready (or fails) so you do not have to guess. On success, call browse_open on the returned URL. On failure it returns the server log tail -- read it, go back to Build to fix the cause, and do not conclude the app works.";
sem ProcessTools.serve.entry_file = "Entry .jac file to serve; empty string means 'main.jac'.";
"""Start the dev server and wait until it is actually serving, returning its URL.

Launches `jac start <entry>` detached and polls its log until the ready URL
appears -- the first start can be slow because it installs client deps and
builds the client -- then returns that URL for `browse_open`. On failure
returns the log tail so the model can fix the cause. Far more reliable than
starting the server by hand and scraping the log for a URL within a fixed
window.
"""
impl ProcessTools.serve(entry_file: str) -> str {
    entry_path = entry_file or "main.jac";
    abs_entry = _resolve(entry_path);
    if not os.path.isfile(abs_entry) {
        return (
            f"ERROR: no such entry file '{entry_path}' (looked in "
            f"{agent.cwd or os.getcwd()}). Use list_dir to find the app's "
            "main .jac file (the one with the `cl`/`sv` mount), then pass its path."
        );
    }
    if not confirm(f"start the dev server with `jac start {entry_path}`") {
        return "DENIED: the user declined to start the server.";
    }
    # Drop any server we started earlier so we don't leak ports.
    agent.proc._serve_shutdown();
    work_dir = os.path.dirname(abs_entry) or ".";
    target = os.path.basename(abs_entry);
    log_path = "/tmp/jac_ai_serve.log";
    try {
        log_f = open(log_path, "w");
        # Own process group so _serve_shutdown can kill the server *and* the
        # vite/build children it spawns.
        agent.serve_proc = subprocess.Popen(
            [sys.executable, "-m", "jaclang", "start", target],
            cwd=work_dir,
            stdout=log_f,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True
        );
    } except Exception as e {
        return f"ERROR launching `jac start {entry_path}`: {e}";
    }
    # First build is slow (deps + client build); poll the log for the ready URL
    # rather than reading once. Override the budget with JAC_AI_SERVE_TIMEOUT.
    timeout = 120.0;
    try {
        raw = os.environ.get("JAC_AI_SERVE_TIMEOUT");
        if raw {
            timeout = float(raw);
        }
    } except Exception as e {
        _ = e;
    }
    # Match only the local dev URL, never an unrelated link (e.g. a help URL
    # printed among the dependency warnings).
    url_re = re.compile(
        "https?://(?:localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)(?::\\d+)?\\S*"
    );
    deadline = time.time() + timeout;
    url = "";
    while time.time() < deadline {
        if agent.serve_proc.poll() is not None {
            break;  # server exited before becoming ready
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
    agent.proc._serve_shutdown();
    return (
        f"ERROR: the server did not become ready within {int(timeout)}s. "
        f"Last log lines:\n{tail}"
    );
}

sem ProcessTools.stop_server = "Stop the dev server started by serve. Call this when finished with browser QA.";
"""Stop the dev server started by `serve` (best-effort)."""
impl ProcessTools.stop_server -> str {
    agent.proc._serve_shutdown();
    return "OK: dev server stopped.";
}

"""Kill the `serve` dev server and its child processes if one is running."""
impl ProcessTools._serve_shutdown{
    if agent.serve_proc is not None {
        try {
            os.killpg(os.getpgid(int(agent.serve_proc.pid)), int(signal.SIGTERM));
        } except Exception {
            try {
                agent.serve_proc.terminate();
            } except Exception { }
        }
        agent.serve_proc = None;
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
            # Negative hit count sorts most-relevant-first under a plain sort.
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

"""Return the session's CodeIntelligence, rebuilding it if a write happened.

`write_file`/`edit_file` flag the project as dirty; the first semantic query
after a write recompiles so symbol lookups reflect what the agent just wrote.
"""
impl code_intel -> any {
    if agent.ci is None {
        return None;
    }
    if agent.ci_dirty {
        try {
            agent.ci.refresh();
        } except Exception { }
        agent.ci_dirty = False;
    }
    return agent.ci;
}

sem SemanticTools.find_symbol = "Look up a Jac symbol (node, walker, edge, obj, enum, ability, ...) by name via the compiler's symbol table. Returns its exact definition site, fields, abilities, base classes, and every place it is used. This is precise -- unlike grep it never matches a comment or an unrelated identifier. Prefer this over grep whenever you know the name of the thing you are looking for.";
sem SemanticTools.find_symbol.name = "The symbol name to look up, e.g. 'User' or 'make_user'.";
impl SemanticTools.find_symbol(name: str) -> str {
    ci = code_intel();
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
    ci = code_intel();
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
    ci = code_intel();
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
    ci = code_intel();
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
    ci = code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    return str(ci.slice_for(name).render());
}

"""Turn a browser-engine exception into a tool-result string with a next step."""
impl BrowseTools._browse_err(e: Exception) -> str {
    msg = str(e);
    if "no live browser" in msg {
        return "ERROR: no browser is open -- call browse_open(url) first.";
    }
    return f"ERROR: {msg}";
}

"""Run a browser-engine call under the shared confirm / error / truncate policy.

`confirm_msg` empty means the op is read-only and runs unconfirmed; otherwise
the action is gated and a declined call returns a DENIED string. `run` is a
thunk performing the actual `br_*` call; its result is returned (str-cast),
truncated when `clip` is set. Engine exceptions become a `_browse_err` string.
"""
impl BrowseTools._browse(confirm_msg: str, run: any, clip: bool = False) -> str {
    if confirm_msg and not confirm(confirm_msg) {
        return f"DENIED: the user declined to {confirm_msg}.";
    }
    try {
        out = run();
        return truncate(str(out)) if clip else str(out);
    } except Exception as e {
        return agent.web._browse_err(e);
    }
}

sem BrowseTools.browse_open = "Launch a headless browser (or reuse the one already open) and navigate to a URL. Use this to QA a running web app, then read the page with browse_snapshot. An empty URL opens a blank page.";
sem BrowseTools.browse_open.url = "URL to open, e.g. 'http://localhost:8000'. Empty string opens about:blank.";
impl BrowseTools.browse_open(url: str) -> str {
    return agent.web._browse(
        f"open a browser at {url}" if url else "",
        lambda : br_open(agent.browse_session, url or None)
    );
}

sem BrowseTools.browse_navigate = "Navigate the open browser to a different URL and wait for it to load.";
sem BrowseTools.browse_navigate.url = "The URL to navigate to.";
impl BrowseTools.browse_navigate(url: str) -> str {
    return agent.web._browse(
        f"navigate the browser to {url}",
        lambda : br_navigate(agent.browse_session, url)
    );
}

sem BrowseTools.browse_snapshot = "Read the current page as an accessibility tree. Interactive elements are tagged with @e1/@e2 refs that you pass to browse_click, browse_type, and browse_fill. Call this after navigating, and again after any action that changes the page, to see the new state.";
impl BrowseTools.browse_snapshot -> str {
    return agent.web._browse("", lambda : br_snapshot(agent.browse_session), clip=True);
}

sem BrowseTools.browse_click = "Click an element with a real, trusted mouse event. Pass an @ref from browse_snapshot (e.g. '@e5') or a CSS selector (e.g. '#submit').";
sem BrowseTools.browse_click.target = "An @ref from browse_snapshot, or a CSS selector.";
impl BrowseTools.browse_click(target: str) -> str {
    return agent.web._browse(
        f"click {target} in the browser",
        lambda : br_click(agent.browse_session, target)
    );
}

sem BrowseTools.browse_type = "Focus an element and type text into it as real key events, appending to whatever is already there.";
sem BrowseTools.browse_type.target = "An @ref from browse_snapshot, or a CSS selector.";
sem BrowseTools.browse_type.text = "The text to type.";
impl BrowseTools.browse_type(target: str, text: str) -> str {
    return agent.web._browse(
        f"type into {target} in the browser",
        lambda : br_type(agent.browse_session, target, text)
    );
}

sem BrowseTools.browse_fill = "Clear a field and set its value to the given text. Prefer this over browse_type for form fields.";
sem BrowseTools.browse_fill.target = "An @ref from browse_snapshot, or a CSS selector.";
sem BrowseTools.browse_fill.text = "The text to set the field to.";
impl BrowseTools.browse_fill(target: str, text: str) -> str {
    return agent.web._browse(
        f"fill {target} in the browser",
        lambda : br_fill(agent.browse_session, target, text)
    );
}

sem BrowseTools.browse_press = "Press a single key in the browser, e.g. 'Enter', 'Tab', 'Escape', or a chord like 'Ctrl+A'.";
sem BrowseTools.browse_press.key = "The key or chord to press.";
impl BrowseTools.browse_press(key: str) -> str {
    return agent.web._browse(
        f"press {key} in the browser", lambda : br_press(agent.browse_session, key)
    );
}

sem BrowseTools.browse_get = "Read a property of the current page: 'url', 'title', or 'text' (the visible text of the element named by selector).";
sem BrowseTools.browse_get.what = "One of 'url', 'title', or 'text'.";
sem BrowseTools.browse_get.selector = "CSS selector for 'text'; empty string for 'url' or 'title'.";
impl BrowseTools.browse_get(what: str, selector: str) -> str {
    return agent.web._browse(
        "", lambda : br_get(agent.browse_session, what, selector or None), clip=True
    );
}

sem BrowseTools.browse_eval = "Evaluate a JavaScript expression in the page and return its result. Use this to inspect page state or check for errors, e.g. \"document.querySelectorAll('.error').length\".";
sem BrowseTools.browse_eval.expression = "A JavaScript expression to evaluate.";
impl BrowseTools.browse_eval(expression: str) -> str {
    return agent.web._browse(
        f"run JavaScript in the browser: {expression}",
        lambda : br_eval(agent.browse_session, expression),
        clip=True
    );
}

sem BrowseTools.browse_close = "Close the browser and free its resources. Call this when finished with browser QA.";
impl BrowseTools.browse_close -> str {
    return agent.web._browse("", lambda : br_close(agent.browse_session));
}

"""Close the agent's browser session if one was opened (best-effort)."""
impl BrowseTools._browse_shutdown{
    try {
        br_close(agent.browse_session);
    } except Exception {
    # The browser may never have been opened this session; nothing to clean.
    }
}

"""Build the agent's system message: rules, the guide index, and the cheatsheet."""
impl system_prompt -> str {
    index_lines: list[str] = [];
    for g in gs_list() {
        index_lines.append(f"- {g.name}: {g.description}");
    }
    guide_index = "\n".join(index_lines);
    cheatsheet = gs_get("jac-core-cheatsheet");
    cheatsheet_body = cheatsheet.body if cheatsheet is not None else "";
    return (
        AGENT_RULES + "\n## Reference guides available (open one with read_guide)\n\n" + guide_index + "\n\n## Jac core cheatsheet\n\n" + cheatsheet_body
    );
}

"""Clear the durable session memory (the cross-turn ledger)."""
impl reset_session{
    agent.ledger = Ledger();
}

# ---------------------------------------------------------------------------
# Event bus -- structured milestones for the `--ui` web view.
# ---------------------------------------------------------------------------
"""Append one event (kind + fields), stamping a monotonic id; thread-safe."""
impl AgentEventBus.emit(kind: str, fields: dict) -> None {
    if not self.active_feed {
        return;
    }
    # No lock: the only writer is the single turn thread and the only reader is
    # the poll endpoint; under the GIL the list append and the slice-reassign
    # below are each atomic, and `snapshot` copies in one atomic step.
    ev = {"id": self._next_id, "kind": kind};
    ev.update(fields);
    self._next_id += 1;
    self.events.append(ev);
    # Bounded ring: the UI replaces its whole log each poll, so dropping the
    # oldest events just trims scrollback, never breaks continuity.
    if len(self.events) > self._cap {
        self.events = self.events[-self._cap:];
    }
    self.publish(ev);
}

"""Stream a token into the current block, or open a new one.

Reasoning and answer text arrive token-by-token. Rather than one event per
token (which would flood the feed and evict history), append the token to
the trailing event when it is a streaming block of the same `kind`; any
other emitted event closes the block, so the next token starts a fresh one.
The event's `text` grows in place, so each poll shows more of the stream.
"""
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
        # Re-push the grown event so the client sees the cleaned text grow live.
        # The firehose is fed separately from the raw stream (see feed_token).
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

"""Push one raw model token to the live firehose, without touching the event
log. Fed from the unsplit stream, so it includes the tokens that form tool
calls -- which the cleaned reasoning view deliberately hides.
"""
impl AgentEventBus.feed_token(token: str) -> None {
    if not self.active_feed or not self._subscribers {
        return;
    }
    # Token-only message (no `ev`): the client appends it to the firehose and
    # refreshes top-level state, but the event log is untouched.
    msg = self._state();
    msg["token"] = token;
    for q in list(self._subscribers) {
        try {
            q.put_nowait(msg);
        } except Exception { }
    }
}

"""Mark the walker as entering a phase: set active, extend the path, emit."""
impl AgentEventBus.enter(phase: str) -> None {
    self.active = phase;
    self.path.append(phase);
    self.emit("phase", {"node": phase});
}

"""Set the run status ("idle" | "running" | "done") and emit a status event."""
impl AgentEventBus.set_status(s: str) -> None {
    self.status = s;
    self.emit("status", {"status": s});
}

"""Reset the per-turn graph state (active node and path) for a fresh walk."""
impl AgentEventBus.begin_turn -> None {
    self.active = "";
    self.path = [];
    self.cancel_requested = False;
}

"""A JSON-ready snapshot the `ui_poll` endpoint returns each tick."""
impl AgentEventBus._state -> dict {
    # The common top-level state every pushed frame (snapshot/delta/token/
    # ledger) carries, so the client can refresh status, the walker position,
    # the stat line, AND the API-key prompt from any message in one place.
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
    # Copy in one step so the returned lists are stable even if the turn thread
    # emits concurrently (atomic under the GIL).
    snap = self._state();
    snap["events"] = list(self.events);
    snap["ledger"] = self.ledger_view();
    return snap;
}

"""A JSON-ready view of the durable session ledger (changes + notes), read
live off `agent.ledger` so the UI's ledger panel mirrors it."""
impl AgentEventBus.ledger_view -> dict {
    led = agent.ledger;
    if led is None {
        return {"changes": [], "notes": []};
    }
    return {"changes": list(led.changes), "notes": list(led.notes)};
}

"""Push the current ledger to every subscriber. Called whenever the ledger
changes (a phase records a step, or `note` leaves a note) so the UI's ledger
panel updates in real time rather than only on the next poll."""
impl AgentEventBus.publish_ledger -> None {
    if not self.active_feed or not self._subscribers {
        return;
    }
    # A ledger-only message: no `ev`/`token`, so the client refreshes its ledger
    # panel and top-level state without touching the event log or firehose.
    msg = self._state();
    msg["ledger"] = self.ledger_view();
    for q in list(self._subscribers) {
        try {
            q.put_nowait(msg);
        } except Exception { }
    }
}

"""Register an SSE subscriber queue; returns it. Caller unsubscribes on close."""
impl AgentEventBus.subscribe -> any {
    import from queue { Queue }
    q = Queue();
    self._subscribers.append(q);
    return q;
}

"""Drop a subscriber queue (on stream close/disconnect)."""
impl AgentEventBus.unsubscribe(q: any) -> None {
    if q in self._subscribers {
        self._subscribers.remove(q);
    }
}

"""Push one delta message (the changed event + current top-level state) to
every subscriber. Called from `emit`/`emit_stream`.
"""
impl AgentEventBus.publish(ev: dict) -> None {
    if not self.active_feed or not self._subscribers {
        return;
    }
    # One delta carries the changed event plus the current top-level state, so
    # the client upserts the event by id and refreshes status/active/path/stats
    # in one step. Snapshot over a copy of the subscriber list (a stream may
    # unsubscribe concurrently).
    msg = self._state();
    msg["ev"] = ev;
    for q in list(self._subscribers) {
        try {
            q.put_nowait(msg);
        } except Exception { }
    }
}

"""Push a full snapshot (all events + state) to every subscriber -- the
first frame of a new stream, and after a reset.
"""
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

"""Stop a turn that keeps rewriting the same file without making progress.

byLLM calls this before each ReAct iteration. It counts how often each file has
been written so far this turn (from the assistant tool-call history); once any
single file crosses `_REWRITE_LIMIT`, the model is looping on an error it cannot
fix, so end the turn with a summary instead of spending the whole budget.
"""
impl _progress_guard(ctx: any) -> str {
    import json;
    # User pressed Stop (UI): abort the phase at this checkpoint.
    if agent.bus.cancel_requested {
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    counts: dict[str, int] = {};
    # Ordered signature ("name|args") of every tool call, to spot a model stuck
    # re-issuing the SAME call (read or write) -- e.g. read_file(main.jac) 40x.
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
    # Repeated-call loop: the last 3 tool calls are byte-for-byte identical. No
    # legitimate workflow re-runs the exact same call thrice in a row, so end the
    # phase and let the pipeline move on rather than burn the iteration budget.
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

"""Format a tool call as `name(key=value, ...)`, clipping long values."""
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

"""Render a token count compactly: 12400 -> '12.4k', 840 -> '840'."""
impl TurnRenderer._short_num(n: int) -> str {
    return f"{n / 1000:.1f}k" if n >= 1000 else str(n);
}

"""Best-effort USD cost for the turn from litellm's price map; 0 if unknown.

Local models and any model litellm does not price raise here and fall back
to 0 -- which is correct for a local model, and a benign omission otherwise.
"""
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

"""Render token usage (and cost, when priced) from a byLLM `usage` total."""
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

"""Render the project's compiler health from the session's CodeIntelligence.

The count is project-wide, so it catches breakage the turn left in any file.
Reported only when the turn already built the project model (a write or a
semantic-tool query): a stat line must stay cheap and must never trigger a
whole-project compile -- in a large repo that would stall every turn. When
the model is not yet built there is nothing the turn touched, so the stat is
simply omitted.
"""
impl TurnRenderer._format_health -> str {
    ci = code_intel();
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

"""Print the one-line turn summary: duration, tools, files, tokens, health."""
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
    # Generation throughput: completion tokens over the wall-clock turn time.
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

"""Strip a model's stray control tokens from streamed reasoning prose.

Some local templates wrap tool syntax in `<|channel>`/`<token|>` markers and
render quotes as `<|"|>`; clear them so only clean prose reaches the terminal.
The tool-call JSON itself is excluded upstream by `_split_reasoning`.
"""
impl TurnRenderer._strip_control(text: str) -> str {
    import re;
    t = text.replace("<|\"|>", "\"").replace("<|'|>", "'");
    t = re.sub("<\\|[a-z_]+>[a-z]*", "", t);
    t = re.sub("<[a-z_]+\\|>", "", t);
    return t;
}

"""Split accumulated reasoning into the prose safe to show and a hit flag.

A reply is reasoning prose followed by the `<tool_call>` JSON the protocol
recovers into a structured event. Return only the prose before the marker,
and hold back a trailing partial `<tool_call` so a marker split across stream
tokens is never shown. `hit` is True once the marker has appeared.
"""
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

"""Up to `max_lines` lines of a tool result, each clipped, with a more-marker."""
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

"""Format a millisecond duration compactly: '820ms', '1.8s', '13.0s'."""
impl TurnRenderer._fmt_ms(ms: float) -> str {
    return f"{int(ms)}ms" if ms < 1000 else f"{ms / 1000:.1f}s";
}

"""Format a step's model timing as `(24.6s, 113 tps)`, omitting tps if unknown."""
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

"""Render a code-intelligence compile, set as `CodeIntelligence.on_event`.

Fires whenever the compiler-backed project model rebuilds -- the initial
load, and the incremental recompile after each write or the first query
following one. Printed inline with the tool stream (it runs inside a tool's
execution) so the hidden compiler work behind write_file/find_symbol/etc. is
visible: which file, how many modules were recompiled out of the project, and
how long it took.
"""
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
        # In structural mode some modules are served from the on-disk index
        # rather than re-parsed; surface that so the cross-run win is visible.
        what = f"load · compiled {recompiled} files";
        if cached {
            what += f" · {cached} from cache";
        }
    } else {
        # create / edit / delete: show recompiled/total so an incremental
        # refresh reads as cheaper than a full build.
        what = f"{op} {name} · recompiled {recompiled}/{total}";
    }
    console.print(
        f"      ⚙ code intel · {what} · {agent.view._fmt_ms(ms)}", style="dim"
    );
}

"""Consume one byLLM phase event stream, rendering it live.

A phase ability calls this with the stream returned by the `run_phase` byLLM
call (typed `-> str` for the streaming contract, but with `logging=True` it
yields StreamEvent objects). Renders reasoning, tool calls, and the answer
live, and returns this phase's tool-call tallies for the walker to accumulate.
"""
impl TurnRenderer.render_stream(event_stream: any) -> dict {
    out: any = sys.stdout;
    # `\r` animation only makes sense on a tty; piped output gets static lines.
    is_tty = bool(out?.isatty) and bool(out.isatty());
    # A write tool anywhere in the turn arms the verify-and-continue guard.
    # Declared before the try so the `except` handlers can still return them.
    n_read = 0;
    n_write = 0;
    n_run = 0;
    files: set[str] = set();
    usage: dict[str, object] = {};
    answer = "";  # the phase's final answer text, captured for the ledger
    streamed = False;  # raw reasoning/answer tokens on the current line
    thought_raw = "";  # this step's accumulated reasoning tokens
    prose_shown = 0;  # chars of this step's prose already streamed
    step_t0 = 0.0;  # when this step's generation began
    think_on = False;  # a live `thinking...` line is on screen
    last_llm_ms = 0.0;  # model gen time of the step just finished
    last_llm_tokens = 0;  # completion tokens of that step, for tokens/sec
    pend_result: any = None;  # a tool result awaiting its timing event
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
        agent.bus.emit("tool_result", {"text": truncate(str(result), 600)});
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
            # Stop pressed in the UI: quit consuming the stream immediately so
            # the feed stops updating; the progress guard ends the ReAct loop.
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
                # Raw firehose: every generated token, including the ones that
                # form tool calls (which the cleaned reasoning below hides).
                agent.bus.feed_token(tok);
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
                # Generating but no prose yet (streaming as JSON): show a
                # ticking activity line so a slow model is not silent.
                if hit and not streamed and is_tty {
                    out.write(f"\r  ● thinking… {time.time() - step_t0:.1f}s");
                    out.flush();
                    think_on = True;
                }
            } elif kind == "chunk" {
                # Final answer: never a tool call, so stream live in both views.
                clear_think();
                flush_result();
                tok = str(data.get("content", ""));
                answer += tok;
                out.write(tok);
                out.flush();
                streamed = True;
                # Stream the answer into the conversation token-by-token, and
                # the raw token into the firehose.
                agent.bus.emit_stream("answer", tok);
                if tok {
                    agent.bus.feed_token(tok);
                }
            } elif kind == "llm_timing" {
                last_llm_ms = float(data.get("duration_ms", 0) or 0);
                last_llm_tokens = int(data.get("completion_tokens", 0) or 0);
            } elif kind == "tool_call" {
                clear_think();
                end_line();
                flush_result();
                tool = str(data.get("tool", "?"));
                args = data.get("args", {});
                # Tally for turn stats: writes (and the files they touch), runs,
                # everything else a read.
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
                # byLLM emits one `usage` event at stream end, totalled across the turn.
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

"""Record what a phase accomplished, as a one-line ledger entry."""
impl Ledger.record(phase: str, summary: str) {
    self.changes.append({"phase": phase, "summary": truncate(summary, 400)});
}

"""Leave a free-form note visible to every later phase and turn."""
impl Ledger.remember(text: str) {
    self.notes.append(text);
}

"""Render the ledger as compact text for injection into a phase prompt."""
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

"""Fold one phase's render_stream result into the running totals."""
impl TurnStats.absorb(st: dict) {
    self.n_read += int(st["n_read"]);
    self.n_write += int(st["n_write"]);
    self.n_run += int(st["n_run"]);
    self.files |= set(st["files"]);
    for (k, v) in st["usage"].items() {
        self.usage[k] = self.usage.get(k, 0) + v if isinstance(v, (int, float)) else v;
    }
}

"""Compose the system message for a state, given the objective and memory."""
impl Prompt.for_phase(state_ty: type, objective: str, ledger: Ledger) -> str {
    role = str(getattr(state_ty, "_jac_semstr", "") or "");
    return (
        system_prompt() + "\n\n## Current state\n\nYou are in " + role + "\n\n## Objective\n\n" + objective + "\n\n## Progress so far (shared across states)\n\n" + ledger.render()
    );
}

sem AgentRuntime.note = "Record a short note that stays visible to every later phase (Plan, Build, QA) and in later turns. Use it to flag a decision, an assumption, or something to verify.";
sem AgentRuntime.note.text = "The note to remember.";
"""Record a note onto the active session's ledger (the `note` tool).

A memory capability rather than a domain toolbox: it writes to the live
walker's ledger, which the runtime owns, so notes stay visible to every
later phase and turn.
"""
impl AgentRuntime.note(text: str) -> str {
    if agent.active_session is not None {
        agent.active_session.ledger.remember(text);
        agent.bus.publish_ledger();
        return f"noted: {text}";
    }
    return "(no active session to note onto)";
}

# A state's tools are the TOOLS rows tagged with its phase, in registry order.
# The phase is the node's class name lowercased (Plan -> "plan"), the same name
# `run` uses as the phase label -- so Plan/Build/QA need no override.
"""The tools this state exposes: the TOOLS rows tagged with its phase.

Derived from the node's own class name (Plan/Build/QA -> plan/build/qa),
so a state's allowed actions follow from its identity with no per-state
override -- the same name `run` uses as the phase label.
"""
impl PhaseState.tools -> list {
    phase = type(self).__name__.lower();
    return [
        t.fn
        for t in TOOLS
        if phase in t.phases
    ];
}

sem Plan = "the PLANNING state: understand the request and the existing project before writing anything. Use project_map for an unfamiliar project, find_symbol / find_uses / context_slice to navigate by meaning, read_file to read what you will change, and the guides for unfamiliar Jac (read at least the one for the kind of code you will write -- e.g. jac-cl-components for a UI). Do not write or edit files here. Finish by stating a short, concrete plan: whether to scaffold (and which template -- client for a browser-only UI, fullstack for server/data, default for a script), the files to create or change, and what each is for.";

sem Build = "the BUILDING state: carry out the plan. For a new app, scaffold it ONCE with `jac create --use <template> <name>` via run_command, then `cd <name>` so every later tool works inside the project (the cd persists). Pick the SIMPLEST template that fits: `client` for a browser-only UI with no server or saved data (a calculator, a unit converter, a static page); `fullstack` only when you need server endpoints or persistent/multi-user data; `default` for a non-web script. To create a NEW file, call write_file with its FULL contents -- never create files with shell redirection (`echo >`, `cat <<EOF`, `touch`) and never try to edit a file that does not exist yet. Use edit_file only to change a file that already exists, and read it first. Every write reports the compiler errors it introduced; fix them before moving on. Keep files focused; split large archetypes into impl files.";

sem QA = "the QA state: verify the work end to end and fix what you find. Run `jac check .` (zero errors required). For a runnable app, start_app and confirm it boots cleanly. For a web or fullstack app, drive the built-in browser: call serve(entry) to start the dev server -- it waits until the server is actually ready and returns its URL (the first start is slow, as it installs client deps and builds the client). Then browse_open that URL, browse_snapshot to read the page, exercise the main flows with browse_click / browse_fill / browse_type / browse_press (snapshotting after each), check for errors with browse_eval, then browse_close and stop_server. If serve reports the server failed to start, read the log tail it returns and go back to Build to fix the cause -- do not conclude the app works until you have actually run and exercised it.";

"""The imperative kickoff line for a phase, by state label (Plan/Build/QA).

The phase `sem` describes the role; this is the turn's actual instruction. A
weaker model tends to stop after merely exploring or describing a plan, so the
Build line insists on writing code and the QA line insists on actually running
the result -- finishing is not an option until the work exists and is verified.
"""
impl _phase_directive(label: str) -> str {
    if label == "Plan" {
        return (
            "Investigate the request and the existing project, then state a "
            "short, concrete plan. Do not write or edit files in this state."
        );
    }
    if label == "Build" {
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
    if label == "QA" {
        return (
            "Verify the finished work end to end NOW. Run jac_check and require "
            "zero errors. For a web or fullstack app, serve it and drive the "
            "browser (browse_open, browse_snapshot, then click/type the real "
            "controls) to confirm the REQUESTED feature actually works on the "
            "page -- not just that the scaffold loads. If anything is missing, "
            "wrong, or broken, go back to Build to fix it; choose Done only "
            "after you have actually run and exercised the result."
        );
    }
    return f"Carry out the {label} state now.";
}

sem run_phase.directive = "A short instruction kicking off the current phase.";
impl PhaseState.run{
    agent.active_session = visitor;
    label = type(self).__name__;
    # Stop pressed in the UI: halt the walker before entering another phase.
    if agent.bus.cancel_requested {
        return;
    }
    console.print(f"\n  ● {label}", style="bold blue");
    # Move the walker on the live graph: the UI animates the edge from the
    # previous phase to this one.
    agent.bus.enter(label);
    # Refresh the system message with the latest ledger; keep this node's prior
    # working messages (its memory).
    sysmsg = {
        "role": "system",
        "content": Prompt.for_phase(type(self), visitor.objective, visitor.ledger)
    };
    if not self.ctx {
        self.ctx.append(sysmsg);
    } else {
        self.ctx[0] = sysmsg;
    }
    result = agent.view.render_stream(
        run_phase(_phase_directive(label), self.tools(), self.ctx)
    );
    visitor.stats.absorb(result);
    visitor.ledger.record(label, str(result.get("answer", "") or "(no summary)"));
    # Surface the new ledger entry to the UI panel right away (the next bus emit
    # would carry it anyway, but this lands it the instant the phase records).
    agent.bus.publish_ledger();
    # Stop pressed during the phase: halt here, don't route onward (and don't
    # make the QA route-selection LLM call).
    if agent.bus.cancel_requested {
        return;
    }
    # Route to the next state along this node's own out-edges.
    visitor.steps += 1;
    if visitor.steps > visitor.max_steps {
        # Safety valve: a runaway session halts here (no onward visit) rather
        # than looping forever. The outer verify-and-continue still applies.
        console.print("\n  ● step cap reached -- stopping", style="yellow");
    } elif label == "Build"
    and int(result.get("n_write", 0) or 0) == 0
    and visitor.build_nudges < 2 {
        # Build that wrote nothing -- a weaker model often "describes" code (even
        # pastes it into its answer) without ever calling write_file. Don't let
        # that count as building: push back into Build with a blunt instruction
        # to actually write the files. Bounded by build_nudges so a model that
        # truly cannot produce a file falls through instead of looping.
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
    } elif len([-->]) == 1 {
        # Single successor (Plan -> Build, Build -> QA): advance, no LLM call.
        visit [-->];
    } elif _project_errors() {
        # Hard gate: the project does not compile, so finishing is not an option.
        # Skip the model's choice and route straight back to Build to fix it --
        # this is what stops QA from declaring Done on broken code.
        n = len(_project_errors());
        console.print(
            f"  ↳ project has {n} compile error(s) -- returning to Build",
            style="yellow"
        );
        visit [-->][?:Build];
    } else {
        # Several successors (QA -> Build / Plan / Done) and the project
        # compiles: let the model choose along this node's own out-edges,
        # reading each candidate state's `sem`, the objective, and the ledger.
        # Streamed via a stream_handler so the routing call's tokens reach the
        # live firehose, while `visit [-->] by` still constrains the choice to a
        # real successor edge (no free-text parsing, no manual default).
        visit [-->] by agent_model(
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

"""Forward one byLLM StreamEvent from a `visit [-->] by model` routing call.

Passed as the `stream_handler` to the QA routing model so the structured
edge selection still streams: every raw token is teed to the live firehose
and any clean reasoning prose is shown in the feed, while `visit [-->] by`
keeps the choice constrained to a real successor edge. Lighter than
`render_stream` -- routing is one cheap call, not a phase, so it skips the
tool and turn-stat bookkeeping.
"""
impl TurnRenderer.route_stream_event(event: any) -> None {
    # Stop pressed in the UI: drop further routing tokens immediately.
    if agent.bus.cancel_requested {
        return;
    }
    tok = str(event.data.get("content", "")) if event.data else "";
    if not tok {
        return;
    }
    # Every routing token is raw model output -- the structured choice JSON, or
    # reasoning a backend streams ahead of it. Tee it all to the firehose; show
    # only clean reasoning prose (`thought`) in the live reasoning feed.
    agent.bus.feed_token(tok);
    if event.event_type == "thought" {
        cleaned = self._strip_control(tok);
        if cleaned {
            agent.bus.emit_stream("reasoning", cleaned);
        }
    }
}

sem Done = "the DONE state: choose this only when the objective is fully built AND QA has actually verified it (type-checked, and for an app, run and exercised). Ends the session.";
impl Done.finish{
    # No onward visit: the walker's queue empties here and the session ends.
    console.print("\n  ● Done", style="bold green");
    agent.bus.enter("Done");
}

"""Build the phase pipeline and return its entry (Plan).

The single source of truth for the workflow topology: which states exist and
the legal transitions between them. Both the walker (`AgentSession.begin`) and
the UI (`ui_graph`, which traces the result) consume this, so changing an edge
here updates the agent's behavior and the rendered graph at once.
"""
impl build_pipeline -> Plan {
    # Wire the phase pipeline. The edges ARE the legal transitions: Plan -> Build
    # -> QA, with QA looping back to Build/Plan or finishing at Done. This is the
    # only place the topology is written down; `ui_graph` traces these same nodes
    # and edges so the rendered graph can never drift from the real workflow.
    plan = Plan();
    build = Build();
    qa = QA();
    done = Done();
    plan ++> build;
    build ++> qa;
    qa ++> build;
    qa ++> plan;
    qa ++> done;
    return plan;
}

impl AgentSession.begin{
    # Build the pipeline as a free-standing graph and enter at Plan. The session
    # does not hang off root: these nodes exist only for the walker to traverse,
    # so there is no Root -> Plan edge to confuse the topology or the trace.
    visit build_pipeline();
}

"""Run one agent turn: spawn the session walker, then render the turn summary."""
impl run_turn(message: str) {
    agent.turn_wrote = False;
    # The session ledger persists across turns; create it on first use.
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
    # Publish the same summary the CLI prints (print_stats) as structured data
    # for the UI's stats bar: duration, tool breakdown, files, tokens, cost,
    # throughput, and project health.
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
        # Project health, only when the model is already built (cheap) -- same
        # guard the CLI uses so a stat line never forces a whole-project compile.
        n_err = 0;
        n_warn = 0;
        health_loaded = False;
        ci = code_intel();
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

"""The project's current error diagnostics, or [] if no model is built yet."""
impl _project_errors -> list {
    ci = code_intel();
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

"""After a one-shot build, keep going until the project compiles.

A weaker model often declares a multi-file task done while the project still
has compile errors. Rather than accept broken code, feed the outstanding
errors back and let the agent fix them -- bounded by `max_rounds`, and stopping
as soon as a round fails to reduce the error count, so a model that cannot make
progress exits instead of looping. No-op when the initial turn changed no code
(e.g. a read-only query) or the project already compiles.
"""
impl verify_and_continue(max_rounds: int = 3) {
    if not agent.turn_wrote {
        return;
    }
    rnd = 0;
    prev_count = -1;
    while rnd < max_rounds {
        errs = _project_errors();
        if not errs {
            break;
        }
        # Error count didn't shrink -- the model is stuck, so stop nudging.
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

"""Entry point for `jac ai` -- the default `run_ai_agent` hook implementation.

`req` is an `AgentRequest`: the resolved `--model`, `--n_ctx`, and `--safe`
flags, the working directory, and a shared `CodeIntelligence` handle the
semantic tools query. With a non-empty `prompt`, runs a single turn and exits;
otherwise starts an interactive read-eval-print loop. Always returns 0 -- a
failed turn reports its error but does not abort the session.

When `req.ui` is set, hands off to `_run_ui_server`: launches the bundled Jac
web app as a subprocess and opens it in the browser instead of the REPL.
"""
impl run_agent(req: object) -> int {
    global agent_model;
    # Access `req` untyped so attribute reads type-check without importing
    # AgentRequest into this byLLM-only module.
    r: any = req;
    # Seed the session working directory; every file tool and run_command
    # resolves against it, and a `cd` the model issues updates it.
    agent.cwd = os.path.normpath(str(getattr(r, "cwd", "") or os.getcwd()));
    # `--ui`: hand off to the bundled web app instead of the terminal REPL. The
    # child server re-imports this module and runs the agent itself, so nothing
    # else here (model build, banner, REPL) applies to the parent process.
    if bool(getattr(r, "ui", False)) {
        return _run_ui_server(r);
    }
    agent.cfg.yolo_mode = not r.safe;
    agent.cfg.verbose = not bool(getattr(r, "quiet", False));
    # Surface CI recompiles in the live view so the work behind writes/queries shows.
    agent.ci = r.code_intel;
    if agent.ci is not None {
        agent.ci.on_event = agent.view._ci_event;
    }
    initial_prompt = str(r.prompt);
    # Import-time `agent_model` covers jac.toml/default; rebuild only when a
    # flag changes the model or its context window.
    if r.model or r.n_ctx > 0 {
        agent_model = build_model(str(r.model), int(r.n_ctx));
    }
    agent.view.print_banner();
    reset_session();

    if initial_prompt {
        run_turn(initial_prompt);
        # Don't let a one-shot build exit on code that doesn't compile.
        verify_and_continue();
        agent.web._browse_shutdown();
        agent.proc._serve_shutdown();
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
        run_turn(line);
    }

    agent.web._browse_shutdown();
    agent.proc._serve_shutdown();
    console.print("Bye.");
    return 0;
}

# ---------------------------------------------------------------------------
# Web UI bridge -- backend the bundled `ai_ui` server endpoints call.
# ---------------------------------------------------------------------------
"""Configure the agent for a UI session from the launcher's environment.

Called once at the UI server's boot. Reads the user's project directory and
model knobs from the `JAC_AI_UI_*` env vars the launcher set, points `agent.cwd`
and a fresh `CodeIntelligence` at that project, builds the model, and forces
yolo mode (the server has no terminal to confirm at). Idempotent.
"""
impl ui_configure -> None {
    global agent_model;
    # The launcher set these when it spawned this server process.
    proj = os.environ.get("JAC_AI_UI_PROJECT") or os.getcwd();
    agent.cwd = os.path.normpath(proj);
    # No terminal here to confirm at, so writes/commands always run.
    agent.cfg.yolo_mode = True;
    agent.cfg.verbose = True;
    agent.cfg.show_stats = True;
    agent.bus.active_feed = True;
    model_flag = os.environ.get("JAC_AI_UI_MODEL") or "";
    n_ctx = 0;
    try {
        n_ctx = int(os.environ.get("JAC_AI_UI_NCTX") or "0");
    } except Exception { }
    # A project-rooted CodeIntelligence so the semantic tools work, lazily so
    # boot stays cheap. No on_event hook: its prints would only clutter the log.
    agent.ci = CodeIntelligence(proj_dir=agent.cwd, lazy=True);
    reset_session();
    # `agent.cwd` is now set to the user's project, so build_model resolves the
    # model and byLLM config from their jac.toml (via `_byllm_config`), not this
    # child server's working directory (the bundled ai_ui dir).
    # Building the model can fail (missing API key, no local weights). Keep the
    # server up regardless: the UI still loads and reports the problem in the
    # feed, rather than the whole web app failing to boot.
    agent.cfg.n_ctx = n_ctx;
    try {
        agent_model = build_model(model_flag, n_ctx);
        agent.bus.emit(
            "system",
            {"text": f"Connected to {agent.cwd} using {agent_model.model_name}."}
        );
    } except Exception as e {
        agent.bus.emit(
            "error",
            {"text": f"Connected to {agent.cwd}, but the model failed to load: {e}"}
        );
    }
    # Detect whether the chosen model still needs an API key. This rides along in
    # every pushed state frame, so the client opens the settings panel on the
    # key field the moment it connects -- before the user wastes a turn.
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
        # A stop request skips the auto-continue (don't restart work the user
        # just halted).
        if not agent.bus.cancel_requested {
            verify_and_continue();
        }
    } except Exception as e {
        agent.bus.emit("error", {"text": f"agent error: {e}"});
        # An auth failure mid-turn means the key is missing or invalid even if we
        # thought one was present -- force the settings panel open so the user can
        # fix it without hunting through the feed.
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
        # The walker leaves `active` on its final node (Done, or wherever it
        # stopped); fall back to idle so the status pill stops pulsing.
        agent.bus.set_status("idle");
    }
}

"""Start one agent turn for `prompt` on a background thread; never blocks.

Returns False (and does nothing) if a turn is already running, so the UI can
disable its input while busy. The turn writes its milestones to `agent.bus`,
which `ui_poll` drains.
"""
impl ui_send(prompt: str) -> bool {
    text = prompt.strip();
    if not text {
        return False;
    }
    if agent.bus.status == "running" or agent.bus.status == "stopping" {
        return False;  # one turn at a time (and not while a stop is unwinding)
    }
    agent.bus.begin_turn();
    agent.bus.emit("user", {"text": text});
    agent.bus.set_status("running");
    threading.Thread(target=_ui_turn_worker, args=(text, ), daemon=True).start();
    return True;
}

"""The current event feed and walker state -- the UI's per-tick poll payload.

Returns `agent.bus.snapshot()`: the bounded event log plus `status`, the
`active` phase node, and the `path` walked this turn.
"""
impl ui_poll -> dict {
    return agent.bus.snapshot();
}

"""Live SSE event stream: yields a full snapshot, then one message per bus
emit (token by token for reasoning/answer), plus periodic heartbeats so a
client disconnect is detected. jac-scale frames each yielded dict as an
`text/event-stream` `data: {json}` chunk. The `agent_stream` endpoint returns
this; the client reads it to update the UI per token instead of polling.
"""
impl ui_stream -> any {
    import from queue { Empty }
    q = agent.bus.subscribe();
    try {
        # First frame: a full snapshot so a fresh (or reconnecting) client has
        # the complete state; subsequent frames are per-emit deltas. Events that
        # race between subscribe and snapshot may arrive twice -- harmless, the
        # client upserts by id.
        snap = agent.bus.snapshot();
        snap["full"] = True;
        yield snap;
        while True {
            try {
                # Timeout yields a heartbeat so a disconnected client is noticed
                # (the generator reaches a yield and the server can close it).
                yield q.get(timeout=10.0);
            } except Empty {
                yield {"heartbeat": True};
            }
        }
    } finally {
        agent.bus.unsubscribe(q);
    }
}

"""The static phase graph (nodes + edges) the UI renders in cytoscape, with state.

Nodes are Plan/Build/QA/Done; edges are the legal transitions the walker may
take. Returned once on mount; live position comes from `ui_poll`.
"""
impl ui_graph -> dict {
    # Trace the actual phase pipeline instead of hardcoding it, so the rendered
    # graph always matches the walker's real topology: build the graph once, then
    # BFS from the entry, emitting one node per state (id/label from its class
    # name, blurb from its own `desc`) and one edge per out-edge. Change an edge
    # in `build_pipeline` and this -- and the UI -- follow automatically.
    nodes = [];
    edges = [];
    seen = set();
    # Untyped so successors (Any, via the edge ref) append cleanly alongside the
    # Plan entry.
    frontier: list = [build_pipeline()];
    while frontier {
        nd = frontier.pop(0);
        nid = type(nd).__name__;
        if nid in seen {
            continue;
        }
        seen.add(nid);
        # `sem` is the node class's role prompt (`_jac_semstr`, the same string
        # the router shows the model); `tools` are the phase's exposed tool names
        # (Done has none). Both ride along so the UI inspector can show a state's
        # full definition when its graph node is clicked -- no separate lookup.
        tool_names = (
            [getattr(t, "__name__", "") for t in nd.tools()] if nd?.tools else []
        );
        nodes.append(
            {
                "id": nid,
                "label": nid,
                "desc": nd.desc,
                "sem": str(getattr(type(nd), "_jac_semstr", "") or ""),
                "tools": tool_names
            }
        );
        for succ in [nd-->] {
            edges.append({"source": nid, "target": type(succ).__name__});
            frontier.append(succ);
        }
    }
    return {"nodes": nodes, "edges": edges, "state": agent.bus.snapshot()};
}

"""Clear the cross-turn ledger and the event feed for a fresh UI session."""
impl ui_reset -> None {
    reset_session();
    agent.bus.events = [];
    agent.bus.begin_turn();
    agent.bus.set_status("idle");
    # Tell live streams the feed was cleared (set_status only sends a delta).
    agent.bus.publish_full();
}

"""Request that the running turn stop. Sets the bus cancel flag; the progress
guard aborts the current phase and the walker halts at the next checkpoint.
No-op when nothing is running.
"""
impl ui_stop -> None {
    # Only meaningful while a turn is running. Set the cancel flag and flip to a
    # "stopping" status immediately so the UI confirms the click right away --
    # the actual halt lands at the next stream/iteration checkpoint (which can
    # be a second or two with a large local model). The worker clears the flag
    # and drops to idle once the turn unwinds.
    if agent.bus.status == "running" {
        agent.bus.cancel_requested = True;
        agent.bus.set_status("stopping");
        agent.bus.emit("system", {"text": "Stopping…"});
    }
}

"""The settings panel's current values: the active model, whether a key is held
(never the key itself), base_url, temperature, context window, the model source,
the live key-status, and the quick-pick presets.
"""
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
        # Whether a key is currently held -- the actual secret is never sent back.
        "api_key_set": bool(agent.cfg.api_key),
        "base_url": agent.cfg.base_url,
        # -1 signals "provider default" (cloud models leave temperature unset).
        "temperature": (float(t) if t is not None else -1.0),
        "n_ctx": agent.cfg.n_ctx,
        "model_source": agent.cfg.model_source,
        "needs_key": agent.bus.needs_key,
        "key_env": agent.bus.key_env,
        "presets": list(_MODEL_PRESETS)
    };
}

"""Apply settings from the `--ui` panel and rebuild the model live.

`temperature`/`n_ctx` arrive as strings (blank = leave at default). An empty
`api_key` keeps the currently held one (the field is blank unless the user is
changing it), so re-applying other settings never clears the key. Rebuilds the
model with the new name/config, refreshes the key status, and pushes a fresh
state frame so the client closes the panel (or shows the error). Session-only:
nothing is written to disk.
"""
impl ui_apply_settings(
    model: str, api_key: str, base_url: str, temperature: str, n_ctx: str
) -> dict {
    global agent_model;
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
    # Parse the temperature override now; applied after build_model (which sets
    # its own default) so a user value is not clobbered.
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

"""Launch the bundled web UI for `jac ai --ui` and block until the user quits.

Spawns `jac start` on the bundled `ai_ui` Jac app as a child process -- passing
the user's project directory and model flags through `JAC_AI_UI_*` env vars --
polls its log for the ready URL, opens the browser there, and waits. Ctrl-C
shuts the child down. Returns 0 on a clean exit, 1 if the client plugin is
missing or the server never came up.
"""
impl _run_ui_server(r: any) -> int {
    import jaclang;
    import from importlib.util { find_spec }
    if find_spec("jac_client") is None {
        console.error(
            "`jac ai --ui` needs the jac-client plugin, which is not installed.",
            hint="Install it with:  pip install jac-client"
        );
        return 1;
    }
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
    env["JAC_AI_UI_PROJECT"] = agent.cwd;
    env["JAC_AI_UI_MODEL"] = str(getattr(r, "model", "") or "");
    env["JAC_AI_UI_NCTX"] = str(int(getattr(r, "n_ctx", 0) or 0));
    log_path = "/tmp/jac_ai_ui.log";
    console.print("");
    console.print("  Jac AI -- web UI", style="bold");
    console.print(f"  project: {agent.cwd}", style="muted");
    console.print("  building the client (first run installs deps)…", style="muted");
    proc: any = None;
    try {
        log_f = open(log_path, "w");
        proc = subprocess.Popen(
            [sys.executable, "-m", "jaclang", "start", "main.jac"],
            cwd=ui_dir,
            stdout=log_f,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            start_new_session=True
        );
    } except Exception as e {
        console.error(f"failed to launch the UI server: {e}");
        return 1;
    }
    url_re = re.compile(
        "https?://(?:localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)(?::\\d+)?\\S*"
    );
    timeout = 180.0;
    try {
        raw = os.environ.get("JAC_AI_UI_TIMEOUT");
        if raw {
            timeout = float(raw);
        }
    } except Exception { }
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
