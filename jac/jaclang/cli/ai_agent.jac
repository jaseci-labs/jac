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
import from jaclang.cli.agent_api { AgentRequest }
import from typing { Callable }
import from byllm.lib { Model }
import from byllm.parallel { mark_serialize }

obj AgentConfig {
    has yolo_mode: bool = True,
        threads: int = 0,
        temperature: float | None = None,
        model_source: str = "default",
        show_stats: bool = True,
        verbose: bool = True,
        inline_feedback: bool = True,
        api_key: str = "",
        base_url: str = "",
        n_ctx: int = 0;
}

obj Workspace {
    has cwd: str = "",
        ci: any = None,
        ci_dirty: bool = False;

    def resolve(path: str) -> str;
    def set_cwd(new_dir: str);
    def code_intel -> any;
    def project_errors -> list;
}

obj FileTools {
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

obj ProcessTools {
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

obj SemanticTools {
    has ws: Workspace = Workspace();

    def find_symbol(name: str) -> str;
    def find_uses(name: str) -> str;
    def project_map -> str;
    def find_walkers(node_type: str) -> str;
    def context_slice(name: str) -> str;
}

obj GuideTools {
    def search_guides(keyword: str) -> str;
    def read_guide(name: str) -> str;
}

obj BrowseTools {
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

glob _THINK_WIDTH = 40;

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

obj AgentEventBus {
    has events: list[dict] = [],
        active_feed: bool = False,
        status: str = "idle",
        active: str = "",
        path: list[str] = [],
        last_stats: dict = {},
        cancel_requested: bool = False,
        _subscribers: list = [],
        _next_id: int = 1,
        _cap: int = 4000,
        needs_key: bool = False,
        key_env: str = "",
        model_name: str = "",
        call_log: list[dict] = [],
        convos: dict[int, list] = {},
        convo_tools: dict[int, list] = {},
        _cur_convo: int = 0,
        _convo_seq: int = 0,
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
    def emit_call(fields: dict) -> None;
    def open_convo(msgs: any) -> None;
    def set_pending(msgs: any) -> None;
    def close_convo(msgs: any) -> None;
    def set_convo_tools(tools: list[Callable]) -> None;
}


obj AgentRuntime {
    has cfg: AgentConfig = AgentConfig(),
        ws: Workspace = Workspace(),
        ledger: Ledger | None = None,
        active_session: AgentSession | None = None,
        turn_wrote: bool = False,
        bus: AgentEventBus = AgentEventBus(),
        files: FileTools = FileTools(),
        proc: ProcessTools = ProcessTools(),
        semantic: SemanticTools = SemanticTools(),
        guides: GuideTools = GuideTools(),
        web: BrowseTools = BrowseTools(),
        view: TurnRenderer = TurnRenderer(),
        phase_tools: list = [],
        phase_ctx: list = [];

    def postinit -> None;
    def note(text: str) -> str;
}

glob agent: AgentRuntime = AgentRuntime();

enum ToolCat { Read, Write, Run }

node Tool {
    has fn: any,
        category: ToolCat,
        serialize: bool = False;
}

edge Exposes {}

obj ToolSpec {
    has fn: any,
        category: ToolCat,
        serialize: bool = False,
        phases: set[type] = set();
}

def _project_root_of(start: str) -> str;
def resolve_model_name(model_override: str = "") -> str;
def _byllm_config -> any;
def build_model(model_override: str = "", n_ctx: int = 0) -> Model;

glob agent_model = build_model();

def truncate(text: str, limit: int = 12000) -> str;
def confirm(action: str) -> bool;
def _count_diags(diags: list) -> tuple[int, int];
def _term_output_enabled -> bool;
def _term_print(*args: any, **kwargs: any) -> None;
def register_ui_provider_error(exc: any) -> None;
def _install_ui_provider_capture(target_bus: any = None) -> None;
def _tool_result_is_error(result: str, tool_name: str = "") -> bool;

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


glob _REWRITE_LIMIT = 5;


def _progress_guard(ctx: any) -> str;


obj Ledger {
    has changes: list = [],
        notes: list = [];

    def record(phase: str, summary: str);
    def remember(text: str);
    def render -> str;
}


obj TurnStats {
    has n_read: int = 0,
        n_write: int = 0,
        n_run: int = 0,
        files: set[str] = set(),
        usage: dict = {};

    def absorb(st: dict);
}


"""Persistent storage for `jac ai` sessions: JSON CRUD over the cache dir.

One session is one JSON file at `<root_dir>/sessions/<id>.json`, where
`<root_dir>` is the env-derived cache dir (`JAC_AI_CACHE` override or the
centralized platform default, see `cache_paths`) by default and a temp dir
in tests. Mirrors `browser_engine`'s cache pattern.
Writes are atomic (temp file + `os.replace`) so a Ctrl-C mid-save never leaves
torn JSON, and a corrupt file is skipped on list/load with a warning rather
than crashing the agent. `root_dir` empty means resolve the cache dir lazily on
each call, so a test that overrides the `JAC_AI_CACHE` env after construction
still picks it up.

A record is a plain `dict` shaped as: id, name, cwd, created, updated, cfg,
ledger ({changes, notes}), turns (per-turn objective + phase answers + stats),
and totals (running token/tool counts). The store is format-agnostic -- it does
not know about `Ledger` or `AgentConfig`; (de)serialization between the dict and
those objects lives on the agent module (where those types are defined).
"""
obj SessionStore {
    has root_dir: str = "";

    # Enumerate session records, newest-first by `updated`. When `cwd` is set,
    # only sessions whose stored `cwd` matches are returned (isolation: a
    # session belongs to the project it ran in).
    def list_sessions(cwd: str = "") -> list[dict];
    # Load one record by id; returns None (and warns) if the file is missing or
    # its JSON is corrupt -- never raises.
    def load(id: str) -> dict | None;
    # Persist a record atomically: temp file + os.replace. Stamps `updated`.
    def save(record: dict) -> None;
    # Remove a session's file; returns whether a file was removed.
    def delete(id: str) -> bool;
    # Allocate a fresh record (id + timestamps + empty ledger/turns/totals) for
    # a given cwd and optional name.
    def create(cwd: str, name: str = "") -> dict;
    # The most recently updated session for a cwd, or None.
    def most_recent(cwd: str) -> dict | None;
    # The existing session for a (cwd, name) pair, or None. Names are unique
    # within a cwd (see create/save).
    def resolve_by_name(cwd: str, name: str) -> dict | None;
    # Resolve `<root_dir>/sessions`, creating it on first use.
    def _dir -> str;
    # The file path for one session id.
    def _path(id: str) -> str;
}


"""Builds a phase's system prompt: base rules + the node's own role + the ledger."""
obj Prompt {
    static def for_phase(state_ty: type, objective: str, ledger: Ledger) -> str;
}


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


def request_needs_code_changes(objective: str, plan: str) -> bool by agent_model(
    temperature=agent.cfg.temperature
);

sem request_needs_code_changes.objective = "The user's original request for this turn.";
sem request_needs_code_changes.plan = "The plan and findings produced by the Plan phase so far.";


edge Flow {}

node PhaseState {
    has ctx: list = [],
        desc: str = "";

    def tools -> list;
    def directive -> str;
    def step(visitor: AgentSession) -> dict;
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

node Done {
    has desc: str = "Objective built and verified";

    can finish with AgentSession entry;
}

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

with entry {
    for t in TOOL_SPECS {
        if t.serialize {
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
        build_nudges: int = 0,
        # Per-turn phase transcript: {name, answer} pairs collected by
        # PhaseState.step as the walker visits each phase. Fresh per spawn
        # (one AgentSession per turn), then folded into the session record's
        # `turns[].phases` for resume scrollback. Display-only -- never fed
        # back into the model's ctx (see SESSIONS_PLAN §1 sub-decision).
        phases: list = [];

    can begin with Root entry;
}


def run_turn(message: str);
def verify_and_continue(max_rounds: int = 3);
def run_agent(req: AgentRequest) -> int;


def ui_configure -> None;
def ui_send(prompt: str) -> bool;
def ui_poll -> dict;
def ui_graph -> dict;
def ui_reset -> None;
def ui_stop -> None;
def ui_stream -> any;

def ui_call_detail(call_id: int) -> dict;
def ui_phase_context(phase: str) -> dict;
def ui_settings -> dict;
def ui_apply_settings(
    model: str, api_key: str, base_url: str, temperature: str, n_ctx: str
) -> dict;

def _run_ui_server(r: any) -> int;

glob _MODEL_PRESETS: list[str] = [
         "anthropic/claude-opus-4-7",
         "anthropic/claude-sonnet-4-6",
         "openai/gpt-4o",
         "ollama/gemma4:31b",
         "local:gemma-4-e4b"
     ];

def _model_needs_key(name: str) -> tuple[bool, str];

def _refresh_key_status -> None;
