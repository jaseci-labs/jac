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
        inline_feedback: bool = True,
        # Provider API key set live from the `--ui` settings panel; injected into
        # the byLLM model config on (re)build for cloud models. Empty falls back
        # to jac.toml `[plugins.byllm.model] api_key` or the provider env var.
        api_key: str = "",
        # Optional custom endpoint / gateway base_url (cloud models only).
        base_url: str = "",
        # Context-window override (0 = model default); used on rebuild.
        n_ctx: int = 0;
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
    def write_feedback(path: str) -> str;
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
    def serve(entry_file: str) -> str;
    def stop_server -> str;
    def _proc_output(result: any) -> str;
    def run_jac_cli(subcommand: str, path: str) -> str;
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
    def _browse_err(e: Exception) -> str;
    def _browse(confirm_msg: str, run: any, clip: bool = False) -> str;
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
    def fmt_tool_call(tool: str, args: object) -> str;
    def _short_num(n: int) -> str;
    def _estimate_cost(prompt_tokens: int, completion_tokens: int) -> float;
    def _format_tokens(usage: dict[str, object]) -> str;
    def _format_health -> str;
    def print_stats(
        elapsed: float,
        n_read: int,
        n_write: int,
        n_run: int,
        files: set[str],
        usage: dict[str, object]
    );

    def _strip_control(text: str) -> str;
    def _split_reasoning(raw: str) -> tuple[str, bool];
    def _result_snippet(text: str, max_lines: int) -> list[str];
    def _fmt_ms(ms: float) -> str;
    def _fmt_gen(ms: float, tokens: int) -> str;
    def _ci_event(info: any);
    def render_stream(event_stream: any) -> dict;
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
        _cap: int = 4000,
        # API-key status for the `--ui` settings panel, refreshed by
        # `_refresh_key_status`. `needs_key` drives the panel auto-opening; the
        # current model name and the missing provider env var (e.g.
        # `ANTHROPIC_API_KEY`) are shown to the user. Ride along in every pushed
        # state frame so the client always knows whether a key is required.
        needs_key: bool = False,
        key_env: str = "",
        model_name: str = "";

    def emit(kind: str, fields: dict) -> None;
    def emit_stream(kind: str, token: str) -> None;
    def enter(phase: str) -> None;
    def set_status(s: str) -> None;
    def begin_turn -> None;
    def snapshot -> dict;
    def subscribe -> any;
    def unsubscribe(q: any) -> None;
    def publish(ev: dict) -> None;
    def publish_full -> None;
    def feed_token(token: str) -> None;
    def ledger_view -> dict;
    def publish_ledger -> None;
    def _state -> dict;
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

def _resolve(path: str) -> str;
def _set_session_cwd(new_dir: str);
def _project_root_of(start: str) -> str;
def _phase_directive(label: str) -> str;
def resolve_model_name(model_override: str = "") -> str;
def _byllm_config -> any;
def build_model(model_override: str = "", n_ctx: int = 0) -> Model;

# Built at import so every `by` clause has a model; `run_agent` rebuilds on flags.
glob agent_model = build_model();

def truncate(text: str, limit: int = 12000) -> str;
def confirm(action: str) -> bool;
def _count_diags(diags: list) -> tuple[int, int];
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


def system_prompt -> str;
def reset_session;


# Rewriting one file more than this many times signals a non-converging loop;
# the progress guard then ends the turn rather than burning the iteration budget.
glob _REWRITE_LIMIT = 5;


def _progress_guard(ctx: any) -> str;


"""Compact, durable memory shared across phases and turns.

Holds a short record of the changes made and free-form notes any phase may
leave. Every phase's prompt is built from `render()`, so later phases -- and
later turns -- see what earlier ones did without carrying their raw transcripts.
"""
obj Ledger {
    has changes: list = [],
        notes: list = [];

    def record(phase: str, summary: str);
    def remember(text: str);
    def render -> str;
}


"""Running tool-call tallies for a turn, folded in from each phase."""
obj TurnStats {
    has n_read: int = 0,
        n_write: int = 0,
        n_run: int = 0,
        files: set[str] = set(),
        usage: dict = {};

    def absorb(st: dict);
}


"""Builds a phase's system prompt: base rules + the node's own role + the ledger."""
obj Prompt {
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
    has ctx: list = [],
        desc: str = "";

    # One-line role blurb the UI shows under the node. Lives here so tracing the
    # real graph yields the label too -- no separate hardcoded list to keep in
    # sync with the pipeline.
    def tools -> list;
    can run with AgentSession entry;
}

node Plan(PhaseState) {
    has desc: str = "Explore and decide the approach";
}

node Build(PhaseState) {
    has desc: str = "Write and edit the code";
}

node QA(PhaseState) {
    has desc: str = "Type-check, run, and verify";
}

"""The terminal state: the task is complete and verified."""
node Done {
    has desc: str = "Objective built and verified";

    can finish with AgentSession entry;
}

def build_pipeline -> Plan;


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


def run_turn(message: str);
def _project_errors -> list;
def verify_and_continue(max_rounds: int = 3);
def run_agent(req: object) -> int;


# ---------------------------------------------------------------------------
# Web UI bridge. The bundled `ai_ui` fullstack app (served in a child `jac
# start` process) imports these functions as its server endpoints' backend.
# That child process re-imports this module, so its `agent` glob -- and the
# `agent.bus` the turn thread writes to -- is the same object `ui_poll` reads.
# ---------------------------------------------------------------------------
def ui_configure -> None;
def ui_send(prompt: str) -> bool;
def ui_poll -> dict;
def ui_graph -> dict;
def ui_reset -> None;
def ui_stop -> None;
def ui_stream -> any;
def ui_settings -> dict;
def ui_apply_settings(
    model: str, api_key: str, base_url: str, temperature: str, n_ctx: str
) -> dict;

def _run_ui_server(r: any) -> int;

# Quick-pick model names offered in the `--ui` settings panel; the field is
# free-form (any byLLM/litellm name works), these are just one-click defaults.
glob _MODEL_PRESETS: list[str] = [
         "anthropic/claude-opus-4-7",
         "anthropic/claude-sonnet-4-6",
         "openai/gpt-4o",
         "ollama/gemma4:31b",
         "local:gemma-4-e4b"
     ];

"""Whether the given model needs an API key the session does not yet have.

Returns `(needs_key, env_var)`. Local (`local:`) models never need one. A
cloud model is satisfied when a key is already held (`agent.cfg.api_key`), set
in jac.toml, or present in the environment (litellm reads provider env vars).
Only a missing `*_API_KEY` var counts -- a missing base-url (e.g. ollama's
`OLLAMA_API_BASE`) is not a key, so it does not trigger the panel.
"""
def _model_needs_key(name: str) -> tuple[bool, str];

"""Recompute the bus's key status (`needs_key`/`key_env`/`model_name`) from the
currently built model, so the next pushed state frame reflects it."""
def _refresh_key_status -> None;
