"""Interactive Jac coding agent -- the engine behind `jac ai`.

A terminal coding agent built as a byLLM ReAct loop wired to file and guide
tools. The agent reads, writes, and debugs Jac code in the current project,
grounded in the bundled Jac reference guides so it self-serves the
authoritative spec for idiomatic Jac.

This module is imported lazily by the `jac ai` command, so the core CLI keeps
no hard dependency on the byLLM plugin. `run_agent` takes the resolved flags
directly and builds the model from them before the session starts.
"""

# Implementations live in impl/ai_agent.impl.jac.
import from byllm.lib { Model }
import from byllm.parallel { mark_serialize }

"""Session settings for one `jac ai` run, set from the CLI flags by `run_agent`.

Holds the write-once knobs the flags resolve (model source, inference threads,
temperature) and the live display toggles the `/stats`, `/verbose`, and
`/feedback` commands flip mid-session. One object in place of a pile of globals;
`--safe` clears `yolo_mode` (confirm every write/command).
"""
obj AgentConfig {
    has yolo_mode: bool = True,
        # Local-inference thread count; 0 = not a local model.
        threads: int = 0,
        # `None` for cloud models -- some newer ones reject `temperature`.
        temperature: float | None = None,
        model_source: str = "default",
        show_stats: bool = True,
        # Rich live view; `--quiet` turns it off, `/verbose` toggles.
        verbose: bool = True,
        inline_feedback: bool = True;
}

# ---------------------------------------------------------------------------
# Toolboxes -- the agent's capabilities, grouped by domain. Each public method
# is a byLLM tool (its `sem` becomes the tool's JSON-schema description); the
# `TOOLS` registry below wires them to phases. Cross-cutting infra (path
# resolution, confirmation, code intelligence) lives in free functions and on
# `AgentRuntime`, which the methods reach through the `agent` glob. The toolbox
# objects are stateless: per-session state lives on `AgentRuntime`.
# ---------------------------------------------------------------------------
"""File tools: read, write, edit, list, and search files in the project.

Paths resolve against the session working directory; writes are gated by
`confirm` and screened for JavaScript/React drift before they touch disk, and a
successful write reports the compiler errors it introduced via `write_feedback`.
"""
obj FileTools {
    def read_file(path: str) -> str;
    def write_file(path: str, content: str) -> str;
    def edit_file(path: str, old_text: str, new_text: str) -> str;
    def list_dir(path: str) -> str;
    def grep(pattern: str, path: str) -> str;
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
    def write_feedback(path: str) -> str;

    """Reject a write that is JavaScript/React rather than Jac, with a fix-it.

    A weaker model often reverts to its React training and writes JS/TS syntax
    into a `.jac` file (or tries to create a `.js`/`.ts` file outright). This
    returns a non-empty error message naming the offending tokens and the Jac
    form to use, or `""` when the content is clean Jac -- caught at write time so
    one stray file does not cascade into dozens of compile errors. Only `.jac`
    (and code-file extensions) are policed; `.css`/`.json`/`.md`/config writes
    pass through.
    """
    def _js_drift_error(path: str, content: str) -> str;
}

"""Process tools: run shell commands and the `jac` CLI, and manage the dev server.

Commands run in the session working directory (so a `cd` the model issues
persists), are gated by `confirm`, and have their output truncated. `serve` /
`stop_server` own the long-lived dev server; a `jac start`/`jac serve` issued
through `run_command` is redirected to `serve` because it would block.
"""
obj ProcessTools {
    def run_command(command: str) -> str;
    def jac_check(path: str) -> str;
    def start_app(entry_file: str) -> str;
    """Start the dev server and wait until it is actually serving, returning its URL.

    Launches `jac start <entry>` detached and polls its log until the ready URL
    appears -- the first start can be slow because it installs client deps and
    builds the client -- then returns that URL for `browse_open`. On failure
    returns the log tail so the model can fix the cause. Far more reliable than
    starting the server by hand and scraping the log for a URL within a fixed
    window.
    """
    def serve(entry_file: str) -> str;

    """Stop the dev server started by `serve` (best-effort)."""
    def stop_server -> str;

    """Combine a finished subprocess's stdout+stderr into a truncated result string."""
    def _proc_output(result: any) -> str;

    """Run a `jac` subcommand on a file and return its combined output."""
    def run_jac_cli(subcommand: str, path: str) -> str;

    """Kill the `serve` dev server and its child processes if one is running."""
    def _serve_shutdown;
}

"""Semantic tools: navigate by the compiler's symbol table, not text search.

Each method answers from `code_intel()` (the shared CodeIntelligence, rebuilt
after a write), so lookups are exact -- a symbol's definition site and uses, the
project's archetypes, the walkers that visit a node, or a typed context slice --
where grep would match comments and unrelated identifiers.
"""
obj SemanticTools {
    def find_symbol(name: str) -> str;
    def find_uses(name: str) -> str;
    def project_map -> str;
    def find_walkers(node_type: str) -> str;
    def context_slice(name: str) -> str;
}

"""Guide tools: search and read the bundled Jac reference guides -- the
authoritative spec for idiomatic Jac, consulted before writing unfamiliar code.
"""
obj GuideTools {
    def search_guides(keyword: str) -> str;
    def read_guide(name: str) -> str;
}

"""Browser tools: drive a headless browser over the Chrome DevTools Protocol.

Built on the built-in `jac browse` engine (no npm/pip). Every call reconnects to
one shared session (`agent.browse_session`), so they are all serialized. Reads
(snapshot, get, eval) run unconfirmed; navigations and interactions are gated by
`confirm`.
"""
obj BrowseTools {
    def browse_open(url: str) -> str;
    def browse_navigate(url: str) -> str;
    def browse_snapshot -> str;
    def browse_click(target: str) -> str;
    def browse_type(target: str, text: str) -> str;
    def browse_fill(target: str, text: str) -> str;
    def browse_press(key: str) -> str;
    def browse_get(what: str, selector: str) -> str;
    def browse_eval(expression: str) -> str;
    def browse_close -> str;
    """Turn a browser-engine exception into a tool-result string with a next step."""
    def _browse_err(e: Exception) -> str;

    """Run a browser-engine call under the shared confirm / error / truncate policy.

    `confirm_msg` empty means the op is read-only and runs unconfirmed; otherwise
    the action is gated and a declined call returns a DENIED string. `run` is a
    thunk performing the actual `br_*` call; its result is returned (str-cast),
    truncated when `clip` is set. Engine exceptions become a `_browse_err` string.
    """
    def _browse(confirm_msg: str, run: any, clip: bool = False) -> str;

    """Close the agent's browser session if one was opened (best-effort)."""
    def _browse_shutdown;
}

# Upper bound on the live "thinking..." line, used to erase it cleanly.
glob _THINK_WIDTH = 40;

"""Turn renderer: the live terminal view of a phase, plus the turn summary.

Consumes the byLLM event stream (reasoning, tool calls, results, the answer) and
renders it live, returning the phase's tool-call tallies; also prints the banner,
the help, the per-turn stat line, and the code-intelligence compile events. The
formatters are pure; `render_stream` keeps its per-stream state in locals.
"""
obj TurnRenderer {
    def print_banner;
    def print_help;
    """Format a tool call as `name(key=value, ...)`, clipping long values."""
    def fmt_tool_call(tool: str, args: object) -> str;

    """Render a token count compactly: 12400 -> '12.4k', 840 -> '840'."""
    def _short_num(n: int) -> str;

    """Best-effort USD cost for the turn from litellm's price map; 0 if unknown.

    Local models and any model litellm does not price raise here and fall back
    to 0 -- which is correct for a local model, and a benign omission otherwise.
    """
    def _estimate_cost(prompt_tokens: int, completion_tokens: int) -> float;

    """Render token usage (and cost, when priced) from a byLLM `usage` total."""
    def _format_tokens(usage: dict[str, object]) -> str;

    """Render the project's compiler health from the session's CodeIntelligence.

    The count is project-wide, so it catches breakage the turn left in any file.
    Reported only when the turn already built the project model (a write or a
    semantic-tool query): a stat line must stay cheap and must never trigger a
    whole-project compile -- in a large repo that would stall every turn. When
    the model is not yet built there is nothing the turn touched, so the stat is
    simply omitted.
    """
    def _format_health -> str;

    """Print the one-line turn summary: duration, tools, files, tokens, health."""
    def print_stats(
        elapsed: float,
        n_read: int,
        n_write: int,
        n_run: int,
        files: set[str],
        usage: dict[str, object]
    );

    """Strip a model's stray control tokens from streamed reasoning prose.

    Some local templates wrap tool syntax in `<|channel>`/`<token|>` markers and
    render quotes as `<|"|>`; clear them so only clean prose reaches the terminal.
    The tool-call JSON itself is excluded upstream by `_split_reasoning`.
    """
    def _strip_control(text: str) -> str;

    """Split accumulated reasoning into the prose safe to show and a hit flag.

    A reply is reasoning prose followed by the `<tool_call>` JSON the protocol
    recovers into a structured event. Return only the prose before the marker,
    and hold back a trailing partial `<tool_call` so a marker split across stream
    tokens is never shown. `hit` is True once the marker has appeared.
    """
    def _split_reasoning(raw: str) -> tuple[str, bool];

    """Up to `max_lines` lines of a tool result, each clipped, with a more-marker."""
    def _result_snippet(text: str, max_lines: int) -> list[str];

    """Format a millisecond duration compactly: '820ms', '1.8s', '13.0s'."""
    def _fmt_ms(ms: float) -> str;

    """Format a step's model timing as `(24.6s, 113 tps)`, omitting tps if unknown."""
    def _fmt_gen(ms: float, tokens: int) -> str;

    """Render a code-intelligence compile, set as `CodeIntelligence.on_event`.

    Fires whenever the compiler-backed project model rebuilds -- the initial
    load, and the incremental recompile after each write or the first query
    following one. Printed inline with the tool stream (it runs inside a tool's
    execution) so the hidden compiler work behind write_file/find_symbol/etc. is
    visible: which file, how many modules were recompiled out of the project, and
    how long it took.
    """
    def _ci_event(info: any);

    """Consume one byLLM phase event stream, rendering it live.

    A phase ability calls this with the stream returned by the `run_phase` byLLM
    call (typed `-> str` for the streaming contract, but with `logging=True` it
    yields StreamEvent objects). Renders reasoning, tool calls, and the answer
    live, and returns this phase's tool-call tallies for the walker to accumulate.
    """
    def render_stream(event_stream: any) -> dict;

    """Forward one byLLM StreamEvent from a `visit [-->] by model` routing call.

    Passed as the `stream_handler` to the QA routing model so the structured
    edge selection still streams: every raw token is teed to the live firehose
    and any clean reasoning prose is shown in the feed, while `visit [-->] by`
    keeps the choice constrained to a real successor edge. Lighter than
    `render_stream` -- routing is one cheap call, not a phase, so it skips the
    tool and turn-stat bookkeeping.
    """
    def route_stream_event(event: any) -> None;
}

"""A live, in-process feed of structured agent events for the `--ui` web view.

The terminal renderer prints to stdout; this bus tees the same milestones --
phase transitions, tool calls and results, reasoning prose, the answer, and turn
stats -- as structured records so the bundled web UI can render them and animate
the phase-graph walker in real time. It lives on `AgentRuntime`, is appended to
from the background turn thread, and read by the `ui_poll` endpoint, so every
mutation takes `_lk`. `events` is a bounded ring (the UI replaces its log
wholesale each poll, so no cursor is needed); `active` / `status` / `path` carry
the current walker position for the graph.
"""
obj AgentEventBus {
    has events: list[dict] = [],
        # True only in a `--ui` session; the terminal path leaves it False so the
        # emit points are no-ops and the bus stays empty and unread.
        active_feed: bool = False,
        # "idle" | "running" | "done" -- drives the UI status pill and graph glow.
        status: str = "idle",
        # The phase node the walker currently occupies (Plan/Build/QA/Done).
        active: str = "",
        # Phase nodes in visit order this turn; the UI animates the edge between
        # each consecutive pair to show the walker moving.
        path: list[str] = [],
        # The latest turn's summary stats (the same set the CLI prints): duration,
        # tool breakdown, files, tokens, cost, throughput, and project health.
        # Surfaced in `snapshot` and rendered as chips by the UI's stats bar.
        last_stats: dict = {},
        # Set by `ui_stop`; the progress guard aborts the phase and the walker
        # halts, so the user can stop a turn mid-flight.
        cancel_requested: bool = False,
        # Live subscribers (one `queue.Queue` per open SSE stream). Every emit
        # pushes a message to each, so the UI updates per token instead of
        # polling. `emit_stream` re-pushes the growing event each token, so the
        # client sees reasoning/answer text arrive a token at a time.
        _subscribers: list = [],
        _next_id: int = 1,
        # Large enough to keep a full session's history (reasoning/answer stream
        # into single growing events via `emit_stream`, so the count stays low).
        _cap: int = 4000;

    """Append one event (kind + fields), stamping a monotonic id; thread-safe."""
    def emit(kind: str, fields: dict) -> None;

    """Stream a token into the current block, or open a new one.

    Reasoning and answer text arrive token-by-token. Rather than one event per
    token (which would flood the feed and evict history), append the token to
    the trailing event when it is a streaming block of the same `kind`; any
    other emitted event closes the block, so the next token starts a fresh one.
    The event's `text` grows in place, so each poll shows more of the stream.
    """
    def emit_stream(kind: str, token: str) -> None;

    """Mark the walker as entering a phase: set active, extend the path, emit."""
    def enter(phase: str) -> None;

    """Set the run status ("idle" | "running" | "done") and emit a status event."""
    def set_status(s: str) -> None;

    """Reset the per-turn graph state (active node and path) for a fresh walk."""
    def begin_turn -> None;

    """A JSON-ready snapshot the `ui_poll` endpoint returns each tick."""
    def snapshot -> dict;

    """Register an SSE subscriber queue; returns it. Caller unsubscribes on close."""
    def subscribe -> any;

    """Drop a subscriber queue (on stream close/disconnect)."""
    def unsubscribe(q: any) -> None;

    """Push one delta message (the changed event + current top-level state) to
    every subscriber. Called from `emit`/`emit_stream`.
    """
    def publish(ev: dict) -> None;

    """Push a full snapshot (all events + state) to every subscriber -- the
    first frame of a new stream, and after a reset.
    """
    def publish_full -> None;

    """Push one raw model token to the live firehose, without touching the event
    log. Fed from the unsplit stream, so it includes the tokens that form tool
    calls -- which the cleaned reasoning view deliberately hides.
    """
    def feed_token(token: str) -> None;
}


"""All mutable per-session state for one `jac ai` run, gathered in one object.

This is the single composition root: the working directory, the shared
CodeIntelligence handle (and its dirty flag), the durable ledger, the live
walker, the dev-server and browser handles, and the per-turn write flag all
live here as fields instead of as a pile of module globals. Field assignments
mutate it in place, so the functions that update it need no `global`. `cfg`
carries the write-once knobs and the live `/stats`, `/verbose`, `/feedback`
toggles.
"""
obj AgentRuntime {
    has cfg: AgentConfig = AgentConfig(),
        # Logical working directory: every file tool resolves its `path` against
        # this and `run_command` runs in it, so a `cd` the model issues in one
        # shell command persists to the next call and to the file tools (a plain
        # subprocess cwd does not survive between calls). Set by `run_agent`.
        cwd: str = "",
        # Shared CodeIntelligence the semantic tools query; set by `run_agent`.
        ci: any = None,
        # Set on write; the next semantic query rebuilds the project model.
        ci_dirty: bool = False,
        # Durable cross-turn memory.
        ledger: Ledger | None = None,
        # The live walker, so the `note` tool can reach its ledger.
        active_session: AgentSession | None = None,
        # The dev server `serve` launched, tracked so it can be polled then stopped.
        serve_proc: any = None,
        # Shared headless-browser session id; every browser call reconnects to it.
        browse_session: str = "jac-ai",
        # Set by a file-writing tool; gates verify-and-continue.
        turn_wrote: bool = False,
        # Live structured event feed for the `--ui` web view; the terminal path
        # leaves it untouched (it stays empty and is never read).
        bus: AgentEventBus = AgentEventBus(),
        # Toolboxes: the agent's capabilities, composed onto the runtime.
        files: FileTools = FileTools(),
        proc: ProcessTools = ProcessTools(),
        semantic: SemanticTools = SemanticTools(),
        guides: GuideTools = GuideTools(),
        web: BrowseTools = BrowseTools(),
        # The live terminal view and turn-summary renderer.
        view: TurnRenderer = TurnRenderer();

    """Record a note onto the active session's ledger (the `note` tool).

    A memory capability rather than a domain toolbox: it writes to the live
    walker's ledger, which the runtime owns, so notes stay visible to every
    later phase and turn.
    """
    def note(text: str) -> str;
}

glob agent: AgentRuntime = AgentRuntime();

# A tool's properties -- its stats category, whether it must be serialized, and
# which phases may call it -- declared together on one descriptor instead of
# spread across separate hand-kept lists. The `TOOLS` registry (built after the
# tool functions, below) is the single source those lists are now derived from.
obj ToolSpec {
    has fn: any,
        # "read" | "write" | "run"; drives the turn-stat breakdown (anything
        # that is neither write nor run counts as a read).
        category: str,
        # Side-effecting: byLLM keeps any parallel batch containing it sequential.
        serialize: bool = False,
        # Subset of {"plan", "build", "qa"} -- the phases that expose this tool.
        phases: set[str] = set();
}

"""Resolve a tool path against the session working directory.

Absolute paths pass through; relative paths are joined onto `agent.cwd` so
every file tool agrees on what `main.jac` means, regardless of where `jac ai`
was launched or which subfolder the model has `cd`'d into.
"""
def _resolve(path: str) -> str;

"""Point the session (and its code intelligence) at a new working directory.

Called when a `run_command` changes the shell's directory. Re-roots the shared
CodeIntelligence at the new project root (the nearest ancestor holding a
`jac.toml`, else the directory itself) so semantic queries and the health line
reflect the project the model actually moved into -- e.g. a freshly scaffolded
app subfolder -- not the launch directory.
"""
def _set_session_cwd(new_dir: str);

"""The project root for a directory: nearest ancestor with a `jac.toml`, else it."""
def _project_root_of(start: str) -> str;

"""The imperative kickoff line for a phase, by state label (Plan/Build/QA).

The phase `sem` describes the role; this is the turn's actual instruction. A
weaker model tends to stop after merely exploring or describing a plan, so the
Build line insists on writing code and the QA line insists on actually running
the result -- finishing is not an option until the work exists and is verified.
"""
def _phase_directive(label: str) -> str;

"""Pick which model `jac ai` should run.

Priority: the `--model` flag (`model_override`), then `[plugins.byllm.model]
default_model` in jac.toml, then the bundled local model so the command works
with no API key. Records the winning source in `agent.cfg.model_source`.
"""
def resolve_model_name(model_override: str = "") -> str;

"""byLLM config rooted at the agent's working dir, not the process cwd.

The single source of truth for which `jac.toml` supplies the model and byLLM
settings: `agent.cwd` (the user's project). This matters under `jac ai --ui`,
where the process runs in the bundled web app's directory -- resolving against
process cwd there would read the wrong `jac.toml`. Falls back to the default
(process cwd) only before `agent.cwd` is set (import time).
"""
def _byllm_config -> any;

"""Build the agent's LLM, supporting any byLLM-compatible model.

The model name is resolved by `resolve_model_name` (flag, then jac.toml, then
the bundled local default). Cloud models work out of the box: byLLM's `Model`
pulls `api_key`/`base_url` from `[plugins.byllm.model]` in jac.toml (or the
usual provider env vars). Local models additionally read the runtime knobs
(gpu layers, threads, auto-download) from `[plugins.byllm.local]`; a non-zero
`n_ctx` overrides the configured context window.
"""
def build_model(model_override: str = "", n_ctx: int = 0) -> Model;

# Built at import so every `by` clause has a model; `run_agent` rebuilds on flags.
glob agent_model = build_model();

"""Clip oversized tool output so it does not blow the model's context."""
def truncate(text: str, limit: int = 12000) -> str;

"""Ask the user to approve a side-effecting action; honours `--yolo`."""
def confirm(action: str) -> bool;


"""Count a diagnostics list as `(errors, warnings)` by severity."""
def _count_diags(diags: list) -> tuple[int, int];


"""Return the session's CodeIntelligence, rebuilding it if a write happened.

`write_file`/`edit_file` flag the project as dirty; the first semantic query
after a write recompiles so symbol lookups reflect what the agent just wrote.
"""
def code_intel -> any;


glob AGENT_RULES = """\
You are Jac AI, a coding agent working inside the user's terminal in their Jac
project. You read, write, and debug Jac code, and verify it really works. You
move through states -- planning, building, QA -- and the state you are in tells
you what to do now; these are the habits that hold across all of them.

Universal habits:
- Batch aggressively. Independent tool calls run in parallel, so issue them
  together in ONE step -- never one at a time.
- Navigate by meaning, not text. find_symbol, find_uses, project_map,
  find_walkers, and context_slice read the compiler's symbol table and are
  exact; reserve grep for plain text -- comments, strings, TODOs.
- Never guess. Read a file before editing it, and consult the bundled guides
  before writing unfamiliar Jac -- they are the authoritative spec for correct,
  idiomatic Jac.
- Leave a note. When you make a decision, rely on an assumption, or spot
  something a later state should check, call `note` -- notes stay visible to
  every later state and turn.

You write JAC, not JavaScript, TypeScript, or React. Jac is Python-flavored
with braces. A UI component looks like Python, NOT like a React class or
function component. If you catch yourself writing React, STOP and write Jac:
- A component is `def:pub Name(props) -> JsxElement { ... }` -- never a
  `class`, never `function`, never `() => {}`, never `constructor`/`render`,
  never `this.props` (props are plain function parameters; state is `has`).
- NEVER `import React`, never `from "react"`, never `export` / `export default`.
- Define functions with `def`, not `function`; use `lambda(x: int) -> int {...}`,
  not `x => ...`. Declare variables `x: int = 1`, never `const`/`let`/`var`.
- Refer to the current object as `self`, not `this`. Use `==`/`!=`, not
  `===`/`!==`. Use `None`, not `null`/`undefined`. End statements with `;`.
- Every source file is `.jac` (a client component is `.cl.jac`). Never create
  a `.js`, `.ts`, `.jsx`, or `.tsx` file. JSX still uses `className` and
  `{expr}` -- that part is the same.
When unsure of the Jac form for any UI pattern, call read_guide("jac-cl-components")
and copy its shapes exactly.

Jac gotchas -- the type checker rejects all of these, so never write them:
- There is no `pass` statement. For an empty block, write empty braces: `{}`.
- A docstring (`\"\"\"...\"\"\"`) goes immediately BEFORE a declaration, never as
  the first statement inside a function body -- in a body it is a parse error.
- The gradual / untyped type is lowercase `any`, with no import. Never write
  capital `Any`, and never `import from typing { Any }`.
""";


"""Build the agent's system message: rules, the guide index, and the cheatsheet."""
def system_prompt -> str;


"""Clear the durable session memory (the cross-turn ledger)."""
def reset_session;


# Rewriting one file more than this many times signals a non-converging loop;
# the progress guard then ends the turn rather than burning the iteration budget.
glob _REWRITE_LIMIT = 5;


"""Stop a turn that keeps rewriting the same file without making progress.

byLLM calls this before each ReAct iteration. It counts how often each file has
been written so far this turn (from the assistant tool-call history); once any
single file crosses `_REWRITE_LIMIT`, the model is looping on an error it cannot
fix, so end the turn with a summary instead of spending the whole budget.
"""
def _progress_guard(ctx: any) -> str;


"""Compact, durable memory shared across phases and turns.

Holds a short record of the changes made and free-form notes any phase may
leave. Every phase's prompt is built from `render()`, so later phases -- and
later turns -- see what earlier ones did without carrying their raw transcripts.
"""
obj Ledger {
    has changes: list = [],
        notes: list = [];

    """Record what a phase accomplished, as a one-line ledger entry."""
    def record(phase: str, summary: str);

    """Leave a free-form note visible to every later phase and turn."""
    def remember(text: str);

    """Render the ledger as compact text for injection into a phase prompt."""
    def render -> str;
}


"""Running tool-call tallies for a turn, folded in from each phase."""
obj TurnStats {
    has n_read: int = 0,
        n_write: int = 0,
        n_run: int = 0,
        files: set[str] = set(),
        usage: dict = {};

    """Fold one phase's render_stream result into the running totals."""
    def absorb(st: dict);
}


"""Builds a phase's system prompt: base rules + the node's own role + the ledger."""
obj Prompt {
    """Compose the system message for a state, given the objective and memory."""
    static def for_phase(state_ty: type, objective: str, ledger: Ledger) -> str;
}


# One byLLM ReAct call serving every phase. `max_tokens=8192` is a generous
# ceiling so large write_file arguments are not truncated mid-stream.
"""Run the current phase: the LLM works with `tools` over the phase's own `ctx`."""
def run_phase(directive: str, tools: list, ctx: list) -> str by agent_model(
    tools=tools,
    conversation=ctx,
    stream=True,
    logging=True,
    temperature=agent.cfg.temperature,
    max_tokens=8192,
    parallelize=True,
    max_react_iterations=60,
    on_iteration=_progress_guard
);


# The single source of truth for the agent's tools. Each row pairs a tool
# function with its properties; the stats categories, each PhaseState's tool
# set (PhaseState.tools), and the serialize calls below are all derived from
# this table, so adding a tool means adding one row here. Order is the order
# tools are offered to the model within a phase.
glob TOOLS: list[ToolSpec] = [
         ToolSpec(
             fn=agent.files.read_file, category="read", phases={"plan", "build", "qa"}
         ),
         ToolSpec(
             fn=agent.files.write_file,
             category="write",
             serialize=True,
             phases={"build"}
         ),
         ToolSpec(
             fn=agent.files.edit_file,
             category="write",
             serialize=True,
             phases={"build"}
         ),
         ToolSpec(fn=agent.files.list_dir, category="read", phases={"plan", "build"}),
         ToolSpec(fn=agent.files.grep, category="read", phases={"plan", "build"}),
         ToolSpec(
             fn=agent.semantic.find_symbol, category="read", phases={"plan", "build"}
         ),
         ToolSpec(
             fn=agent.semantic.find_uses, category="read", phases={"plan", "build"}
         ),
         ToolSpec(fn=agent.semantic.project_map, category="read", phases={"plan"}),
         ToolSpec(fn=agent.semantic.find_walkers, category="read", phases={"plan"}),
         ToolSpec(
             fn=agent.semantic.context_slice, category="read", phases={"plan", "build"}
         ),
         ToolSpec(fn=agent.proc.jac_check, category="run", phases={"build", "qa"}),
         ToolSpec(
             fn=agent.proc.start_app, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(fn=agent.proc.serve, category="run", serialize=True, phases={"qa"}),
         ToolSpec(
             fn=agent.proc.stop_server, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.proc.run_command,
             category="run",
             serialize=True,
             phases={"build", "qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_open, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_navigate, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_snapshot,
             category="read",
             serialize=True,
             phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_click, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_type, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_fill, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_press, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_get, category="read", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_eval, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.web.browse_close, category="run", serialize=True, phases={"qa"}
         ),
         ToolSpec(
             fn=agent.guides.search_guides, category="read", phases={"plan", "build"}
         ),
         ToolSpec(
             fn=agent.guides.read_guide, category="read", phases={"plan", "build"}
         ),
         ToolSpec(
             fn=agent.note,
             category="read",
             serialize=True,
             phases={"plan", "build", "qa"}
         )
     ];

# Tool-name groups for the turn-stat breakdown, derived from TOOLS; everything
# not named here counts as a read.
glob _WRITE_TOOLS: set[str] = {
         str(t.fn.__name__)
         for t in TOOLS
         if t.category == "write"
     },
     _RUN_TOOLS: set[str] = {
         str(t.fn.__name__)
         for t in TOOLS
         if t.category == "run"
     };

# Side-effecting tools must not run concurrently; serialize each one so byLLM
# keeps any parallel batch that contains it sequential. Derived from TOOLS.
with entry {
    for t in TOOLS {
        if t.serialize {
            # Tools are toolbox methods: mark the underlying function so the flag
            # survives (a bound method is a throwaway and rejects attributes).
            mark_serialize(t.fn?.__func__ or t.fn);
        }
    }
}

# OSP agent: an AgentSession walker over a small state graph laid out as a
# pipeline -- Plan --> Build --> QA, with QA looping back to Build/Plan or on to
# Done. The legal transitions ARE the edges, so each state routes only among its
# own successors: the shared `PhaseState.run` runs the phase, records a ledger
# entry, then advances along the single out-edge, or lets the model pick when a
# state has several (only QA does). Each state owns its prompt (`sem`) and tool
# set (`tools()`).
"""A phase state: a self-contained step with its own prompt, tools, and context."""
node PhaseState {
    has ctx: list = [];

    """The tools this state exposes: the TOOLS rows tagged with its phase.

    Derived from the node's own class name (Plan/Build/QA -> plan/build/qa),
    so a state's allowed actions follow from its identity with no per-state
    override -- the same name `run` uses as the phase label.
    """
    def tools -> list;

    can run with AgentSession entry;
}

node Plan(PhaseState) {}

node Build(PhaseState) {}

node QA(PhaseState) {}

"""The terminal state: the task is complete and verified."""
node Done {
    can finish with AgentSession entry;
}

walker AgentSession {
    has objective: str,
        ledger: Ledger,
        stats: TurnStats,
        steps: int = 0,
        max_steps: int = 16,
        # How many times a Build phase has ended writing nothing and been pushed
        # back to actually write code; bounded so a model that simply cannot
        # produce a file does not loop forever.
        build_nudges: int = 0;

    can begin with Root entry;
}


"""Run one agent turn: spawn the session walker, then render the turn summary."""
def run_turn(message: str);


"""The project's current error diagnostics, or [] if no model is built yet."""
def _project_errors -> list;


"""After a one-shot build, keep going until the project compiles.

A weaker model often declares a multi-file task done while the project still
has compile errors. Rather than accept broken code, feed the outstanding
errors back and let the agent fix them -- bounded by `max_rounds`, and stopping
as soon as a round fails to reduce the error count, so a model that cannot make
progress exits instead of looping. No-op when the initial turn changed no code
(e.g. a read-only query) or the project already compiles.
"""
def verify_and_continue(max_rounds: int = 3);


"""Entry point for `jac ai` -- the default `run_ai_agent` hook implementation.

`req` is an `AgentRequest`: the resolved `--model`, `--n_ctx`, and `--safe`
flags, the working directory, and a shared `CodeIntelligence` handle the
semantic tools query. With a non-empty `prompt`, runs a single turn and exits;
otherwise starts an interactive read-eval-print loop. Always returns 0 -- a
failed turn reports its error but does not abort the session.

When `req.ui` is set, hands off to `_run_ui_server`: launches the bundled Jac
web app as a subprocess and opens it in the browser instead of the REPL.
"""
def run_agent(req: object) -> int;


# ---------------------------------------------------------------------------
# Web UI bridge. The bundled `ai_ui` fullstack app (served in a child `jac
# start` process) imports these functions as its server endpoints' backend.
# That child process re-imports this module, so its `agent` glob -- and the
# `agent.bus` the turn thread writes to -- is the same object `ui_poll` reads.
# ---------------------------------------------------------------------------
"""Configure the agent for a UI session from the launcher's environment.

Called once at the UI server's boot. Reads the user's project directory and
model knobs from the `JAC_AI_UI_*` env vars the launcher set, points `agent.cwd`
and a fresh `CodeIntelligence` at that project, builds the model, and forces
yolo mode (the server has no terminal to confirm at). Idempotent.
"""
def ui_configure -> None;

"""Start one agent turn for `prompt` on a background thread; never blocks.

Returns False (and does nothing) if a turn is already running, so the UI can
disable its input while busy. The turn writes its milestones to `agent.bus`,
which `ui_poll` drains.
"""
def ui_send(prompt: str) -> bool;

"""The current event feed and walker state -- the UI's per-tick poll payload.

Returns `agent.bus.snapshot()`: the bounded event log plus `status`, the
`active` phase node, and the `path` walked this turn.
"""
def ui_poll -> dict;

"""The static phase graph (nodes + edges) the UI renders in cytoscape, with state.

Nodes are Plan/Build/QA/Done; edges are the legal transitions the walker may
take. Returned once on mount; live position comes from `ui_poll`.
"""
def ui_graph -> dict;

"""Clear the cross-turn ledger and the event feed for a fresh UI session."""
def ui_reset -> None;

"""Request that the running turn stop. Sets the bus cancel flag; the progress
guard aborts the current phase and the walker halts at the next checkpoint.
No-op when nothing is running.
"""
def ui_stop -> None;

"""Live SSE event stream: yields a full snapshot, then one message per bus
emit (token by token for reasoning/answer), plus periodic heartbeats so a
client disconnect is detected. jac-scale frames each yielded dict as an
`text/event-stream` `data: {json}` chunk. The `agent_stream` endpoint returns
this; the client reads it to update the UI per token instead of polling.
"""
def ui_stream -> any;

"""Launch the bundled web UI for `jac ai --ui` and block until the user quits.

Spawns `jac start` on the bundled `ai_ui` Jac app as a child process -- passing
the user's project directory and model flags through `JAC_AI_UI_*` env vars --
polls its log for the ready URL, opens the browser there, and waits. Ctrl-C
shuts the child down. Returns 0 on a clean exit, 1 if the client plugin is
missing or the server never came up.
"""
def _run_ui_server(r: any) -> int;
