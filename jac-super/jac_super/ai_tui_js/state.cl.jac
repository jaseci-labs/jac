"""TUI state for the JS sidecar: one Event per agent-bus emit, one TuiState per
session. Ported from `ai_tui_na/state.na.jac` + `feed.na.jac` with identical
semantics; projection (build_rows/wrap_event/_wrap_line) is folded in as
TuiState methods + same-module helpers so every call compiles to direct JS (no
cross-module RPC). See PLAN.md Phase 2.
"""

obj:pub Event {
    has id: int = 0,
        kind: str = "",
        text: str = "",
        node: str = "";
}

# One wrapped transcript line: composed text plus the source event's kind so the
# renderer can derive its color/attr without reaching back into `events`.
obj:pub DisplayRow {
    has text: str = "",
        kind: str = "",
        is_continuation: bool = False;
}

def event_prefix(ev: Event) -> str {
    kind = ev.kind;
    if kind == "user" {
        return "> ";
    }
    if kind == "answer" {
        return "  ";
    }
    if kind == "reasoning" {
        return "~ ";
    }
    if kind == "system" {
        return "* ";
    }
    if kind == "error" {
        return "! ";
    }
    if kind == "phase" {
        return "> ";
    }
    if kind == "call" {
        return "# ";
    }
    if kind == "tool_result" {
        return "  | ";
    }
    return "  ";
}

def event_text(ev: Event) -> str {
    kind = ev.kind;
    if kind == "phase" {
        if len(ev.node) > 0 {
            return ev.node;
        }
    }
    return ev.text;
}

# Hard char-wrap one newline-free logical line to `width`, emitting DisplayRows.
# The first row carries `first_pre`; every continuation carries `cont_pre`.
def _wrap_line(
    text: str,
    width: int,
    first_pre: str,
    cont_pre: str,
    kind: str,
    out: list[DisplayRow]
) -> None {
    af = width - len(first_pre);
    if af < 1 {
        af = 1;
    }
    ac = width - len(cont_pre);
    if ac < 1 {
        ac = 1;
    }
    n = len(text);
    if n == 0 {
        # Preserve blank lines as an empty (prefixed) row.
        out.append(DisplayRow(text=first_pre, kind=kind, is_continuation=False));
        return;
    }
    pos: int = 0;
    first: bool = True;
    while pos < n {
        take = af;
        if not first {
            take = ac;
        }
        chunk = text[pos:pos + take];
        row_text = first_pre + chunk;
        if not first {
            row_text = cont_pre + chunk;
        }
        out.append(DisplayRow(text=row_text, kind=kind, is_continuation=not first));
        pos = pos + take;
        first = False;
    }
}

# Project one event into wrapped rows: split on explicit newlines, then wrap each
# logical line. Continuation rows are indented under the gutter.
def wrap_event(ev: Event, width: int, out: list[DisplayRow]) {
    pre = event_prefix(ev);
    cont = "    ";
    body = event_text(ev);
    parts = body.split("\n");
    i: int = 0;
    np = len(parts);
    while i < np {
        _wrap_line(parts[i], width, pre, cont, ev.kind, out);
        i = i + 1;
    }
}

obj:pub TuiState {
    has status: str = "idle",
        active: str = "",
        model_name: str = "",
        needs_key: bool = False,
        key_env: str = "",
        cwd: str = "",
        events: list[Event] = [],
        dirty: bool = True,
        input_buf: str = "",
        # Top visible DISPLAY-ROW index (not an event index).
        viewport_top: int = 0,
        term_rows: int = 24,
        term_cols: int = 80,
        quit_flag: bool = False,
        # Derived layout cache: display_rows is rebuilt from events+width by
        # build_rows() whenever layout_dirty is set or layout_cols drifts from
        # term_cols. follow_tail pins the viewport to the last row (streaming).
        display_rows: list[DisplayRow] = [],
        layout_cols: int = -1,
        layout_dirty: bool = True,
        follow_tail: bool = True;

    def reset_events {
        self.events = [];
        self.display_rows = [];
        self.layout_dirty = True;
        self.follow_tail = True;
        self.viewport_top = 0;
    }

    def upsert_event(ev_id: int, kind: str, text: str, node_name: str) -> None {
        for ev in self.events {
            if ev.id == ev_id {
                ev.text = text;
                ev.kind = kind;
                if len(node_name) > 0 {
                    ev.node = node_name;
                }
                self.layout_dirty = True;
                return;
            }
        }
        new_ev = Event(id=ev_id, kind=kind, text=text, node=node_name);
        self.events.append(new_ev);
        n = len(self.events);
        if n > 2000 {
            self.events = self.events[n - 2000:];
        }
        self.layout_dirty = True;
    }

    # Scrolling operates on display-row indices; clamping against the live
    # transcript height happens in render (which knows the visible height).
    def scroll_up(n: int) {
        if self.viewport_top > n {
            self.viewport_top = self.viewport_top - n;
        } else {
            self.viewport_top = 0;
        }
        # Detaching from the bottom: stop auto-following new rows.
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

    # Rebuild display_rows from events at the current width (term_cols - 4, min
    # 20), matching the renderer's inner content width. Records layout_cols and
    # clears layout_dirty so render skips the rebuild until text/width changes.
    def build_rows {
        width = self.term_cols - 4;
        if width < 20 {
            width = 20;
        }
        rows: list[DisplayRow] = [];
        i: int = 0;
        n = len(self.events);
        while i < n {
            wrap_event(self.events[i], width, rows);
            i = i + 1;
        }
        self.display_rows = rows;
        self.layout_cols = self.term_cols;
        self.layout_dirty = False;
    }
}
