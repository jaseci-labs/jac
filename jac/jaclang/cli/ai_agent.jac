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
import from typing { Callable }
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

"""The session's view of the project on disk: the working directory and the
shared CodeIntelligence handle (with its dirty flag), plus the operations over
them. Path resolution, re-rooting on a `cd`, the lazily-refreshed code-intel
handle, and the current project errors all live here as methods, so the
file/process/semantic tools depend on this one cohesive object instead of a pile
of module globals. Injected into those toolboxes by `AgentRuntime.postinit`.
"""
obj Workspace {
    has cwd: str = "",
        ci: any = None,
        # Set on write; the next code-intel query rebuilds the project model.
        ci_dirty: bool = False;

    # Resolve a tool path against `cwd` (absolute paths pass through).
    def resolve(path: str) -> str;
    # Re-root the session (and its code intelligence) at a new working directory.
    def set_cwd(new_dir: str);
    # The shared CodeIntelligence, rebuilt lazily when a write marked it dirty.
    def code_intel -> any;
    # The project's current compiler errors (empty list if none / unavailable).
    def project_errors -> list;
}

# ---------------------------------------------------------------------------
# Toolboxes -- the agent's capabilities, grouped by domain. Each public method
# is a byLLM tool (its `sem` becomes the tool's JSON-schema description); the
# `TOOL_SPECS` registry below wires them to phases. Cross-cutting infra (path
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
    # Injected by AgentRuntime.postinit: the shared workspace (path resolution,
    # code intelligence) and the session config (write feedback toggle).
    has ws: Workspace = Workspace(),
        cfg: AgentConfig = AgentConfig();

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
    # `ws` injected by AgentRuntime.postinit. `serve_proc` is this toolbox's own
    # resource: the dev server `serve` launched, tracked so it can be polled then
    # stopped.
    has ws: Workspace = Workspace(),
        serve_proc: any = None;

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
    # Injected by AgentRuntime.postinit: the shared workspace, whose code_intel()
    # answers every lookup.
    has ws: Workspace = Workspace();

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
one shared session (`self.session_id`), so they are all serialized. Reads
(snapshot, get, eval) run unconfirmed; navigations and interactions are gated by
`confirm`.
"""
obj BrowseTools {
    # This toolbox's own resource: the shared headless-browser session id; every
    # browser call reconnects to it.
    has session_id: str = "jac-ai";

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
    def _emit_call_usage(data: any, phase: str) -> None;
}

"""A live, in-process feed of structured agent events for the `--ui` web view.

The terminal renderer prints to stdout; this bus tees the same milestones --
phase transitions, tool calls and results, reasoning prose, the answer, and turn
stats -- as structured records so the bundled web UI can render them and animate
the phase-graph walker in real time. It lives on `AgentRuntime`, is appended to
from a single background turn thread and read by the `ui_poll`/stream endpoints.
Per-field reads/writes rely on that single-writer discipline (plus the GIL for
individual ops); `_lock` serializes only the check-then-act sections that would
otherwise race -- notably turn start in `ui_send`, where two rapid submissions
could both pass the status check and spawn a worker. `events` is a bounded ring
(the UI replaces its log wholesale each poll, so no cursor is needed); `active` /
`status` / `path` carry the current walker position for the graph.
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
        model_name: str = "",
        # Per-call conversation capture backing the token-usage detail view. Each
        # model call records the conversation it belongs to (`_cur_convo`) and its
        # token counts into `call_log`; the growing message snapshot for each
        # conversation lives once in `convos`, kept as the longest seen. From those,
        # `ui_call_detail` reconstructs a call's full input and output using the
        # assistant messages as call boundaries (each call yields one assistant
        # message), plus the diff vs the prior call. Kept OUT of the event ring /
        # `snapshot` -- heavy, fetched lazily per click, not pushed every frame.
        call_log: list[dict] = [],
        convos: dict[int, list] = {},
        # The tool JSON schemas the phase sends with every call in a conversation.
        # These ride the API's `tools` parameter -- NOT the messages -- so they
        # are captured separately (per convo, since a phase's tool set is fixed)
        # and surfaced in the detail view so the row's `tokens_in` reconciles.
        convo_tools: dict[int, list] = {},
        _cur_convo: int = 0,
        _convo_seq: int = 0,
        # Serializes check-then-act turn control (ui_send's status check + set)
        # so two near-simultaneous submissions can't both start a turn. A real
        # Lock is installed in AgentRuntime.postinit (threading is in scope there).
        _lock: any = None;

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
    def ledger_view -> dict;
    def publish_ledger -> None;
    def _state -> dict;
    # Per-call conversation capture (token-usage detail view). `msgs` is the
    # backend's heterogeneous message list (litellm dicts or objects), so it is
    # `any` rather than a concrete element type.
    def emit_call(fields: dict) -> None;
    def open_convo(msgs: any) -> None;
    def set_pending(msgs: any) -> None;
    def close_convo(msgs: any) -> None;
    # Capture the current conversation's tool JSON schemas (the `tools` API param).
    def set_convo_tools(tools: list[Callable]) -> None;
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
        # The project on disk (cwd + code intelligence) and its operations. The
        # file/process/semantic tools share this one object, wired to them in
        # `postinit`.
        ws: Workspace = Workspace(),
        # Durable cross-turn memory.
        ledger: Ledger | None = None,
        # The live walker, so the `note` tool can reach its ledger.
        active_session: AgentSession | None = None,
        # Set by a file-writing tool; gates verify-and-continue.
        turn_wrote: bool = False,
        # Live structured event feed for the `--ui` web view; the terminal path
        # leaves it untouched (it stays empty and is never read).
        bus: AgentEventBus = AgentEventBus(),
        # Toolboxes: the agent's capabilities, composed onto the runtime. They own
        # their own resources (proc the dev server, web the browser session) and
        # take the shared workspace/config injected in `postinit`.
        files: FileTools = FileTools(),
        proc: ProcessTools = ProcessTools(),
        semantic: SemanticTools = SemanticTools(),
        guides: GuideTools = GuideTools(),
        web: BrowseTools = BrowseTools(),
        # The live terminal view and turn-summary renderer.
        view: TurnRenderer = TurnRenderer(),
        # The current phase's tools and conversation, set by `PhaseState.step`
        # right before it calls `run_phase`. They live here -- not as `run_phase`
        # parameters -- because byLLM serializes a `by` function's parameters into
        # the prompt as text inputs; passing the conversation as a parameter would
        # duplicate the whole history (it is already fed via `conversation=`) and
        # dump the tool list as object reprs. As globals the `by` clause reads,
        # only `directive` remains a (genuine) prompt input.
        phase_tools: list = [],
        phase_ctx: list = [];

    # Inject the shared workspace/config into the toolboxes that need them, so a
    # toolbox depends on its collaborators rather than reaching the module glob.
    def postinit -> None;
    def note(text: str) -> str;
}

glob agent: AgentRuntime = AgentRuntime();

# Tools are modeled as a small graph: each capability is a `Tool` node that a
# phase state is connected to by an `Exposes` edge (built in `build_pipeline`).
# A state's `tools()` is then just its Exposes-neighbours -- no global lookup and
# no stringly-typed phase match.
enum ToolCat {
    # Drives the turn-stat breakdown; anything that is neither Write nor Run
    # counts as a read.
    Read,
    Write,
    Run
}

"""One capability the agent can call: a tool function plus its stats category and
whether it must be serialized. Connected to the phase states that expose it by
`Exposes` edges."""
node Tool {
    has fn: any,
        category: ToolCat,
        # Side-effecting: byLLM keeps any parallel batch containing it sequential.
        serialize: bool = False;
}

"""Connects a phase state to a `Tool` it exposes."""
edge Exposes {}

# A tool's declaration row -- the function, its stats category, whether it must
# be serialized, and the phase-state types that expose it -- on one descriptor
# instead of spread across separate hand-kept lists. The `TOOL_SPECS` registry
# (declared after the phase nodes, below) is the single source the stat groups,
# the `Exposes` edges, and the serialize calls are all derived from.
obj ToolSpec {
    has fn: any,
        category: ToolCat,
        serialize: bool = False,
        # The phase-state types that expose this tool (subset of {Plan,Build,QA}).
        phases: set[type] = set();
}

def _project_root_of(start: str) -> str;
def resolve_model_name(model_override: str = "") -> str;
def _byllm_config -> any;
def build_model(model_override: str = "", n_ctx: int = 0) -> Model;

# Built at import so every `by` clause has a model; `run_agent` rebuilds on flags.
glob agent_model = build_model();

def truncate(text: str, limit: int = 12000) -> str;
def confirm(action: str) -> bool;
def _count_diags(diags: list) -> tuple[int, int];

# Flatten one conversation message (litellm dict or object) to a small JSON-safe
# record (role + truncated content + tool-call summaries) for the token-usage
# detail snapshots.
def _san_msg(m: any) -> dict;


glob AGENT_RULES = """\
You are Jac AI, a coding agent working inside the user's terminal in their Jac
project. You read, write, and debug Jac code, and verify it really works. You
move through states and the state you are in tells
you what to do now; these are the habits that hold across all of them.

Universal habits:
- Batch aggressively. Independent tool calls run in parallel, so issue them
  together in ONE step -- never one at a time.
- Navigate by meaning, not text. find_symbol, find_uses, project_map,
  find_walkers, and context_slice read the compiler's symbol table and are
  exact; reserve grep for plain text -- comments, strings, TODOs.
- Never guess. Read a file before editing it, and consult the bundled guides
  before writing unfamiliar Jac -- they are the authoritative spec for correct,
  idiomatic Jac. read_guide("jac-core-cheatsheet") is the core-syntax primer;
  read it before writing Jac when you are unsure of the basics.
- Leave a note. When you make a decision, rely on an assumption, or spot
  something a later state should check, call `note` -- notes stay visible to
  every later state and turn.

You write only JAC -- Python-flavored with braces -- never JavaScript, TypeScript.
A UI component is Jac (`def:pub Name(props) -> JsxElement { ... }`), not a
React class or function. Before writing any UI code, call
read_guide("jac-cl-components") and copy its shapes exactly.
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
# ceiling so large write_file arguments are not truncated mid-stream. The phase's
# tools and conversation are read from the `agent` glob (set by `PhaseState.run`)
# rather than passed as parameters: byLLM serializes a `by` function's parameters
# into the prompt, so passing them would duplicate the whole conversation and dump
# the tool list as object reprs. Only `directive` stays a parameter -- it is the
# real per-call instruction byLLM should put in the prompt.
"""Run the current phase: the LLM works with the phase's tools over its own ctx."""
def run_phase(directive: str) -> str by agent_model(
    tools=agent.phase_tools,
    conversation=agent.phase_ctx,
    stream=True,
    logging=True,
    temperature=agent.cfg.temperature,
    max_tokens=8192,
    parallelize=True,
    max_react_iterations=60,
    on_iteration=_progress_guard,
    max_tool_result_length=4000
);


# The read-only fast path's triage. A single typed-bool model call (no tools, no
# conversation) decides, after Plan, whether the request actually needs code
# written -- so a pure question or inspection can finish at Done without entering
# Build (and its wrote-nothing nudge loop) or QA. A bool return routes
# deterministically in Jac, sidestepping `visit [-->] by`'s LLM edge filter,
# which a weak model can crash with an out-of-range index. Biased toward True
# (Build) so a misjudgement never silently skips real work.
"""True if carrying out the request requires creating or editing any file.

Return True for ANYTHING that writes or changes code -- this is the default, so
when in doubt return True. Return False only for a pure question, explanation,
or read-only inspection that changes no files at all (e.g. "what does this do?",
"list the files", "is there a bug here?")."""
def request_needs_code_changes(objective: str, plan: str) -> bool by agent_model(
    temperature=agent.cfg.temperature
);

sem request_needs_code_changes.objective = "The user's original request for this turn.";
sem request_needs_code_changes.plan = "The plan and findings produced by the Plan phase so far.";


# The `TOOL_SPECS` registry -- the single source of truth for the agent's tools
# -- is declared below the phase nodes (so each row's `phases` can name the state
# types directly), along with the stat-group and serialize derivations.

# OSP agent: an AgentSession walker over a small state graph laid out as a
# pipeline -- Plan --> Build --> QA, with QA looping back to Build/Plan or on to
# Done. The legal transitions ARE the edges, so each state routes only among its
# own successors. Behavior is polymorphic, not branched on a label string: the
# shared `step` runs the phase and records a ledger entry, `halt` is the common
# stop guard, and each concrete state owns its own `run` ability -- so each owns
# its routing (Plan's read-only fast path, Build's wrote-nothing nudge, QA's
# model-picked edge) -- plus its `directive`, prompt (`sem`), and tool set
# (`tools()`).
"""A legal transition between phase states (Plan->Build->QA->Done). Distinct
from `Exposes` so the routing traversals see only successor states, never the
`Tool` nodes a state exposes."""
edge Flow {}

"""A phase state: a self-contained step with its own prompt, tools, and context."""
node PhaseState {
    has ctx: list = [],
        # One-line role blurb the UI shows under the node. Lives here so tracing
        # the real graph yields the label too -- no separate hardcoded list to
        # keep in sync with the pipeline.
        desc: str = "";

    # The tools this state exposes (its `Exposes`-edge neighbours).
    def tools -> list;
    # The imperative kickoff line for this phase; overridden per state.
    def directive -> str;
    # Shared phase body: run the LLM over this state's tools/ctx, fold the result
    # into the walker's stats and ledger, and return the phase result. No `visit`
    # -- routing is each concrete state's own `run` ability.
    def step(visitor: AgentSession) -> dict;
    # Common stop guard, called after `step`: True once the turn is cancelled or
    # the step cap is hit (and it advances the step counter). Each `run` returns
    # early on it before routing.
    def halt(visitor: AgentSession) -> bool;
}

node Plan(PhaseState) {
    has desc: str = "Explore and decide the approach";

    override def directive -> str;
    can run with AgentSession entry;
}

node Build(PhaseState) {
    has desc: str = "Write and edit the code";

    override def directive -> str;
    can run with AgentSession entry;
}

node QA(PhaseState) {
    has desc: str = "Type-check, run, and verify";

    override def directive -> str;
    can run with AgentSession entry;
}

"""The terminal state: the task is complete and verified."""
node Done {
    has desc: str = "Objective built and verified";

    can finish with AgentSession entry;
}

# The single source of truth for the agent's tools. Each row pairs a tool
# function with its properties; the stat groups (_WRITE_TOOLS/_RUN_TOOLS), each
# state's tool affordances (materialized as Exposes edges in build_pipeline), and
# the serialize calls below are all derived from this table, so adding a tool
# means adding one row here. Order is the order tools are offered to the model
# within a phase. Declared after the phase nodes so each `phases` set can name
# the state types directly.
glob TOOL_SPECS: list[ToolSpec] = [
         ToolSpec(
             fn=agent.files.read_file, category=ToolCat.Read, phases={Plan, Build, QA}
         ),
         ToolSpec(
             fn=agent.files.write_file,
             category=ToolCat.Write,
             serialize=True,
             phases={Build}
         ),
         ToolSpec(
             fn=agent.files.edit_file,
             category=ToolCat.Write,
             serialize=True,
             phases={Build}
         ),
         ToolSpec(fn=agent.files.list_dir, category=ToolCat.Read, phases={Plan, Build}),
         ToolSpec(fn=agent.files.grep, category=ToolCat.Read, phases={Plan, Build}),
         ToolSpec(
             fn=agent.semantic.find_symbol, category=ToolCat.Read, phases={Plan, Build}
         ),
         ToolSpec(
             fn=agent.semantic.find_uses, category=ToolCat.Read, phases={Plan, Build}
         ),
         ToolSpec(fn=agent.semantic.project_map, category=ToolCat.Read, phases={Plan}),
         ToolSpec(fn=agent.semantic.find_walkers, category=ToolCat.Read, phases={Plan}),
         ToolSpec(
             fn=agent.semantic.context_slice,
             category=ToolCat.Read,
             phases={Plan, Build}
         ),
         ToolSpec(fn=agent.proc.jac_check, category=ToolCat.Run, phases={Build, QA}),
         ToolSpec(
             fn=agent.proc.start_app, category=ToolCat.Run, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.proc.serve, category=ToolCat.Run, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.proc.stop_server,
             category=ToolCat.Run,
             serialize=True,
             phases={QA}
         ),
         ToolSpec(
             fn=agent.proc.run_command,
             category=ToolCat.Run,
             serialize=True,
             phases={Build, QA}
         ),
         ToolSpec(
             fn=agent.web.browse_open, category=ToolCat.Run, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_navigate,
             category=ToolCat.Run,
             serialize=True,
             phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_snapshot,
             category=ToolCat.Read,
             serialize=True,
             phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_click,
             category=ToolCat.Run,
             serialize=True,
             phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_type, category=ToolCat.Run, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_fill, category=ToolCat.Run, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_press,
             category=ToolCat.Run,
             serialize=True,
             phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_get, category=ToolCat.Read, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_eval, category=ToolCat.Run, serialize=True, phases={QA}
         ),
         ToolSpec(
             fn=agent.web.browse_close,
             category=ToolCat.Run,
             serialize=True,
             phases={QA}
         ),
         ToolSpec(
             fn=agent.guides.search_guides, category=ToolCat.Read, phases={Plan, Build}
         ),
         ToolSpec(
             fn=agent.guides.read_guide, category=ToolCat.Read, phases={Plan, Build}
         ),
         ToolSpec(
             fn=agent.note,
             category=ToolCat.Read,
             serialize=True,
             phases={Plan, Build, QA}
         )
     ];

# Tool-name groups for the turn-stat breakdown, derived from TOOL_SPECS;
# everything not named here counts as a read.
glob _WRITE_TOOLS: set[str] = {
         str(t.fn.__name__)
         for t in TOOL_SPECS
         if t.category == ToolCat.Write
     },
     _RUN_TOOLS: set[str] = {
         str(t.fn.__name__)
         for t in TOOL_SPECS
         if t.category == ToolCat.Run
     };

# Side-effecting tools must not run concurrently; serialize each one so byLLM
# keeps any parallel batch that contains it sequential. Derived from TOOL_SPECS.
with entry {
    for t in TOOL_SPECS {
        if t.serialize {
            # Tools are toolbox methods: mark the underlying function so the flag
            # survives (a bound method is a throwaway and rejects attributes).
            mark_serialize(t.fn?.__func__ or t.fn);
        }
    }
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
# Lazily fetched detail for one token-usage row (model call): its full input
# conversation, the diff vs the prior call, and its output messages.
def ui_call_detail(call_id: int) -> dict;
def ui_phase_context(phase: str) -> dict;
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
