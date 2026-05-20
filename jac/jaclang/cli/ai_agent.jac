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
import html;
import difflib;
import subprocess;
import from pathlib { Path }
import from datetime { datetime }

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
     show_stats: bool = True;

# Tool names grouped for the turn-stat breakdown: tools that mutate files,
# and tools that execute code or shell commands. Everything else is a read.
glob _WRITE_TOOLS: set[str] = {"write_file","edit_file"},
     _RUN_TOOLS: set[str] = {"run_command","jac_check","start_app"};

# The shared CodeIntelligence handle for this session, set by `run_agent` from
# the AgentRequest. The semantic tools (find_symbol, find_uses, ...) query it
# so the agent navigates the project by compiler symbol data, not text search.
glob agent_ci: any = None,
     # Set by write_file/edit_file after a successful write; the next semantic
     # query rebuilds the project model so lookups reflect the new source.
     agent_ci_dirty: bool = False;

#===============================================================================
# SESSION LOG STATE
#===============================================================================
# When `--log` is passed, the session records every turn -- the user's
# message, the agent's reasoning and answer, each tool call and result, and a
# unified diff of every file the agent wrote -- and renders it to a single
# self-contained HTML file. The file is rewritten after every turn, so a
# session cut short by a crash or Ctrl-C still leaves a complete log behind.
glob log_enabled: bool = False,
     # Absolute path of the HTML log for this session; set by `run_agent`.
     log_path: str = "",
     # When the session started -- shown in the log header.
     log_session_started: datetime | None = None,
     # One dict per turn: {"user", "blocks", "started", "stats"}. `blocks` is
     # the ordered interaction stream (thought / answer / tool_call /
     # tool_result / diff entries) the HTML renderer walks.
     log_turns: list[dict[str, any]] = [],
     # The turn currently being recorded; tool helpers append diff blocks to it.
     log_current_turn: dict[str, any] | None = None;

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
    if agent_ci is None {
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
# SESSION LOG -- record the interaction + diffs and render them to HTML
#===============================================================================
"""HTML-escape any value for safe inclusion in the session log."""
def esc(value: any) -> str {
    return html.escape(str(value));
}


"""Open a new turn in the session log; later helpers append blocks to it."""
def log_start_turn(message: str) {
    global log_current_turn;
    if not log_enabled {
        return;
    }
    turn: dict[str, any] = {
        "user": message,
        "blocks": [],
        "started": time.time(),
        "stats": {}
    };
    log_turns.append(turn);
    log_current_turn = turn;
}


"""Append a structured interaction block to the turn being recorded."""
def log_block(block: dict[str, any]) {
    if not log_enabled or log_current_turn is None {
        return;
    }
    log_current_turn["blocks"].append(block);
}


"""Record a run of streamed model text, merging consecutive same-kind tokens.

The model streams `thought` and `answer` text one token at a time; merging
them into a single block keeps the rendered log readable instead of one
`<div>` per token. A tool call between two runs breaks the merge, so each
contiguous stretch of reasoning or response stays its own block.
"""
def log_text(kind: str, content: str) {
    if not log_enabled or log_current_turn is None or not content {
        return;
    }
    blocks = log_current_turn["blocks"];
    if blocks and blocks[-1].get("kind") == kind {
        blocks[-1]["text"] = str(blocks[-1]["text"]) + content;
    } else {
        blocks.append({"kind": kind, "text": content});
    }
}


"""Record a unified diff for a file the agent just wrote.

Called by `write_file`/`edit_file` with the file's contents before and after
the write, so the log shows exactly what changed. An empty `old_text` means
the file was newly created.
"""
def log_diff(path: str, old_text: str, new_text: str) {
    if not log_enabled or log_current_turn is None {
        return;
    }
    diff_lines = list(
        difflib.unified_diff(
            old_text.splitlines(),
            new_text.splitlines(),
            fromfile=path,
            tofile=path,
            lineterm="",
            n=3
        )
    );
    log_current_turn["blocks"].append(
        {"kind": "diff", "path": path, "diff": diff_lines, "created": old_text == ""}
    );
}


"""Close the current turn, attach its stats, and rewrite the HTML log.

The whole file is re-rendered after every turn so a session ended by a crash
or Ctrl-C still leaves a complete, openable log on disk.
"""
def log_finish_turn(stats: dict[str, any]) {
    if not log_enabled or log_current_turn is None {
        return;
    }
    log_current_turn["stats"] = stats;
    try {
        Path(log_path).write_text(render_log_html());
    } except Exception { }
}


# Self-contained styling for the HTML log -- a dark, modern theme; embedded so
# the log file is a single portable artifact with no external assets.
glob LOG_CSS = """
*{box-sizing:border-box;}
html,body{margin:0;}
body{background:radial-gradient(1100px 560px at 50% -200px,#1a2336 0%,#0b0e14 60%);
color:#e6edf3;font:15px/1.65 ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;}
.wrap{max-width:940px;margin:0 auto;padding:28px 22px 96px;}
.hdr{text-align:center;padding:34px 0 30px;border-bottom:1px solid #222b3a;margin-bottom:34px;}
.brand{font-size:13px;letter-spacing:.22em;text-transform:uppercase;color:#8aa4ff;font-weight:600;}
.hdr h1{margin:8px 0 4px;font-size:30px;font-weight:700;letter-spacing:-.02em;}
.hdr .sub{color:#8b97a8;font-size:14px;}
.stats{display:flex;gap:14px;justify-content:center;margin-top:22px;flex-wrap:wrap;}
.stat{background:#11161f;border:1px solid #222b3a;border-radius:12px;padding:12px 20px;min-width:104px;}
.stat .num{display:block;font-size:22px;font-weight:700;}
.stat .lbl{display:block;font-size:12px;color:#8b97a8;text-transform:uppercase;letter-spacing:.06em;}
.empty{color:#8b97a8;text-align:center;padding:40px;}
.turn{background:#11161f;border:1px solid #222b3a;border-radius:16px;padding:22px;margin-bottom:22px;position:relative;}
.turn-tag{position:absolute;top:-11px;left:20px;background:#8aa4ff;color:#0b0e14;font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;padding:3px 11px;border-radius:999px;}
.msg-user{display:flex;gap:12px;margin:10px 0 18px;}
.msg-user .role{flex:none;width:46px;font-size:12px;font-weight:700;color:#4c8dff;text-transform:uppercase;letter-spacing:.05em;padding-top:2px;}
.msg-user .utext{flex:1;background:#161c28;border:1px solid #222b3a;border-left:3px solid #4c8dff;border-radius:8px;padding:10px 14px;white-space:pre-wrap;word-break:break-word;}
.block{margin:12px 0;}
.blabel{font-size:11px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;color:#8b97a8;margin-bottom:5px;}
.btext{white-space:pre-wrap;word-break:break-word;}
.block.thought .btext{color:#8b97a8;font-style:italic;border-left:2px solid #b083f0;padding-left:12px;}
.block.thought .blabel{color:#b083f0;}
.bhead{display:flex;align-items:center;gap:9px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:13.5px;font-weight:600;margin-bottom:6px;}
.badge{font-size:10px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;padding:2px 8px;border-radius:6px;}
.badge.tool{background:rgba(227,179,65,.16);color:#e3b341;}
.badge.result{background:rgba(138,164,255,.16);color:#8aa4ff;}
.badge.diff{background:rgba(88,196,220,.16);color:#58c4dc;}
pre{margin:0;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:13px;line-height:1.55;white-space:pre-wrap;word-break:break-word;}
.args{background:#161c28;border:1px solid #222b3a;border-radius:8px;padding:10px 13px;color:#8b97a8;}
.argk{color:#8aa4ff;font-weight:600;}
details.result{background:#161c28;border:1px solid #222b3a;border-radius:8px;}
details.result summary{cursor:pointer;padding:9px 13px;font-size:13px;color:#8b97a8;display:flex;align-items:center;gap:9px;list-style:none;}
details.result summary::-webkit-details-marker{display:none;}
details.result[open] summary{border-bottom:1px solid #222b3a;}
details.result pre{padding:11px 13px;color:#e6edf3;max-height:420px;overflow:auto;}
.diffbody{border:1px solid #222b3a;border-radius:8px;overflow:hidden;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12.5px;line-height:1.6;}
.dl{padding:1px 13px;white-space:pre-wrap;word-break:break-word;}
.dl.add{background:rgba(63,185,80,.14);color:#56d364;}
.dl.del{background:rgba(248,81,73,.13);color:#f4807a;}
.dl.hunk{background:rgba(88,196,220,.1);color:#58c4dc;}
.dl.fmeta{color:#8b97a8;}
.dl.meta{color:#8b97a8;font-style:italic;}
.dl.ctx{color:#8b97a8;}
.turn-foot{margin-top:16px;padding-top:12px;border-top:1px dashed #222b3a;font-size:12.5px;color:#8b97a8;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;}
""";


"""Render one summary card for the log header."""
def _stat_card(value: int, label: str) -> str {
    return f'<div class="stat"><span class="num">{value}</span>' + f'<span class="lbl">{esc(
        label
    )}</span></div>';
}


"""Render a tool call's arguments as escaped, key-highlighted lines."""
def _log_fmt_args(args: object) -> str {
    if not isinstance(args, dict) {
        return esc(args);
    }
    lines: list[str] = [];
    for (key, value) in args.items() {
        sval = str(value);
        if len(sval) > 1200 {
            sval = sval[:1200] + f"\n… [{len(sval) - 1200} more chars]";
        }
        lines.append(f'<span class="argk">{esc(key)}</span>  {esc(sval)}');
    }
    return "\n".join(lines) or "(no arguments)";
}


"""Render unified-diff lines as colour-coded HTML rows."""
def _render_diff(diff_lines: any) -> str {
    dl = list(diff_lines);
    if not dl {
        return '<div class="dl meta">(no textual changes)</div>';
    }
    rows: list[str] = [];
    for raw in dl[:2000] {
        line = str(raw);
        cls = "ctx";
        if line.startswith("+++") or line.startswith("---") {
            cls = "fmeta";
        } elif line.startswith("@@") {
            cls = "hunk";
        } elif line.startswith("+") {
            cls = "add";
        } elif line.startswith("-") {
            cls = "del";
        }
        rows.append(f'<div class="dl {cls}">{esc(line) or "&nbsp;"}</div>');
    }
    if len(dl) > 2000 {
        rows.append(f'<div class="dl meta">… {len(dl) - 2000} more diff lines</div>');
    }
    return "".join(rows);
}


"""Render one interaction block (reasoning, response, tool call, ...) to HTML."""
def _render_block(block: any) -> str {
    kind = str(block.get("kind", ""));
    if kind == "thought" {
        return '<div class="block thought"><div class="blabel">Reasoning</div>' + f'<div class="btext">{esc(
            block.get("text", "")
        )}</div></div>';
    }
    if kind == "answer" {
        return '<div class="block answer"><div class="blabel">Response</div>' + f'<div class="btext">{esc(
            block.get("text", "")
        )}</div></div>';
    }
    if kind == "tool_call" {
        return '<div class="block tool"><div class="bhead">' + f'<span class="badge tool">tool</span>{esc(
            block.get("tool", "?")
        )}</div>' + f'<pre class="args">{_log_fmt_args(
            block.get("args", {})
        )}</pre></div>';
    }
    if kind == "tool_result" {
        result = str(block.get("result", ""));
        return '<details class="block result"><summary>' + f'<span class="badge result">result</span>{esc(
            preview_result(result)
        )}' + f'</summary><pre>{esc(result)}</pre></details>';
    }
    if kind == "diff" {
        verb = "created" if block.get("created", False) else "edited";
        return '<div class="block diff"><div class="bhead">' + f'<span class="badge diff">{verb}</span>{esc(
            block.get("path", "")
        )}</div>' + f'<div class="diffbody">{_render_diff(
            list(block.get("diff", []))
        )}</div></div>';
    }
    return "";
}


"""Render a turn's stat line: duration, tool calls, files changed, tokens."""
def _fmt_log_stats(stats: any) -> str {
    parts: list[str] = [f"{float(str(stats.get('elapsed', 0.0))):.1f}s"];
    n_tools = (
        int(str(stats.get("n_read", 0))) + int(str(stats.get("n_write", 0))) + int(
            str(stats.get("n_run", 0))
        )
    );
    if n_tools {
        parts.append(f"{n_tools} tool call" + ("" if n_tools == 1 else "s"));
    }
    n_files = int(str(stats.get("n_files", 0)));
    if n_files {
        parts.append(f"{n_files} file" + ("" if n_files == 1 else "s") + " changed");
    }
    tokens = str(stats.get("tokens", ""));
    if tokens {
        parts.append(tokens);
    }
    return "  ·  ".join(parts);
}


"""Render one recorded turn -- the user message and its interaction blocks."""
def _render_turn(idx: int, turn: dict[str, any]) -> str {
    out: list[str] = [f'<section class="turn"><div class="turn-tag">Turn {idx}</div>'];
    out.append(
        '<div class="msg-user"><div class="role">You</div>' + f'<div class="utext">{esc(
            turn.get("user", "")
        )}</div></div>'
    );
    for block in turn["blocks"] {
        out.append(_render_block(block));
    }
    stats = turn.get("stats", {});
    if stats {
        out.append(f'<div class="turn-foot">{esc(_fmt_log_stats(stats))}</div>');
    }
    out.append("</section>");
    return "".join(out);
}


"""Render the whole session as one self-contained HTML document.

Walks every recorded turn -- the user's message, the agent's reasoning and
response, each tool call and result, and every file diff -- into a styled,
dependency-free page. Re-run after each turn by `log_finish_turn`.
"""
def render_log_html -> str {
    started = log_session_started;
    started_str = started.strftime("%Y-%m-%d %H:%M") if started is not None else "";
    files_changed: set[str] = set();
    n_tools = 0;
    for turn in log_turns {
        for block in turn["blocks"] {
            kind = block.get("kind");
            if kind == "tool_call" {
                n_tools += 1;
            } elif kind == "diff" {
                files_changed.add(str(block.get("path", "")));
            }
        }
    }
    n_turns = len(log_turns);
    body: list[str] = [
        '<header class="hdr"><div class="brand">⬡ Jac AI</div>' + '<h1>Session Log</h1>' + f'<div class="sub">{esc(
            started_str
        )} &nbsp;·&nbsp; ' + f'{esc(
            agent_model.model_name
        )}</div><div class="stats">' + _stat_card(
            n_turns, "turn" if n_turns == 1 else "turns"
        ) + _stat_card(n_tools, "tool calls") + _stat_card(
            len(files_changed), "files changed"
        ) + '</div></header>'
    ];
    if not log_turns {
        body.append('<div class="empty">No turns recorded yet.</div>');
    }
    for (idx, turn) in enumerate(log_turns, 1) {
        body.append(_render_turn(idx, turn));
    }
    return (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">' + '<meta name="viewport" content="width=device-width, initial-scale=1">' + f'<title>Jac AI Session — {esc(
            started_str
        )}</title><style>' + LOG_CSS + '</style></head><body><div class="wrap">' + "".join(
            body
        ) + '</div></body></html>'
    );
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
        # Capture the prior contents so the session log can diff the write;
        # an absent file logs as a creation.
        old = "";
        try {
            old = p.read_text();
        } except Exception {
            old = "";
        }
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text(content);
        log_diff(path, old, content);
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
        updated = original.replace(old_text, new_text);
        Path(path).write_text(updated);
        log_diff(path, original, updated);
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
3. For a web or fullstack app, also QA it in a real browser with the
   `agent-browser` CLI, driven through run_command:
   - Check the CLI first: `command -v agent-browser`. If it is missing, tell
     the user, suggest they run `npm i -g agent-browser`, skip the browser
     step, and do NOT install it yourself.
   - If it is installed, start the server detached so it stays up during the
     test -- from the app's directory run
     `nohup jac start <entry> > /tmp/jac_qa.log 2>&1 &` -- wait a few seconds,
     then read /tmp/jac_qa.log for the URL it serves on.
   - Drive the browser: `agent-browser open <url>`, `agent-browser snapshot`
     to read the page, exercise the main user flows with click/type/fill, and
     check for console or on-page errors. Take an `agent-browser screenshot`.
   - Stop the server when finished: `pkill -f "jac start"`.
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
    if yolo_mode {
        console.print(
            "  file writes and commands run without confirmation (use --safe to confirm each)",
            style="yellow"
        );
    }
    if log_enabled {
        console.print(f"  session log: {log_path}", style="muted");
    }
    console.print("  type a request, /help for commands, /exit to quit", style="muted");
    console.print("");
}


def print_help {
    console.print("  /help    show this help", style="muted");
    console.print("  /clear   reset the conversation", style="muted");
    console.print("  /guides  list the bundled Jac reference guides", style="muted");
    console.print("  /stats   toggle the per-turn stat line", style="muted");
    console.print("  /exit    quit the session", style="muted");
}


"""Point the user at the HTML session log; a no-op unless `--log` recorded one."""
def report_log {
    if log_enabled and log_turns {
        console.print("");
        console.print(f"  session log saved to {log_path}", style="muted");
    }
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
    health = _format_health();
    if health {
        parts.append(health);
    }
    console.print("  " + "  ·  ".join(parts), style="muted");
}


"""Run one agent turn, rendering the full byLLM event stream to the terminal.

`ask` runs with `stream=True, logging=True`, so it yields a StreamEvent for
every step of the ReAct loop. Both the model's reasoning (`thought`) and its
final answer (`chunk`) arrive as token-level events and are written straight
to stdout as they land, so the whole turn streams live; `tool_call` and
`tool_result` events punctuate it.
"""
def run_turn(message: str) {
    console.print("");
    # Open a session-log turn (a no-op unless `--log` is set); the event loop
    # and the write tools fill it in as the turn unfolds.
    log_start_turn(message);
    # `ask` is typed `-> str` for byLLM's streaming contract, but with
    # logging=True it actually yields StreamEvent objects -- iterate via an
    # `any`-typed handle so attribute access type-checks.
    event_stream: any = ask(message);
    out: any = sys.stdout;
    # True while raw model tokens have been written since the last newline,
    # so structured lines (tool calls, results) start cleanly.
    streamed = False;
    # Turn-stat accumulators -- declared before the try so the `finally` can
    # render them even if the stream errors out partway through.
    started = time.time();
    n_read = 0;
    n_write = 0;
    n_run = 0;
    files: set[str] = set();
    usage: dict[str, object] = {};
    try {
        for event in event_stream {
            kind = event.event_type;
            data = event.data;
            if kind == "thought" or kind == "chunk" {
                # Stream every model token live -- reasoning and answer alike.
                # console.print buffers and takes no flush arg, so write direct.
                token = str(data.get("content", ""));
                out.write(token);
                out.flush();
                streamed = True;
                log_text("thought" if kind == "thought" else "answer", token);
            } elif kind == "tool_call" {
                if streamed {
                    out.write("\n");
                    out.flush();
                    streamed = False;
                }
                tool = str(data.get("tool", "?"));
                args = data.get("args", {});
                # Tally the call for the turn stats: writes (and the files they
                # touch), code/shell runs, and everything else as a read.
                if tool in _WRITE_TOOLS {
                    n_write += 1;
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
                console.print(f"  ⏺ {fmt_tool_call(tool, args)}", style="cyan");
                log_block({"kind": "tool_call", "tool": tool, "args": args});
            } elif kind == "usage" {
                # byLLM emits one `usage` event at stream end with token totals
                # aggregated across every LLM call in the turn.
                total = data.get("total", {});
                if isinstance(total, dict) {
                    usage = total;
                }
            } elif kind == "tool_result" {
                if streamed {
                    out.write("\n");
                    out.flush();
                    streamed = False;
                }
                result_text = str(data.get("result", ""));
                console.print(f"    {preview_result(result_text)}", style="dim");
                log_block({"kind": "tool_result", "result": result_text});
            } elif kind == "steps_done" {
                if streamed {
                    out.write("\n");
                    out.flush();
                    streamed = False;
                }
                console.print("");
            }
        }
        if streamed {
            out.write("\n");
            out.flush();
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
    } finally {
        # Always render the turn summary -- a turn cut short by an error or an
        # interrupt is exactly when its stats are most worth seeing.
        elapsed = time.time() - started;
        if show_stats {
            print_stats(elapsed, n_read, n_write, n_run, files, usage);
        }
        # Close the log turn and rewrite the HTML file (no-op unless --log);
        # done last so a crashed turn still leaves a complete log on disk.
        log_finish_turn(
            {
                "elapsed": elapsed,
                "n_read": n_read,
                "n_write": n_write,
                "n_run": n_run,
                "n_files": len(files),
                "tokens": _format_tokens(usage)
            }
        );
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
    global agent_model,yolo_mode,agent_ci,show_stats,log_enabled,log_path,log_session_started,log_turns,log_current_turn;
    # `req` is an AgentRequest; access it untyped so attribute reads
    # type-check without importing the class into this byLLM-only module.
    r: any = req;
    # File writes and code execution run without prompting unless `--safe`
    # asks to confirm each one.
    yolo_mode = not r.safe;
    # The compiler-backed project model the semantic tools navigate.
    agent_ci = r.code_intel;
    initial_prompt = str(r.prompt);
    # The import-time `agent_model` already covers jac.toml/default; only
    # rebuild when a flag actually changes the model or its context window.
    if r.model or r.n_ctx > 0 {
        agent_model = build_model(str(r.model), int(r.n_ctx));
    }
    # With `--log`, give this session a fresh HTML log under .jac_ai_sessions/,
    # named by start time so successive sessions never clobber one another.
    log_enabled = bool(r.log);
    log_turns = [];
    log_current_turn = None;
    if log_enabled {
        log_session_started = datetime.now();
        logs_dir = Path(str(r.cwd or os.getcwd())) / ".jac_ai_sessions";
        try {
            logs_dir.mkdir(parents=True, exist_ok=True);
        } except Exception { }
        stamp = log_session_started.strftime("%Y%m%d-%H%M%S");
        log_path = str(logs_dir / f"session-{stamp}.html");
    }
    print_banner();
    reset_history();

    if initial_prompt {
        run_turn(initial_prompt);
        report_log();
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
        run_turn(line);
    }

    report_log();
    console.print("Bye.");
    return 0;
}
