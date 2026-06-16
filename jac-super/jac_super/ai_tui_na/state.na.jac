"""TUI state: one Event per agent bus emit, one TuiState for the whole session."""

obj Event {
    has id: int = 0,
        kind: str = "",
        text: str = "",
        node: str = "";
}

"""One wrapped transcript line: composed text plus the source event's kind so the
renderer can derive its color/attr without reaching back into `events`."""
obj DisplayRow {
    has text: str = "",
        kind: str = "",
        is_continuation: bool = False;
}

obj TuiState {
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
}
