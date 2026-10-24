import os;
import sys;
import time;
import threading;
import logging;
import warnings;
import queue;
import difflib;

import from jaclang.osprey.ui.model { UiRegion, UiContainer, MainScreen, Overlay }
import from jaclang.osprey.ui.runtime_core {
    UiSession,
    create_session,
    append_child_session,
    set_current_screen,
    set_focus
}
import from jaclang.osprey.ui.runtime { open_modal_overlay, close_overlay }
import from jaclang.osprey.ui.layout_types_core { Axis, LayoutSpec, OverlayAnchor }
import from jaclang.osprey.ui.layout_types { fill_axis, fixed_axis, grow_axis, rect_of }
import from jaclang.osprey.ui.renderer {
    create_renderer,
    set_node_contract,
    set_node_spans,
    request_cursor,
    clear_cursor,
    render_frame,
    relayout,
    detach_node
}
import from jaclang.osprey.ui.renderer_types { Renderer }
import from jaclang.osprey.ui.terminal { ProcessTerminal, read_terminal_size }
import from jaclang.osprey.ui.virtual_terminal { VirtualTerminal }
import from jaclang.osprey.ui.input { InputNormalizer, coalesce_events }
import from jaclang.osprey.ui.input_events {
    KeyEvent,
    TextEvent,
    PasteEvent,
    MouseEvent
}
import from jaclang.osprey.ui.cells { StyleAttrs, TextSpan }
import from jaclang.osprey.ui.width { display_width }
import from jaclang.osprey.ui.markdown_proj { project_markdown }

node Row(UiContainer) {}

node Col(UiContainer) {}

node Pane(UiRegion) {
    has pane: str = "";
}

node Sheet(Overlay) {
    has sheet: str = "";
}

obj NavRow {
    has key: str,
        label: str,
        kind: str,
        depth: int = 0,
        expandable: bool = False,
        expanded: bool = False,
        detail: str = "";
}

obj PickItem {
    has key: str,
        label: str,
        detail: str = "",
        kind: str = "",
        data: any = None;
}

obj ChatEntry {
    has role: str,
        text: str = "",
        title: str = "",
        status: str = "",
        kind: str = "",
        ident: str = "",
        detail: str = "",
        time: float = 0.0,
        locs: list[str] = [];
}

obj Studio {
    has root_dir: str,
        model: ProjectModel,
        sess: UiSession postinit,
        r: Renderer postinit,
        term: (ProcessTerminal | VirtualTerminal) postinit,
        norm: InputNormalizer postinit,
        screen: MainScreen postinit,
        header: Pane postinit,
        body: Row postinit,
        nav: Pane postinit,
        center: Pane postinit,
        right: Col postinit,
        chat_pane: Pane postinit,
        tray_pane: Pane postinit,
        prompt: Pane postinit,
        status: Pane postinit,
        sheet: (Sheet | None) = None,
        sheet_kind: str = "",
        focus: str = "nav",
        center_mode: str = "code",
        running: bool = True,
        dirty: bool = True,
        indexing: bool = False,
        index_done: int = 0,
        index_total: int = 0,
        index_error: str = "",
        nav_rows: list[NavRow] = [],
        nav_sel: int = 0,
        nav_top: int = 0,
        expanded: set[str] = set(),
        code_path: str = "",
        code_lines: list[str] = [],
        code_mtime: float = 0.0,
        code_top: int = 0,
        code_left: int = 0,
        cur_line: int = 0,
        cur_col: int = 0,
        code_h: int = 10,
        code_w: int = 40,
        wire_mod: str = "",
        wire_col: int = 1,
        wire_sel: list[int] = [0, 0, 0],
        wire_top: list[int] = [0, 0, 0],
        chat: list[ChatEntry] = [],
        chat_top: int = 0,
        chat_follow: bool = True,
        chat_h: int = 10,
        tray: list[str] = [],
        tray_sel: int = 0,
        draft: str = "",
        caret: int = 0,
        history: list[str] = [],
        hist_i: int = -1,
        flash: str = "",
        flash_kind: str = "info",
        flash_until: float = 0.0,
        hover: str = "",
        picker_query: str = "",
        picker_items: list[PickItem] = [],
        picker_sel: int = 0,
        picker_purpose: str = "goto",
        picker_title: str = "",
        sheet_lines: list[list[TextSpan]] = [],
        sheet_scroll: int = 0,
        approval: dict[str, any] = {},
        quit_armed: float = 0.0,
        last_stale_check: float = 0.0,
        file_syms: dict[str, list[StNode]] = {},
        intel: any = None,
        agent: any = None,
        agent_name: str = "",
        agent_state: str = "none",
        session_id: str = "",
        spin: int = 0,
        log_path: str = "",
        verbs: dict[str, str] = {},
        config: dict[str, any] = {},
        registry: any = None,
        rec: any = None,
        tool_index: dict[str, int] = {},
        term_index: dict[str, int] = {},
        plan_idx: int = -1,
        msg_open: str = "",
        queued: list[dict[str, any]] = [],
        pending: list[dict[str, any]] = [],
        tickets: dict[int, str] = {},
        hover_due: float = 0.0,
        agent_title: str = "",
        agent_commands: list[str] = [],
        loc_items: list[PickItem] = [],
        agent_items: list[PickItem] = [],
        turn_started: float = 0.0,
        gate: any = None,
        bridge: any = None,
        bridge_path: str = "",
        gate_mode: str = "ask",
        changed: dict[str, str] = {},
        plan_entries: list[dict[str, any]] = [],
        plan_links: list[dict[str, any]] = [],
        auto_allowed: int = 0,
        chat_sel: int = -1,
        chat_open: set[int] = set(),
        chat_starts: list[int] = [],
        baselines: dict[str, str] = {},
        line_marks: dict[str, dict[int, str]] = {},
        nav_w: int = 34,
        side_w: int = 0,
        show_inlays: bool = True,
        pending_new: list[str] = [],
        gmap: (MapState | None) = None,
        wire_items: list[PickItem] = [],
        doc_result: (tuple[str, str] | None) = None,
        doc_busy: bool = False,
        restored_transcript: str = "";

    def postinit;
    def install_layout;
    def say(text: str, kind: str = "info", secs: float = 4.0);
}

def run_tui(root_dir: str, agent_name: str = "", session_id: str = "") -> int;

def start_indexing(app: Studio);

def main_loop(app: Studio);

def pump_background(app: Studio);

def handle_event(app: Studio, ev: any) -> None;

def handle_mouse(app: Studio, ev: MouseEvent) -> None;

def pane_node(app: Studio, name: str) -> any;

def pane_at(app: Studio, x: int, y: int) -> str;

glob FOCUS_RING: list[str] = ["nav", "code", "chat", "tray", "prompt"];

def handle_key(app: Studio, key: str) -> None;

def cycle_focus(app: Studio, step: int);

def toggle_center(app: Studio) -> None;

def current_module_key(app: Studio) -> str;

def module_of_key(app: Studio, key: str) -> str;

def rebuild_nav(app: Studio);

def walk_nav(app: Studio, key: str, depth: int, rows: list[NavRow]);

def nav_key(app: Studio, key: str);

def nav_activate(app: Studio) -> None;

def open_key(app: Studio, key: str, focus: bool = False) -> None;

def reveal_in_nav(app: Studio, key: str);

def load_code(app: Studio, path: str, keep_pos: bool = False) -> None;

def goto_line(app: Studio, line: int);

def clamp_cursor(app: Studio);

def gutter_width(app: Studio) -> int;

def code_key(app: Studio, key: str) -> None;

def symbols_in_file(app: Studio, path: str) -> list[StNode];

def symbol_at_cursor(app: Studio) -> (StNode | None);

def word_at_cursor(app: Studio) -> str;

def jump_decl_impl(app: Studio) -> None;

def goto_definition(app: Studio) -> None;

def find_references(app: Studio) -> None;

def show_locations(app: Studio, title: str, items: list[PickItem]) -> None;

def jump_diagnostic(app: Studio) -> None;

def update_hover(app: Studio) -> None;

def wire_columns(app: Studio) -> list[list[PickItem]];

def wire_key(app: Studio, key: str) -> None;

def chat_key(app: Studio, key: str);

def tray_key(app: Studio, key: str);

def add_to_tray(app: Studio, key: str) -> None;

def prompt_insert(app: Studio, text: str) -> None;

def prompt_key(app: Studio, key: str);

def submit(app: Studio) -> None;

glob VERBS: dict[str, str] = {
         "explain": "Explain what the selected code does, how it is wired into the rest of the project, and anything surprising.",
         "tests": "Write tests for the selected code. Follow the project's existing test conventions.",
         "refactor": "Refactor the selected code for clarity without changing behaviour. Keep the archwire wiring valid.",
         "review": "Review the selected code for bugs and risky assumptions. Do not change files; report findings.",
         "doc": "Document the selected code: add or improve its docstrings and sem strings.",
         "fix": "Fix the problems in the selected code. Check your edits compile.",
         "move": "Move the selected code to the module named below, updating archwire.jac so every import stays wired:"
     };

def run_slash(app: Studio, text: str);

def send_to_agent(app: Studio, text: str);

def cancel_turn(app: Studio);

def open_agent_picker(app: Studio);

def open_sheet(app: Studio, kind: str, width: int, height: int, anchor: OverlayAnchor);

def close_sheet(app: Studio) -> None;

def screen_size(app: Studio) -> tuple[int, int];

def open_picker(app: Studio, purpose: str, title: str, query: str);

def refresh_picker(app: Studio);

def palette_items(app: Studio) -> list[PickItem];

def open_palette(app: Studio);

def run_palette(app: Studio, key: str);

def sheet_text(app: Studio, ch: str) -> None;

def sheet_key(app: Studio, key: str) -> None;

def pick(app: Studio, item: PickItem, alt: bool);

def choose_agent(app: Studio, name: str);

glob HELP_TEXT: list[tuple[str, str]] = [
         ("", "Moving around"),
         (
             "Tab / Shift+Tab",
             "move focus: navigator, code, transcript, context, prompt"
         ),
         (
             "Ctrl+P",
             "go to any module or symbol (Tab in the list adds it to the context)"
         ),
         ("Ctrl+T or w", "switch the centre between code and the archwire wiring view"),
         ("m", "the architecture map: the wiring a package level at a time"),
         ("Ctrl+X", "command palette"),
         ("Ctrl+L", "jump to the prompt"),
         ("Ctrl+C / Ctrl+Q", "cancel the agent's turn (twice to quit) / quit"),
         ("", "Navigator"),
         ("↑ ↓  j k", "move"),
         ("→ ←  l h", "expand / collapse"),
         ("Enter", "open in the code view"),
         ("Space or a", "add to the context"),
         ("", "Code"),
         ("arrows, PgUp/PgDn, g/G", "move the cursor"),
         ("Space or a", "add the symbol under the cursor to the context"),
         ("Enter or d", "go to definition"),
         ("r", "find references"),
         ("i", "jump between a declaration and its impl"),
         ("e", "next diagnostic"),
         ("t", "show or hide inferred types (inlay hints)"),
         ("", "Wiring view"),
         ("← →", "providers | module | consumers"),
         ("Enter", "follow a wire to that module, or open a symbol"),
         ("Space", "add the wire or symbol to the context"),
         ("A", "add every item in the column to the context"),
         ("", "Architecture map"),
         ("v or 1-7", "matrix, layers, issues, roles, iface, rules, clusters"),
         (
             "s / b",
             "slice (what it rests on) / blast radius (what depends on it); again for all wires"
         ),
         ("x", "clear the slice, blast radius or cluster filter"),
         ("arrows", "move; in the matrix the row feeds the column"),
         ("Enter", "open a package, a module's wiring, or the wires behind a number"),
         ("Backspace or u", "up one package level"),
         ("Space", "add a group, a dependency or the whole level to the context"),
         ("d / t", "matrix: jump to the diagonal / swap row and column"),
         ("", "Context and prompt"),
         ("@", "in the prompt: pick something to add to the context"),
         ("Enter / Alt+Enter", "send / new line"),
         (
             "/explain /tests /review ...",
             "verbs that act on the context (also /refactor /doc /fix /move)"
         ),
         ("/agent", "choose the agent"),
         ("x or Delete", "in the context tray: remove the selected item"),
         ("", "Transcript"),
         ("↑ ↓  j k", "select an entry"),
         ("Enter", "expand a tool call, or jump to the code a plan step touches"),
         ("o", "open the files a tool call touched"),
         ("", "Layout"),
         ("Alt+← / Alt+→", "move the edge of the focused pane"),
         ("Ctrl+X → reset layout", "restore the default pane sizes")
     ];

def open_help(app: Studio);

def approval_key(app: Studio, key: str);

def paint(app: Studio);

def pane_rect(app: Studio, n: any) -> tuple[int, int];

def title_row(
    app: Studio, text: str, focused: bool, width: int, right: str = ""
) -> list[TextSpan];

def paint_header(app: Studio) -> None;

glob SPIN: str = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏";

def paint_nav(app: Studio) -> None;

def code_line_spans(
    app: Studio, idx: int, text: str, styles: (list[list[any]] | None)
) -> list[TextSpan];

def slice_spans(spans: list[TextSpan], left: int) -> list[TextSpan];

def paint_code(app: Studio) -> None;

def paint_wiring(app: Studio) -> None;

def paint_map(app: Studio) -> None;

def open_map(app: Studio, key: str, inside: bool = False) -> None;

def set_map_scope(app: Studio, scope: str, select: str = "") -> None;

def map_key(app: Studio, key: str) -> None;

def map_activate(app: Studio) -> None;

def map_add(app: Studio) -> None;

def open_wire_list(app: Studio, src: str, dst: str) -> None;

def map_target(app: Studio) -> str;

def ensure_map_data(app: Studio) -> None;

def map_filter(app: Studio, key: str, direction: str, again: bool = False) -> None;

def map_spec(app: Studio) -> str;

def apply_spec(app: Studio, spec: str) -> None;

def map_list_activate(app: Studio, it: MapItem) -> None;

def open_doc(app: Studio, title: str, text: str) -> None;

def start_doc(app: Studio, kind: str) -> None;

def open_wires(app: Studio, title: str, wires: list[WireInfo]) -> None;

def deliver(app: Studio, blocks: list[dict[str, any]]) -> None;

def wire_ref(w: WireInfo) -> str;

def map_sig(app: Studio) -> tuple[int, int, int];

def chat_lines(app: Studio, width: int) -> list[list[TextSpan]];

def paint_chat(app: Studio) -> None;

def paint_tray(app: Studio) -> None;

def paint_prompt(app: Studio) -> None;

def paint_status(app: Studio) -> None;

def paint_sheet(app: Studio) -> None;

impl Studio.postinit {
    handle = create_session();
    self.sess = handle.session;
    self.screen = MainScreen(key="studio");
    self.header = Pane(key="header", pane="header");
    self.body = Row(key="body");
    self.nav = Pane(key="nav", pane="nav");
    self.center = Pane(key="center", pane="center");
    self.right = Col(key="right");
    self.chat_pane = Pane(key="chat", pane="chat");
    self.tray_pane = Pane(key="tray", pane="tray");
    self.prompt = Pane(key="prompt", pane="prompt");
    self.status = Pane(key="status", pane="status");
    s = self.sess;
    ui_top = s.ui_root;
    if ui_top is None {
        raise RuntimeError("osprey session has no root");
    }
    append_child_session(s, ui_top, self.screen);
    append_child_session(s, self.screen, self.header);
    append_child_session(s, self.screen, self.body);
    append_child_session(s, self.body, self.nav);
    append_child_session(s, self.body, self.center);
    append_child_session(s, self.body, self.right);
    append_child_session(s, self.right, self.chat_pane);
    append_child_session(s, self.right, self.tray_pane);
    append_child_session(s, self.screen, self.prompt);
    append_child_session(s, self.screen, self.status);
    set_current_screen(s, self.screen);
    set_focus(s, self.nav);
    (cols, rows) = read_terminal_size(120, 36);
    self.r = create_renderer(cols, rows);
    self.term = ProcessTerminal();
    self.norm = InputNormalizer();
    self.expanded = set();
    self.install_layout();
}

impl Studio.install_layout {
    r = self.r;
    set_node_contract(
        r, self.screen, LayoutSpec(width=fill_axis(), height=fill_axis())
    );
    set_node_contract(
        r, self.header, LayoutSpec(width=fill_axis(), height=fixed_axis(1.0))
    );
    set_node_contract(
        r,
        self.body,
        LayoutSpec(width=fill_axis(), height=grow_axis(1.0), flow_axis=Axis.HORIZONTAL)
    );
    set_node_contract(
        r, self.nav, LayoutSpec(width=fixed_axis(float(self.nav_w)), height=fill_axis())
    );
    set_node_contract(
        r, self.center, LayoutSpec(width=grow_axis(3.0), height=fill_axis())
    );
    set_node_contract(
        r,
        self.right,
        LayoutSpec(
            width=(
                fixed_axis(float(self.side_w)) if self.side_w > 0 else grow_axis(2.0)
            ),
            height=fill_axis()
        )
    );
    set_node_contract(
        r, self.chat_pane, LayoutSpec(width=fill_axis(), height=grow_axis(1.0))
    );
    set_node_contract(
        r, self.tray_pane, LayoutSpec(width=fill_axis(), height=fixed_axis(7.0))
    );
    set_node_contract(
        r, self.prompt, LayoutSpec(width=fill_axis(), height=fixed_axis(4.0))
    );
    set_node_contract(
        r, self.status, LayoutSpec(width=fill_axis(), height=fixed_axis(1.0))
    );
}

impl Studio.say(text: str, kind: str = "info", secs: float = 4.0) {
    self.flash = text;
    self.flash_kind = kind;
    self.flash_until = time.time() + secs;
    self.dirty = True;
}

impl run_tui(root_dir: str, agent_name: str = "", session_id: str = "") -> int {
    if not sys.stdin.isatty() or not sys.stdout.isatty() {
        sys.stderr.write(
            "jac hack needs an interactive terminal; try `jac hack model`.\n"
        );
        return 1;
    }
    model = ProjectModel(root_dir=root_dir);
    model.build(index=False);
    app = Studio(root_dir=root_dir, model=model);
    app.config = load_studio_config(root_dir);
    app.verbs = dict(VERBS);
    for (vk, vv) in app.config.get("verbs", {}).items() {
        app.verbs[str(vk)] = str(vv);
    }
    app.agent_name = agent_name or str(app.config.get("default_agent", ""));
    app.session_id = session_id;
    log_dir = os.path.join(root_dir, ".jac", "studio", "logs");
    os.makedirs(log_dir, exist_ok=True);
    app.log_path = os.path.join(log_dir, "studio.log");
    log_file = open(app.log_path, "a", buffering=1);
    saved_out = sys.stdout;
    saved_err = sys.stderr;
    saved_handlers = list(logging.getLogger().handlers);
    saved_level = logging.getLogger().level;
    rc = 0;
    try {
        logging.getLogger().handlers = [logging.StreamHandler(log_file)];
        logging.getLogger().setLevel(logging.WARNING);
        warnings.simplefilter("ignore");
        app.term.start();
        app.term.set_title("jac hack");
        app.term.enable_mouse();
        sys.stderr = log_file;
        start_indexing(app);
        try {
            app.intel = CodeIntel();
            app.intel.start(root_dir);
        } except Exception as e {
            app.intel = None;
            app.say(f"code intelligence is off: {e}", "warn", 6.0);
        }
        start_gate_and_bridge(app, session_id);
        if session_id {
            restore_session(app, session_id);
        }
        app.say(
            "Welcome to jac hack. Tab moves focus, Ctrl+P finds anything, F1 shows keys.",
            "info",
            8.0
        );
        rebuild_nav(app);
        main_loop(app);
    } except KeyboardInterrupt {
        rc = 130;
    } finally {
        try {
            app.term.stop();
        } except Exception {}
        try {
            if app.rec is not None {
                app.rec.tray = list(app.tray);
                app.rec.save();
            }
        } except Exception {}
        try {
            if app.agent is not None {
                app.agent.stop();
            }
        } except Exception {}
        try {
            if app.intel is not None {
                app.intel.stop();
            }
        } except Exception {}
        try {
            if app.bridge is not None {
                app.bridge.stop();
            }
        } except Exception {}
        sys.stderr = saved_err;
        sys.stdout = saved_out;
        logging.getLogger().handlers = saved_handlers;
        logging.getLogger().setLevel(saved_level);
        log_file.close();
        if app.rec is not None {
            saved_err.write(
                f"jac hack: session {app.rec.id[:8]} saved; resume with `jac hack -s {app.rec.id[:8]}`\n"
            );
        }
    }
    return rc;
}

impl start_indexing(app: Studio) {
    app.indexing = True;
    app.index_total = len(
        [
            m
            for m in app.model.modules.values()
            if m.kind == "module"
        ]
    );
    def progress(n: int, total: int, key: str) {
        app.index_done = n;
        app.index_total = total;
        if n % 20 == 0 or n == total {
            app.dirty = True;
        }
    }
    def work {
        try {
            app.model.index_all(progress);
        } except Exception as e {
            app.index_error = str(e);
        }
        app.indexing = False;
        app.file_syms = {};
        app.dirty = True;
    }
    threading.Thread(target=work, daemon=True).start();
}

impl main_loop(app: Studio) {
    frame_t = 0.0;
    trace = os.environ.get("JAC_STUDIO_TRACE", "") == "1";
    painted_size = app.term.size();
    while app.running {
        t0 = time.time();
        raw = app.term.poll_input(0.03);
        if getattr(app.term, "eof", False) {
            break;
        }
        if app.term.size() != painted_size {
            painted_size = app.term.size();
            app.dirty = True;
        }
        t1 = time.time();
        events: list[any] = [];
        if raw {
            events = app.norm.feed(raw);
        } elif app.norm.buffer == "\x1b" {
            events = app.norm.flush_buffer();
        }
        for ev in coalesce_events(events) {
            handle_event(app, ev);
        }
        t2 = time.time();
        pump_background(app);
        t3 = time.time();
        now = time.time();
        if app.flash and now > app.flash_until {
            app.flash = "";
            app.dirty = True;
        }
        if app.indexing or app.agent_state in ["busy", "starting"] {
            if now - frame_t > 0.12 {
                app.spin += 1;
                app.dirty = True;
            }
        }
        if app.dirty {
            paint(app);
            app.dirty = False;
            frame_t = now;
        }
        t4 = time.time();
        if trace and t4 - t0 > 0.25 {
            sys.stderr.write(
                f"slow frame {t4 - t0:.2f}s: poll {t1 - t0:.2f} input {t2
                    - t1:.2f} pump {t3 - t2:.2f} paint {t4 - t3:.2f} events {len(
                    events
                )}\n"
            );
        }
    }
}

impl pump_background(app: Studio) {
    now = time.time();
    if app.doc_result is not None and app.sheet is None {
        (title, text) = app.doc_result;
        app.doc_result = None;
        open_doc(
            app, title, "```\n" + text + "\n```" if not text.startswith("#") else text
        );
    }
    pump_agent(app);
    pump_bridge(app);
    pump_reviews(app);
    ta = time.time();
    pump_intel(app, now);
    tb = time.time();
    if os.environ.get("JAC_STUDIO_TRACE", "") == "1" and tb - now > 0.2 {
        sys.stderr.write(f"  pump: agent {ta - now:.2f} intel {tb - ta:.2f}\n");
    }
    if not app.indexing and now - app.last_stale_check > 1.5 {
        app.last_stale_check = now;
        try {
            stale = app.model.stale_files();
        } except Exception {
            stale = [];
        }
        while app.pending_new {
            stale.append(app.pending_new.pop(0));
        }
        for f in stale[:20] {
            app.model.refresh(f);
            app.file_syms = {};
            app.dirty = True;
        }
        if app.code_path {
            try {
                m = os.path.getmtime(app.code_path);
                if m != app.code_mtime {
                    load_code(app, app.code_path, keep_pos=True);
                    app.say(
                        f"{os.path.basename(app.code_path)} changed on disk; reloaded",
                        "info"
                    );
                }
            } except OSError {}
        }
        if stale {
            rebuild_nav(app);
        }
    }
}

impl handle_event(app: Studio, ev: any) -> None {
    if isinstance(ev, KeyEvent) {
        handle_key(app, ev.key);
    } elif isinstance(ev, TextEvent) {
        if not ev.text {
            return;
        }
        if app.sheet is not None {
            for ch in ev.text {
                sheet_text(app, ch);
            }
        } elif app.focus == "prompt" {
            prompt_insert(app, ev.text);
        } else {
            for ch in ev.text {
                handle_key(app, ch);
            }
        }
    } elif isinstance(ev, PasteEvent) {
        if app.sheet is not None and app.sheet_kind == "picker" {
            app.picker_query += ev.text.replace("\n", " ");
            refresh_picker(app);
        } else {
            app.focus = "prompt";
            prompt_insert(app, ev.text);
        }
    } elif isinstance(ev, MouseEvent) {
        handle_mouse(app, ev);
    }
    app.dirty = True;
}

impl handle_mouse(app: Studio, ev: MouseEvent) -> None {
    if app.sheet is not None {
        return;
    }
    (x, y) = (ev.x - 1, ev.y - 1);
    if ev.button in [64, 65] {
        delta = -3 if ev.button == 64 else 3;
        target = pane_at(app, x, y);
        if target == "center" and app.center_mode == "code" {
            app.code_top = max(
                0, min(app.code_top + delta, max(0, len(app.code_lines) - 1))
            );
        } elif target == "chat" {
            app.chat_follow = False;
            app.chat_top = max(0, app.chat_top + delta);
        } elif target == "nav" {
            app.nav_top = max(
                0, min(app.nav_top + delta, max(0, len(app.nav_rows) - 1))
            );
        }
        return;
    }
    if not ev.pressed or ev.motion {
        return;
    }
    target = pane_at(app, x, y);
    if not target {
        return;
    }
    if target in ["nav", "center", "chat", "tray", "prompt"] {
        app.focus = "code" if target == "center" else target;
    }
    rect = rect_of(app.r.layout, pane_node(app, target));
    if rect is None {
        return;
    }
    row = y - rect.y - 1;
    if target == "nav" and row >= 0 {
        idx = app.nav_top + row;
        if 0 <= idx < len(app.nav_rows) {
            if idx == app.nav_sel {
                nav_activate(app);
            }
            app.nav_sel = idx;
        }
    } elif target == "center" and app.center_mode == "code" and row >= 0 {
        app.cur_line = min(max(0, app.code_top + row), max(0, len(app.code_lines) - 1));
        app.cur_col = max(0, x - rect.x - gutter_width(app) + app.code_left);
        clamp_cursor(app);
    } elif target == "tray" and row >= 0 {
        if row < len(app.tray) {
            app.tray_sel = row;
        }
    }
}

impl pane_node(app: Studio, name: str) -> any {
    return {
        "nav": app.nav,
        "center": app.center,
        "chat": app.chat_pane,
        "tray": app.tray_pane,
        "prompt": app.prompt,
        "header": app.header,
        "status": app.status
    }.get(
        name
    );
}

impl pane_at(app: Studio, x: int, y: int) -> str {
    for name in ["nav", "center", "chat", "tray", "prompt"] {
        rect = rect_of(app.r.layout, pane_node(app, name));
        if rect is not None
            and rect.x <= x < rect.x + rect.width
            and rect.y <= y < rect.y + rect.height {
            return name;
        }
    }
    return "";
}

impl handle_key(app: Studio, key: str) -> None {
    if app.sheet is not None {
        sheet_key(app, key);
        return;
    }
    if key == "ctrl+q" {
        app.running = False;
        return;
    }
    if key == "ctrl+c" {
        if app.agent is not None and app.agent_state == "busy" {
            cancel_turn(app);
            return;
        }
        if time.time() - app.quit_armed < 2.0 {
            app.running = False;
        } else {
            app.quit_armed = time.time();
            app.say("Press Ctrl+C again to quit (Ctrl+Q quits at once)", "warn", 2.0);
        }
        return;
    }
    if key == "tab" {
        cycle_focus(app, 1);
        return;
    }
    if key == "shift+tab" {
        cycle_focus(app, -1);
        return;
    }
    if key == "ctrl+p" {
        open_picker(app, "goto", "Go to symbol or module", "");
        return;
    }
    if key == "ctrl+x" {
        open_palette(app);
        return;
    }
    if key == "f1" or (key == "?" and app.focus != "prompt") {
        open_help(app);
        return;
    }
    if key == "ctrl+t" or (key == "w" and app.focus in ["nav", "code"]) {
        toggle_center(app);
        return;
    }
    if key in ["s", "b"]
        and (
            app.focus == "nav" or (app.focus == "code" and app.center_mode == "code")
        ) {
        target = map_target(app);
        if app.focus == "code" and app.code_path {
            sym = symbol_at_cursor(app);
            if sym is not None {
                target = sym.key;
            }
        }
        if target {
            map_filter(app, target, "up" if key == "s" else "down");
        }
        return;
    }
    if key == "m" and app.focus in ["nav", "code"] {
        if app.center_mode == "map" {
            app.center_mode = "code";
        } else {
            open_map(app, map_target(app));
        }
        return;
    }
    if key == "ctrl+l" {
        app.focus = "prompt";
        return;
    }
    if key in ["alt+left", "alt+right"] {
        resize_panes(app, -1 if key == "alt+left" else 1);
        return;
    }
    if key == "escape" and app.focus != "prompt" {
        app.hover = "";
        if app.focus == "code" and app.center_mode != "code" {
            app.center_mode = "code";
        }
        return;
    }
    if app.focus == "nav" {
        nav_key(app, key);
    } elif app.focus == "code" {
        if app.center_mode == "code" {
            code_key(app, key);
        } elif app.center_mode == "map" {
            map_key(app, key);
        } else {
            wire_key(app, key);
        }
    } elif app.focus == "chat" {
        chat_key(app, key);
    } elif app.focus == "tray" {
        tray_key(app, key);
    } elif app.focus == "prompt" {
        prompt_key(app, key);
    }
}

impl cycle_focus(app: Studio, step: int) {
    i = FOCUS_RING.index(app.focus) if app.focus in FOCUS_RING else 0;
    app.focus = FOCUS_RING[(i + step) % len(FOCUS_RING)];
}

impl toggle_center(app: Studio) -> None {
    if app.center_mode == "map" {
        nd = app.gmap.selected_node() if app.gmap is not None else None;
        if nd is not None and nd.kind == "module" {
            app.wire_mod = nd.key;
            app.center_mode = "wiring";
            app.wire_sel = [0, 0, 0];
            app.wire_top = [0, 0, 0];
            app.wire_col = 1;
        } else {
            app.center_mode = "code";
        }
        app.focus = "code";
        return;
    }
    if app.center_mode == "code" {
        key = current_module_key(app);
        if key {
            app.wire_mod = key;
        }
        if not app.wire_mod {
            app.say(
                "Select a module first: wiring shows what feeds it and what it feeds",
                "warn"
            );
            return;
        }
        app.center_mode = "wiring";
        app.wire_sel = [0, 0, 0];
        app.wire_top = [0, 0, 0];
        app.wire_col = 1;
    } else {
        app.center_mode = "code";
    }
    app.focus = "code";
}

impl current_module_key(app: Studio) -> str {
    if app.focus == "nav" and 0 <= app.nav_sel < len(app.nav_rows) {
        key = app.nav_rows[app.nav_sel].key;
        return module_of_key(app, key);
    }
    if app.code_path {
        mod = app.model.module_for_file(app.code_path);
        if mod is not None {
            return mod.key;
        }
    }
    return app.wire_mod;
}

impl module_of_key(app: Studio, key: str) -> str {
    if key in app.model.modules {
        return key;
    }
    best = "";
    for mk in app.model.modules {
        if key.startswith(mk + ".") and len(mk) > len(best) {
            best = mk;
        }
    }
    return best;
}

impl rebuild_nav(app: Studio) {
    rows: list[NavRow] = [];
    with app.model.lock {
        walk_nav(app, "", 0, rows);
    }
    sel_key = app.nav_rows[app.nav_sel].key
        if 0 <= app.nav_sel < len(app.nav_rows)
        else "";
    app.nav_rows = rows;
    if sel_key {
        for (i, r) in enumerate(rows) {
            if r.key == sel_key {
                app.nav_sel = i;
                break;
            }
        }
    }
    app.nav_sel = min(app.nav_sel, max(0, len(rows) - 1));
    app.dirty = True;
}

impl walk_nav(app: Studio, key: str, depth: int, rows: list[NavRow]) {
    kids = app.model.children(key);
    pkgs = sorted(
        [
            k
            for k in kids
            if k.kind == "package"
        ],
        key=lambda (k: StNode) -> str { k.name }
    );
    mods = sorted(
        [
            k
            for k in kids
            if k.kind == "module"
        ],
        key=lambda (k: StNode) -> str { k.name }
    );
    syms = [
        k
        for k in kids
        if k.kind not in ["package", "module", "external", "rule"]
    ];
    for kid in pkgs + mods + syms {
        expandable = kid.kind in ["package", "module"]
            or len(app.model.children(kid.key)) > 0;
        open_ = kid.key in app.expanded;
        detail = "";
        if kid.kind == "module" and isinstance(kid, StModule) {
            if kid.error {
                detail = "!";
            } elif not kid.indexed {
                detail = "…";
            }
        }
        rows.append(
            NavRow(
                key=kid.key,
                label=kid.name,
                kind=kid.kind,
                depth=depth,
                expandable=expandable,
                expanded=open_,
                detail=detail
            )
        );
        if open_ {
            walk_nav(app, kid.key, depth + 1, rows);
        }
    }
}

impl nav_key(app: Studio, key: str) {
    n = len(app.nav_rows);
    if key in ["down", "j"] {
        app.nav_sel = min(n - 1, app.nav_sel + 1);
    } elif key in ["up", "k"] {
        app.nav_sel = max(0, app.nav_sel - 1);
    } elif key == "page_down" {
        app.nav_sel = min(n - 1, app.nav_sel + 15);
    } elif key == "page_up" {
        app.nav_sel = max(0, app.nav_sel - 15);
    } elif key in ["home", "g"] {
        app.nav_sel = 0;
    } elif key in ["end", "G"] {
        app.nav_sel = max(0, n - 1);
    } elif key in ["right", "l"] {
        if 0 <= app.nav_sel < n {
            row = app.nav_rows[app.nav_sel];
            if row.expandable and not row.expanded {
                ensure_indexed(app, row.key);
                app.expanded.add(row.key);
                rebuild_nav(app);
            } elif row.expanded and app.nav_sel + 1 < n {
                app.nav_sel += 1;
            }
        }
    } elif key in ["left", "h"] {
        if 0 <= app.nav_sel < n {
            row = app.nav_rows[app.nav_sel];
            if row.expanded {
                app.expanded.discard(row.key);
                rebuild_nav(app);
            } else {
                for i in range(app.nav_sel - 1, -1, -1) {
                    if app.nav_rows[i].depth < row.depth {
                        app.nav_sel = i;
                        break;
                    }
                }
            }
        }
    } elif key == "enter" {
        nav_activate(app);
    } elif key in [" ", "ctrl+space", "a"] {
        if 0 <= app.nav_sel < n {
            add_to_tray(app, app.nav_rows[app.nav_sel].key);
        }
    }
}

impl nav_activate(app: Studio) -> None {
    if not (0 <= app.nav_sel < len(app.nav_rows)) {
        return;
    }
    row = app.nav_rows[app.nav_sel];
    if row.kind == "package" {
        if row.key in app.expanded {
            app.expanded.discard(row.key);
        } else {
            app.expanded.add(row.key);
        }
        rebuild_nav(app);
        return;
    }
    open_key(app, row.key);
    if row.kind == "module" and row.key not in app.expanded {
        app.expanded.add(row.key);
        rebuild_nav(app);
    }
}

impl open_key(app: Studio, key: str, focus: bool = False) -> None {
    ensure_indexed(app, key);
    nd = app.model.node_for(key);
    if nd is None or not nd.file {
        app.say(f"{key} has no source", "warn");
        return;
    }
    load_code(app, nd.file);
    line = max(nd.line - 1, 0);
    goto_line(app, line);
    app.center_mode = "code";
    if isinstance(nd, StModule) {
        app.wire_mod = nd.key;
    }
    if focus {
        app.focus = "code";
    }
    reveal_in_nav(app, key);
}

impl reveal_in_nav(app: Studio, key: str) {
    parts = key.split(".");
    changed = False;
    for i in range(1, len(parts)) {
        prefix = ".".join(parts[:i]);
        if (
            prefix in app.model.packages
            or prefix in app.model.modules
            or prefix in app.model.symbols
        )
            and prefix not in app.expanded {
            app.expanded.add(prefix);
            changed = True;
        }
    }
    if changed {
        rebuild_nav(app);
    }
    for (i, r) in enumerate(app.nav_rows) {
        if r.key == key {
            app.nav_sel = i;
            break;
        }
    }
}

impl load_code(app: Studio, path: str, keep_pos: bool = False) -> None {
    fmod = app.model.module_for_file(path);
    if fmod is not None and not fmod.indexed {
        ensure_indexed(app, fmod.key);
    }
    try {
        with open(path, encoding="utf-8", errors="replace") as fh {
            text = fh.read();
        }
        app.code_mtime = os.path.getmtime(path);
    } except OSError as e {
        app.say(f"cannot open {path}: {e}", "error");
        return;
    }
    if path != app.code_path {
        keep_pos = False;
    }
    app.code_path = path;
    app.code_lines = text.split("\n");
    if not keep_pos {
        app.cur_line = 0;
        app.cur_col = 0;
        app.code_top = 0;
        app.code_left = 0;
    }
    clamp_cursor(app);
    if app.intel is not None {
        try {
            app.intel.invalidate(path);
            app.intel.request_check(path);
        } except Exception {}
    }
    app.hover = "";
}

impl goto_line(app: Studio, line: int) {
    app.cur_line = max(0, min(line, max(0, len(app.code_lines) - 1)));
    app.cur_col = 0;
    app.code_top = max(0, app.cur_line - max(app.code_h // 3, 1));
}

impl clamp_cursor(app: Studio) {
    n = len(app.code_lines);
    app.cur_line = max(0, min(app.cur_line, max(0, n - 1)));
    ln = app.code_lines[app.cur_line] if n else "";
    app.cur_col = max(0, min(app.cur_col, len(ln)));
    if app.cur_line < app.code_top {
        app.code_top = app.cur_line;
    }
    if app.cur_line >= app.code_top + app.code_h {
        app.code_top = app.cur_line - app.code_h + 1;
    }
    textw = app.code_w - gutter_width(app);
    if app.cur_col < app.code_left {
        app.code_left = app.cur_col;
    }
    if textw > 4 and app.cur_col >= app.code_left + textw - 1 {
        app.code_left = app.cur_col - textw + 2;
    }
}

impl gutter_width(app: Studio) -> int {
    return len(str(max(len(app.code_lines), 1))) + 3;
}

impl code_key(app: Studio, key: str) -> None {
    if not app.code_path {
        if key in ["enter", " "] {
            app.focus = "nav";
        }
        return;
    }
    if key in ["down", "j"] {
        app.cur_line += 1;
    } elif key in ["up", "k"] {
        app.cur_line -= 1;
    } elif key in ["left", "h"] {
        app.cur_col -= 1;
    } elif key in ["right", "l"] {
        app.cur_col += 1;
    } elif key == "page_down" {
        app.cur_line += app.code_h - 2;
        app.code_top += app.code_h - 2;
    } elif key == "page_up" {
        app.cur_line -= app.code_h - 2;
        app.code_top = max(0, app.code_top - app.code_h + 2);
    } elif key in ["home", "0"] {
        app.cur_col = 0;
    } elif key in ["end", "$"] {
        app.cur_col = len(app.code_lines[app.cur_line]) if app.code_lines else 0;
    } elif key == "g" {
        app.cur_line = 0;
    } elif key == "G" {
        app.cur_line = len(app.code_lines) - 1;
    } elif key in [" ", "ctrl+space", "a"] {
        sym = symbol_at_cursor(app);
        if sym is not None {
            add_to_tray(app, sym.key);
        } else {
            mod = app.model.module_for_file(app.code_path);
            if mod is not None {
                add_to_tray(app, mod.key);
            }
        }
    } elif key == "i" {
        jump_decl_impl(app);
    } elif key in ["enter", "f12", "d"] {
        goto_definition(app);
    } elif key in ["r", "ctrl+r"] {
        find_references(app);
    } elif key == "t" {
        app.show_inlays = not app.show_inlays;
        app.say("inferred types " + ("shown" if app.show_inlays else "hidden"));
    } elif key == "e" {
        jump_diagnostic(app);
    }
    clamp_cursor(app);
    update_hover(app);
}

impl symbols_in_file(app: Studio, path: str) -> list[StNode] {
    if path in app.file_syms {
        return app.file_syms[path];
    }
    found: list[StNode] = [];
    with app.model.lock {
        for s in app.model.symbols.values() {
            if s.file == path or (isinstance(s, StAbility) and s.impl_file == path) {
                found.append(s);
            }
        }
    }
    app.file_syms[path] = found;
    return found;
}

impl symbol_at_cursor(app: Studio) -> (StNode | None) {
    line = app.cur_line + 1;
    best: (StNode | None) = None;
    best_span = 10 ** 9;
    for s in symbols_in_file(app, app.code_path) {
        if isinstance(s, StImpl) {
            continue;
        }
        (lo, hi) = (s.line, max(s.end_line, s.line));
        if isinstance(s, StAbility)
            and s.impl_file == app.code_path
            and not (s.file == app.code_path and lo <= line <= hi) {
            (lo, hi) = (s.impl_line, max(s.impl_end_line, s.impl_line));
        }
        if lo <= line <= hi and (hi - lo) < best_span {
            best = s;
            best_span = hi - lo;
        }
    }
    return best;
}

impl word_at_cursor(app: Studio) -> str {
    if not app.code_lines {
        return "";
    }
    ln = app.code_lines[app.cur_line];
    i = min(app.cur_col, len(ln));
    lo = i;
    while lo > 0 and (ln[lo - 1].isalnum() or ln[lo - 1] == "_") {
        lo -= 1;
    }
    hi = i;
    while hi < len(ln) and (ln[hi].isalnum() or ln[hi] == "_") {
        hi += 1;
    }
    return ln[lo:hi];
}

impl jump_decl_impl(app: Studio) -> None {
    sym = symbol_at_cursor(app);
    if sym is None or not isinstance(sym, StAbility) or not sym.impl_file {
        app.say("No separate impl for the symbol here", "warn");
        return;
    }
    in_impl = sym.impl_file == app.code_path
        and sym.impl_line <= app.cur_line + 1 <= max(sym.impl_end_line, sym.impl_line);
    if in_impl {
        load_code(app, sym.file);
        goto_line(app, sym.line - 1);
        app.say(f"declaration of {sym.name}");
    } else {
        load_code(app, sym.impl_file);
        goto_line(app, sym.impl_line - 1);
        app.say(f"impl of {sym.name}  ({os.path.basename(sym.impl_file)})");
    }
}

impl goto_definition(app: Studio) -> None {
    if app.intel is not None {
        try {
            t = app.intel.request_definition(
                app.code_path, app.cur_line + 1, app.cur_col
            );
            app.tickets[t] = "definition";
            app.say("finding definition…");
            return;
        } except Exception {}
    }
    word = word_at_cursor(app);
    if not word {
        return;
    }
    hits = [
        h
        for h in app.model.search(word, limit=20)
        if h.name == word
    ];
    if not hits {
        app.say(f"no definition found for {word}", "warn");
        return;
    }
    if len(hits) == 1 {
        open_key(app, hits[0].key);
        return;
    }
    open_picker(app, "goto", f"Definitions of {word}", word);
}

impl find_references(app: Studio) -> None {
    if app.intel is not None {
        try {
            t = app.intel.request_references(
                app.code_path, app.cur_line + 1, app.cur_col
            );
            app.tickets[t] = "references";
            app.say("finding references…");
            return;
        } except Exception {}
    }
    word = word_at_cursor(app);
    if not word {
        return;
    }
    items: list[PickItem] = [];
    for mod in list(app.model.modules.values()) {
        for f in mod.files {
            try {
                with open(f, encoding="utf-8", errors="replace") as fh {
                    for (i, ln) in enumerate(fh) {
                        if word in ln {
                            items.append(
                                PickItem(
                                    key=f"{f}:{i + 1}",
                                    label=f"{os.path.relpath(f, app.root_dir)}:{i + 1}",
                                    detail=ln.strip()[:80],
                                    kind="ref",
                                    data=(f, i)
                                )
                            );
                        }
                    }
                }
            } except OSError {}
        }
        if len(items) > 400 {
            break;
        }
    }
    show_locations(app, f"Text matches of {word}", items);
}

impl show_locations(app: Studio, title: str, items: list[PickItem]) -> None {
    if not items {
        app.say(f"{title}: none", "warn");
        return;
    }
    open_picker(app, "locations", title, "");
    app.picker_items = items;
    app.picker_sel = 0;
    app.loc_items = items;
}

impl jump_diagnostic(app: Studio) -> None {
    if app.intel is None {
        app.say("diagnostics need the code intelligence service", "warn");
        return;
    }
    diags = sorted(
        app.intel.diagnostics(app.code_path),
        key=lambda (d: any) -> tuple[int, int] { (d.line, d.col) }
    );
    for d in diags {
        if d.line - 1 > app.cur_line {
            goto_line(app, d.line - 1);
            app.cur_col = max(d.col, 0);
            return;
        }
    }
    if diags {
        goto_line(app, diags[0].line - 1);
        app.cur_col = max(diags[0].col, 0);
    } else {
        st = app.intel.status(app.code_path);
        app.say(
            "no diagnostics in this file" if st == "ready" else f"checking… ({st})",
            "ok"
        );
    }
}

impl update_hover(app: Studio) -> None {
    sym = symbol_at_cursor(app);
    if sym is None {
        app.hover = "";
    } else {
        sig = getattr(sym, "signature", "") or getattr(sym, "type_str", "");
        app.hover = f"{sym.kind} {sym.key}  {sig}".strip();
    }
    if app.intel is not None {
        app.hover_due = time.time() + 0.35;
    }
}

impl wire_columns(app: Studio) -> list[list[PickItem]] {
    m = app.model;
    key = app.wire_mod;
    provs: list[PickItem] = [];
    for w in m.providers(key) {
        names = ", ".join(w.names) if w.names else "(whole module)";
        scope = f" → {w.scope}" if w.scope else "";
        provs.append(
            PickItem(
                key=w.provider,
                label=w.provider,
                detail=names + scope,
                kind="wire",
                data=w
            )
        );
    }
    mids: list[PickItem] = [];
    mod = m.modules.get(key);
    if mod is not None {
        mids.append(PickItem(key=key, label=key, detail=mod.kind, kind="module"));
        for r in m.rules_for(key) {
            mids.append(
                PickItem(
                    key=r.key,
                    label=f"rule {r.name}",
                    detail=" | ".join(r.sources) + " → " + " | ".join(r.targets),
                    kind="rule"
                )
            );
        }
        with m.lock {
            for s in m.children(key) {
                sig = getattr(s, "signature", "") or "";
                mids.append(PickItem(key=s.key, label=s.name, detail=sig, kind=s.kind));
            }
        }
    }
    cons: list[PickItem] = [];
    for w in m.consumers(key) {
        names = ", ".join(w.names) if w.names else "(whole module)";
        scope = f" → {w.scope}" if w.scope else "";
        cons.append(
            PickItem(
                key=w.consumer,
                label=w.consumer + scope,
                detail=names,
                kind="wire",
                data=w
            )
        );
    }
    return [provs, mids, cons];
}

impl wire_key(app: Studio, key: str) -> None {
    cols = wire_columns(app);
    c = app.wire_col;
    n = len(cols[c]);
    if key in ["left", "h"] {
        app.wire_col = max(0, c - 1);
    } elif key in ["right", "l"] {
        app.wire_col = min(2, c + 1);
    } elif key in ["down", "j"] {
        app.wire_sel[c] = min(max(n - 1, 0), app.wire_sel[c] + 1);
    } elif key in ["up", "k"] {
        app.wire_sel[c] = max(0, app.wire_sel[c] - 1);
    } elif key == "enter" {
        if n == 0 {
            return;
        }
        item = cols[c][app.wire_sel[c]];
        if c in [0, 2] {
            target = item.key;
            if target in app.model.modules
                and app.model.modules[target].kind == "module" {
                app.wire_mod = target;
                app.wire_sel = [0, 0, 0];
                app.wire_top = [0, 0, 0];
                app.wire_col = 1;
                reveal_in_nav(app, target);
            } else {
                app.say(f"{target} is outside the project", "warn");
            }
        } elif item.kind == "rule" {
            nd = None;
            for r in app.model.rules {
                if r.key == item.key {
                    nd = r;
                }
            }
            if nd is not None {
                load_code(app, nd.file);
                app.center_mode = "code";
                app.say(f"rule {nd.name} lives in {os.path.basename(nd.file)}");
            }
        } else {
            open_key(app, item.key);
        }
    } elif key in [" ", "ctrl+space", "a"] {
        if n == 0 {
            return;
        }
        item = cols[c][app.wire_sel[c]];
        if c in [0, 2] and item.data is not None {
            w = item.data;
            add_to_tray(app, wire_ref(w));
        } else {
            add_to_tray(app, item.key);
        }
    } elif key == "A" {
        added = 0;
        for item in cols[c] {
            k = item.key;
            if c in [0, 2] and item.data is not None {
                k = wire_ref(item.data);
            }
            if k not in app.tray {
                app.tray.append(k);
                added += 1;
            }
        }
        app.say(f"+ {added} items from this column added to the context", "ok");
    } elif key == "o" {
        open_key(app, app.wire_mod);
    } elif key == "escape" {
        app.center_mode = "code";
    }
}

impl chat_key(app: Studio, key: str) {
    n = len(app.chat);
    if key in ["up", "k", "down", "j"] {
        if app.chat_sel < 0 or app.chat_sel >= n {
            app.chat_sel = n - 1;
        } elif key in ["up", "k"] {
            app.chat_sel = max(0, app.chat_sel - 1);
        } else {
            app.chat_sel = min(n - 1, app.chat_sel + 1);
        }
        app.chat_follow = app.chat_sel == n - 1;
        if 0 <= app.chat_sel < len(app.chat_starts) {
            at = app.chat_starts[app.chat_sel];
            if at < app.chat_top {
                app.chat_top = at;
            } elif at >= app.chat_top + app.chat_h - 2 {
                app.chat_top = max(0, at - app.chat_h + 4);
            }
        }
    } elif key == "page_up" {
        app.chat_follow = False;
        app.chat_top = max(0, app.chat_top - app.chat_h + 2);
    } elif key == "page_down" {
        app.chat_top += app.chat_h - 2;
    } elif key in ["end", "G"] {
        app.chat_follow = True;
        app.chat_sel = n - 1;
    } elif key in ["home", "g"] {
        app.chat_follow = False;
        app.chat_top = 0;
        app.chat_sel = 0 if n else -1;
    } elif key in ["enter", "space", " ", "o"] and 0 <= app.chat_sel < n {
        e = app.chat[app.chat_sel];
        if e.role == "plan" {
            open_plan_links(app);
        } elif e.role == "tool" and key == "o" and e.locs {
            open_locations(app, e.locs, e.title or "Tool locations");
        } elif e.role == "tool" and key == "o" {
            app.say("this tool call names no files", "warn");
        } elif e.role == "tool" {
            if app.chat_sel in app.chat_open {
                app.chat_open.discard(app.chat_sel);
            } else {
                app.chat_open.add(app.chat_sel);
            }
        }
    }
}

impl tray_key(app: Studio, key: str) {
    n = len(app.tray);
    if key in ["down", "j"] {
        app.tray_sel = min(max(n - 1, 0), app.tray_sel + 1);
    } elif key in ["up", "k"] {
        app.tray_sel = max(0, app.tray_sel - 1);
    } elif key in ["delete", "backspace", "x", "d"] {
        if 0 <= app.tray_sel < n {
            gone = app.tray.pop(app.tray_sel);
            app.tray_sel = min(app.tray_sel, max(0, len(app.tray) - 1));
            app.say(f"removed {gone} from context");
        }
    } elif key == "enter" {
        if 0 <= app.tray_sel < n {
            k = app.tray[app.tray_sel];
            pair = parse_deps_key(k);
            if k.startswith(MAP_PREFIX) {
                (scope_, spec_) = split_spec(k[len(MAP_PREFIX):]);
                open_map(app, scope_, inside=True);
                if spec_ {
                    apply_spec(app, spec_);
                    set_map_scope(app, scope_);
                }
            } elif pair is not None {
                (a, b) = (pair[0].split("."), pair[1].split("."));
                n = 0;
                while n < min(len(a), len(b)) and a[n] == b[n] {
                    n += 1;
                }
                open_map(app, "");
                apply_spec(app, split_spec(k)[1]);
                set_map_scope(app, ".".join(a[:n]), pair[0]);
                open_wire_list(app, pair[0], pair[1]);
            } elif not k.startswith("wire:") {
                open_key(app, k, focus=True);
            }
        }
    } elif key == "C" {
        app.tray = [];
        app.tray_sel = 0;
        app.say("context cleared");
    }
}

impl add_to_tray(app: Studio, key: str) -> None {
    if key in app.tray {
        app.say(f"{key} is already in the context", "info");
        return;
    }
    app.tray.append(key);
    app.tray_sel = len(app.tray) - 1;
    app.say(f"+ {key} added to the context", "ok");
}

impl prompt_insert(app: Studio, text: str) -> None {
    if text == "@"
        and (app.caret == 0 or app.draft[app.caret - 1:app.caret] in [" ", "\n"]) {
        open_picker(app, "tray", "Add to context", "");
        return;
    }
    app.draft = app.draft[:app.caret] + text + app.draft[app.caret:];
    app.caret += len(text);
}

impl prompt_key(app: Studio, key: str) {
    if key == "enter" {
        submit(app);
    } elif key in ["alt+\r", "alt+enter", "ctrl+j"] {
        prompt_insert(app, "\n");
    } elif key == "backspace" {
        if app.caret > 0 {
            app.draft = app.draft[:app.caret - 1] + app.draft[app.caret:];
            app.caret -= 1;
        }
    } elif key == "delete" {
        app.draft = app.draft[:app.caret] + app.draft[app.caret + 1:];
    } elif key == "left" {
        app.caret = max(0, app.caret - 1);
    } elif key == "right" {
        app.caret = min(len(app.draft), app.caret + 1);
    } elif key in ["home", "ctrl+a"] {
        app.caret = app.draft.rfind("\n", 0, app.caret) + 1;
    } elif key in ["end", "ctrl+e"] {
        nl = app.draft.find("\n", app.caret);
        app.caret = len(app.draft) if nl < 0 else nl;
    } elif key == "ctrl+u" {
        app.draft = "";
        app.caret = 0;
    } elif key == "ctrl+k" {
        nl = app.draft.find("\n", app.caret);
        app.draft = app.draft[:app.caret] + (app.draft[nl:] if nl >= 0 else "");
    } elif key == "ctrl+w" {
        i = app.caret;
        while i > 0 and app.draft[i - 1] == " " {
            i -= 1;
        }
        while i > 0 and app.draft[i - 1] not in [" ", "\n"] {
            i -= 1;
        }
        app.draft = app.draft[:i] + app.draft[app.caret:];
        app.caret = i;
    } elif key == "up" {
        if app.history and "\n" not in app.draft {
            app.hist_i = len(app.history) - 1
                if app.hist_i < 0
                else max(0, app.hist_i - 1);
            app.draft = app.history[app.hist_i];
            app.caret = len(app.draft);
        }
    } elif key == "down" {
        if app.hist_i >= 0 {
            app.hist_i += 1;
            if app.hist_i >= len(app.history) {
                app.hist_i = -1;
                app.draft = "";
            } else {
                app.draft = app.history[app.hist_i];
            }
            app.caret = len(app.draft);
        }
    } elif key == "escape" {
        app.focus = "nav";
    }
}

impl submit(app: Studio) -> None {
    text = app.draft.strip();
    if not text {
        return;
    }
    app.history.append(text);
    app.hist_i = -1;
    app.draft = "";
    app.caret = 0;
    if text.startswith("/") {
        run_slash(app, text);
        return;
    }
    send_to_agent(app, text);
}

impl run_slash(app: Studio, text: str) {
    parts = text[1:].split(" ", 1);
    verb = parts[0].lower();
    rest = parts[1] if len(parts) > 1 else "";
    if verb in app.verbs {
        send_to_agent(app, (app.verbs[verb] + " " + rest).strip());
    } elif verb in ["help", "?"] {
        open_help(app);
    } elif verb == "clear" {
        app.chat = [];
        app.chat_top = 0;
    } elif verb == "agent" {
        open_agent_picker(app);
    } elif verb == "quit" {
        app.running = False;
    } else {
        app.say(
            f"unknown command /{verb}; try "
                + " ".join(["/" + v for v in app.verbs])
                + " /agent /clear",
            "warn"
        );
    }
}

impl send_to_agent(app: Studio, text: str) {
    app.chat.append(
        ChatEntry(role="user", text=text, detail=", ".join(app.tray), time=time.time())
    );
    app.chat_follow = True;
    app.msg_open = "";
    if app.rec is None {
        app.rec = new_session(app.root_dir, agent=app.agent_name, title=text[:60]);
        app.session_id = app.rec.id;
    }
    app.rec.add("user", text);
    app.rec.tray = list(app.tray);
    blocks: list[dict[str, any]] = [];
    if app.tray {
        try {
            blocks = context_blocks(app.model, app.tray);
        } except Exception as e {
            app.chat.append(
                ChatEntry(role="error", text=f"could not build the context: {e}")
            );
        }
        blocks.insert(
            0,
            {
                "type": "text",
                "text": "I selected these items in jac hack (a compiler-backed view of this Jac project); my request follows them."
            }
        );
    }
    blocks.append({"type": "text", "text": text});
    if app.agent is not None and app.agent_state == "ready" {
        deliver(app, blocks);
        app.agent_state = "busy";
        app.turn_started = time.time();
        return;
    }
    if app.agent_state == "busy" {
        app.say(
            "the agent is still working; your message will follow its turn", "warn"
        );
    }
    app.queued.append({"blocks": blocks});
    start_agent(app);
}

impl cancel_turn(app: Studio) {
    if app.agent is not None {
        try {
            app.agent.cancel();
        } except Exception {}
    }
    app.queued = [];
    app.say("cancelling the agent's turn…", "warn");
}

impl open_agent_picker(app: Studio) {
    reg = ensure_registry(app);
    items: list[PickItem] = [];
    for name in reg.names() {
        spec = reg.get(name);
        if spec is None {
            continue;
        }
        ok = spec.runnable();
        detail = ("ready" if ok else spec.reason())
            + ("  (current)" if name == app.agent_name else "");
        items.append(
            PickItem(
                key=name,
                label=f"{name}  {spec.title}",
                detail=detail,
                kind="walker" if ok else "external"
            )
        );
    }
    app.agent_items = items;
    open_picker(app, "agents", "Choose the agent", "");
}

impl open_sheet(
    app: Studio, kind: str, width: int, height: int, anchor: OverlayAnchor
) {
    close_sheet(app);
    sh = Sheet(key=f"sheet-{kind}", sheet=kind);
    append_child_session(app.sess, app.screen, sh);
    open_modal_overlay(app.sess, app.screen, sh, initial_focus=sh, z_index=20);
    set_node_contract(
        app.r,
        sh,
        LayoutSpec(
            width=fixed_axis(float(width)),
            height=fixed_axis(float(height)),
            overlay_anchor=anchor
        )
    );
    app.sheet = sh;
    app.sheet_kind = kind;
    app.sheet_scroll = 0;
    app.dirty = True;
}

impl close_sheet(app: Studio) -> None {
    sh = app.sheet;
    if sh is None {
        return;
    }
    app.sheet = None;
    app.sheet_kind = "";
    detach_node(app.r, sh);
    try {
        close_overlay(app.sess, sh);
    } except Exception {}
    app.dirty = True;
}

impl screen_size(app: Studio) -> tuple[int, int] {
    return (app.r.layout.viewport.columns, app.r.layout.viewport.rows);
}

impl open_picker(app: Studio, purpose: str, title: str, query: str) {
    (cols, rows) = screen_size(app);
    w = min(max(60, cols * 2 // 3), cols - 4);
    h = min(24, rows - 4);
    open_sheet(app, "picker", w, h, OverlayAnchor.TOP);
    app.picker_purpose = purpose;
    app.picker_title = title;
    app.picker_query = query;
    app.picker_sel = 0;
    refresh_picker(app);
}

impl refresh_picker(app: Studio) {
    if app.picker_purpose == "locations" {
        base = app.loc_items;
        q = app.picker_query.lower();
        app.picker_items = [
            i
            for i in base
            if q in i.label.lower() or q in i.detail.lower()
        ];
    } elif app.picker_purpose == "palette" {
        q = app.picker_query.lower();
        app.picker_items = [
            i
            for i in palette_items(app)
            if q in i.label.lower()
        ];
    } elif app.picker_purpose == "agents" {
        app.picker_items = app.agent_items;
    } elif app.picker_purpose == "wires" {
        q = app.picker_query.lower();
        app.picker_items = [
            i
            for i in app.wire_items
            if q in i.label.lower() or q in i.detail.lower()
        ];
    } else {
        hits = app.model.search(app.picker_query, limit=200);
        app.picker_items = [
            PickItem(
                key=h.key,
                label=h.key,
                detail=getattr(h, "signature", "")
                    or (os.path.relpath(h.file, app.root_dir) if h.file else ""),
                kind=h.kind
            ) for h in hits
        ];
    }
    app.picker_sel = min(app.picker_sel, max(0, len(app.picker_items) - 1));
}

impl palette_items(app: Studio) -> list[PickItem] {
    extra = [
        PickItem(key=v, label=f"Ask: {v}   /{v}")
        for v in app.verbs
        if v not in ["explain", "tests", "refactor", "review"]
    ];
    return extra
        + [
            PickItem(key="goto", label="Go to symbol or module   Ctrl+P"),
            PickItem(key="wiring", label="Toggle code / wiring view   Ctrl+T"),
            PickItem(key="map", label="Architecture map   m"),
            PickItem(key="tour", label="Architecture tour of the codebase"),
            PickItem(key="diff", label="Architecture changes since the main branch"),
            PickItem(key="agent", label="Choose agent   /agent"),
            PickItem(key="explain", label="Ask: explain the context   /explain"),
            PickItem(key="tests", label="Ask: write tests   /tests"),
            PickItem(key="refactor", label="Ask: refactor   /refactor"),
            PickItem(key="review", label="Ask: review   /review"),
            PickItem(key="clear-tray", label="Clear the context tray"),
            PickItem(key="clear-chat", label="Clear the transcript   /clear"),
            PickItem(key="reindex", label="Re-index the project"),
            PickItem(key="plan-links", label="Go to the code linked to the plan"),
            PickItem(key="changed", label="Go to symbols changed this session"),
            PickItem(key="reset-layout", label="Reset the pane sizes"),
            PickItem(key="help", label="Keys and help   F1"),
            PickItem(key="quit", label="Quit   Ctrl+Q")
        ];
}

impl open_palette(app: Studio) {
    open_picker(app, "palette", "Command palette", "");
}

impl run_palette(app: Studio, key: str) {
    if key == "goto" {
        open_picker(app, "goto", "Go to symbol or module", "");
    } elif key == "wiring" {
        toggle_center(app);
    } elif key == "map" {
        open_map(app, map_target(app));
    } elif key in ["tour", "diff"] {
        start_doc(app, key);
    } elif key == "agent" {
        open_agent_picker(app);
    } elif key in app.verbs {
        send_to_agent(app, app.verbs[key]);
    } elif key == "clear-tray" {
        app.tray = [];
    } elif key == "clear-chat" {
        app.chat = [];
    } elif key == "reindex" {
        if not app.indexing {
            start_indexing(app);
        }
    } elif key == "plan-links" {
        open_plan_links(app);
    } elif key == "changed" {
        open_changed(app);
    } elif key == "reset-layout" {
        app.nav_w = 34;
        app.side_w = 0;
        app.install_layout();
    } elif key == "help" {
        open_help(app);
    } elif key == "quit" {
        app.running = False;
    }
}

impl sheet_text(app: Studio, ch: str) -> None {
    if app.sheet_kind == "picker" {
        if ord(ch) >= 32 {
            app.picker_query += ch;
            app.picker_sel = 0;
            refresh_picker(app);
        }
        return;
    }
    sheet_key(app, ch);
}

impl sheet_key(app: Studio, key: str) -> None {
    kind = app.sheet_kind;
    if kind == "picker" {
        n = len(app.picker_items);
        if key == "escape" {
            close_sheet(app);
        } elif key in ["down", "ctrl+n"] {
            app.picker_sel = min(max(n - 1, 0), app.picker_sel + 1);
        } elif key in ["up", "ctrl+p"] {
            app.picker_sel = max(0, app.picker_sel - 1);
        } elif key == "page_down" {
            app.picker_sel = min(max(n - 1, 0), app.picker_sel + 10);
        } elif key == "page_up" {
            app.picker_sel = max(0, app.picker_sel - 10);
        } elif key == "backspace" {
            app.picker_query = app.picker_query[:-1];
            app.picker_sel = 0;
            refresh_picker(app);
        } elif key == "ctrl+u" {
            app.picker_query = "";
            refresh_picker(app);
        } elif key in ["enter", "tab"] {
            if 0 <= app.picker_sel < n {
                pick(app, app.picker_items[app.picker_sel], key == "tab");
            } else {
                close_sheet(app);
            }
        }
        return;
    }
    if kind == "help" {
        if key in ["escape", "q", "f1", "?", "enter"] {
            close_sheet(app);
        } elif key in ["down", "j"] {
            app.sheet_scroll += 1;
        } elif key in ["up", "k"] {
            app.sheet_scroll = max(0, app.sheet_scroll - 1);
        }
        return;
    }
    if kind == "approval" {
        approval_key(app, key);
        return;
    }
    if kind == "doc" {
        page = 20;
        if key in ["escape", "q"] {
            close_sheet(app);
        } elif key in ["down", "j"] {
            app.sheet_scroll = min(
                app.sheet_scroll + 1, max(0, len(app.sheet_lines) - 3)
            );
        } elif key in ["up", "k"] {
            app.sheet_scroll = max(0, app.sheet_scroll - 1);
        } elif key in ["page_down", " "] {
            app.sheet_scroll = min(
                app.sheet_scroll + page, max(0, len(app.sheet_lines) - 3)
            );
        } elif key == "page_up" {
            app.sheet_scroll = max(0, app.sheet_scroll - page);
        }
        return;
    }
    if key == "escape" {
        close_sheet(app);
    }
}

impl pick(app: Studio, item: PickItem, alt: bool) {
    purpose = app.picker_purpose;
    close_sheet(app);
    if purpose == "goto" {
        if alt {
            add_to_tray(app, item.key);
        } else {
            open_key(app, item.key, focus=True);
        }
    } elif purpose == "tray" {
        add_to_tray(app, item.key);
        app.focus = "prompt";
    } elif purpose == "locations" {
        (f, line) = item.data;
        load_code(app, f);
        goto_line(app, line);
        app.center_mode = "code";
        app.focus = "code";
    } elif purpose == "palette" {
        run_palette(app, item.key);
    } elif purpose == "agents" {
        choose_agent(app, item.key);
    } elif purpose == "wires" {
        w = item.data;
        if alt {
            add_to_tray(app, wire_ref(w));
        } elif w.consumer in app.model.modules
            and app.model.modules[w.consumer].kind == "module" {
            app.wire_mod = w.consumer;
            app.center_mode = "wiring";
            app.wire_sel = [0, 0, 0];
            app.wire_top = [0, 0, 0];
            app.wire_col = 0;
            for (i, pw) in enumerate(app.model.providers(w.consumer)) {
                if pw is w {
                    app.wire_sel[0] = i;
                }
            }
            app.focus = "code";
        }
    }
}

impl choose_agent(app: Studio, name: str) {
    reg = ensure_registry(app);
    spec = reg.get(name);
    if spec is None {
        return;
    }
    if not spec.runnable() {
        app.say(f"{name} is not available: {spec.reason()}", "error", 6.0);
        return;
    }
    if name == app.agent_name and app.agent is not None {
        return;
    }
    stop_agent(app);
    app.agent_name = name;
    app.say(f"agent set to {name}; it starts with your next message", "ok");
}

impl open_help(app: Studio) {
    (cols, rows) = screen_size(app);
    open_sheet(
        app,
        "help",
        min(84, cols - 4),
        min(len(HELP_TEXT) + 4, rows - 2),
        OverlayAnchor.CENTER
    );
}

impl approval_key(app: Studio, key: str) {
    if not app.pending {
        close_sheet(app);
        return;
    }
    req = app.pending[0];
    if key in ["down", "j"] {
        app.sheet_scroll += 1;
        return;
    }
    if key in ["up", "k"] {
        app.sheet_scroll = max(0, app.sheet_scroll - 1);
        return;
    }
    if key == "page_down" {
        app.sheet_scroll += 15;
        return;
    }
    if key == "page_up" {
        app.sheet_scroll = max(0, app.sheet_scroll - 15);
        return;
    }
    if req["type"] == "permission" {
        options = req["data"].get("options") or [];
        chosen: (str | None) = None;
        decided = False;
        if key.isdigit() and 1 <= int(key) <= len(options) {
            chosen = options[int(key) - 1].get("optionId");
            decided = True;
        } elif key in ["a", "y", "enter"] {
            chosen = first_option(options, ["allow_once", "allow_always"]);
            decided = True;
        } elif key in ["r", "n"] {
            chosen = first_option(options, ["reject_once", "reject_always"]);
            decided = True;
        } elif key == "escape" {
            chosen = None;
            decided = True;
        }
        if decided {
            finish_permission(app, req, chosen);
        }
        return;
    }
    if req["type"] == "write" {
        rv = req.get("review");
        checking = app.gate is not None and not req.get("done");
        if checking and (key in ["a", "A", "y", "enter"] or key.isdigit()) {
            app.say(
                "The compiler is still checking this edit. Wait for its verdict, or press r to reject it.",
                "warn",
                6.0
            );
            return;
        }
        leaves = leaf_changes(rv.symbol_changes) if rv is not None else [];
        if key.isdigit() and 1 <= int(key) <= min(len(leaves), 9) and len(leaves) > 1 {
            held = req.get("keep");
            keep: set[str] = set(held)
                if held is not None
                else set([lc.key for lc in leaves]);
            k = leaves[int(key) - 1].key;
            group = change_groups(rv.symbol_changes).get(k, [k])
                if rv is not None
                else [k];
            if k in keep {
                keep.difference_update(group);
            } else {
                keep.update(group);
            }
            if len(group) > 1 {
                app.say(
                    f"{len(group)} changes share lines ({', '.join(
                        group
                    )}), so they are kept or dropped together"
                );
            }
            req["keep"] = keep;
            req.pop("partial", None);
            at = app.sheet_scroll;
            open_approval(app);
            app.sheet_scroll = at;
            return;
        }
        if key in ["a", "y", "enter"]
            and rv is not None
            and rv.arch_changes
            and not req.get("arch_ok") {
            app.say(
                "This edit changes the architecture (the ⚖ lines). Press A to approve that change and accept the edit.",
                "warn",
                8.0
            );
            return;
        }
        if key == "A" and rv is not None and rv.arch_changes {
            req["arch_ok"] = True;
            key = "a";
        }
        if key in ["a", "y", "enter"] {
            keep_now = req.get("keep");
            if rv is not None
                and keep_now is not None
                and len(keep_now) < len(leaves) {
                part = req.get("partial");
                if part is None or part["keep"] != frozenset(keep_now) {
                    start_partial_review(app, req, keep_now);
                    return;
                }
                if not part["done"] {
                    app.say("Still checking the selected changes…");
                    return;
                }
                finish_partial(app, req, keep_now);
            } else {
                finish_write(app, req, True, "");
            }
        } elif key in ["r", "n", "escape"] {
            finish_write(app, req, False, "The user rejected this edit in jac hack.");
        } elif key == "f" {
            finish_write(app, req, False, write_feedback(req));
        }
    }
}

impl paint(app: Studio) {
    (cols, rows) = app.term.size();
    if cols != app.r.layout.viewport.columns or rows != app.r.layout.viewport.rows {
        app.r.layout.viewport.columns = cols;
        app.r.layout.viewport.rows = rows;
    }
    marks: list[tuple[str, float]] = [("start", time.perf_counter())];
    relayout(app.r, app.screen);
    marks.append(("layout", time.perf_counter()));
    paint_header(app);
    paint_nav(app);
    marks.append(("nav", time.perf_counter()));
    if app.center_mode == "code" {
        paint_code(app);
    } elif app.center_mode == "map" {
        paint_map(app);
    } else {
        paint_wiring(app);
    }
    marks.append(("center", time.perf_counter()));
    paint_chat(app);
    marks.append(("chat", time.perf_counter()));
    paint_tray(app);
    paint_prompt(app);
    paint_status(app);
    if app.sheet is not None {
        paint_sheet(app);
    }
    marks.append(("rest", time.perf_counter()));
    render_frame(app.r, app.screen, app.term);
    marks.append(("render", time.perf_counter()));
    if TRACE and marks[-1][1] - marks[0][1] > 0.15 {
        parts = [
            f"{marks[i][0]} {marks[i][1] - marks[i - 1][1]:.2f}"
            for i in range(1, len(marks))
        ];
        sys.stderr.write("  paint: " + " ".join(parts) + "\n");
    }
}

impl pane_rect(app: Studio, n: any) -> tuple[int, int] {
    rect = rect_of(app.r.layout, n);
    if rect is None {
        return (0, 0);
    }
    return (rect.width, rect.height);
}

impl title_row(
    app: Studio, text: str, focused: bool, width: int, right: str = ""
) -> list[TextSpan] {
    a = THEME.title_focus if focused else THEME.title;
    spans = [sp(" " + text + " ", a)];
    used = display_width(" " + text + " ");
    if right {
        pad = width - used - display_width(right) - 1;
        if pad > 0 {
            spans.append(sp(" " * pad, a));
            spans.append(sp(right + " ", a));
        }
    }
    return fit(spans, width, a);
}

impl paint_header(app: Studio) -> None {
    (w, h) = pane_rect(app, app.header);
    if w <= 0 {
        return;
    }
    st_ = app.model.stats() if not app.indexing else {};
    proj = os.path.basename(app.root_dir);
    mods = len(
        [
            m
            for m in app.model.modules.values()
            if m.kind == "module"
        ]
    );
    agent = app.agent_name or "no agent";
    spans = [
        sp(" ◆ jac hack ", THEME.header),
        sp("│ ", THEME.header_dim),
        sp(proj + " ", THEME.header),
        sp(f"│ {mods} modules · {len(app.model.wires)} wires ", THEME.header_dim),
        sp(f"│ agent: {agent} ({app.agent_state}) ", THEME.header_dim)
    ];
    if app.session_id {
        spans.append(sp(f"│ session {app.session_id[:8]} ", THEME.header_dim));
    }
    set_node_spans(app.r, app.header, [fit(spans, w, THEME.header)]);
}

impl paint_nav(app: Studio) -> None {
    (w, h) = pane_rect(app, app.nav);
    if w <= 0 or h <= 0 {
        return;
    }
    focused = app.focus == "nav";
    right = "";
    if app.indexing {
        right = f"{SPIN[app.spin % len(SPIN)]} {app.index_done}/{app.index_total}";
    }
    out: list[list[TextSpan]] = [title_row(app, "NAVIGATOR", focused, w, right)];
    body_h = h - 1;
    if app.nav_sel < app.nav_top {
        app.nav_top = app.nav_sel;
    }
    if app.nav_sel >= app.nav_top + body_h {
        app.nav_top = app.nav_sel - body_h + 1;
    }
    if not app.nav_rows and app.indexing {
        out.append(plain("  indexing the project…", w, THEME.dim));
    }
    for i in range(app.nav_top, min(len(app.nav_rows), app.nav_top + body_h)) {
        row = app.nav_rows[i];
        sel = i == app.nav_sel;
        arrow = "  ";
        if row.expandable {
            arrow = "▾ " if row.expanded else "▸ ";
        }
        spans = [
            sp(" " + "  " * row.depth + arrow, THEME.faint),
            sp(kind_icon(row.kind) + " ", kind_attrs(row.kind)),
            sp(row.label, THEME.text if row.kind != "has" else THEME.dim)
        ];
        if row.detail {
            spans.append(sp(" " + row.detail, THEME.warn));
        }
        if row.key in app.changed {
            spans.append(
                sp(
                    " ●",
                    StyleAttrs(
                        fg={"added": 114, "removed": 203}.get(app.changed[row.key], 179)
                    )
                )
            );
        }
        line = fit(spans, w, None);
        if sel {
            line = restyle(line, C_SEL_FOCUS if focused else C_SEL);
        }
        out.append(line);
    }
    while len(out) < h {
        out.append(blank(w));
    }
    set_node_spans(app.r, app.nav, out[:h], THEME.pane);
}

impl code_line_spans(
    app: Studio, idx: int, text: str, styles: (list[list[any]] | None)
) -> list[TextSpan] {
    if styles is None or idx >= len(styles) or not styles[idx] {
        return [sp(text, THEME.text)];
    }
    spans: list[TextSpan] = [];
    pos = 0;
    for s in sorted(styles[idx], key=lambda (x: any) -> int { x.start }) {
        (a, b) = (max(s.start, pos), min(s.end, len(text)));
        if a > pos {
            spans.append(sp(text[pos:a], THEME.text));
        }
        if b > a {
            spans.append(sp(text[a:b], style_for(s.style)));
            pos = b;
        }
    }
    if pos < len(text) {
        spans.append(sp(text[pos:], THEME.text));
    }
    return spans;
}

impl slice_spans(spans: list[TextSpan], left: int) -> list[TextSpan] {
    if left <= 0 {
        return spans;
    }
    out: list[TextSpan] = [];
    skipn = left;
    for s in spans {
        if skipn <= 0 {
            out.append(s);
        } elif len(s.text) <= skipn {
            skipn -= len(s.text);
        } else {
            out.append(sp(s.text[skipn:], s.attrs));
            skipn = 0;
        }
    }
    return out;
}

impl paint_code(app: Studio) -> None {
    (w, h) = pane_rect(app, app.center);
    if w <= 0 or h <= 0 {
        return;
    }
    focused = app.focus == "code";
    app.code_h = max(h - 1, 1);
    app.code_w = w;
    if not app.code_path {
        out = [title_row(app, "CODE", focused, w)];
        tips = [
            "",
            "  Pick something in the navigator (Enter), or press Ctrl+P to find any",
            "  module or symbol. Ctrl+T shows how a module is wired: what feeds it",
            "  and what it feeds. m opens the architecture map: the wiring between",
            "  packages, a level at a time.",
            "",
            "  Select code (Space) to put it in the context, then tell an agent what",
            "  to do with it in the prompt below."
        ];
        for t in tips {
            out.append(plain(t, w, THEME.dim));
        }
        while len(out) < h {
            out.append(blank(w));
        }
        set_node_spans(app.r, app.center, out[:h], THEME.pane);
        return;
    }
    rel = os.path.relpath(app.code_path, app.root_dir);
    sym = symbol_at_cursor(app);
    status = "";
    diags: list[any] = [];
    styles: (list[list[any]] | None) = None;
    if app.intel is not None {
        try {
            status = app.intel.status(app.code_path);
            diags = app.intel.diagnostics(app.code_path);
            styles = app.intel.line_styles(app.code_path);
        } except Exception {}
    }
    right = f"{app.cur_line + 1}:{app.cur_col + 1}";
    if diags {
        ne = len(
            [
                d
                for d in diags
                if d.severity == "error"
            ]
        );
        nw = len(diags) - ne;
        right = f"✖{ne} ⚠{nw}  " + right;
    }
    if status and status not in ["ready", "idle"] {
        right = status + "  " + right;
    }
    title = rel + (f"  ›  {sym.key}" if sym is not None else "");
    out = [title_row(app, title, focused, w, right)];
    gw = gutter_width(app);
    diag_lines: dict[int, str] = {};
    diag_text: dict[int, str] = {};
    for d in diags {
        if d.line not in diag_text or d.severity == "error" {
            diag_text[d.line] = (d.code + " " if d.code else "")
                + d.message.split("\n")[0];
        }
        sev = diag_lines.get(d.line, "");
        if sev != "error" {
            diag_lines[d.line] = d.severity;
        }
    }
    marks = app.line_marks.get(os.path.realpath(app.code_path), {});
    hints: dict[int, list[tuple[int, str]]] = {};
    if app.intel is not None and app.show_inlays {
        try {
            hints = app.intel.inlays(app.code_path);
        } except Exception {}
    }
    sym_lo = 0;
    sym_hi = -1;
    if sym is not None {
        if sym.file == app.code_path {
            (sym_lo, sym_hi) = (sym.line, sym.end_line);
        } elif isinstance(sym, StAbility) {
            (sym_lo, sym_hi) = (sym.impl_line, sym.impl_end_line);
        }
    }
    for i in range(app.code_top, min(len(app.code_lines), app.code_top + h - 1)) {
        text = app.code_lines[i];
        cur = i == app.cur_line;
        mark = " ";
        mark_a = THEME.gutter;
        sev = diag_lines.get(i + 1, "");
        chg = marks.get(i + 1, "");
        if sev == "error" {
            (mark, mark_a) = ("●", THEME.err);
        } elif sev {
            (mark, mark_a) = ("●", THEME.warn);
        } elif chg {
            (mark, mark_a) = (
                "▌",
                StyleAttrs(fg=({"added": 114, "removed": 203}.get(chg, 179)))
            );
        } elif sym_lo <= i + 1 <= sym_hi {
            (mark, mark_a) = ("│", StyleAttrs(fg=24));
        }
        num = str(i + 1).rjust(gw - 3);
        gutter = [
            sp(num, THEME.gutter_cur if cur else THEME.gutter),
            sp(" " + mark + " ", mark_a)
        ];
        line_spans = code_line_spans(app, i, text, styles);
        if app.show_inlays and (i + 1) in hints {
            line_spans = with_inlays(line_spans, hints[i + 1]);
        }
        body = slice_spans(line_spans, app.code_left);
        dmsg = diag_text.get(i + 1, "");
        if dmsg {
            sev_a = THEME.err if diag_lines.get(i + 1, "") == "error" else THEME.warn;
            body = body + [sp("   ● " + dmsg, StyleAttrs(fg=sev_a.fg, italic=True))];
        }
        line = fit(gutter + body, w, None);
        if cur and focused {
            line = restyle(line, 236);
        }
        out.append(line);
    }
    while len(out) < h {
        out.append(blank(w));
    }
    set_node_spans(app.r, app.center, out[:h], THEME.pane);
    if focused and app.sheet is None {
        row = app.cur_line - app.code_top + 1;
        col = gw + app.cur_col - app.code_left;
        if 0 < row < h and 0 <= col < w {
            request_cursor(app.r, app.center, row_offset=row, col_offset=col);
        }
    }
}

impl paint_wiring(app: Studio) -> None {
    (w, h) = pane_rect(app, app.center);
    if w <= 0 or h <= 0 {
        return;
    }
    focused = app.focus == "code";
    cols = wire_columns(app);
    out = [
        title_row(
            app,
            f"WIRING  {app.wire_mod}",
            focused,
            w,
            "← feeds it │ module │ it feeds →"
        )
    ];
    side = max(int((w - 2) * 0.3), 12);
    widths = [side, w - 2 - 2 * side, side];
    heads = [
        f"feeds this ({len(cols[0])})",
        "module, rules and symbols",
        f"consumed by ({len(cols[2])})"
    ];
    head = [];
    for c in range(3) {
        a = THEME.accent if c == app.wire_col and focused else THEME.dim;
        head += fit([sp(" " + heads[c], a)], widths[c], None);
        if c < 2 {
            head.append(sp("│", THEME.faint));
        }
    }
    out.append(head);
    body_h = h - 2;
    rows_per = 2;
    vis = max(body_h // rows_per, 1);
    for c in range(3) {
        if app.wire_sel[c] < app.wire_top[c] {
            app.wire_top[c] = app.wire_sel[c];
        }
        if app.wire_sel[c] >= app.wire_top[c] + vis {
            app.wire_top[c] = app.wire_sel[c] - vis + 1;
        }
    }
    for r in range(body_h) {
        line: list[TextSpan] = [];
        for c in range(3) {
            idx = app.wire_top[c] + r // rows_per;
            cell: list[TextSpan] = [];
            if idx < len(cols[c]) {
                item = cols[c][idx];
                if r % rows_per == 0 {
                    icon = kind_icon(item.kind);
                    label = item.label;
                    room = widths[c] - 4;
                    if room > 4 and len(label) > room {
                        label = "…" + label[len(label) - room + 1:];
                    }
                    bad = item.kind == "wire"
                        and item.data is not None
                        and bool(getattr(item.data, "violation", ""));
                    cell = [
                        sp(
                            " " + ("⚠" if bad else icon) + " ",
                            THEME.err if bad else kind_attrs(item.kind)
                        ),
                        sp(label, THEME.err if bad else THEME.text)
                    ];
                } elif item.kind == "wire"
                    and item.data is not None
                    and getattr(item.data, "violation", "") {
                    cell = [
                        sp("    " + item.data.violation, THEME.err),
                        sp("  " + item.detail, THEME.dim)
                    ];
                } else {
                    cell = [sp("    " + item.detail, THEME.dim)];
                }
                cell = fit(cell, widths[c], None);
                if idx == app.wire_sel[c] and (c == app.wire_col) {
                    cell = restyle(cell, C_SEL_FOCUS if focused else C_SEL);
                }
            } else {
                cell = blank(widths[c]);
            }
            line += cell;
            if c < 2 {
                line.append(sp("│", THEME.faint));
            }
        }
        out.append(fit(line, w, None));
    }
    while len(out) < h {
        out.append(blank(w));
    }
    set_node_spans(app.r, app.center, out[:h], THEME.pane);
}

impl map_target(app: Studio) -> str {
    if app.focus == "nav" and 0 <= app.nav_sel < len(app.nav_rows) {
        return app.nav_rows[app.nav_sel].key;
    }
    if app.center_mode == "wiring" and app.wire_mod {
        return app.wire_mod;
    }
    if app.code_path {
        mod = app.model.module_for_file(app.code_path);
        if mod is not None {
            return mod.key;
        }
    }
    return "";
}

impl open_map(app: Studio, key: str, inside: bool = False) -> None {
    if app.gmap is None {
        app.gmap = MapState();
    }
    app.gmap.only = None;
    app.gmap.only_spec = "";
    app.gmap.only_label = "";
    app.gmap.data = {};
    key = key.strip();
    scope = scope_for(app.model, key) if key else "";
    if key and scope == key and not inside {
        scope = key.rsplit(".", 1)[0] if "." in key else "";
    }
    set_map_scope(app, scope, key);
    app.center_mode = "map";
    app.focus = "code";
}

impl set_map_scope(app: Studio, scope: str, select: str = "") -> None {
    st = app.gmap;
    if st is None {
        return;
    }
    st.level = graph_level(app.model, scope, st.only);
    st.scope = st.level.scope;
    st.sig = map_sig(app);
    (st.r, st.c, st.sel, st.item) = (0, 0, 0, 0);
    (st.top, st.left, st.scroll) = (0, 0, 0);
    if select {
        st.select_key(group_of(select, st.scope));
    }
}

impl paint_map(app: Studio) -> None {
    (w, h) = pane_rect(app, app.center);
    if w <= 0 or h <= 0 {
        return;
    }
    st = app.gmap;
    if st is None {
        app.center_mode = "code";
        return;
    }
    if st.level is None or st.sig != map_sig(app) {
        keep = "";
        if st.level is not None and st.level.nodes {
            i = st.r if st.view == "matrix" else st.sel;
            keep = st.level.nodes[min(i, len(st.level.nodes) - 1)].key;
        }
        set_map_scope(app, st.scope, keep);
    }
    focused = app.focus == "code";
    lvl = st.level;
    if lvl is None {
        return;
    }
    ensure_map_data(app);
    stats = f"{len(lvl.nodes)} groups · {lvl.wires} wires · {lvl.back_wires} backward";
    if st.only is not None {
        stats = f"{st.only_label} · x clears";
    }
    out = [
        title_row(
            app, f"MAP  {crumbs(st.scope)}   {stats}", focused, w, view_tabs(st.view)
        )
    ];
    out += map_lines(st, w, h - 1, focused);
    set_node_spans(app.r, app.center, out[:h], THEME.pane);
}

impl map_key(app: Studio, key: str) -> None {
    st = app.gmap;
    if st is None {
        return;
    }
    if key == "v" {
        st.set_view(MAP_VIEWS[(MAP_VIEWS.index(st.view) + 1) % len(MAP_VIEWS)]);
    } elif key in ["1", "2", "3", "4", "5", "6", "7"] {
        st.set_view(MAP_VIEWS[int(key) - 1]);
    } elif key in ["s", "b"] {
        it = st.selected_item();
        target = it.key
            if it is not None and it.kind in ["module", "export", "import"]
            else st.group_key();
        map_filter(app, target, "up" if key == "s" else "down", True);
    } elif key == "x" {
        if st.only is None {
            return;
        }
        st.only = None;
        st.only_label = "";
        st.only_spec = "";
        st.data = {};
        set_map_scope(app, st.scope, st.group_key());
    } elif key in ["backspace", "u"] {
        up = parent_scope(app.model, st.scope, st.only);
        if up is None {
            app.say("This is the whole project");
            return;
        }
        set_map_scope(app, up, st.scope);
    } elif key == "enter" {
        map_activate(app);
    } elif key in [" ", "a", "ctrl+space"] {
        map_add(app);
    } elif key == "A" {
        add_to_tray(app, MAP_PREFIX + st.scope + map_spec(app));
    } elif key == "o" {
        nd = st.selected_node();
        if nd is not None and nd.kind == "module" {
            open_key(app, nd.key);
        }
    } else {
        map_move(st, key);
    }
}

impl map_activate(app: Studio) -> None {
    st = app.gmap;
    if st is None or st.level is None or not st.level.nodes {
        return;
    }
    lvl = st.level;
    if st.view in ["roles", "iface", "rules", "clusters"] {
        it = st.selected_item();
        if it is not None {
            map_list_activate(app, it);
        }
        return;
    }
    if st.view == "issues" {
        items = issue_items(lvl);
        if not items {
            return;
        }
        it = items[min(st.item, len(items) - 1)];
        if it.kind == "cycle" {
            st.set_view("layers");
            st.sel = lvl.index.get(it.src, 0);
        } else {
            open_wire_list(app, it.src, it.dst);
        }
        return;
    }
    nd = st.selected_node();
    if nd is not None {
        if nd.kind == "package" {
            set_map_scope(app, nd.key);
        } else {
            app.wire_mod = nd.key;
            app.center_mode = "wiring";
            app.wire_sel = [0, 0, 0];
            app.wire_top = [0, 0, 0];
            app.wire_col = 1;
            reveal_in_nav(app, nd.key);
        }
        return;
    }
    e = st.selected_edge();
    if e is not None {
        open_wire_list(app, e.src, e.dst);
    } else {
        app.say("No wires between these two");
    }
}

impl map_add(app: Studio) -> None {
    st = app.gmap;
    if st is None or st.level is None or not st.level.nodes {
        return;
    }
    if st.view in ["roles", "iface", "rules", "clusters"] {
        li = st.selected_item();
        if li is not None
            and li.key
            and li.kind in ["module", "export", "import", "wire"] {
            add_to_tray(app, li.key);
        } elif li is not None and li.kind == "rule" {
            add_to_tray(app, MAP_PREFIX + st.scope + map_spec(app));
        }
        return;
    }
    if st.view == "issues" {
        items = issue_items(st.level);
        if not items {
            return;
        }
        it = items[min(st.item, len(items) - 1)];
        add_to_tray(
            app,
            (MAP_PREFIX + st.scope if it.kind == "cycle" else deps_key(it.src, it.dst))
                + map_spec(app)
        );
        return;
    }
    nd = st.selected_node();
    if nd is not None {
        add_to_tray(
            app, MAP_PREFIX + nd.key + map_spec(app) if nd.kind == "package" else nd.key
        );
        return;
    }
    e = st.selected_edge();
    if e is not None {
        add_to_tray(app, deps_key(e.src, e.dst) + map_spec(app));
    } else {
        app.say("No wires between these two");
    }
}

impl open_wire_list(app: Studio, src: str, dst: str) -> None {
    st = app.gmap;
    with app.model.lock {
        wires = edge_wires(app.model, src, dst, st.only if st is not None else None);
    }
    if not wires {
        app.say(f"{src} does not feed {dst}");
        return;
    }
    items: list[PickItem] = [];
    for w in wires {
        names = ", ".join(w.names) if w.names else "whole module";
        scope = f" (in {w.scope})" if w.scope else "";
        bad = f"   ⚠ {w.violation}" if w.violation else "";
        items.append(
            PickItem(
                key=w.consumer,
                label=f"{w.provider} ++> {w.consumer}{scope}",
                detail=names + bad,
                kind="wire",
                data=w
            )
        );
    }
    app.wire_items = items;
    short_src = src.rsplit(".", 1)[-1];
    short_dst = dst.rsplit(".", 1)[-1];
    open_picker(app, "wires", f"Wires {short_src} → {short_dst} ({len(items)})", "");
}

impl ensure_map_data(app: Studio) -> None {
    st = app.gmap;
    if st is None or st.level is None {
        return;
    }
    view = st.view;
    if view not in ["roles", "iface", "rules", "clusters"] {
        return;
    }
    base = f"{st.sig}";
    if view == "roles" {
        ck = f"{base}|{st.scope}";
    } elif view == "iface" {
        ck = f"{base}|{st.group_key()}";
    } elif view == "clusters" {
        ck = f"{base}|{st.scope}|{st.only_label}";
    } else {
        ck = base;
    }
    cur = st.data.get(view);
    if cur is not None and cur[0] == ck {
        return;
    }
    if view == "roles" {
        found: any = module_roles(app.model, st.scope);
    } elif view == "iface" {
        found = interface_of(app.model, st.group_key());
    } elif view == "rules" {
        found = intent_report(app.model);
    } else {
        found = cluster_report(app.model, st.scope);
        if st.only is not None {
            found.clusters = [
                cl
                for cl in found.clusters
                if any([m in st.only for m in cl.members])
            ];
        }
    }
    st.data[view] = (ck, found);
}

impl map_filter(app: Studio, key: str, direction: str, again: bool = False) -> None {
    if app.gmap is None {
        app.gmap = MapState();
    }
    st = app.gmap;
    word = "slice" if direction == "up" else "blast";
    prior = spec_parts(st.only_spec) if again and st.only is not None else {};
    if word in prior {
        key = prior[word];
    }
    r = reach(app.model, key, direction);
    if not r.seeds {
        app.say(f"{key} is not a module, package or name the wiring knows", "warn");
        return;
    }
    full = word in prior and prior[word] == key and "all" not in prior;
    spec = f"{word}={key}" + ("&all" if full else "");
    mods = filter_modules(app.model, spec) or set(r.seeds);
    if not full and mods == r.modules() {
        spec = f"{word}={key}&all";
        full = True;
    }
    n = len(mods) - len(r.seeds);
    what = "slice" if direction == "up" else "blast radius";
    when = "through any wire" if full else "at import time";
    st.only = mods;
    st.only_spec = spec;
    st.only_label = f"{what} of {key.rsplit('.', 1)[-1]}: {n} module(s) {when}";
    st.data = {};
    set_map_scope(app, "", r.seeds[0]);
    app.center_mode = "map";
    app.focus = "code";
    total = len(r.modules()) - len(r.seeds);
    more = ""
        if full
        else f"; press {'s' if direction == 'up' else 'b'} again for all {total} reachable through any wire";
    app.say(f"{what.capitalize()} of {key}: {n} module(s) {when}{more}", "ok", 6.0);
}

impl map_spec(app: Studio) -> str {
    st = app.gmap;
    return f"?{st.only_spec}"
        if st is not None and st.only is not None and st.only_spec
        else "";
}

impl apply_spec(app: Studio, spec: str) -> None {
    st = app.gmap;
    if st is None or not spec {
        return;
    }
    mods = filter_modules(app.model, spec);
    if mods is None {
        return;
    }
    st.only = mods;
    st.only_spec = spec;
    st.only_label = f"{filter_label(spec)}: {len(mods)} module(s)";
    st.data = {};
}

impl open_wires(app: Studio, title: str, wires: list[WireInfo]) -> None {
    if not wires {
        app.say("No wires");
        return;
    }
    items: list[PickItem] = [];
    for w in wires {
        names = ", ".join(w.names) if w.names else "whole module";
        scope = f" (in {w.scope})" if w.scope else "";
        bad = f"   ⚠ {w.violation}" if w.violation else "";
        items.append(
            PickItem(
                key=w.consumer,
                label=f"{w.provider} ++> {w.consumer}{scope}",
                detail=names + bad,
                kind="wire",
                data=w
            )
        );
    }
    app.wire_items = items;
    open_picker(app, "wires", f"{title} ({len(items)})", "");
}

impl map_list_activate(app: Studio, it: MapItem) -> None {
    st = app.gmap;
    if st is None {
        return;
    }
    m = app.model;
    if it.kind == "module" or it.kind == "import" {
        if it.key in m.modules and m.modules[it.key].kind == "module" {
            app.wire_mod = it.key;
            app.center_mode = "wiring";
            app.wire_sel = [0, 0, 0];
            app.wire_top = [0, 0, 0];
            app.wire_col = 1;
            reveal_in_nav(app, it.key);
        }
    } elif it.kind == "export" {
        map_filter(app, it.key, "down");
    } elif it.kind == "group" {
        st.only = None;
        st.only_label = "";
        st.only_spec = "";
        st.data = {};
        set_map_scope(app, it.key);
        st.set_view("matrix");
    } elif it.kind == "split" {
        set_map_scope(app, it.key);
        st.set_view("matrix");
    } elif it.kind == "rule" {
        with m.lock {
            wires = [
                w
                for w in m.wires
                if it.key in w.rules
            ];
        }
        open_wires(app, f"Wires rule {it.label.split(':')[0]} admits", wires);
    } elif it.kind == "arm" {
        rec = m.rule_recs.get(it.key);
        wires: list[WireInfo] = [];
        if rec is not None {
            pats = [
                (p, t) for p in rec.sources
                for t in rec.targets
                if p.text == it.src and t.text == it.dst
            ];
            with m.lock {
                for w in m.wires {
                    if it.key in w.rules {
                        for (p, t) in pats {
                            if p.matches(w.local_provider)
                                and t.matches(w.local_consumer) {
                                wires.append(w);
                            }
                        }
                    }
                }
            }
        }
        open_wires(app, f"Wires using {it.src} --> {it.dst}", wires);
    } elif it.kind == "wire" {
        with m.lock {
            wires = [
                w
                for w in m.wires
                if w.provider == it.src and w.consumer == it.dst
            ];
        }
        open_wires(app, "Wire", wires);
    } elif it.kind == "cluster" {
        held = st.data.get("clusters");
        if held is None {
            return;
        }
        for cl in held[1].clusters {
            if str(cl.id) == it.key {
                st.only = set(cl.members);
                st.only_label = f"cluster #{cl.id}: {len(cl.members)} modules";
                scope = held[1].scope;
                st.only_spec = f"cluster={cl.id}@{scope}";
                st.data = {};
                set_map_scope(app, scope);
                st.set_view("matrix");
                return;
            }
        }
    }
}

impl open_doc(app: Studio, title: str, text: str) -> None {
    (cols, rows) = screen_size(app);
    w = min(110, cols - 4);
    h = rows - 4;
    lines: list[list[TextSpan]] = [
        fit([sp(" " + title, THEME.overlay_title)], w, THEME.overlay_title)
    ];
    for pl in project_markdown(text, w - 4) {
        lines.append(
            fit(
                [sp("  ", None)]
                    + [sp(x.text, with_bg(x.attrs, 237)) for x in pl.spans],
                w,
                THEME.overlay
            )
        );
    }
    lines.append(
        fit(
            [sp(" ↑↓ PgUp PgDn scroll · Esc closes", StyleAttrs(fg=244, bg=237))],
            w,
            THEME.overlay
        )
    );
    open_sheet(app, "doc", w, h, OverlayAnchor.CENTER);
    app.sheet_lines = lines;
}

impl start_doc(app: Studio, kind: str) -> None {
    if app.doc_busy {
        app.say("Still working on the last one");
        return;
    }
    app.doc_busy = True;
    scope = app.gmap.scope if app.gmap is not None else "";
    model = app.model;
    def work {
        try {
            if kind == "tour" {
                app.doc_result = (
                    f"Tour of {scope or 'the project'}",
                    tour_text(model, scope)
                );
            } else {
                base = default_base(model.root_dir);
                d = arch_diff(model, base);
                app.doc_result = (f"Architecture changes since {base}", diff_text(d));
            }
        } except Exception as e {
            app.doc_result = ("Failed", f"{type(e).__name__}: {e}");
        }
        app.doc_busy = False;
        app.dirty = True;
    }
    threading.Thread(target=work, daemon=True).start();
    app.say(
        "Writing the tour…"
            if kind == "tour"
            else "Comparing the wiring with the base revision…",
        "info",
        8.0
    );
}

impl chat_lines(app: Studio, width: int) -> list[list[TextSpan]] {
    out: list[list[TextSpan]] = [];
    starts: list[int] = [];
    inner = max(width - 2, 10);
    focused = app.focus == "chat";
    for (idx, e) in enumerate(app.chat) {
        starts.append(len(out));
        first = len(out);
        if e.role == "user" {
            out.append(fit([sp("▍you", THEME.accent2)], width, None));
            for ln in wrap_plain(e.text, inner) {
                out.append(fit([sp("  " + ln, THEME.text)], width, None));
            }
            if e.detail {
                out.append(fit([sp("  ⊕ " + e.detail, THEME.faint)], width, None));
            }
        } elif e.role == "agent" {
            out.append(
                fit([sp("▍" + (app.agent_name or "agent"), THEME.accent)], width, None)
            );
            for pl in project_markdown(e.text, inner) {
                spans = [sp("  ", None)] + [sp(s.text, s.attrs) for s in pl.spans];
                out.append(fit(spans, width, None));
            }
        } elif e.role == "thought" {
            for ln in wrap_plain(e.text, inner)[-6:] {
                out.append(fit([sp("  ∴ " + ln, THEME.faint)], width, None));
            }
        } elif e.role == "tool" {
            icon = {
                "completed": "✓",
                "failed": "✗",
                "in_progress": "…",
                "pending": "·"
            }.get(
                e.status, "·"
            );
            a = THEME.ok
                if e.status == "completed"
                else (THEME.err if e.status == "failed" else THEME.dim);
            body = wrap_plain(e.detail, inner - 6) if e.detail else [];
            is_open = idx in app.chat_open;
            fold = "";
            if len(body) > 1 or e.locs {
                fold = " ▾" if is_open else " ▸";
            }
            out.append(
                fit(
                    [
                        sp(f"  {icon} ", a),
                        sp(e.title or e.kind or "tool", THEME.dim),
                        sp(fold, THEME.faint)
                    ],
                    width,
                    None
                )
            );
            shown = body[:60] if is_open else body[:1];
            for ln in shown {
                out.append(fit([sp("      " + ln, THEME.faint)], width, None));
            }
            if not is_open and len(body) > 1 {
                out.append(
                    fit(
                        [sp(f"      … {len(body) - 1} more line(s)", THEME.faint)],
                        width,
                        None
                    )
                );
            }
        } elif e.role == "plan" {
            out.append(
                fit(
                    [
                        sp("  plan", THEME.accent2),
                        sp(
                            "  Enter jumps to linked code" if app.plan_links else "",
                            THEME.faint
                        )
                    ],
                    width,
                    None
                )
            );
            for ln in e.text.split("\n") {
                for (k, part) in enumerate(wrap_plain(ln, inner - 6)) {
                    out.append(
                        fit(
                            [sp(("    " if k == 0 else "      ") + part, THEME.dim)],
                            width,
                            None
                        )
                    );
                }
            }
        } elif e.role == "error" {
            for ln in wrap_plain(e.text, inner) {
                out.append(fit([sp("  ✖ " + ln, THEME.err)], width, None));
            }
        } else {
            for ln in wrap_plain(e.text, inner) {
                out.append(fit([sp("  " + ln, THEME.dim)], width, None));
            }
        }
        if focused and idx == app.chat_sel and first < len(out) {
            out[first] = restyle(out[first], C_SEL_FOCUS);
        }
        out.append(blank(width));
    }
    app.chat_starts = starts;
    return out;
}

impl paint_chat(app: Studio) -> None {
    (w, h) = pane_rect(app, app.chat_pane);
    if w <= 0 or h <= 0 {
        return;
    }
    focused = app.focus == "chat";
    right = "";
    if app.agent_state == "busy" {
        right = f"{SPIN[app.spin % len(SPIN)]} working";
    }
    out = [title_row(app, "AGENT", focused, w, right)];
    lines = chat_lines(app, w);
    body_h = h - 1;
    app.chat_h = body_h;
    max_top = max(0, len(lines) - body_h);
    if app.chat_follow or app.chat_top > max_top {
        app.chat_top = max_top;
        if app.chat_top >= max_top {
            app.chat_follow = True;
        }
    }
    if not lines {
        out.append(
            plain(
                "  Ask about the selected code, or use /explain, /tests,", w, THEME.dim
            )
        );
        out.append(
            plain("  /refactor. The context tray below is sent along.", w, THEME.dim)
        );
    }
    out += lines[app.chat_top:app.chat_top + body_h];
    while len(out) < h {
        out.append(blank(w));
    }
    set_node_spans(app.r, app.chat_pane, out[:h], THEME.pane);
}

impl paint_tray(app: Studio) -> None {
    (w, h) = pane_rect(app, app.tray_pane);
    if w <= 0 or h <= 0 {
        return;
    }
    focused = app.focus == "tray";
    out = [
        title_row(
            app,
            f"CONTEXT ({len(app.tray)})",
            focused,
            w,
            "x removes" if focused else ""
        )
    ];
    if not app.tray {
        out.append(
            plain("  Space on code, a symbol or a wire adds it here.", w, THEME.dim)
        );
    }
    for (i, k) in enumerate(app.tray[:h - 1]) {
        nd = app.model.node_for(k) if not k.startswith("wire:") else None;
        kind = nd.kind
            if nd is not None
            else ("wire" if k.startswith("wire:") else "?");
        label = k[5:] if k.startswith("wire:") else k;
        if k.startswith(MAP_PREFIX) {
            kind = "package";
            (scope_, spec_) = split_spec(k[len(MAP_PREFIX):]);
            label = "map of "
                + (scope_ or "the project")
                + (f" ({filter_label(spec_)})" if spec_ else "");
        } elif parse_deps_key(k) is not None {
            kind = "wire";
            (src, dst) = parse_deps_key(k);
            spec_ = split_spec(k)[1];
            label = f"wires {src} → {dst}"
                + (f" ({filter_label(spec_)})" if spec_ else "");
        }
        line = fit(
            [sp(" " + kind_icon(kind) + " ", kind_attrs(kind)), sp(label, THEME.text)],
            w,
            None
        );
        if i == app.tray_sel and focused {
            line = restyle(line, C_SEL_FOCUS);
        }
        out.append(line);
    }
    while len(out) < h {
        out.append(blank(w));
    }
    set_node_spans(app.r, app.tray_pane, out[:h], THEME.pane);
}

impl paint_prompt(app: Studio) -> None {
    (w, h) = pane_rect(app, app.prompt);
    if w <= 0 or h <= 0 {
        return;
    }
    focused = app.focus == "prompt";
    hint = "Enter send · Alt+Enter newline · @ add context · /explain /tests /refactor"
        if focused
        else "Ctrl+L to type";
    out = [title_row(app, "PROMPT", focused, w, hint)];
    lines = app.draft.split("\n");
    before = app.draft[:app.caret];
    crow = before.count("\n");
    ccol = display_width(before.split("\n")[-1]);
    body_h = h - 1;
    top = max(0, crow - body_h + 1);
    for (i, ln) in enumerate(lines[top:top + body_h]) {
        lead = "❯ " if top + i == 0 else "  ";
        out.append(fit([sp(lead, THEME.accent), sp(ln, THEME.text)], w, None));
    }
    if not app.draft {
        out[1] = fit(
            [
                sp("❯ ", THEME.accent),
                sp("Tell the agent what to do with the context…", THEME.faint)
            ],
            w,
            None
        );
    }
    while len(out) < h {
        out.append(blank(w));
    }
    set_node_spans(app.r, app.prompt, out[:h], THEME.pane);
    if focused and app.sheet is None {
        request_cursor(
            app.r, app.prompt, row_offset=1 + crow - top, col_offset=2 + ccol
        );
    } elif app.focus != "code" or app.sheet is not None {
        clear_cursor(app.r);
    }
}

impl paint_status(app: Studio) -> None {
    (w, h) = pane_rect(app, app.status);
    if w <= 0 {
        return;
    }
    if app.flash {
        a = {"warn": THEME.warn, "error": THEME.err, "ok": THEME.ok}.get(
            app.flash_kind, THEME.status
        );
        spans = [sp(" " + app.flash, with_bg(a, 236))];
    } elif app.focus == "code" and cursor_diag(app) {
        spans = [sp(" " + cursor_diag(app), with_bg(THEME.err, 236))];
    } elif app.hover and app.focus == "code" {
        spans = [sp(" " + app.hover.split("\n")[0], THEME.status)];
    } else {
        hints = {
            "nav": "↑↓ move  →← open/close  Enter open  Space add  w wiring  m map  s slice  b blast",
            "code": "Space add  Enter definition  r references  i decl/impl  e next diagnostic  t types  w wiring  m map",
            "chat": "↑↓ select  Enter expand / plan links  o open tool file  End follow",
            "tray": "↑↓ select  x remove  Enter open  C clear",
            "prompt": "Enter send  Alt+Enter newline  @ add  ↑ history"
        }.get(
            app.focus, ""
        );
        if app.center_mode == "wiring" and app.focus == "code" {
            hints = "←→ column  ↑↓ select  Enter follow/open  Space add  o open module  Esc code";
        }
        if app.center_mode == "map" and app.focus == "code" {
            hints = "v view  arrows move  Enter open  u up  s slice  b blast  x unfilter  Space add  Esc code";
        }
        spans = [
            sp(f" {app.focus.upper()} ", THEME.status_key),
            sp(" " + hints, THEME.status)
        ];
    }
    right = "Tab focus · Ctrl+P find · Ctrl+X commands · F1 help ";
    used = sum([display_width(s.text) for s in spans]);
    if used + display_width(right) + 2 < w {
        spans.append(sp(" " * (w - used - display_width(right)), THEME.status));
        spans.append(sp(right, StyleAttrs(fg=244, bg=236)));
    }
    set_node_spans(app.r, app.status, [fit(spans, w, THEME.status)]);
}

impl paint_sheet(app: Studio) -> None {
    sh = app.sheet;
    if sh is None {
        return;
    }
    (w, h) = pane_rect(app, sh);
    if w <= 0 or h <= 0 {
        return;
    }
    out: list[list[TextSpan]] = [];
    if app.sheet_kind == "picker" {
        out.append(
            fit(
                [sp(" " + app.picker_title, THEME.overlay_title)],
                w,
                THEME.overlay_title
            )
        );
        out.append(
            fit(
                [
                    sp(" ❯ ", StyleAttrs(fg=75, bg=237, bold=True)),
                    sp(app.picker_query, THEME.overlay),
                    sp("▏", StyleAttrs(fg=75, bg=237))
                ],
                w,
                THEME.overlay
            )
        );
        body_h = h - 3;
        top = max(0, app.picker_sel - body_h + 1);
        for i in range(top, min(len(app.picker_items), top + body_h)) {
            item = app.picker_items[i];
            sel = i == app.picker_sel;
            base = THEME.overlay_sel if sel else THEME.overlay;
            spans = [
                sp(
                    " " + kind_icon(item.kind) + " ",
                    with_bg(kind_attrs(item.kind), base.bg)
                ),
                sp(item.label, base)
            ];
            if item.detail {
                spans.append(
                    sp("  " + item.detail, with_bg(StyleAttrs(fg=244), base.bg))
                );
            }
            out.append(fit(spans, w, base));
        }
        if not app.picker_items {
            out.append(
                fit(
                    [sp("   nothing matches", with_bg(THEME.dim, 237))],
                    w,
                    THEME.overlay
                )
            );
        }
        while len(out) < h - 1 {
            out.append(blank(w, THEME.overlay));
        }
        foot = " ↑↓ select · Enter choose · Esc close";
        if app.picker_purpose == "goto" {
            foot = " ↑↓ select · Enter open · Tab add to context · Esc close";
        } elif app.picker_purpose == "wires" {
            foot = " ↑↓ select · Enter show in the wiring view · Tab add to context · Esc close";
        }
        out.append(fit([sp(foot, StyleAttrs(fg=244, bg=237))], w, THEME.overlay));
    } elif app.sheet_kind == "approval" {
        out = approval_view(app, w, h);
    } elif app.sheet_kind == "help" {
        out.append(fit([sp(" Keys", THEME.overlay_title)], w, THEME.overlay_title));
        rows = HELP_TEXT[app.sheet_scroll:];
        for (k, v) in rows[:h - 2] {
            if not k {
                out.append(
                    fit(
                        [sp(" " + v, StyleAttrs(fg=179, bg=237, bold=True))],
                        w,
                        THEME.overlay
                    )
                );
            } else {
                out.append(
                    fit(
                        [
                            sp("   " + k[:27].ljust(28), StyleAttrs(fg=117, bg=237)),
                            sp(v, THEME.overlay)
                        ],
                        w,
                        THEME.overlay
                    )
                );
            }
        }
        while len(out) < h - 1 {
            out.append(blank(w, THEME.overlay));
        }
        out.append(
            fit([sp(" Esc closes", StyleAttrs(fg=244, bg=237))], w, THEME.overlay)
        );
    } else {
        for ln in app.sheet_lines[app.sheet_scroll:app.sheet_scroll + h] {
            out.append(fit(ln, w, THEME.overlay));
        }
        while len(out) < h {
            out.append(blank(w, THEME.overlay));
        }
    }
    set_node_spans(app.r, sh, out[:h], THEME.overlay);
}

def load_studio_config(root_dir: str) -> dict[str, any];

def ensure_indexed(app: Studio, key: str) -> None;

impl load_studio_config(root_dir: str) -> dict[str, any] {
    user = read_studio_table(user_config_path());
    proj = read_studio_table(os.path.join(root_dir, "jac.toml"));
    merged: dict[str, any] = dict(user);
    for (k, v) in proj.items() {
        if k in ["verbs", "agents"]
            and isinstance(v, dict)
            and isinstance(merged.get(k), dict) {
            both = dict(merged[k]);
            both.update(v);
            merged[k] = both;
        } else {
            merged[k] = v;
        }
    }
    return merged;
}

impl ensure_indexed(app: Studio, key: str) -> None {
    mk = module_of_key(app, key);
    mod = app.model.modules.get(mk) if mk else None;
    if mod is None or mod.kind != "module" or mod.indexed {
        return;
    }
    app.model.index_module(mk);
    app.file_syms = {};
}

def style_for(style: str) -> StyleAttrs;

def cursor_diag(app: Studio) -> str;

def pump_intel(app: Studio, now: float) -> None;

def ensure_registry(app: Studio) -> any;

def mcp_servers(app: Studio) -> list[dict[str, any]];

def start_agent(app: Studio) -> None;

def stop_agent(app: Studio);

def pump_agent(app: Studio) -> None;

def close_message(app: Studio);

def append_stream(app: Studio, role: str, text: str) -> None;

def summarize_tool(d: dict[str, any]) -> str;

def handle_agent_event(app: Studio, ev: any) -> None;

def first_option(options: list[dict[str, any]], kinds: list[str]) -> (str | None);

def diff_spans(text: str, width: int) -> list[list[TextSpan]];

def open_approval(app: Studio) -> None;

def review_lines(
    review: any, w: int, keep: (set[str] | None) = None
) -> list[list[TextSpan]];

def approval_view(app: Studio, w: int, h: int) -> list[list[TextSpan]];

def next_approval(app: Studio);

def finish_permission(app: Studio, req: dict[str, any], option_id: (str | None));

def finish_write(app: Studio, req: dict[str, any], accept: bool, message: str);

def write_feedback(req: dict[str, any]) -> str;

def restore_session(app: Studio, session_id: str) -> None;

impl style_for(style: str) -> StyleAttrs {
    if style in CODE_STYLES {
        return CODE_STYLES[style];
    }
    parts = style.split(".");
    base = CODE_STYLES.get(parts[0], THEME.text);
    if "declaration" in parts or "definition" in parts {
        return StyleAttrs(fg=base.fg, bold=True, italic=base.italic);
    }
    return base;
}

impl cursor_diag(app: Studio) -> str {
    if app.intel is None or not app.code_path {
        return "";
    }
    try {
        for d in app.intel.diagnostics(app.code_path) {
            if d.line == app.cur_line + 1 {
                text = (d.code + " " if d.code else "") + d.message.split("\n")[0];
                if d.help {
                    text += "  — " + d.help.split("\n")[0];
                }
                return text;
            }
        }
    } except Exception {}
    return "";
}

impl pump_intel(app: Studio, now: float) -> None {
    if app.intel is None {
        return;
    }
    if app.hover_due and now >= app.hover_due and app.code_path {
        app.hover_due = 0.0;
        try {
            t = app.intel.request_hover(app.code_path, app.cur_line + 1, app.cur_col);
            app.tickets[t] = "hover";
        } except Exception {}
    }
    try {
        done = app.intel.poll();
    } except Exception {
        done = [];
    }
    for (t, res) in done {
        kind = app.tickets.pop(t, "");
        if kind == "hover" {
            if res {
                lines = [
                    l.strip()
                    for l in str(res).replace("```jac", "").replace("```", "").split(
                        "\n"
                    )
                    if l.strip()
                ];
                if lines {
                    app.hover = "  ".join(lines[:2]);
                }
            }
        } elif kind == "definition" {
            if res and res.get("path") {
                load_code(app, str(res["path"]));
                goto_line(app, int(res.get("line", 1)) - 1);
                app.cur_col = int(res.get("col", 0));
                clamp_cursor(app);
                app.center_mode = "code";
                app.say(
                    f"definition: {os.path.relpath(str(res['path']), app.root_dir)}:{res.get(
                        'line', 1
                    )}"
                );
            } else {
                app.say("no definition found here", "warn");
            }
        } elif kind == "references" {
            items: list[PickItem] = [];
            for r in (res or []) {
                path = str(r.get("path", ""));
                line = int(r.get("line", 1));
                items.append(
                    PickItem(
                        key=f"{path}:{line}",
                        label=f"{os.path.relpath(path, app.root_dir)}:{line}",
                        detail=str(r.get("text", "")).strip()[:90],
                        kind="ref",
                        data=(path, line - 1)
                    )
                );
            }
            show_locations(app, f"References ({len(items)})", items);
        }
        app.dirty = True;
    }
    if app.code_path {
        st = app.intel.status(app.code_path);
        if st in ["queued", "checking"] {
            app.dirty = True;
        }
    }
}

impl ensure_registry(app: Studio) -> any {
    if app.registry is None {
        app.registry = AgentRegistry(root_dir=app.root_dir);
    }
    return app.registry;
}

impl mcp_servers(app: Studio) -> list[dict[str, any]] {
    servers = [jac_mcp_server()];
    if app.bridge_path {
        servers.append(
            {
                "name": "studio",
                "command": servers[0]["command"],
                "args": ["hack", "mcp", "--socket", app.bridge_path],
                "env": []
            }
        );
    }
    return servers;
}

impl start_agent(app: Studio) -> None {
    if app.agent is not None and app.agent_state in ["starting", "ready", "busy"] {
        return;
    }
    reg = ensure_registry(app);
    name = app.agent_name or reg.default_name();
    if not name {
        app.chat.append(
            ChatEntry(
                role="error",
                text="No agent can run here. `jac hack agents` lists what is missing."
            )
        );
        app.queued = [];
        return;
    }
    spec = reg.get(name);
    if spec is not None and not spec.runnable() {
        app.chat.append(
            ChatEntry(role="error", text=f"{name} cannot start: {spec.reason()}")
        );
        app.queued = [];
        return;
    }
    app.agent_name = name;
    load_id = "";
    if app.rec is not None and app.rec.agent == name and app.rec.agent_session_id {
        load_id = app.rec.agent_session_id;
    }
    if app.rec is not None {
        app.rec.agent = name;
    }
    try {
        sess = reg.create_session(
            name=name,
            project_model=app.model,
            load_session_id=load_id,
            read_hook=(app.gate.read if app.gate is not None else None)
        );
    } except Exception as e {
        app.chat.append(
            ChatEntry(role="error", text=f"could not create the {name} session: {e}")
        );
        app.queued = [];
        return;
    }
    app.agent = sess;
    app.agent_state = "starting";
    app.chat.append(ChatEntry(role="system", text=f"starting {name}…"));
    servers = mcp_servers(app);
    root_dir = app.root_dir;
    def boot {
        try {
            sess.start(root_dir, servers);
        } except Exception as e {
            sess.events.put(
                AgentEvent(
                    kind="error", data={"message": f"{name} could not start: {e}"}
                )
            );
            sess.events.put(AgentEvent(kind="__start_failed", data={}));
        }
    }
    threading.Thread(target=boot, daemon=True).start();
}

impl stop_agent(app: Studio) {
    if app.agent is not None {
        try {
            app.agent.stop();
        } except Exception {}
    }
    app.agent = None;
    app.agent_state = "none";
    app.agent_title = "";
}

impl pump_agent(app: Studio) -> None {
    ag = app.agent;
    if ag is None {
        return;
    }
    for _ in range(300) {
        try {
            ev = ag.events.get_nowait();
        } except queue.Empty {
            break;
        }
        handle_agent_event(app, ev);
        app.dirty = True;
    }
}

impl close_message(app: Studio) {
    app.msg_open = "";
}

impl append_stream(app: Studio, role: str, text: str) -> None {
    if not text {
        return;
    }
    if app.msg_open == role and app.chat and app.chat[-1].role == role {
        app.chat[-1].text += text;
    } else {
        app.chat.append(ChatEntry(role=role, text=text, time=time.time()));
        app.msg_open = role;
    }
}

impl summarize_tool(d: dict[str, any]) -> str {
    out: list[str] = [];
    for c in (d.get("content") or []) {
        if not isinstance(c, dict) {
            continue;
        }
        if c.get("type") == "diff" {
            old = str(c.get("oldText") or "");
            new = str(c.get("newText") or "");
            added = 0;
            removed = 0;
            sm = difflib.SequenceMatcher(
                None, old.split("\n"), new.split("\n"), autojunk=False
            );
            for (tag, i1, i2, j1, j2) in sm.get_opcodes() {
                if tag != "equal" {
                    added += j2 - j1;
                    removed += i2 - i1;
                }
            }
            out.append(f"edit {c.get('path', '')}  +{added} -{removed}");
        } elif c.get("type") == "content" {
            inner = c.get("content") or {};
            if isinstance(inner, dict) and inner.get("type") == "text" {
                text = str(inner.get("text", "")).strip();
                if text {
                    out.append(text);
                }
            }
        } elif c.get("type") == "terminal" {
            out.append(f"terminal {c.get('terminalId', '')}");
        }
    }
    for loc in (d.get("locations") or [])[:3] {
        if isinstance(loc, dict) and loc.get("path") {
            out.append(
                f"{loc['path']}" + (f":{loc['line']}" if loc.get("line") else "")
            );
        }
    }
    return "\n".join(out)[:600];
}

impl handle_agent_event(app: Studio, ev: any) -> None {
    kind = ev.kind;
    d = ev.data or {};
    if d.get("replay") {
        return;
    }
    if app.rec is not None
        and kind not in ["ready", "log", "__start_failed", "commands"] {
        try {
            app.rec.record(ev);
        } except Exception {}
    }
    if kind == "ready" {
        app.agent_title = str(d.get("title") or d.get("agent") or app.agent_name);
        if d.get("resumed") {
            app.restored_transcript = "";
        }
        if app.rec is not None and d.get("session_id") {
            app.rec.agent_session_id = str(d.get("session_id"));
        }
        if app.chat
            and app.chat[-1].role == "system"
            and app.chat[-1].text.startswith("starting ") {
            app.chat[-1].text = f"{app.agent_title} is ready.";
        }
        app.agent_state = "ready";
        if app.queued {
            item = app.queued.pop(0);
            deliver(app, item["blocks"]);
            app.agent_state = "busy";
            app.turn_started = time.time();
        }
    } elif kind == "__start_failed" {
        app.agent = None;
        app.agent_state = "error";
        app.queued = [];
    } elif kind == "message_chunk" {
        append_stream(app, "agent", str(d.get("text", "")));
    } elif kind == "thought_chunk" {
        append_stream(app, "thought", str(d.get("text", "")));
    } elif kind in ["tool_call", "tool_call_update"] {
        close_message(app);
        tid = str(d.get("id", ""));
        idx = app.tool_index.get(tid, -1);
        if idx < 0 or idx >= len(app.chat) {
            app.chat.append(ChatEntry(role="tool", ident=tid, time=time.time()));
            idx = len(app.chat) - 1;
            app.tool_index[tid] = idx;
        }
        e = app.chat[idx];
        if d.get("title") {
            e.title = rel_text(app, str(d["title"]));
        }
        if d.get("kind") {
            e.kind = str(d["kind"]);
        }
        if d.get("status") {
            e.status = str(d["status"]);
        }
        detail = summarize_tool(d);
        if detail {
            e.detail = rel_text(app, detail);
        }
        for loc in (d.get("locations") or []) {
            if isinstance(loc, dict) and loc.get("path") {
                ref = str(loc["path"]) + (f":{loc['line']}" if loc.get("line") else "");
                if ref not in e.locs {
                    e.locs.append(ref);
                }
            }
        }
    } elif kind == "plan" {
        close_message(app);
        app.plan_entries = list(d.get("entries") or []);
        text = plan_text(app);
        if 0 <= app.plan_idx < len(app.chat)
            and app.chat[app.plan_idx].role == "plan" {
            app.chat[app.plan_idx].text = text;
        } else {
            app.chat.append(ChatEntry(role="plan", text=text, time=time.time()));
            app.plan_idx = len(app.chat) - 1;
        }
    } elif kind == "permission" {
        close_message(app);
        if auto_permission(app, d) {
            return;
        }
        app.pending.append({"type": "permission", "data": d});
        if app.sheet is None {
            open_approval(app);
        }
    } elif kind == "write" {
        close_message(app);
        req: dict[str, any] = {"type": "write", "data": d, "review": None};
        start_review(app, req);
        app.pending.append(req);
        if app.sheet is None {
            open_approval(app);
        }
    } elif kind == "terminal" {
        tid = str(d.get("terminal_id", ""));
        idx = app.term_index.get(tid, -1);
        if idx < 0 or idx >= len(app.chat) {
            app.chat.append(
                ChatEntry(role="tool", ident=tid, kind="execute", time=time.time())
            );
            idx = len(app.chat) - 1;
            app.term_index[tid] = idx;
        }
        e = app.chat[idx];
        e.title = "$ " + str(d.get("command", ""));
        tail = str(d.get("output", "")).rstrip("\n").split("\n")[-6:];
        e.detail = "\n".join(tail);
        code = d.get("exit_code");
        e.status = "in_progress"
            if code is None
            else ("completed" if code == 0 else "failed");
    } elif kind == "commands" {
        app.agent_commands = [
            str(c.get("name", ""))
            for c in (d.get("commands") or [])
            if isinstance(c, dict)
        ];
    } elif kind == "turn_end" {
        close_message(app);
        reason = str(d.get("stop_reason", ""));
        secs = time.time() - app.turn_started if app.turn_started else 0.0;
        if reason and reason != "end_turn" {
            app.chat.append(ChatEntry(role="system", text=f"turn ended: {reason}"));
        } elif secs > 0 {
            app.say(f"{app.agent_name} finished in {secs:.0f}s", "ok");
        }
        app.agent_state = "ready" if app.agent is not None else "none";
        if app.rec is not None {
            try {
                app.rec.tray = list(app.tray);
                app.rec.save();
            } except Exception {}
        }
        if app.queued and app.agent is not None {
            item = app.queued.pop(0);
            deliver(app, item["blocks"]);
            app.agent_state = "busy";
            app.turn_started = time.time();
        }
    } elif kind == "error" {
        close_message(app);
        app.chat.append(
            ChatEntry(
                role="error", text=str(d.get("message", "error")), time=time.time()
            )
        );
    }
}

impl first_option(options: list[dict[str, any]], kinds: list[str]) -> (str | None) {
    for k in kinds {
        for o in options {
            if o.get("kind") == k {
                return o.get("optionId");
            }
        }
    }
    return None;
}

impl diff_spans(text: str, width: int) -> list[list[TextSpan]] {
    out: list[list[TextSpan]] = [];
    for ln in text.rstrip("\n").split("\n") {
        a = THEME.overlay;
        if ln.startswith("+++") or ln.startswith("---") {
            a = StyleAttrs(fg=250, bg=237, bold=True);
        } elif ln.startswith("+") {
            a = StyleAttrs(fg=114, bg=237);
        } elif ln.startswith("-") {
            a = StyleAttrs(fg=203, bg=237);
        } elif ln.startswith("@@") {
            a = StyleAttrs(fg=81, bg=237);
        }
        out.append(fit([sp(" " + ln, a)], width, THEME.overlay));
    }
    return out;
}

impl open_approval(app: Studio) -> None {
    if not app.pending {
        return;
    }
    (cols, rows) = screen_size(app);
    open_sheet(
        app,
        "approval",
        max(40, min(cols - 2, 170)),
        max(10, rows - 6),
        OverlayAnchor.CENTER
    );
    req = app.pending[0];
    w = max(40, min(cols - 2, 170));
    lines: list[list[TextSpan]] = [];
    if req["type"] == "permission" {
        tc = req["data"].get("tool_call") or {};
        title = str(tc.get("title") or tc.get("toolCallId") or "a tool call");
        lines.append(
            fit(
                [
                    sp(f" {app.agent_name} asks permission: ", THEME.overlay_title),
                    sp(title, THEME.overlay_title)
                ],
                w,
                THEME.overlay_title
            )
        );
        known: dict[str, any] = {};
        idx = app.tool_index.get(str(tc.get("toolCallId", "")), -1);
        if 0 <= idx < len(app.chat) {
            known = {"content": []};
        }
        diffs = permission_diffs(tc, app.root_dir, known);
        raw = tc.get("rawInput");
        if not diffs and raw {
            for ln in str(raw)[:2000].split("\n") {
                lines.append(fit([sp(" " + ln, THEME.overlay)], w, THEME.overlay));
            }
        }
        for dtext in diffs {
            lines += diff_spans(dtext, w);
        }
    } else {
        d = req["data"];
        path = str(d.get("path", ""));
        rel = os.path.relpath(path, app.root_dir) if path else "?";
        lines.append(
            fit(
                [
                    sp(f" {app.agent_name} wants to write ", THEME.overlay_title),
                    sp(rel, THEME.overlay_title)
                ],
                w,
                THEME.overlay_title
            )
        );
        part = req.get("partial");
        if part is not None {
            prv = part.get("review");
            if not part["done"] {
                verdict = [
                    sp("  Selected changes only: checking…", with_bg(THEME.warn, 237))
                ];
            } elif prv is not None and prv.clean() {
                verdict = [
                    sp("  Selected changes only: ✓ ", with_bg(THEME.ok, 237)),
                    sp(prv.summary() + "   press a to write them", THEME.overlay)
                ];
            } elif prv is not None {
                verdict = [
                    sp("  Selected changes only: ✗ ", with_bg(THEME.err, 237)),
                    sp(
                        prv.summary()
                            + "   a writes them anyway, f sends these problems back, r rejects",
                        THEME.overlay
                    )
                ];
                for dg in prv.new_errors()[:6] {
                    lines.append(
                        fit(
                            [
                                sp(
                                    f"    {os.path.basename(dg.file)}:{dg.line} {dg.message}",
                                    with_bg(THEME.err, 237)
                                )
                            ],
                            w,
                            THEME.overlay
                        )
                    );
                }
            } else {
                verdict = [
                    sp(
                        "  Selected changes only: not checked "
                            + str(part.get("error", "")),
                        THEME.overlay
                    )
                ];
            }
            lines.insert(1, fit(verdict, w, THEME.overlay));
        }
        if app.gate is not None {
            for ln in review_lines(req.get("review"), w, req.get("keep")) {
                lines.append(ln);
            }
        }
        old = d.get("old_content");
        if old is None {
            old = read_or_empty(path);
        }
        lines += diff_spans(
            unified_diff(path, str(old), str(d.get("content", "")), app.root_dir), w
        );
    }
    app.sheet_lines = lines;
    app.sheet_scroll = 0;
}

impl review_lines(
    review: any, w: int, keep: (set[str] | None) = None
) -> list[list[TextSpan]] {
    out: list[list[TextSpan]] = [];
    bg = 237;
    if review is None {
        out.append(
            fit(
                [
                    sp(
                        "  ⠿ checking the edit with the compiler…",
                        StyleAttrs(fg=179, bg=bg)
                    )
                ],
                w,
                THEME.overlay
            )
        );
        out.append(blank(w, THEME.overlay));
        return out;
    }
    took = f"checked {len(review.checked_files)} file(s) in {review.elapsed:.1f}s";
    if not review.checked {
        out.append(
            fit(
                [
                    sp(
                        f"  ⚠ could not check the edit: {review.check_error}",
                        StyleAttrs(fg=221, bg=bg)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    } elif review.clean() {
        out.append(
            fit(
                [
                    sp("  ✔ compiles clean  ", StyleAttrs(fg=114, bg=bg, bold=True)),
                    sp(took, StyleAttrs(fg=244, bg=bg))
                ],
                w,
                THEME.overlay
            )
        );
    } else {
        out.append(
            fit(
                [
                    sp(
                        f"  ✖ {len(review.new_errors())} new error(s)  ",
                        StyleAttrs(fg=203, bg=bg, bold=True)
                    ),
                    sp(took, StyleAttrs(fg=244, bg=bg))
                ],
                w,
                THEME.overlay
            )
        );
    }
    leaves = leaf_changes(review.symbol_changes);
    leaf_keys = [lc.key for lc in leaves];
    for sc in review.symbol_changes[:12] {
        mark = {"added": "+", "removed": "-"}.get(sc.change, "~");
        col = {"added": 114, "removed": 203}.get(sc.change, 179);
        pubtag = "  (public)" if sc.public else "";
        box = "      ";
        if sc.key in leaf_keys and len(leaves) > 1 {
            n = leaf_keys.index(sc.key) + 1;
            on = keep is None or sc.key in keep;
            box = f" {n if n < 10 else ' '} {'☑' if on else '☐'} ";
            if not on {
                col = 244;
            }
        }
        out.append(
            fit(
                [
                    sp(
                        f"  {box}{mark} {sc.kind} {sc.key} {sc.change}{pubtag}",
                        StyleAttrs(fg=col, bg=bg)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    if len(review.symbol_changes) > 10 {
        out.append(
            fit(
                [
                    sp(
                        f"    … {len(review.symbol_changes)
                            - 10} more symbol change(s)",
                        StyleAttrs(fg=244, bg=bg)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    if review.arch_changes {
        out.append(
            fit(
                [
                    sp(
                        "  ⚖ architecture change: approve it separately with A",
                        StyleAttrs(fg=255, bg=94, bold=True)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    for ac in review.arch_changes[:8] {
        out.append(
            fit(
                [
                    sp(
                        f"    ⚖ architecture {ac.kind}: {ac.detail}",
                        StyleAttrs(fg=221, bg=bg, bold=True)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    for dg in review.new_diagnostics[:8] {
        col = 203 if dg.severity == "error" else 221;
        out.append(
            fit(
                [sp(f"    {dg.short(review.root_dir)}", StyleAttrs(fg=col, bg=bg))],
                w,
                THEME.overlay
            )
        );
    }
    if review.resolved_diagnostics {
        out.append(
            fit(
                [
                    sp(
                        f"    ✓ fixes {len(
                            review.resolved_diagnostics
                        )} existing diagnostic(s)",
                        StyleAttrs(fg=114, bg=bg)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    out.append(blank(w, THEME.overlay));
    return out;
}

impl approval_view(app: Studio, w: int, h: int) -> list[list[TextSpan]] {
    out: list[list[TextSpan]] = [];
    if not app.pending {
        return [blank(w, THEME.overlay)];
    }
    req = app.pending[0];
    head = app.sheet_lines[:1];
    body = app.sheet_lines[1:];
    out += head;
    if len(app.pending) > 1 {
        out.append(
            fit(
                [
                    sp(
                        f"  ({len(app.pending) - 1} more waiting)",
                        with_bg(THEME.dim, 237)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    room = h - len(out) - 2;
    top = min(app.sheet_scroll, max(0, len(body) - room));
    app.sheet_scroll = top;
    out += body[top:top + room];
    while len(out) < h - 2 {
        out.append(blank(w, THEME.overlay));
    }
    if req["type"] == "permission" {
        opts = req["data"].get("options") or [];
        spans = [sp(" ", THEME.overlay)];
        for (i, o) in enumerate(opts[:9]) {
            k = str(o.get("kind", ""));
            a = StyleAttrs(fg=255, bg=28, bold=True)
                if k.startswith("allow")
                else StyleAttrs(fg=255, bg=124, bold=True);
            spans.append(sp(f" {i + 1} {o.get('name', k)} ", a));
            spans.append(sp(" ", THEME.overlay));
        }
        out.append(fit(spans, w, THEME.overlay));
        out.append(
            fit(
                [
                    sp(
                        " Enter/a allow · r reject · Esc cancel · ↑↓ scroll",
                        StyleAttrs(fg=244, bg=237)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    } else {
        out.append(
            fit(
                [
                    sp(" ", THEME.overlay),
                    sp(accept_label(req), StyleAttrs(fg=255, bg=28, bold=True)),
                    sp(" ", THEME.overlay),
                    sp(" r reject ", StyleAttrs(fg=255, bg=124, bold=True)),
                    sp(" ", THEME.overlay),
                    sp(
                        " f reject and send the problems back ",
                        StyleAttrs(fg=255, bg=130, bold=True)
                    )
                ],
                w,
                THEME.overlay
            )
        );
        out.append(
            fit(
                [
                    sp(
                        " 1-9 toggle a symbol · ↑↓ PgUp PgDn scroll the diff",
                        StyleAttrs(fg=244, bg=237)
                    )
                ],
                w,
                THEME.overlay
            )
        );
    }
    return out[:h];
}

impl next_approval(app: Studio) {
    if app.pending {
        app.pending.pop(0);
    }
    close_sheet(app);
    if app.pending {
        open_approval(app);
    }
}

impl finish_permission(app: Studio, req: dict[str, any], option_id: (str | None)) {
    d = req["data"];
    try {
        app.agent.respond_permission(d.get("request_id"), option_id);
    } except Exception as e {
        app.say(f"could not answer the agent: {e}", "error");
    }
    tc = d.get("tool_call") or {};
    accepted = option_id is not None
        and any(
            [
                o.get("optionId") == option_id
                    and str(o.get("kind", "")).startswith("allow")
                for o in (d.get("options") or [])
            ]
        );
    if app.rec is not None {
        try {
            app.rec.decide("permission", accepted, message=str(tc.get("title", "")));
        } except Exception {}
    }
    app.say(
        ("allowed: " if accepted else "rejected: ") + str(tc.get("title", "")),
        "ok" if accepted else "warn"
    );
    next_approval(app);
}

impl finish_write(app: Studio, req: dict[str, any], accept: bool, message: str) {
    d = req["data"];
    try {
        app.agent.resolve_write(d.get("request_id"), accept, message);
    } except Exception as e {
        app.say(f"could not answer the agent: {e}", "error");
    }
    path = str(d.get("path", ""));
    review = req.get("review");
    with REVIEW_LOCK {
        req["cancelled"] = True;
    }
    if app.gate is not None and path {
        try {
            app.gate.unstage(path);
        } except Exception {}
        if not accept {
            rerun_reviews(app, req, path);
        }
    }
    if accept and review is not None {
        mark_changed(app, path, review);
    }
    if accept and path.endswith(".jac") and app.model.module_for_file(path) is None {
        app.last_stale_check = 0.0;
        app.pending_new.append(path);
    }
    if app.intel is not None and path {
        try {
            app.intel.invalidate(path);
        } except Exception {}
    }
    if app.rec is not None {
        try {
            app.rec.decide(
                "write",
                accept,
                path=path,
                message=message,
                detail=(review.summary() if review is not None else "")
            );
        } except Exception {}
    }
    rel = os.path.relpath(path, app.root_dir) if path else "?";
    app.say(
        ("wrote " if accept else "rejected the edit to ") + rel,
        "ok" if accept else "warn"
    );
    if accept and path == app.code_path {
        load_code(app, path, keep_pos=True);
    }
    next_approval(app);
}

impl wire_ref(w: WireInfo) -> str {
    scope = f".{w.scope}" if w.scope else "";
    return f"wire:{w.provider}->{w.consumer}{scope}";
}

impl map_sig(app: Studio) -> tuple[int, int, int] {
    m = app.model;
    return (id(m.wires), len(m.wires), len(m.modules));
}

impl deliver(app: Studio, blocks: list[dict[str, any]]) -> None {
    if app.restored_transcript {
        blocks = [{"type": "text", "text": app.restored_transcript}] + blocks;
        app.restored_transcript = "";
    }
    app.agent.prompt(blocks);
}


impl write_feedback(req: dict[str, any]) -> str {
    part = req.get("partial");
    keep = req.get("keep");
    if part is not None
        and part["done"]
        and keep is not None
        and part["keep"] == frozenset(keep) {
        prv = part.get("review");
        if prv is not None and not prv.clean() {
            try {
                return f"The user kept only part of this edit ({', '.join(
                    sorted(keep)
                )}) and that selection does not compile. "
                    + str(prv.feedback());
            } except Exception {}
        }
    }
    review = req.get("review");
    if review is not None {
        try {
            return str(review.feedback());
        } except Exception {}
    }
    return "The user rejected this edit in jac hack. Check that it compiles and keeps the archwire wiring valid, then try again.";
}

impl restore_session(app: Studio, session_id: str) -> None {
    rec = load_session(app.root_dir, session_id);
    if rec is None {
        app.say(f"no saved session matches {session_id}", "error", 6.0);
        return;
    }
    app.rec = rec;
    app.session_id = rec.id;
    if rec.agent and not app.agent_name {
        app.agent_name = rec.agent;
    }
    app.tray = [k for k in rec.tray];
    for en in rec.entries {
        role = str(en.get("role", "system"));
        tc = en.get("tool_call") or {};
        if role == "tool" {
            app.chat.append(
                ChatEntry(
                    role="tool",
                    title=str(tc.get("title", "")),
                    status=str(tc.get("status", "")),
                    kind=str(tc.get("kind", ""))
                )
            );
        } else {
            app.chat.append(
                ChatEntry(
                    role=role
                        if role in ["user", "agent", "plan", "thought"]
                        else "system",
                    text=str(en.get("text", ""))
                )
            );
        }
    }
    app.restored_transcript = transcript_of(rec.entries);
    app.chat.append(
        ChatEntry(
            role="system",
            text=f"resumed session {rec.id[:8]} ({len(rec.entries)} entries)"
        )
    );
}

glob AUTO_KINDS: list[str] = ["read", "search", "think", "fetch"],
     REVIEW_LOCK: any = threading.Lock();

def start_gate_and_bridge(app: Studio, session_id: str);

def auto_permission(app: Studio, d: dict[str, any]) -> bool;

def start_review(app: Studio, req: dict[str, any]) -> None;

def start_partial_review(app: Studio, req: dict[str, any], keep: set[str]) -> None;

def rerun_reviews(app: Studio, req: dict[str, any], path: str) -> None;

def pump_reviews(app: Studio) -> None;

def mark_changed(app: Studio, path: str, review: any);

def pump_bridge(app: Studio) -> None;

def bridge_handle(app: Studio, method: str, params: dict[str, any]) -> any;

def plan_text(app: Studio) -> str;

impl start_gate_and_bridge(app: Studio, session_id: str) {
    gmode = str(app.config.get("gate", "ask"));
    app.gate_mode = gmode if gmode in ["ask", "auto", "strict", "off"] else "ask";
    if app.gate_mode != "off" {
        try {
            app.gate = EditGate(root_dir=app.root_dir);
        } except Exception as e {
            app.gate = None;
            app.say(f"compiler-checked edits are off: {e}", "warn", 6.0);
        }
    }
    try {
        br = BridgeServer(root_dir=app.root_dir, session=(session_id or "studio"));
        br.queries = StudioQueries(
            model=app.model, read_text=(app.gate.read if app.gate is not None else None)
        );
        app.bridge_path = br.start();
        app.bridge = br;
    } except Exception as e {
        app.bridge = None;
        app.bridge_path = "";
        app.say(f"the jac hack tools for agents are off: {e}", "warn", 6.0);
    }
}

impl auto_permission(app: Studio, d: dict[str, any]) -> bool {
    tc = d.get("tool_call") or {};
    title = str(tc.get("title", ""));
    kind = str(tc.get("kind", "") or "");
    idx = app.tool_index.get(str(tc.get("toolCallId", "")), -1);
    if not kind and 0 <= idx < len(app.chat) {
        kind = app.chat[idx].kind;
    }
    raw = str(tc.get("rawInput", ""))[:400];
    tools = "mcp__studio__" in title
        or "mcp__jac__" in title
        or "mcp__studio__" in raw
        or "mcp__jac__" in raw;
    allow = kind in AUTO_KINDS or tools or (kind == "edit" and app.gate is not None);
    extra = app.config.get("auto_allow", []);
    if isinstance(extra, list)
        and (kind in extra or any([str(x) in title for x in extra])) {
        allow = True;
    }
    if not allow {
        return False;
    }
    opt = first_option(d.get("options") or [], ["allow_once", "allow_always"]);
    if opt is None {
        return False;
    }
    try {
        app.agent.respond_permission(d.get("request_id"), opt);
    } except Exception {
        return False;
    }
    app.auto_allowed += 1;
    return True;
}

impl start_review(app: Studio, req: dict[str, any]) -> None {
    gate = app.gate;
    if gate is None {
        req["done"] = True;
        return;
    }
    d = req["data"];
    path = str(d.get("path", ""));
    content = str(d.get("content", ""));
    def cancelled -> bool {
        return bool(req.get("cancelled"));
    }
    def work {
        while True {
            try {
                req["review"] = gate.review(path, content, cancelled);
            } except Exception as e {
                req["error"] = str(e);
            }
            with REVIEW_LOCK {
                if req.get("cancelled") {
                    gate.unstage_if(path, content);
                    req["done"] = True;
                    break;
                }
                if req.pop("recheck", False) {
                    continue;
                }
                req["done"] = True;
                break;
            }
        }
        app.dirty = True;
    }
    threading.Thread(target=work, daemon=True).start();
}

impl start_partial_review(app: Studio, req: dict[str, any], keep: set[str]) -> None {
    rv = req["review"];
    path = str(req["data"].get("path", ""));
    text = partial_text(rv.old_text, rv.new_text, rv.symbol_changes, keep);
    part: dict[str, any] = {
        "keep": frozenset(keep),
        "text": text,
        "done": False,
        "review": None,
        "seen": False
    };
    req["partial"] = part;
    gate = app.gate;
    def cancelled -> bool {
        return bool(req.get("cancelled"));
    }
    def work {
        if gate is not None {
            try {
                part["review"] = gate.review(path, text, cancelled);
            } except Exception as e {
                part["error"] = str(e);
            }
            if req.get("cancelled") {
                gate.unstage_if(path, text);
            }
        }
        part["done"] = True;
        app.dirty = True;
    }
    threading.Thread(target=work, daemon=True).start();
    app.say(
        "Checking just the selected changes; press a again once the verdict is shown",
        "info",
        6.0
    );
    at = app.sheet_scroll;
    open_approval(app);
    app.sheet_scroll = at;
}

impl rerun_reviews(app: Studio, req: dict[str, any], path: str) -> None {
    real = os.path.realpath(path);
    again: list[dict[str, any]] = [];
    with REVIEW_LOCK {
        for other in app.pending {
            if other is req or other.get("type") != "write" {
                continue;
            }
            if not other.get("done") {
                other["recheck"] = True;
                continue;
            }
            rv = other.get("review");
            if rv is None or real not in rv.seen_staged {
                continue;
            }
            for k in ["review", "partial", "keep", "error"] {
                other.pop(k, None);
            }
            other["done"] = False;
            other["seen"] = False;
            again.append(other);
        }
    }
    for other in again {
        start_review(app, other);
    }
}

impl pump_reviews(app: Studio) -> None {
    if not app.pending {
        return;
    }
    req = app.pending[0];
    part = req.get("partial");
    if part is not None and part["done"] and not part["seen"] {
        part["seen"] = True;
        if app.sheet is not None and app.sheet_kind == "approval" {
            at = app.sheet_scroll;
            open_approval(app);
            app.sheet_scroll = at;
        }
    }
    if req.get("type") != "write" or not req.get("done") or req.get("seen") {
        return;
    }
    req["seen"] = True;
    app.dirty = True;
    rv = req.get("review");
    if rv is not None {
        rel = os.path.relpath(rv.path, app.root_dir);
        if not rv.arch_changes and rv.checked {
            if app.gate_mode == "auto" and rv.clean() {
                app.chat.append(
                    ChatEntry(
                        role="system",
                        text=f"accepted a clean edit to {rel}: {rv.summary()}"
                    )
                );
                finish_write(app, req, True, "");
                return;
            }
            if app.gate_mode in ["auto", "strict"] and not rv.clean() {
                app.chat.append(
                    ChatEntry(
                        role="system",
                        text=f"sent an edit to {rel} back: {rv.summary()}"
                    )
                );
                finish_write(app, req, False, rv.feedback());
                return;
            }
        }
    }
    if app.sheet is not None and app.sheet_kind == "approval" {
        keep = app.sheet_scroll;
        open_approval(app);
        app.sheet_scroll = keep;
    }
}

impl mark_changed(app: Studio, path: str, review: any) {
    real = os.path.realpath(path);
    if real not in app.baselines {
        app.baselines[real] = review.old_text;
    }
    app.line_marks[real] = line_changes(app.baselines[real], review.new_text);
    md = app.model.module_for_file(path);
    prefix = md.key if md is not None else "";
    for sc in review.symbol_changes {
        key = f"{prefix}.{sc.key}" if prefix else sc.key;
        app.changed[key] = sc.change;
        if "." in sc.key {
            owner = f"{prefix}.{sc.key.rsplit('.', 1)[0]}"
                if prefix
                else sc.key.rsplit(".", 1)[0];
            app.changed.setdefault(owner, "changed");
        }
    }
    if prefix and review.symbol_changes {
        app.changed.setdefault(prefix, "changed");
    }
}

impl pump_bridge(app: Studio) -> None {
    br = app.bridge;
    if br is None {
        return;
    }
    def handler(method: str, params: dict[str, any]) -> any {
        return bridge_handle(app, method, params);
    }
    try {
        if br.drain(handler) {
            app.dirty = True;
        }
    } except Exception {}
}

impl bridge_handle(app: Studio, method: str, params: dict[str, any]) -> any {
    q = app.bridge.queries;
    if method == "selection" {
        sym = symbol_at_cursor(app) if app.code_path else None;
        return q.selection(
            app.tray,
            code_path=app.code_path,
            cursor=(app.cur_line + 1, app.cur_col),
            cursor_symbol=(sym.key if sym is not None else ""),
            wiring_module=app.wire_mod,
            extra={
                "focused_pane": app.focus,
                "center_view": app.center_mode,
                "map_scope": app.gmap.scope
                    if app.gmap is not None and app.center_mode == "map"
                    else None
            }
        );
    }
    if method == "focus" {
        loc = q.locate(str(params.get("key", "")), int(params.get("line", 0) or 0));
        load_code(app, str(loc["file"]));
        goto_line(app, max(int(loc.get("line", 1) or 1) - 1, 0));
        app.center_mode = "code";
        if loc.get("module") {
            app.wire_mod = str(loc["module"]);
        }
        if loc.get("key") and loc.get("kind") != "file" {
            reveal_in_nav(app, str(loc["key"]));
        }
        note = str(params.get("note", "") or "");
        who = app.agent_name or "the agent";
        app.say(
            f"{who}: {note}" if note else f"{who} is showing {loc.get('key', '')}",
            "info",
            8.0
        );
        return {"ok": True, "shown": loc};
    }
    if method == "link_plan" {
        steps = q.link_plan(params.get("entries") or []);
        app.plan_links = steps;
        if 0 <= app.plan_idx < len(app.chat) {
            app.chat[app.plan_idx].text = plan_text(app);
        }
        return {"ok": True, "steps": steps};
    }
    return q.handle(method, params);
}

impl plan_text(app: Studio) -> str {
    marks = {"completed": "☑", "in_progress": "◐", "pending": "☐"};
    links: dict[str, list[str]] = {};
    for stp in app.plan_links {
        links[str(stp.get("step", ""))] = [str(k) for k in (stp.get("keys") or [])];
    }
    lines: list[str] = [];
    for (i, en) in enumerate(app.plan_entries) {
        content = str(en.get("content", ""));
        line = f"{marks.get(str(en.get('status', '')), '☐')} {content}";
        keys = links.get(str(i), links.get(content, []));
        if keys {
            line += "  → " + ", ".join(keys[:4]);
        }
        lines.append(line);
    }
    return "\n".join(lines);
}

glob TRACE: bool = os.environ.get("JAC_STUDIO_TRACE", "") == "1";

def rel_text(app: Studio, text: str) -> str;

def line_changes(old: str, new: str) -> dict[int, str];

def resize_panes(app: Studio, step: int);

def open_locations(app: Studio, refs: list[str], title: str) -> None;

def open_plan_links(app: Studio) -> None;

def open_changed(app: Studio) -> None;

impl rel_text(app: Studio, text: str) -> str {
    top = app.root_dir.rstrip("/") + "/";
    real = os.path.realpath(app.root_dir).rstrip("/") + "/";
    return text.replace(real, "").replace(top, "");
}

impl line_changes(old: str, new: str) -> dict[int, str] {
    out: dict[int, str] = {};
    sm = difflib.SequenceMatcher(
        None, old.split("\n"), new.split("\n"), autojunk=False
    );
    for (tag, i1, i2, j1, j2) in sm.get_opcodes() {
        if tag == "insert" {
            for j in range(j1, j2) {
                out[j + 1] = "added";
            }
        } elif tag == "replace" {
            for j in range(j1, j2) {
                out[j + 1] = "changed";
            }
        } elif tag == "delete" {
            out.setdefault(j1 + 1, "removed");
        }
    }
    return out;
}

impl resize_panes(app: Studio, step: int) {
    (cols, rows) = screen_size(app);
    if app.focus == "nav" {
        app.nav_w = max(16, min(cols // 2, app.nav_w + 4 * step));
    } else {
        cur = app.side_w;
        if cur <= 0 {
            (rw, rh) = pane_rect(app, app.right);
            cur = rw or (cols - app.nav_w) * 2 // 5;
        }
        grow = -step;
        app.side_w = max(24, min(cols - app.nav_w - 30, cur + 4 * grow));
    }
    app.install_layout();
    app.dirty = True;
}

impl open_locations(app: Studio, refs: list[str], title: str) -> None {
    items: list[PickItem] = [];
    for ref in refs {
        (path, sep, tail) = ref.rpartition(":");
        line = 0;
        if sep and tail.isdigit() {
            line = max(int(tail) - 1, 0);
        } else {
            path = ref;
        }
        nd = app.model.node_for(ref);
        if nd is not None and nd.file {
            path = nd.file;
            line = max(nd.line - 1, 0);
        }
        if not path or not os.path.isfile(path) {
            continue;
        }
        items.append(
            PickItem(
                key=ref,
                label=rel_text(app, ref),
                detail=f"{os.path.relpath(path, app.root_dir)}:{line + 1}",
                kind=(nd.kind if nd is not None else "module"),
                data=(path, line)
            )
        );
    }
    if not items {
        app.say("nothing to open there", "warn");
        return;
    }
    if len(items) == 1 {
        (f, ln) = items[0].data;
        load_code(app, f);
        goto_line(app, ln);
        app.center_mode = "code";
        app.focus = "code";
        return;
    }
    app.loc_items = items;
    open_picker(app, "locations", title, "");
}

impl open_plan_links(app: Studio) -> None {
    refs: list[str] = [];
    for stp in app.plan_links {
        for k in (stp.get("keys") or []) {
            if str(k) not in refs {
                refs.append(str(k));
            }
        }
    }
    if not refs {
        app.say(
            "the plan has no linked code yet (agents link it with studio_link_plan)",
            "warn",
            5.0
        );
        return;
    }
    open_locations(app, refs, "Code the plan touches");
}

impl open_changed(app: Studio) -> None {
    refs = [
        k
        for k in app.changed
        if app.changed[k] != "removed"
    ];
    if not refs {
        app.say("no accepted edits in this session yet", "warn");
        return;
    }
    open_locations(app, refs, "Changed this session");
}

def with_inlays(spans: list[TextSpan], hints: list[tuple[int, str]]) -> list[TextSpan];

impl with_inlays(
    spans: list[TextSpan], hints: list[tuple[int, str]]
) -> list[TextSpan] {
    out: list[TextSpan] = [];
    pending = sorted(hints, key=lambda (h: tuple[int, str]) -> int { h[0] });
    hint_a = StyleAttrs(fg=244, italic=True);
    pos = 0;
    k = 0;
    for s in spans {
        t = s.text;
        start = pos;
        cut = 0;
        while k < len(pending) and pending[k][0] <= start + len(t) {
            at = max(pending[k][0] - start, 0);
            if at > cut {
                out.append(TextSpan(text=t[cut:at], attrs=s.attrs));
            }
            out.append(TextSpan(text=pending[k][1], attrs=hint_a));
            cut = max(cut, at);
            k += 1;
        }
        if cut < len(t) {
            out.append(TextSpan(text=t[cut:], attrs=s.attrs));
        }
        pos += len(t);
    }
    while k < len(pending) {
        out.append(TextSpan(text=pending[k][1], attrs=hint_a));
        k += 1;
    }
    return out;
}

def finish_partial(app: Studio, req: dict[str, any], keep: set[str]) -> None;

impl finish_partial(app: Studio, req: dict[str, any], keep: set[str]) -> None {
    d = req["data"];
    rv = req["review"];
    path = str(d.get("path", ""));
    rel = os.path.relpath(path, app.root_dir);
    part = req.get("partial");
    text = part["text"]
        if part is not None
        else partial_text(rv.old_text, rv.new_text, rv.symbol_changes, keep);
    leaves = leaf_changes(rv.symbol_changes);
    kept = [
        lc.key
        for lc in leaves
        if lc.key in keep
    ];
    dropped = [
        lc.key
        for lc in leaves
        if lc.key not in keep
    ];
    try {
        with open(path, "w", encoding="utf-8") as fh {
            fh.write(text);
        }
    } except OSError as e {
        app.say(f"could not write {rel}: {e}", "error", 6.0);
        return;
    }
    msg = (
        f"The user applied only part of your edit to {rel}. Kept: {', '.join(kept)
            or 'nothing'}. "
        + f"Dropped: {', '.join(
            dropped
        )}. The file on disk now holds just the kept changes; "
        + "read it again before you continue, and do not re-apply the dropped changes unless asked."
    );
    finish_write(app, req, False, msg);
    real = os.path.realpath(path);
    if real not in app.baselines {
        app.baselines[real] = rv.old_text;
    }
    app.line_marks[real] = line_changes(app.baselines[real], text);
    md = app.model.module_for_file(path);
    prefix = md.key if md is not None else "";
    for k in kept {
        app.changed[f"{prefix}.{k}" if prefix else k] = "changed";
    }
    if prefix and kept {
        app.changed.setdefault(prefix, "changed");
    }
    if os.path.realpath(app.code_path) == real {
        load_code(app, path, keep_pos=True);
    }
    app.chat.append(
        ChatEntry(
            role="system",
            text=f"applied {len(kept)} of {len(leaves)} symbol change(s) to {rel}; dropped {', '.join(
                dropped
            )}"
        )
    );
    app.say(f"applied part of the edit to {rel}", "ok");
}

def accept_label(req: dict[str, any]) -> str;

impl accept_label(req: dict[str, any]) -> str {
    rv = req.get("review");
    if rv is not None and rv.arch_changes {
        return " A approve the architecture change and accept ";
    }
    return " a accept selected " if req.get("keep") is not None else " a accept ";
}
