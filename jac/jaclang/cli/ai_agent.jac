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

import from byllm.lib { Model }
import from byllm.config_loader { get_byllm_config }
import from byllm.parallel { mark_serialize }

import from jaclang.cli.console { console }
import from jaclang.cli.guide_store {
    list_guides as gs_list,
    get_guide as gs_get,
    search_guides as gs_search
}

#===============================================================================
# MODEL & SESSION STATE
#===============================================================================

# Skip confirmation prompts; set by `run_agent` from the `--yolo` flag.
glob yolo_mode: bool = False,
     # Resolved CPU thread count for local inference; shown in the banner. Set by
     # `build_model`; 0 means "not a local model / leave it to the backend".
     agent_threads: int = 0,
     # Sampling temperature for the agent's calls. Set by `build_model`: a low,
     # deterministic value for local models, `None` for cloud models (some newer
     # ones reject `temperature` outright, so it is left to the provider default).
     agent_temperature: float | None = None,
     # Where the resolved model came from -- shown in the banner so the user can
     # see whether a `--model` flag, jac.toml, or the built-in default won.
     agent_model_source: str = "default";

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
        return f"OK: wrote {len(content)} chars to {path}";
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
        return f"OK: edited {path}";
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
    # server left running after the tool returns.
    time.sleep(12);
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


# Side-effecting tools must never run concurrently; byLLM keeps any parallel
# batch that contains one of these sequential.
with entry {
    mark_serialize(write_file);
    mark_serialize(edit_file);
    mark_serialize(run_command);
    mark_serialize(start_app);
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
- Never guess. Read a file before editing it; consult the guides before
  writing unfamiliar Jac. The bundled guides are the authoritative spec for
  correct, idiomatic Jac.
- Keep files focused and modest in size; split large archetypes into impl
  files. For a large file, write a skeleton first, then fill it with edit_file.
- Make minimal, targeted changes. Prefer edit_file over rewriting a whole file.
- Verify. After writing code, run `jac check .` to type-check the whole
  project and fix every error. For an app, use start_app to confirm it boots.
- When the task is complete, finish with a short plain-language summary of what
  you changed and why.

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


"""Address the user's latest message, using tools as needed."""
def ask(message: str) -> str by agent_model(
    tools=[
        read_file,
        write_file,
        edit_file,
        list_dir,
        grep,
        run_command,
        jac_check,
        start_app,
        search_guides,
        read_guide
    ],
    conversation=history,
    stream=True,
    logging=True,
    temperature=agent_temperature,
    max_tokens=8192,
    parallelize=True,
    max_react_iterations=80
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
    console.print("  type a request, /help for commands, /exit to quit", style="muted");
    console.print("");
}


def print_help {
    console.print("  /help    show this help", style="muted");
    console.print("  /clear   reset the conversation", style="muted");
    console.print("  /guides  list the bundled Jac reference guides", style="muted");
    console.print("  /exit    quit the session", style="muted");
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


"""Condense a tool result to a single clipped line for the activity log."""
def preview_result(text: str) -> str {
    stripped = text.strip();
    if not stripped {
        return "(no output)";
    }
    lines = stripped.splitlines();
    head = lines[0];
    if len(head) > 100 {
        head = head[:100] + "...";
    }
    rest = len(lines) - 1;
    return head + (f"  (+{rest} more lines)" if rest > 0 else "");
}


"""Run one agent turn, rendering the full byLLM event stream to the terminal.

`ask` runs with `stream=True, logging=True`, so it yields a StreamEvent for
every step of the ReAct loop -- the model's reasoning (`thought`), each
`tool_call` and `tool_result`, and finally the answer `chunk`s -- instead of
going silent while tools run.
"""
def run_turn(message: str) {
    console.print("");
    answering = False;
    # `ask` is typed `-> str` for byLLM's streaming contract, but with
    # logging=True it actually yields StreamEvent objects -- iterate via an
    # `any`-typed handle so attribute access type-checks.
    event_stream: any = ask(message);
    # Thoughts are buffered, not printed live: byLLM echoes the model's final
    # reasoning as both a `thought` and the answer `chunk`s. Buffered thoughts
    # flush only when a tool call follows them (genuine mid-loop reasoning);
    # the final pre-answer thought is dropped at `steps_done`.
    pending_thought = "";
    try {
        for event in event_stream {
            kind = event.event_type;
            data = event.data;
            if kind == "thought" {
                pending_thought = str(data.get("content", "")).strip();
            } elif kind == "tool_call" {
                if pending_thought {
                    console.print(pending_thought, style="dim italic");
                    pending_thought = "";
                }
                call = fmt_tool_call(str(data.get("tool", "?")), data.get("args", {}));
                console.print(f"  ⏺ {call}", style="cyan");
            } elif kind == "tool_result" {
                console.print(
                    f"    {preview_result(str(data.get('result', '')))}", style="dim"
                );
            } elif kind == "steps_done" {
                console.print("");
            } elif kind == "chunk" {
                # Answer chunks are streaming -- the buffered thought was just
                # byLLM's echo of the final reasoning, so drop it.
                pending_thought = "";
                answering = True;
                console.print(str(data.get("content", "")), end="");
            }
        }
        if answering {
            console.print("");
        } elif pending_thought {
            # No answer chunks arrived -- the model's final message itself is
            # the answer; surface it rather than leaving the turn blank.
            console.print(pending_thought);
        }
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
}


"""Entry point for `jac ai`.

Applies the resolved `--model`, `--n_ctx`, and `--yolo` flags, then runs.
With `initial_prompt`, runs a single turn and exits; otherwise starts an
interactive read-eval-print loop. Always returns 0 -- a failed turn reports
its error but does not abort the session.
"""
def run_agent(
    initial_prompt: str = "", model: str = "", n_ctx: int = 0, yolo: bool = False
) -> int {
    global agent_model,yolo_mode;
    yolo_mode = yolo;
    # The import-time `agent_model` already covers jac.toml/default; only
    # rebuild when a flag actually changes the model or its context window.
    if model or n_ctx > 0 {
        agent_model = build_model(model, n_ctx);
    }
    print_banner();
    reset_history();

    if initial_prompt {
        run_turn(initial_prompt);
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
        run_turn(line);
    }

    console.print("Bye.");
    return 0;
}
