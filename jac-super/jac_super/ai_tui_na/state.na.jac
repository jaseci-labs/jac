"""TUI state: one Event per agent bus emit, one TuiState for the whole session."""

obj Event {
    has id: int = 0,
        kind: str = "",
        text: str = "",
        node: str = "";
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
        viewport_top: int = 0,
        term_rows: int = 24,
        term_cols: int = 80,
        quit_flag: bool = False;

    def reset_events {
        self.events = [];
    }

    def upsert_event(ev_id: int, kind: str, text: str, node_name: str) -> None {
        for ev in self.events {
            if ev.id == ev_id {
                ev.text = text;
                ev.kind = kind;
                if len(node_name) > 0 {
                    ev.node = node_name;
                }
                return;
            }
        }
        new_ev = Event(id=ev_id, kind=kind, text=text, node=node_name);
        self.events.append(new_ev);
        n = len(self.events);
        if n > 2000 {
            self.events = self.events[n - 2000:];
        }
    }

    def scroll_up(n: int) {
        if self.viewport_top > n {
            self.viewport_top = self.viewport_top - n;
        } else {
            self.viewport_top = 0;
        }
        self.dirty = True;
    }

    def scroll_down(n: int) {
        self.viewport_top = self.viewport_top + n;
        self.dirty = True;
    }

    def scroll_to_bottom {
        self.viewport_top = 999999;
        self.dirty = True;
    }
}
