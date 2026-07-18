import from jaclang.cli.ai_tui.session_models {
    SessionContext,
    SessionEntry,
    SessionMutation,
    SessionQuery,
    SessionView
}


obj SessionManager {
    has cwd: str = "",
        entries: list[SessionEntry] = [],
        leaf_id: str = "",
        disposed: bool = False,
        _next: int = 1;

    static def in_memory(cwd: str) -> SessionManager {
        return SessionManager(cwd=cwd);
    }

    static def open(target: any) -> SessionManager {
        cwd = "";
        if hasattr(target, "cwd") {
            cwd = str(target.cwd or "");
        }
        return SessionManager.in_memory(cwd);
    }

    def append(item: SessionMutation) -> SessionEntry {
        if self.disposed {
            raise RuntimeError("SessionManager is disposed");
        }
        eid = "e" + str(self._next);
        self._next += 1;
        parent = item.parent_id or self.leaf_id;
        payload: dict[str, any] = {};
        if item.payload {
            payload = dict(item.payload);
        }
        row = SessionEntry(
            id=eid, kind=item.kind, text=item.text, parent_id=parent, payload=payload
        );
        self.entries.append(row);
        self.leaf_id = eid;
        return row;
    }

    def select_leaf(leaf: str) -> None {
        for e in self.entries {
            if e.id == leaf {
                self.leaf_id = leaf;
                return;
            }
        }
        raise ValueError("unknown entry_id: " + leaf);
    }

    def view(query: SessionQuery) -> SessionView {
        rows = list(self.entries);
        if query.limit > 0 and len(rows) > query.limit {
            rows = rows[len(rows) - query.limit:];
        }
        return SessionView(leaf_id=self.leaf_id, entries=rows);
    }

    def build_context -> SessionContext {
        msgs: list[dict[str, any]] = [];
        for e in self.entries {
            msgs.append({"id": e.id, "kind": e.kind, "text": e.text});
        }
        return SessionContext(cwd=self.cwd, leaf_id=self.leaf_id, messages=msgs);
    }

    def flush -> None {
        return;
    }

    def dispose {
        self.disposed = True;
    }
}
