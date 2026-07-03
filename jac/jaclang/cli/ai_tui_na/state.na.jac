import from .select_list { SelectList }
import from .theme {
    TH_USER_R,
    TH_USER_G,
    TH_USER_B,
    TH_ANSWER_R,
    TH_ANSWER_G,
    TH_ANSWER_B,
    TH_REASON_R,
    TH_REASON_G,
    TH_REASON_B,
    TH_SYSTEM_R,
    TH_SYSTEM_G,
    TH_SYSTEM_B,
    TH_LOGO_R,
    TH_LOGO_G,
    TH_LOGO_B,
    TH_ERROR_R,
    TH_ERROR_G,
    TH_ERROR_B,
    TH_PHASE_R,
    TH_PHASE_G,
    TH_PHASE_B,
    TH_CALL_R,
    TH_CALL_G,
    TH_CALL_B,
    TH_RESULT_R,
    TH_RESULT_G,
    TH_RESULT_B,
    TH_NONE,
    TH_BOLD,
    TH_DIM,
    TH_DIM_ITALIC
}

enum EventKind {
    UNKNOWN = 0,
    USER = 1,
    ANSWER = 2,
    REASONING = 3,
    SYSTEM = 4,
    LOGO = 5,
    ERROR = 6,
    PHASE = 7,
    CALL = 8,
    TOOL_RESULT = 9,
    IMG = 10,
    SEP = 11,
}

enum RenderMode { NORMAL = 0, MARKDOWN = 1, TOOL_CALL = 2, TOOL_RESULT = 3, IMAGE = 4 }

obj KindStyle {
    has prefix: str = "  ",
        r: int = 200,
        g: int = 200,
        b: int = 200,
        attrs: int = TH_NONE,
        mode: RenderMode = RenderMode.NORMAL;
}

def kind_style(kind: EventKind) -> KindStyle {
    if kind == EventKind.USER {
        return KindStyle(
            prefix="> ", r=TH_USER_R, g=TH_USER_G, b=TH_USER_B, attrs=TH_BOLD
        );
    }
    if kind == EventKind.ANSWER {
        return KindStyle(
            prefix="  ",
            r=TH_ANSWER_R,
            g=TH_ANSWER_G,
            b=TH_ANSWER_B,
            mode=RenderMode.MARKDOWN
        );
    }
    if kind == EventKind.REASONING {
        return KindStyle(
            prefix="~ ",
            r=TH_REASON_R,
            g=TH_REASON_G,
            b=TH_REASON_B,
            attrs=TH_DIM_ITALIC,
            mode=RenderMode.MARKDOWN
        );
    }
    if kind == EventKind.SYSTEM {
        return KindStyle(prefix="* ", r=TH_SYSTEM_R, g=TH_SYSTEM_G, b=TH_SYSTEM_B);
    }
    if kind == EventKind.LOGO {
        return KindStyle(
            prefix="", r=TH_LOGO_R, g=TH_LOGO_G, b=TH_LOGO_B, attrs=TH_BOLD
        );
    }
    if kind == EventKind.ERROR {
        return KindStyle(
            prefix="! ", r=TH_ERROR_R, g=TH_ERROR_G, b=TH_ERROR_B, attrs=TH_BOLD
        );
    }
    if kind == EventKind.PHASE {
        return KindStyle(prefix="> ", r=TH_PHASE_R, g=TH_PHASE_G, b=TH_PHASE_B);
    }
    if kind == EventKind.CALL {
        return KindStyle(
            prefix="# ",
            r=TH_CALL_R,
            g=TH_CALL_G,
            b=TH_CALL_B,
            mode=RenderMode.TOOL_CALL
        );
    }
    if kind == EventKind.TOOL_RESULT {
        return KindStyle(
            prefix="  | ",
            r=TH_RESULT_R,
            g=TH_RESULT_G,
            b=TH_RESULT_B,
            attrs=TH_DIM,
            mode=RenderMode.TOOL_RESULT
        );
    }
    if kind == EventKind.IMG {
        return KindStyle(prefix="  ", mode=RenderMode.IMAGE);
    }
    return KindStyle();
}

enum TuiStatus { IDLE = 0, RUNNING = 1, UNKNOWN = 2, }

enum OverlayKind { PALETTE = 0, MODEL = 1, FILE = 2, }

enum AcKind { NONE = 0, SLASH = 1, AT_FILE = 2, }

obj AcItem {
    has value: str = "",
        label: str = "",
        description: str = "";
}

obj AcState {
    has active: bool = False,
        kind: AcKind = AcKind.NONE,
        items: list[AcItem] = [],
        selected_idx: int = 0,
        prefix: str = "",
        query: str = "";

    def dismiss {
        self.active = False;
        self.kind = AcKind.NONE;
        self.items = [];
        self.selected_idx = 0;
        self.prefix = "";
        self.query = "";
    }

    def nav_up {
        n = len(self.items);
        if n == 0 {
            return;
        }
        if self.selected_idx > 0 {
            self.selected_idx = self.selected_idx - 1;
        } else {
            self.selected_idx = n - 1;
        }
    }

    def nav_down {
        n = len(self.items);
        if n == 0 {
            return;
        }
        if self.selected_idx < n - 1 {
            self.selected_idx = self.selected_idx + 1;
        } else {
            self.selected_idx = 0;
        }
    }
}

obj EditorState {
    has lines: list[str] = [""],
        cursor_line: int = 0,
        cursor_col: int = 0,
        scroll_offset: int = 0,
        history: list[str] = [],
        history_idx: int = -1,
        history_draft_lines: list[str] = [""],
        history_draft_line: int = 0,
        history_draft_col: int = 0;

    def get_text -> str {
        result: str = "";
        i: int = 0;
        n = len(self.lines);
        while i < n {
            if i > 0 {
                result = result + "\n";
            }
            result = result + self.lines[i];
            i = i + 1;
        }
        return result;
    }

    def text_len -> int {
        total: int = 0;
        i: int = 0;
        n = len(self.lines);
        while i < n {
            total = total + len(self.lines[i]);
            i = i + 1;
        }
        if n > 1 {
            total = total + (n - 1);
        }
        return total;
    }

    def clear {
        self.lines = [""];
        self.cursor_line = 0;
        self.cursor_col = 0;
        self.scroll_offset = 0;
        self.history_idx = -1;
    }
}

obj DisplayRow {
    has text: str = "",
        kind: EventKind = EventKind.UNKNOWN,
        is_continuation: bool = False,
        pre_styled: bool = False;
}

obj Event {
    has id: int = 0,
        kind: EventKind = EventKind.UNKNOWN,
        text: str = "",
        node: str = "",
        cache_text_len: int = -1,
        cache_width: int = -1,
        cached_rows: list[DisplayRow] = [];
}

obj TuiState {
    has status: TuiStatus = TuiStatus.IDLE,
        active: str = "",
        model_name: str = "",
        needs_key: bool = False,
        key_env: str = "",
        cwd: str = "",
        events: list[Event] = [],
        dirty: bool = True,
        editor: EditorState = EditorState(),
        viewport_top: int = 0,
        term_rows: int = 24,
        term_cols: int = 80,
        quit_flag: bool = False,
        render_fd: int = -1,
        ipc_fd: int = -1,
        display_rows: list[DisplayRow] = [],
        layout_cols: int = -1,
        layout_dirty: bool = True,
        follow_tail: bool = True,
        overlay_active: bool = False,
        overlay_kind: OverlayKind = OverlayKind.PALETTE,
        overlay_title: str = "",
        overlay_filter: str = "",
        overlay_full_redraw: bool = False,
        select_list: SelectList = SelectList(),
        files: list[str] = [],
        model_presets: list[str] = [],
        ac: AcState = AcState();

    def mark_layout_dirty {
        self.dirty = True;
        self.layout_dirty = True;
    }

    def reset_events {
        self.events = [];
        self.display_rows = [];
        self.mark_layout_dirty();
        self.follow_tail = True;
        self.viewport_top = 0;
        self.ac.dismiss();
    }

    def upsert_event(ev_id: int, kind: EventKind, text: str, node_name: str) -> None {
        if kind == EventKind.USER and ev_id >= 0 {
            for ev in self.events {
                if ev.id == -1 and ev.kind == EventKind.USER and ev.text == text {
                    ev.id = ev_id;
                    if len(node_name) > 0 {
                        ev.node = node_name;
                    }
                    self.mark_layout_dirty();
                    return;
                }
            }
        }

        for ev in self.events {
            if ev.id == ev_id {
                ev.text = text;
                ev.kind = kind;
                if len(node_name) > 0 {
                    ev.node = node_name;
                }

                ev.cache_text_len = -1;
                self.mark_layout_dirty();
                return;
            }
        }
        new_ev = Event(id=ev_id, kind=kind, text=text, node=node_name);
        self.events.append(new_ev);
        n = len(self.events);
        if n > 2000 {
            self.events = self.events[n - 2000:];
        }
        self.mark_layout_dirty();
    }

    def append_to_event(ev_id: int, delta: str) -> None {
        for ev in self.events {
            if ev.id == ev_id {
                ev.text = ev.text + delta;
                self.mark_layout_dirty();
                return;
            }
        }
        self.upsert_event(ev_id, EventKind.UNKNOWN, delta, "");
    }

    def scroll_up(n: int) {
        if self.viewport_top > n {
            self.viewport_top = self.viewport_top - n;
        } else {
            self.viewport_top = 0;
        }

        self.follow_tail = False;
        self.dirty = True;
    }

    def scroll_down(n: int) {
        self.viewport_top = self.viewport_top + n;
        self.dirty = True;
    }

    def scroll_to_bottom {
        self.follow_tail = True;
        self.dirty = True;
    }
}
