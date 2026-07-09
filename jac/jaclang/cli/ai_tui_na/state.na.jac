"""Core TUI state: event feed, per-kind styling, autocomplete, and the TuiState root."""
import from .editor { EditorState }
import from .select_list { SelectList, SelectItem }
import from .terminal { Rgb }
import from .theme {
    TH_USER,
    TH_ANSWER,
    TH_REASON,
    TH_SYSTEM,
    TH_LOGO,
    TH_ERROR,
    TH_PHASE,
    TH_CALL,
    TH_RESULT,
    TH_NONE,
    TH_BOLD,
    TH_DIM,
    TH_DIM_ITALIC
}

glob _EVENT_CAP: int = 2000;

# --- event kinds and styling ---

"""Semantic kind of a feed event; drives prefix/color/render mode."""
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

"""How an event's text body is rendered into display rows."""
enum RenderMode { NORMAL = 0, MARKDOWN = 1, TOOL_CALL = 2, TOOL_RESULT = 3, IMAGE = 4 }

"""Presentation attributes for one EventKind: gutter prefix, color, SGR attrs, render mode."""
obj KindStyle {
    has prefix: str = "  ",
        color: Rgb = Rgb(r=200, g=200, b=200),
        attrs: int = TH_NONE,
        mode: RenderMode = RenderMode.NORMAL;
}

"""Style table for the feed: maps an EventKind to its KindStyle."""
def kind_style(kind: EventKind) -> KindStyle {
    match kind {
        case EventKind.USER:
            return KindStyle(prefix="> ", color=TH_USER, attrs=TH_BOLD);
        case EventKind.ANSWER:
            return KindStyle(prefix="  ", color=TH_ANSWER, mode=RenderMode.MARKDOWN);
        case EventKind.REASONING:
            return KindStyle(
                prefix="~ ", color=TH_REASON, attrs=TH_DIM_ITALIC, mode=RenderMode.MARKDOWN
            );
        case EventKind.SYSTEM:
            return KindStyle(prefix="* ", color=TH_SYSTEM);
        case EventKind.LOGO:
            return KindStyle(prefix="", color=TH_LOGO, attrs=TH_BOLD);
        case EventKind.ERROR:
            return KindStyle(prefix="! ", color=TH_ERROR, attrs=TH_BOLD);
        case EventKind.PHASE:
            return KindStyle(prefix="> ", color=TH_PHASE);
        case EventKind.CALL:
            return KindStyle(prefix="# ", color=TH_CALL, mode=RenderMode.TOOL_CALL);
        case EventKind.TOOL_RESULT:
            return KindStyle(
                prefix="  | ", color=TH_RESULT, attrs=TH_DIM, mode=RenderMode.TOOL_RESULT
            );
        case EventKind.IMG:
            return KindStyle(prefix="  ", mode=RenderMode.IMAGE);
        case _:
            return KindStyle();
    }
}

# --- small state enums ---

"""Backend run status as last reported over IPC."""
enum TuiStatus { IDLE = 0, RUNNING = 1, UNKNOWN = 2 }

"""Which modal overlay is showing (when TuiState.overlay_active)."""
enum OverlayKind { PALETTE = 0, MODEL = 1, FILE = 2 }

"""Autocomplete trigger family: slash commands or @-file mentions."""
enum AcKind { NONE = 0, SLASH = 1, AT_FILE = 2 }

# --- autocomplete ---

"""Inline autocomplete popup state: candidate items, selection, and the
prefix/query pair that produced them."""
obj AcState {
    has active: bool = False,
        kind: AcKind = AcKind.NONE,
        items: list[SelectItem] = [],
        selected_idx: int = 0,
        prefix: str = "",
        query: str = "";

    """Close the popup and reset every field to its declared default."""
    def dismiss {
        self.active = False;
        self.kind = AcKind.NONE;
        self.items = [];
        self.selected_idx = 0;
        self.prefix = "";
        self.query = "";
    }

    """Move selection up one item, wrapping to the bottom."""
    def nav_up {
        if not self.items {
            return;
        }
        last = len(self.items) - 1;
        self.selected_idx = self.selected_idx - 1 if self.selected_idx > 0 else last;
    }

    """Move selection down one item, wrapping to the top."""
    def nav_down {
        if not self.items {
            return;
        }
        last = len(self.items) - 1;
        self.selected_idx = self.selected_idx + 1 if self.selected_idx < last else 0;
    }
}

# --- feed records ---

"""One rendered feed line; pre_styled rows carry their own ANSI codes."""
obj DisplayRow {
    has text: str = "",
        kind: EventKind = EventKind.UNKNOWN,
        is_continuation: bool = False,
        pre_styled: bool = False;
}

"""One feed event plus its wrap cache. cache_text_len = -1 means the cache
is invalid; feed re-wraps when (len(text), width) stops matching the keys."""
obj Event {
    has id: int = 0,
        kind: EventKind = EventKind.UNKNOWN,
        text: str = "",
        node: str = "",
        cache_text_len: int = -1,
        cache_width: int = -1,
        cached_rows: list[DisplayRow] = [];
}

# --- root state ---

"""Root mutable state for the TUI: feed events, editor, viewport, overlay,
autocomplete, and terminal geometry. dirty/layout_dirty gate redraw work."""
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

    """Flag both a repaint and a display-row rebuild."""
    def mark_layout_dirty {
        self.dirty = True;
        self.layout_dirty = True;
    }

    """Drop all events and derived rows; snap the viewport back to a tailing top."""
    def reset_events {
        self.events = [];
        self.display_rows = [];
        self.mark_layout_dirty();
        self.follow_tail = True;
        self.viewport_top = 0;
        self.ac.dismiss();
    }

    """Give a locally echoed user event (pending id -1) its server-assigned id.
    Returns True when a matching pending event was adopted."""
    def _adopt_pending_user(ev_id: int, text: str, node_name: str) -> bool {
        for ev in self.events {
            if ev.id == -1 and ev.kind == EventKind.USER and ev.text == text {
                ev.id = ev_id;
                if node_name {
                    ev.node = node_name;
                }
                self.mark_layout_dirty();
                return True;
            }
        }
        return False;
    }

    """Insert or update the event with id ev_id. Server USER events first try to
    adopt the matching locally echoed pending event (id -1) instead of duplicating
    it. Updates invalidate the wrap cache; the feed is capped at _EVENT_CAP."""
    def upsert_event(ev_id: int, kind: EventKind, text: str, node_name: str) {
        if kind == EventKind.USER and ev_id >= 0 {
            if self._adopt_pending_user(ev_id, text, node_name) {
                return;
            }
        }
        for ev in self.events {
            if ev.id == ev_id {
                ev.text = text;
                ev.kind = kind;
                if node_name {
                    ev.node = node_name;
                }
                ev.cache_text_len = -1;
                self.mark_layout_dirty();
                return;
            }
        }
        self.events.append(Event(id=ev_id, kind=kind, text=text, node=node_name));
        overflow = len(self.events) - _EVENT_CAP;
        if overflow > 0 {
            self.events = self.events[overflow:];
        }
        self.mark_layout_dirty();
    }

    """Append streamed delta text to event ev_id, creating it if unknown."""
    def append_to_event(ev_id: int, delta: str) {
        for ev in self.events {
            if ev.id == ev_id {
                ev.text += delta;
                self.mark_layout_dirty();
                return;
            }
        }
        self.upsert_event(ev_id, EventKind.UNKNOWN, delta, "");
    }

    """Scroll the feed up n rows (clamped at the top) and stop tailing."""
    def scroll_up(n: int) {
        self.viewport_top = max(0, self.viewport_top - n);
        self.follow_tail = False;
        self.dirty = True;
    }

    """Scroll the feed down n rows; screen clamps against the row count."""
    def scroll_down(n: int) {
        self.viewport_top += n;
        self.dirty = True;
    }

    """Resume tailing: keep the viewport pinned to the newest rows."""
    def scroll_to_bottom {
        self.follow_tail = True;
        self.dirty = True;
    }
}
