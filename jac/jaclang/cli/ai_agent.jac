"""Interactive Jac coding agent -- the engine behind `jac ai`.

A terminal coding agent built as a byLLM ReAct loop wired to file and guide
tools. The agent reads, writes, and debugs Jac code in the current project,
grounded in the bundled Jac reference guides so it self-serves the
authoritative spec for idiomatic Jac.

This module is imported lazily by the `jac ai` command, so the core CLI keeps
no hard dependency on the byLLM plugin. `run_agent` takes the resolved flags
directly and builds the model from them before the session starts.
"""

import os;
import re;
import sys;
import time;
import subprocess;
import from pathlib { Path }

import from byllm.lib { Model, IterationAction }
import from byllm.config_loader { get_byllm_config }
import from byllm.parallel { mark_serialize }

import from jaclang.cli.console { console }
import from jaclang.cli.guide_store {
    list_guides as gs_list,
    get_guide as gs_get,
    search_guides as gs_search
}
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

#===============================================================================
# MODEL & SESSION STATE
#===============================================================================

# Skip confirmation prompts for file writes and code execution. On by default;
# `run_agent` clears it when the `--safe` flag asks to confirm every action.
glob yolo_mode: bool = True,
     # Resolved CPU thread count for local inference; shown in the banner. Set by
     # `build_model`; 0 means "not a local model / leave it to the backend".
     agent_threads: int = 0,
     # Sampling temperature for the agent's calls. Set by `build_model`: a low,
     # deterministic value for local models, `None` for cloud models (some newer
     # ones reject `temperature` outright, so it is left to the provider default).
     agent_temperature: float | None = None,
     # Where the resolved model came from -- shown in the banner so the user can
     # see whether a `--model` flag, jac.toml, or the built-in default won.
     agent_model_source: str = "default",
     # Whether to print the one-line turn summary (duration, tool calls, files
     # changed, tokens, project health) after each turn. Toggled with `/stats`.
     show_stats: bool = True,
     # Rich live view: stream the model's reasoning, a `thinking... Ns` line for
     # reasoning-less models, per-step/tool timings, and multi-line tool-result
     # snippets. Cleared by `--quiet`/`-q`; toggled with `/verbose`. When off,
     # only tool-call lines, one-line results, and the final answer are shown.
     verbose: bool = True,
     # Whether write_file/edit_file append inline compiler feedback (the
     # recompile-and-diff that surfaces errors the write introduced). On by
     # default and now incremental, so it costs an LSP-save; toggle off with
     # `/feedback` for sessions that would rather rely on explicit `jac_check`.
     inline_feedback: bool = True;

# Tool names grouped for the turn-stat breakdown: tools that mutate files,
# and tools that execute code or shell commands. Everything else is a read.
glob _WRITE_TOOLS: set[str] = {"write_file", "edit_file"},
     _RUN_TOOLS: set[str] = {
         "run_command",
         "jac_check",
         "start_app",
         "browse_open",
         "browse_navigate",
         "browse_click",
         "browse_type",
         "browse_fill",
         "browse_press",
         "browse_eval",
         "browse_close"
     },
     # Set True by `run_turn` when the turn issued a file-writing tool call, so
     # the one-shot verify-and-continue guard only kicks in when code changed.
     _turn_wrote: bool = False;

# The shared CodeIntelligence handle for this session, set by `run_agent` from
# the AgentRequest. The semantic tools (find_symbol, find_uses, ...) query it
# so the agent navigates the project by compiler symbol data, not text search.
glob agent_ci: any = None,
     # Set by write_file/edit_file after a successful write; the next semantic
     # query rebuilds the project model so lookups reflect the new source.
     agent_ci_dirty: bool = False;

"""Pick which model `jac ai` should run.

Priority: the `--model` flag (`model_override`), then `[plugins.byllm.model]
default_model` in jac.toml, then the bundled local model so the command works
with no API key. Records the winning source in `agent_model_source`.
"""
def resolve_model_name(model_override: str = "") -> str {
    global agent_model_source;
    flag = model_override.strip();
    if flag {
        agent_model_source = "command line";
        return flag;
    }
    # Read the raw [plugins.byllm.model] table -- not the defaults-merged
    # config -- so an unset `default_model` does not masquerade as a choice.
    toml_model = "";
    try {
        raw = get_byllm_config().get_jac_config().get_plugin_config("byllm");
        model_section = raw.get("model", {});
        if isinstance(model_section, dict) {
            toml_model = str(model_section.get("default_model", "")).strip();
        }
    } except Exception {
        toml_model = "";
    }
    if toml_model {
        agent_model_source = "jac.toml";
        return toml_model;
    }
    agent_model_source = "default";
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
def build_model(model_override: str = "", n_ctx: int = 0) -> Model {
    global agent_threads,agent_temperature;
    name = resolve_model_name(model_override);
    cfg: dict[str, object] = {};
    is_local = name.startswith("local:");
    # Reset first: a rebuild may swap a local model for a cloud one, and the
    # banner must not keep showing a stale thread count.
    agent_threads = 0;
    # Pin local models to a low temperature for deterministic code edits;
    # leave cloud models at the provider default (newer ones reject the param).
    agent_temperature = 0.3 if is_local else None;
    if is_local {
        try {
            cfg = dict(get_byllm_config().get_local_config());
        } except Exception {
            cfg = {};
        }
        # Cap CPU usage so local inference does not peg (and overheat) the
        # machine: a jac.toml [plugins.byllm.local] n_threads wins, otherwise
        # default to half the cores.
        if not cfg.get("n_threads") {
            cores = os.cpu_count() or 2;
            cfg["n_threads"] = max(1, cores // 2);
        }
        agent_threads = int(cfg.get("n_threads") or 0);
    }
    if n_ctx > 0 {
        cfg["n_ctx"] = n_ctx;
    }
    return Model(model_name=name, config=cfg);
}

# Built at import time from jac.toml (or the bundled default) so `ask`'s `by`
# clause always has a model; `run_agent` rebuilds it when flags are passed.
glob agent_model = build_model(),
     # The running conversation. byLLM's `conversation=` kwarg splices this list
     # into each turn and writes the updated history back in place. Pre-seeded with
     # the agent's system message by `reset_history`.
     history: list[object] = [];

#===============================================================================
# TOOL HELPERS
#===============================================================================
"""Clip oversized tool output so it does not blow the model's context."""
def truncate(text: str, limit: int = 12000) -> str {
    if len(text) > limit {
        extra = len(text) - limit;
        return text[:limit] + f"\n... [truncated, {extra} more chars]";
    }
    return text;
}

"""Ask the user to approve a side-effecting action; honours `--yolo`."""
def confirm(action: str) -> bool {
    if yolo_mode {
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
def write_feedback(path: str) -> str {
    global agent_ci_dirty;
    if agent_ci is None or not inline_feedback {
        # When inline feedback is off the project model is still stale after a
        # write; flag it so the next semantic query (or `jac_check`) refreshes.
        if agent_ci is not None and not inline_feedback {
            agent_ci_dirty = True;
        }
        return "";
    }
    # The write changed the project; mark dirty up front so a failed refresh
    # still triggers a rebuild on the next semantic query.
    agent_ci_dirty = True;
    try {
        # refresh_and_diff recompiles and returns the diagnostics this edit is
        # responsible for: all of `path`, plus breakage in dependent modules.
        diags: list = list(agent_ci.refresh_and_diff(path));
    } except Exception {
        return "";
    }
    agent_ci_dirty = False;
    if not diags {
        return "";
    }
    n_err = len(
        [
            d
            for d in diags
            if d.severity == "error"
        ]
    );
    n_warn = len(diags) - n_err;
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

#===============================================================================
# TOOLS -- plain typed functions; byLLM turns the annotations into JSON schema
#===============================================================================
def read_file(path: str) -> str {
    try {
        return truncate(Path(path).read_text());
    } except Exception as e {
        return f"ERROR reading {path}: {e}";
    }
}

sem read_file = "Read and return the full text of a file.";
sem read_file.path = "Path to the file to read, relative to the project.";


def write_file(path: str, content: str) -> str {
    if not confirm(f"write {len(content)} chars to {path}") {
        return "DENIED: the user declined this write.";
    }
    try {
        p = Path(path);
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text(content);
        return f"OK: wrote {len(content)} chars to {path}" + write_feedback(path);
    } except Exception as e {
        return f"ERROR writing {path}: {e}";
    }
}

sem write_file = "Create a file or overwrite it entirely with new content.";
sem write_file.path = "Path of the file to write.";
sem write_file.content = "The full new contents of the file.";


def edit_file(path: str, old_text: str, new_text: str) -> str {
    try {
        original = Path(path).read_text();
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
    if not confirm(f"edit {path}") {
        return "DENIED: the user declined this edit.";
    }
    try {
        Path(path).write_text(original.replace(old_text, new_text));
        return f"OK: edited {path}" + write_feedback(path);
    } except Exception as e {
        return f"ERROR writing {path}: {e}";
    }
}

sem edit_file = "Replace one exact, unique occurrence of text in a file.";
sem edit_file.path = "Path of the file to edit.";
sem edit_file.old_text = "Exact text to find; must occur exactly once in the file.";
sem edit_file.new_text = "Text to replace it with.";


def list_dir(path: str) -> str {
    try {
        target = Path(path or ".");
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

sem list_dir = "List the entries of a directory (hidden entries excluded).";
sem list_dir.path = "Directory path; empty string means the current directory.";


def grep(pattern: str, path: str) -> str {
    try {
        regex = re.compile(pattern);
    } except Exception as e {
        return f"ERROR: invalid regular expression: {e}";
    }
    search_root = Path(path or ".");
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

sem grep = "Search for a regular expression across .jac files (or one file).";
sem grep.pattern = "Python regular expression to search for.";
sem grep.path = "File or directory to search; empty string means current directory.";


"""Run a `jac` subcommand on a file and return its combined output."""
def run_jac_cli(subcommand: str, path: str) -> str {
    try {
        result = subprocess.run(
            [sys.executable, "-m", "jaclang", subcommand, path],
            capture_output=True,
            text=True,
            timeout=120
        );
        combined = ((result.stdout or "") + (result.stderr or "")).strip();
        return truncate(combined or f"(no output; exit code {result.returncode})");
    } except Exception as e {
        return f"ERROR running `jac {subcommand} {path}`: {e}";
    }
}


def run_command(command: str) -> str {
    if not confirm(f"run shell command: {command}") {
        return "DENIED: the user declined to run this command.";
    }
    # Put the running interpreter's bin directory first on PATH so `jac` (and
    # other console scripts installed alongside it) resolve even when the
    # session was launched without the environment activated.
    env = dict(os.environ);
    bin_dir = os.path.dirname(sys.executable);
    if bin_dir {
        env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "");
    }
    try {
        result = subprocess.run(
            command, shell=True, capture_output=True, text=True, timeout=180, env=env
        );
        combined = ((result.stdout or "") + (result.stderr or "")).strip();
        return truncate(combined or f"(no output; exit code {result.returncode})");
    } except subprocess.TimeoutExpired {
        return f"ERROR: `{command}` timed out after 180s.";
    } except Exception as e {
        return f"ERROR running `{command}`: {e}";
    }
}

sem run_command = "Run a shell command in the project directory and return its combined output. Use this to scaffold a new project (`jac create --use fullstack <name>`), install dependencies (`jac install`), run a file (`jac run <file>`), run tests, or any other shell task. `jac create` templates: default, client, fullstack.";
sem run_command.command = "The shell command to run.";


def jac_check(path: str) -> str {
    return run_jac_cli("check", path or ".");
}

sem jac_check = "Type-check and compile Jac code with `jac check`. Pass a single file, or a directory (`.` for the whole project) to check everything at once. Use this after writing or editing Jac code to confirm it is valid.";
sem jac_check.path = "File or directory to check; '.' or empty string checks the whole project.";


def start_app(entry_file: str) -> str {
    entry_path = entry_file or "main.jac";
    if not confirm(f"start the app with `jac start {entry_path}`") {
        return "DENIED: the user declined to start the app.";
    }
    # `jac start` resolves the project (and its installed deps) from the entry
    # file's own directory, so run it there -- not wherever the session was
    # launched -- which matters when the app was scaffolded into a subfolder.
    work_dir = os.path.dirname(entry_path) or ".";
    target = os.path.basename(entry_path);
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
    # Let it boot, then stop it -- we only want the startup diagnostics, not a
    # server left running after the tool returns. The boot window defaults to
    # 12s but can be shortened via JAC_AI_START_TIMEOUT (seconds), mainly so
    # tests need not wait the full default.
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

sem start_app = "Start the app with `jac start` for ~12 seconds to confirm it boots, then stop it; returns the startup logs. Use this after building an app to catch errors that `jac check` cannot.";
sem start_app.entry_file = "Entry .jac file to start; empty string means 'main.jac'.";


def search_guides(keyword: str) -> str {
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

sem search_guides = "Search the bundled Jac reference guides; returns matching guide names and descriptions ranked by relevance. Matches any word in the query, so several keywords broaden the search.";
sem search_guides.keyword = "Keywords to search guide names, descriptions, and bodies for.";


def read_guide(name: str) -> str {
    guide = gs_get(name);
    if guide is None {
        available = ", ".join([g.name for g in gs_list()]);
        return f"ERROR: no guide named '{name}'. Available guides: {available}";
    }
    return truncate(guide.body, 16000);
}

sem read_guide = "Read a bundled Jac reference guide in full -- the authoritative spec for writing correct, idiomatic Jac.";
sem read_guide.name = "Exact guide name, e.g. 'jac-walker-patterns'.";


#===============================================================================
# SEMANTIC TOOLS -- backed by the Jac compiler's symbol table, not text search
#===============================================================================
"""Return the session's CodeIntelligence, rebuilding it if a write happened.

`write_file`/`edit_file` flag the project as dirty; the first semantic query
after a write recompiles so symbol lookups reflect what the agent just wrote.
"""
def code_intel -> any {
    global agent_ci_dirty;
    if agent_ci is None {
        return None;
    }
    if agent_ci_dirty {
        try {
            agent_ci.refresh();
        } except Exception { }
        agent_ci_dirty = False;
    }
    return agent_ci;
}


def find_symbol(name: str) -> str {
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

sem find_symbol = "Look up a Jac symbol (node, walker, edge, obj, enum, ability, ...) by name via the compiler's symbol table. Returns its exact definition site, fields, abilities, base classes, and every place it is used. This is precise -- unlike grep it never matches a comment or an unrelated identifier. Prefer this over grep whenever you know the name of the thing you are looking for.";
sem find_symbol.name = "The symbol name to look up, e.g. 'User' or 'make_user'.";


def find_uses(name: str) -> str {
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

sem find_uses = "List every definition and use of a symbol across the whole project, computed from the compiler's def/use chains. Use this before renaming or changing a symbol to see exactly what it touches.";
sem find_uses.name = "The symbol name whose references to list.";


def project_map -> str {
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

sem project_map = "Show every node, walker, edge, and object archetype in the project with its location -- a structural overview built from the compiler, not a directory listing. Use this first to understand an unfamiliar project.";


def find_walkers(node_type: str) -> str {
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

sem find_walkers = "Find every walker entry point that traverses a given node type -- an Object-Spatial query the compiler answers from walker entry signatures. Use this to see how a node is visited.";
sem find_walkers.node_type = "The node archetype name, e.g. 'User'.";


def context_slice(name: str) -> str {
    ci = code_intel();
    if ci is None {
        return "ERROR: code intelligence is unavailable in this session.";
    }
    return str(ci.slice_for(name).render());
}

sem context_slice = "Get a typed context slice for a symbol: its definition, the types it depends on, and where it is used -- a focused, compiler-accurate neighbourhood to read instead of opening whole files.";
sem context_slice.name = "The symbol to build a context slice around.";


#===============================================================================
# BROWSER TOOLS
#===============================================================================
# A headless browser, driven over the Chrome DevTools Protocol by the built-in
# `jac browse` engine -- no npm/pip install. The agent uses these to QA a
# running web app: open its URL, read the page as an accessibility tree, then
# act on the @refs that snapshot assigns. Every call reconnects to one shared,
# isolated browser session, so they are all serialized below.
glob _BROWSE_SESSION: str = "jac-ai";


"""Turn a browser-engine exception into a tool-result string with a next step."""
def _browse_err(e: Exception) -> str {
    msg = str(e);
    if "no live browser" in msg {
        return "ERROR: no browser is open -- call browse_open(url) first.";
    }
    return f"ERROR: {msg}";
}


def browse_open(url: str) -> str {
    if url and not confirm(f"open a browser at {url}") {
        return "DENIED: the user declined opening the browser.";
    }
    try {
        return br_open(_BROWSE_SESSION, url or None);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_open = "Launch a headless browser (or reuse the one already open) and navigate to a URL. Use this to QA a running web app, then read the page with browse_snapshot. An empty URL opens a blank page.";
sem browse_open.url = "URL to open, e.g. 'http://localhost:8000'. Empty string opens about:blank.";


def browse_navigate(url: str) -> str {
    if not confirm(f"navigate the browser to {url}") {
        return "DENIED: the user declined this navigation.";
    }
    try {
        return br_navigate(_BROWSE_SESSION, url);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_navigate = "Navigate the open browser to a different URL and wait for it to load.";
sem browse_navigate.url = "The URL to navigate to.";


def browse_snapshot -> str {
    try {
        return truncate(br_snapshot(_BROWSE_SESSION));
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_snapshot = "Read the current page as an accessibility tree. Interactive elements are tagged with @e1/@e2 refs that you pass to browse_click, browse_type, and browse_fill. Call this after navigating, and again after any action that changes the page, to see the new state.";


def browse_click(target: str) -> str {
    if not confirm(f"click {target} in the browser") {
        return "DENIED: the user declined this click.";
    }
    try {
        return br_click(_BROWSE_SESSION, target);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_click = "Click an element with a real, trusted mouse event. Pass an @ref from browse_snapshot (e.g. '@e5') or a CSS selector (e.g. '#submit').";
sem browse_click.target = "An @ref from browse_snapshot, or a CSS selector.";


def browse_type(target: str, text: str) -> str {
    if not confirm(f"type into {target} in the browser") {
        return "DENIED: the user declined this input.";
    }
    try {
        return br_type(_BROWSE_SESSION, target, text);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_type = "Focus an element and type text into it as real key events, appending to whatever is already there.";
sem browse_type.target = "An @ref from browse_snapshot, or a CSS selector.";
sem browse_type.text = "The text to type.";


def browse_fill(target: str, text: str) -> str {
    if not confirm(f"fill {target} in the browser") {
        return "DENIED: the user declined this input.";
    }
    try {
        return br_fill(_BROWSE_SESSION, target, text);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_fill = "Clear a field and set its value to the given text. Prefer this over browse_type for form fields.";
sem browse_fill.target = "An @ref from browse_snapshot, or a CSS selector.";
sem browse_fill.text = "The text to set the field to.";


def browse_press(key: str) -> str {
    if not confirm(f"press {key} in the browser") {
        return "DENIED: the user declined this key press.";
    }
    try {
        return br_press(_BROWSE_SESSION, key);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_press = "Press a single key in the browser, e.g. 'Enter', 'Tab', 'Escape', or a chord like 'Ctrl+A'.";
sem browse_press.key = "The key or chord to press.";


def browse_get(what: str, selector: str) -> str {
    try {
        return truncate(str(br_get(_BROWSE_SESSION, what, selector or None)));
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_get = "Read a property of the current page: 'url', 'title', or 'text' (the visible text of the element named by selector).";
sem browse_get.what = "One of 'url', 'title', or 'text'.";
sem browse_get.selector = "CSS selector for 'text'; empty string for 'url' or 'title'.";


def browse_eval(expression: str) -> str {
    if not confirm(f"run JavaScript in the browser: {expression}") {
        return "DENIED: the user declined this script.";
    }
    try {
        return truncate(str(br_eval(_BROWSE_SESSION, expression)));
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_eval = "Evaluate a JavaScript expression in the page and return its result. Use this to inspect page state or check for errors, e.g. \"document.querySelectorAll('.error').length\".";
sem browse_eval.expression = "A JavaScript expression to evaluate.";


def browse_close -> str {
    try {
        return br_close(_BROWSE_SESSION);
    } except Exception as e {
        return _browse_err(e);
    }
}

sem browse_close = "Close the browser and free its resources. Call this when finished with browser QA.";


"""Close the agent's browser session if one was opened (best-effort)."""
def _browse_shutdown {
    try {
        br_close(_BROWSE_SESSION);
    } except Exception {
    # The browser may never have been opened this session; nothing to clean.
    }
}


# Side-effecting tools must never run concurrently; byLLM keeps any parallel
# batch that contains one of these sequential. Every browser tool reconnects to
# the same shared Chrome, so they are all serialized to avoid interleaving on
# the page.
with entry {
    mark_serialize(write_file);
    mark_serialize(edit_file);
    mark_serialize(run_command);
    mark_serialize(start_app);
    mark_serialize(browse_open);
    mark_serialize(browse_navigate);
    mark_serialize(browse_snapshot);
    mark_serialize(browse_click);
    mark_serialize(browse_type);
    mark_serialize(browse_fill);
    mark_serialize(browse_press);
    mark_serialize(browse_get);
    mark_serialize(browse_eval);
    mark_serialize(browse_close);
}

#===============================================================================
# SYSTEM PROMPT & THE AGENT TURN
#===============================================================================
glob AGENT_RULES = """\
You are Jac AI, a coding agent working inside the user's terminal in their Jac
project. You help the user read, write, and debug Jac code.

Work like this:
- Plan first. For any multi-file task, open with a short plan -- the files you
  will create or change and what each is for -- then carry it out.
- Scaffold, don't hand-build. For a new project or app, run `jac create --use
  <template> <name>` with run_command instead of writing the project layout by
  hand. Templates: default, client, fullstack. Then adapt the generated files.
- Batch aggressively. Independent tool calls run in parallel, so issue them
  together in ONE step -- never one at a time. Reading five files is one step
  with five read_file calls. Loading the guides you need is one step. Grepping
  or checking several paths is one step. Writes to different files go in one
  step. Sequence a call only when it truly needs an earlier call's output.
- Decide and commit. When two or more approaches would both work, pick the
  simplest and build it. Do not re-litigate a choice you have already acted on,
  and never write a file just to delete it -- think the choice through first.
- Navigate by meaning, not text. To find where a node, walker, edge, or
  ability is defined or used, call find_symbol or find_uses -- they read the
  compiler's symbol table and are exact. Use project_map for a structural
  overview of an unfamiliar project, find_walkers to see how a node is
  traversed, and context_slice to read a symbol's typed neighbourhood. Reserve
  grep for plain text -- comments, strings, TODOs.
- Never guess. Read a file before editing it; consult the guides before
  writing unfamiliar Jac. The bundled guides are the authoritative spec for
  correct, idiomatic Jac.
- Keep files focused and modest in size; split large archetypes into impl
  files. For a large file, write a skeleton first, then fill it with edit_file.
- Make minimal, targeted changes. Prefer edit_file over rewriting a whole file.
- Drive a browser when it helps. A headless browser is built in: use browse_open
  to load a running web app, browse_snapshot to read the page, and the
  browse_click/fill/type/press tools to exercise user flows. No install needed.
- Fix as you go. Every write_file and edit_file result reports the compiler
  errors and warnings your edit caused -- in the file you wrote and in any
  other file it affects. Fix them before moving on; never leave a write with
  errors behind.
- QA before you finish. This is mandatory: never report a task as done until
  the QA pass below has been run and comes back clean.

QA pass -- before you consider the task done, run every step that applies, in
order, and fix anything it surfaces (then run the pass again):
1. `jac check .` -- a whole-project type-check. It must report zero errors.
2. For any runnable app, call start_app and confirm it boots with no errors in
   the startup logs.
3. For a web or fullstack app, also QA it in a real browser with the built-in
   browse_* tools (a headless browser is built in -- nothing to install):
   - Start the server detached so it stays up during the test -- from the app's
     directory run `nohup jac start <entry> > /tmp/jac_qa.log 2>&1 &` through
     run_command, wait a few seconds, then read /tmp/jac_qa.log for the URL it
     serves on.
   - browse_open(url), then browse_snapshot to read the page. Exercise the main
     user flows with browse_click / browse_fill / browse_type / browse_press,
     calling browse_snapshot again after each step to see the result.
   - Confirm the expected content rendered and check for errors -- use
     browse_eval to inspect page state (e.g. count error nodes) when in doubt.
   - browse_close when finished, then stop the server: `pkill -f "jac start"`.
Once QA is clean, finish with a short plain-language summary of what you
changed and why, plus one line on the QA you ran and that it passed.

Jac gotchas -- the type checker rejects all of these, so never write them:
- There is no `pass` statement. For an empty block, write empty braces: `{}`.
- A docstring (`\"\"\"...\"\"\"`) goes immediately BEFORE a declaration, never as
  the first statement inside a function body -- in a body it is a parse error.
- The gradual / untyped type is lowercase `any`, with no import. Never write
  capital `Any`, and never `import from typing { Any }`.
""";


"""Build the agent's system message: rules, the guide index, and the cheatsheet."""
def system_prompt -> str {
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


"""Reset the conversation to just the agent's system message."""
def reset_history {
    history.clear();
    history.append({"role": "system", "content": system_prompt()});
}


# A turn that rewrites one file more than this many times is not converging --
# typically a weaker model re-emitting a whole file on each compile error. The
# progress guard ends the turn rather than burning the iteration budget.
glob _REWRITE_LIMIT = 5;


"""Stop a turn that keeps rewriting the same file without making progress.

byLLM calls this before each ReAct iteration. It counts how often each file has
been written so far this turn (from the assistant tool-call history); once any
single file crosses `_REWRITE_LIMIT`, the model is looping on an error it cannot
fix, so end the turn with a summary instead of spending the whole budget.
"""
def _progress_guard(ctx: any) -> str {
    import json;
    counts: dict[str, int] = {};
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
            if name not in _WRITE_TOOLS {
                continue;
            }
            raw = fn?.arguments;
            if raw is None and isinstance(fn, dict) {
                raw = fn.get("arguments");
            }
            try {
                parsed = json.loads(raw) if isinstance(raw, str) else (raw or {});
                path = str(parsed.get("path", "")) if isinstance(parsed, dict) else "";
            } except Exception {
                path = "";
            }
            if path {
                counts[path] = counts.get(path, 0) + 1;
            }
        }
    }
    worst = max(counts.values()) if counts else 0;
    if worst > _REWRITE_LIMIT {
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    return IterationAction.CONTINUE;
}


"""Address the user's latest message, using tools as needed."""
def ask(message: str) -> str by agent_model(
    tools=[
        read_file,
        write_file,
        edit_file,
        list_dir,
        grep,
        find_symbol,
        find_uses,
        project_map,
        find_walkers,
        context_slice,
        run_command,
        jac_check,
        start_app,
        search_guides,
        read_guide,
        browse_open,
        browse_navigate,
        browse_snapshot,
        browse_click,
        browse_type,
        browse_fill,
        browse_press,
        browse_get,
        browse_eval,
        browse_close
    ],
    conversation=history,
    stream=True,
    logging=True,
    temperature=agent_temperature,
    max_tokens=8192,
    parallelize=True,
    max_react_iterations=80,
    on_iteration=_progress_guard
    # A generous output ceiling: without it the provider default (~4096 for
    # Anthropic) truncates large `write_file` tool-call arguments mid-stream,
    # so the `content` argument never arrives intact.
);

sem ask = "Continue the coding session by handling the user's latest message.";
sem ask.message = "The user's latest message.";

#===============================================================================
# TERMINAL UI
#===============================================================================
def print_banner {
    console.print("");
    console.print("  Jac AI -- interactive coding agent", style="bold");
    console.print(
        f"  model: {agent_model.model_name}  (from {agent_model_source})", style="muted"
    );
    if agent_threads > 0 {
        console.print(f"  inference threads: {agent_threads}", style="muted");
    }
    if yolo_mode {
        console.print(
            "  file writes and commands run without confirmation (use --safe to confirm each)",
            style="yellow"
        );
    }
    console.print("  type a request, /help for commands, /exit to quit", style="muted");
    console.print("");
}


def print_help {
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
def fmt_tool_call(tool: str, args: object) -> str {
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
def _short_num(n: int) -> str {
    return f"{n / 1000:.1f}k" if n >= 1000 else str(n);
}


"""Best-effort USD cost for the turn from litellm's price map; 0 if unknown.

Local models and any model litellm does not price raise here and fall back
to 0 -- which is correct for a local model, and a benign omission otherwise.
"""
def _estimate_cost(prompt_tokens: int, completion_tokens: int) -> float {
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
def _format_tokens(usage: dict[str, object]) -> str {
    prompt = int(usage.get("prompt_tokens", 0) or 0);
    completion = int(usage.get("completion_tokens", 0) or 0);
    if prompt == 0 and completion == 0 {
        return "";
    }
    text = f"{_short_num(prompt)} in / {_short_num(completion)} out";
    cost = _estimate_cost(prompt, completion);
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
def _format_health -> str {
    ci = code_intel();
    if ci is None or not ci.is_loaded() {
        return "";
    }
    try {
        diags: list[any] = list(ci.diagnostics());
    } except Exception {
        return "";
    }
    n_err = len(
        [
            d
            for d in diags
            if d.severity == "error"
        ]
    );
    n_warn = len(diags) - n_err;
    if n_err == 0 and n_warn == 0 {
        return "project: clean";
    }
    return f"project: {n_err} error(s), {n_warn} warning(s)";
}


"""Print the one-line turn summary: duration, tools, files, tokens, health."""
def print_stats(
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
    tokens = _format_tokens(usage);
    if tokens {
        parts.append(tokens);
    }
    # Generation throughput: completion tokens over the wall-clock turn time.
    # Reported alongside the token totals so the speed of the model (local or
    # cloud) is visible per turn.
    completion = int(usage.get("completion_tokens", 0) or 0);
    if completion > 0 and elapsed > 0 {
        parts.append(f"{completion / elapsed:.1f} tok/s");
    }
    health = _format_health();
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
def _strip_control(text: str) -> str {
    import re;
    t = text.replace("<|\"|>", "\"").replace("<|'|>", "'");
    t = re.sub("<\\|[a-z_]+>[a-z]*", "", t);
    t = re.sub("<[a-z_]+\\|>", "", t);
    return t;
}


"""Split accumulated reasoning into the prose safe to show and a hit flag.

A reply is reasoning prose followed by the `<tool_call>` JSON the protocol
recovers into a structured event. Return only the prose before the marker, and
hold back a trailing partial `<tool_call` so a marker split across stream tokens
is never shown. `hit` is True once the marker has appeared.
"""
def _split_reasoning(raw: str) -> tuple[str, bool] {
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
def _result_snippet(text: str, max_lines: int) -> list[str] {
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
def _fmt_ms(ms: float) -> str {
    return f"{int(ms)}ms" if ms < 1000 else f"{ms / 1000:.1f}s";
}


"""Render a code-intelligence compile, set as `CodeIntelligence.on_event`.

Fires whenever the compiler-backed project model rebuilds -- the initial load,
and the incremental recompile after each write or the first query following one.
Printed inline with the tool stream (it runs inside a tool's execution) so the
hidden compiler work behind write_file/find_symbol/etc. is visible: which file,
how many modules were recompiled out of the project, and how long it took.
"""
def _ci_event(info: any) {
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
        # create / edit / delete: show the recompiled count against the project
        # size so an incremental refresh is visibly cheaper than a full build.
        what = f"{op} {name} · recompiled {recompiled}/{total}";
    }
    console.print(f"      ⚙ code intel · {what} · {_fmt_ms(ms)}", style="dim");
}

# Upper bound on the live "thinking..." line, used to erase it cleanly.
glob _THINK_WIDTH = 40;


"""Run one agent turn, rendering the byLLM event stream live to the terminal.

`ask` runs with `stream=True, logging=True`, yielding a StreamEvent per step of
the ReAct loop. In the default (verbose) view the model's reasoning streams live
(only the prose before the `<tool_call>` JSON, so the protocol text never
leaks), a `thinking... Ns` line marks generation for models that emit no prose,
and each step carries its model/tool latency with a multi-line result snippet.
`--quiet` drops the reasoning, timings, and the live line, leaving tool calls,
one-line results, and the final answer. The final answer (`chunk`) always
streams live.
"""
def run_turn(message: str) {
    console.print("");
    # `ask` is typed `-> str` for byLLM's streaming contract, but with
    # logging=True it actually yields StreamEvent objects -- iterate via an
    # `any`-typed handle so attribute access type-checks.
    event_stream: any = ask(message);
    out: any = sys.stdout;
    # Animated `thinking...` rewrites the line with \r, which only makes sense
    # on a terminal; piped output gets the static lines without it.
    is_tty = bool(out?.isatty) and bool(out.isatty());
    # Reset the per-turn write flag the verify-and-continue guard reads.
    global _turn_wrote;
    _turn_wrote = False;
    # Turn-stat accumulators -- declared before the try so the `finally` can
    # render them even if the stream errors out partway through.
    started = time.time();
    n_read = 0;
    n_write = 0;
    n_run = 0;
    files: set[str] = set();
    usage: dict[str, object] = {};
    # Live-render state.
    streamed = False;  # raw reasoning/answer tokens on the current line
    thought_raw = "";  # this step's accumulated reasoning tokens
    prose_shown = 0;  # chars of this step's prose already streamed
    step_t0 = 0.0;  # when this step's generation began
    think_on = False;  # a live `thinking...` line is on screen
    last_llm_ms = 0.0;  # model gen time of the step just finished
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
        lines = _result_snippet(result, 3 if verbose else 1);
        tail = f"   {_fmt_ms(ms)}" if (verbose and ms is not None) else "";
        console.print(f"      ↳ {lines[0]}{tail}", style="dim");
        for ln in lines[1:] {
            console.print(f"        {ln}", style="dim");
        }
    }
    try {
        for event in event_stream {
            kind = event.event_type;
            data = event.data;
            if kind == "thought" {
                # Reasoning is shown only in the verbose view; quiet hides it.
                if not verbose {
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
                (prose, hit) = _split_reasoning(thought_raw);
                new_raw = prose[prose_shown:];
                prose_shown = len(prose);
                cleaned = _strip_control(new_raw);
                if cleaned {
                    clear_think();
                    out.write(cleaned);
                    out.flush();
                    streamed = True;
                }
                # No prose yet but generating (the call is streaming as JSON):
                # show a live, ticking activity line so a slow model is not silent.
                if hit and not streamed and is_tty {
                    out.write(f"\r  ● thinking… {time.time() - step_t0:.1f}s");
                    out.flush();
                    think_on = True;
                }
            } elif kind == "chunk" {
                # Final answer: never a tool call, so stream live in both views.
                clear_think();
                flush_result();
                out.write(str(data.get("content", "")));
                out.flush();
                streamed = True;
            } elif kind == "llm_timing" {
                last_llm_ms = float(data.get("duration_ms", 0) or 0);
            } elif kind == "tool_call" {
                clear_think();
                end_line();
                flush_result();
                tool = str(data.get("tool", "?"));
                args = data.get("args", {});
                # Tally the call for the turn stats: writes (and the files they
                # touch), code/shell runs, and everything else as a read.
                if tool in _WRITE_TOOLS {
                    n_write += 1;
                    _turn_wrote = True;
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
                gen = f"   ({_fmt_ms(last_llm_ms)})"
                    if (verbose and last_llm_ms > 0)
                    else "";
                console.print(f"  ⏺ {fmt_tool_call(tool, args)}{gen}", style="cyan");
                last_llm_ms = 0.0;
                # Next step's reasoning starts fresh.
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
                # byLLM emits one `usage` event at stream end with token totals
                # aggregated across every LLM call in the turn.
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
    } finally {
        # Always render the turn summary -- a turn cut short by an error or an
        # interrupt is exactly when its stats are most worth seeing.
        if show_stats {
            print_stats(time.time() - started, n_read, n_write, n_run, files, usage);
        }
    }
}


"""The project's current error diagnostics, or [] if no model is built yet."""
def _project_errors -> list {
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
def verify_and_continue(max_rounds: int = 3) {
    if not _turn_wrote {
        return;
    }
    rnd = 0;
    prev_count = -1;
    while rnd < max_rounds {
        errs = _project_errors();
        if not errs {
            break;
        }
        # The last round did not shrink the error count -- the model is stuck,
        # so stop nudging rather than burn another round on the same wall.
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
"""
def run_agent(req: object) -> int {
    global agent_model,yolo_mode,agent_ci,show_stats,verbose,inline_feedback;
    # `req` is an AgentRequest; access it untyped so attribute reads
    # type-check without importing the class into this byLLM-only module.
    r: any = req;
    # File writes and code execution run without prompting unless `--safe`
    # asks to confirm each one.
    yolo_mode = not r.safe;
    # Rich live view unless `--quiet`/`-q` asks for compact output.
    verbose = not bool(getattr(r, "quiet", False));
    # The compiler-backed project model the semantic tools navigate. Surface its
    # recompiles in the live view so the work behind writes and queries is visible.
    agent_ci = r.code_intel;
    if agent_ci is not None {
        agent_ci.on_event = _ci_event;
    }
    initial_prompt = str(r.prompt);
    # The import-time `agent_model` already covers jac.toml/default; only
    # rebuild when a flag actually changes the model or its context window.
    if r.model or r.n_ctx > 0 {
        agent_model = build_model(str(r.model), int(r.n_ctx));
    }
    print_banner();
    reset_history();

    if initial_prompt {
        run_turn(initial_prompt);
        # Don't let a one-shot build exit on code that doesn't compile.
        verify_and_continue();
        _browse_shutdown();
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
            print_help();
            continue;
        }
        if line == "/clear" {
            reset_history();
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
            show_stats = not show_stats;
            console.success("Turn stats on." if show_stats else "Turn stats off.");
            continue;
        }
        if line == "/verbose" {
            verbose = not verbose;
            console.success(
                "Verbose: streaming reasoning, timings, and step detail."
                    if verbose
                    else "Quiet: tool calls and the answer only."
            );
            continue;
        }
        if line == "/feedback" {
            inline_feedback = not inline_feedback;
            console.success(
                "Inline compiler feedback on: writes report errors they introduce."
                    if inline_feedback
                    else "Inline compiler feedback off: use jac_check to compile."
            );
            continue;
        }
        run_turn(line);
    }

    _browse_shutdown();
    console.print("Bye.");
    return 0;
}
