import os;
import json;
import secrets;
import time;

glob SESSION_ROLES: list[str] = ["user", "agent", "tool", "plan", "system"],
     SESSION_FORMAT: int = 1;

node SessionRec {
    has sid: str = "",
        title: str = "",
        agent: str = "",
        agent_session_id: str = "",
        parent: str = "",
        created: float = 0.0,
        updated: float = 0.0,
        tray: list[str] = [];
}

node EntryRec {
    has seq: int = 0,
        role: str = "",
        text: str = "",
        time: float = 0.0,
        extra: dict[str, any] = {};
}

node DecisionRec {
    has seq: int = 0,
        kind: str = "",
        accepted: bool = False,
        path: str = "",
        message: str = "",
        detail: str = "",
        time: float = 0.0;
}

edge HasEntry: SessionRec --> EntryRec {}

edge HasDecision: SessionRec --> DecisionRec {}

edge ForkedFrom: SessionRec --> SessionRec {}

obj StudioSession {
    has id: str = "",
        root_dir: str = "",
        created: float = 0.0,
        updated: float = 0.0,
        agent: str = "",
        agent_session_id: str = "",
        title: str = "",
        parent: str = "",
        entries: list[dict[str, any]] = [],
        tray: list[str] = [],
        decisions: list[dict[str, any]] = [],
        _streaming: bool = False;

    def postinit;
    def path -> str;
    def add(
        role: str, text: str, tool_call: (dict[str, any] | None) = None
    ) -> dict[str, any];

    def append_text(role: str, text: str) -> dict[str, any];
    def record(ev: AgentEvent) -> None;
    def tool_entry(tool_id: str) -> (dict[str, any] | None);
    def decide(
        kind: str, accepted: bool, path: str = "", message: str = "", detail: str = ""
    ) -> dict[str, any];

    def save -> str;
    def to_dict -> dict[str, any];
    def summary -> dict[str, any];
    def fork -> StudioSession;
}

def new_session_id -> str;

def sessions_dir(root_dir: str) -> str;

def new_session(root_dir: str, agent: str = "", title: str = "") -> StudioSession;

def session_from_dict(root_dir: str, d: dict[str, any]) -> StudioSession;

def load_session(root_dir: str, session_id: str) -> (StudioSession | None);

def list_sessions(root_dir: str) -> list[dict[str, any]];

def fork_session(root_dir: str, session_id: str) -> (StudioSession | None);

def transcript_of(entries: list[dict[str, any]]) -> str;

def with_store(root_dir: str, fn: any) -> any;

def _import_json(root_dir: str, top: any) -> None;

def _find(top: any, session_id: str) -> (SessionRec | None);

def _write(top: any, sess: StudioSession) -> SessionRec;

def _read(root_dir: str, rec: SessionRec) -> StudioSession;

impl StudioSession.postinit {
    if not self.id {
        self.id = new_session_id();
    }
    now = time.time();
    if not self.created {
        self.created = now;
    }
    if not self.updated {
        self.updated = self.created;
    }
}

impl StudioSession.path -> str {
    return os.path.join(sessions_dir(self.root_dir), f"{self.id}.json");
}

impl StudioSession.add(
    role: str, text: str, tool_call: (dict[str, any] | None) = None
) -> dict[str, any] {
    if role not in SESSION_ROLES {
        role = "system";
    }
    ent: dict[str, any] = {"role": role, "text": text, "time": time.time()};
    if tool_call is not None {
        ent["tool_call"] = tool_call;
    }
    self.entries.append(ent);
    self._streaming = False;
    self.updated = ent["time"];
    if role == "user" and not self.title {
        self.title = " ".join(text.split())[:80];
    }
    return ent;
}

impl StudioSession.append_text(role: str, text: str) -> dict[str, any] {
    last = self.entries[-1] if self.entries else None;
    if self._streaming
        and last is not None
        and last.get("role") == role
        and "tool_call" not in last {
        last["text"] = last.get("text", "") + text;
        self.updated = time.time();
        return last;
    }
    ent = self.add(role, text);
    self._streaming = True;
    return ent;
}

impl StudioSession.record(ev: AgentEvent) -> None {
    d = ev.data;
    if ev.kind == "message_chunk" {
        self.append_text("agent", str(d.get("text", "")));
    } elif ev.kind == "tool_call" and self.tool_entry(str(d.get("id", ""))) is None {
        tc = {
            "id": d.get("id", ""),
            "title": d.get("title", ""),
            "kind": d.get("kind", ""),
            "status": d.get("status", ""),
            "locations": d.get("locations") or []
        };
        if "raw_input" in d {
            tc["raw_input"] = d["raw_input"];
        }
        self.add("tool", str(d.get("title", "")), tc);
    } elif ev.kind in ["tool_call", "tool_call_update"] {
        e = self.tool_entry(str(d.get("id", "")));
        if e is not None {
            prev: any = e.get("tool_call");
            for k in ["title", "kind", "status", "locations", "raw_input"] {
                if d.get(k) is not None {
                    prev[k] = d[k];
                }
            }
            if d.get("title") {
                e["text"] = str(d["title"]);
            }
        }
        self.updated = time.time();
    } elif ev.kind == "plan" {
        entries = d.get("entries") or [];
        text = "\n".join(
            [f"[{p.get('status', '')}] {p.get('content', '')}" for p in entries]
        );
        last = self.entries[-1] if self.entries else None;
        if last is not None and last.get("role") == "plan" {
            last["text"] = text;
            last["plan"] = entries;
        } else {
            self.add("plan", text)["plan"] = entries;
        }
    } elif ev.kind == "error" {
        self.add("system", "error: " + str(d.get("message", "")));
    } elif ev.kind == "turn_end" {
        self._streaming = False;
        reason = str(d.get("stop_reason", ""));
        if reason and reason != "end_turn" {
            self.add("system", f"turn ended: {reason}");
        }
    } elif ev.kind == "ready" {
        if d.get("session_id") {
            self.agent_session_id = str(d["session_id"]);
        }
    }
}

impl StudioSession.decide(
    kind: str, accepted: bool, path: str = "", message: str = "", detail: str = ""
) -> dict[str, any] {
    dec: dict[str, any] = {
        "kind": kind,
        "accepted": accepted,
        "path": path,
        "message": message,
        "time": time.time()
    };
    if detail {
        dec["detail"] = detail;
    }
    self.decisions.append(dec);
    self.updated = dec["time"];
    return dec;
}


impl StudioSession.to_dict -> dict[str, any] {
    return {
        "format": SESSION_FORMAT,
        "id": self.id,
        "title": self.title,
        "created": self.created,
        "updated": self.updated,
        "agent": self.agent,
        "agent_session_id": self.agent_session_id,
        "parent": self.parent,
        "tray": self.tray,
        "entries": self.entries,
        "decisions": self.decisions
    };
}

impl StudioSession.summary -> dict[str, any] {
    return {
        "id": self.id,
        "title": self.title,
        "agent": self.agent,
        "created": self.created,
        "updated": self.updated,
        "entries": len(self.entries),
        "tray": self.tray,
        "parent": self.parent
    };
}

impl StudioSession.fork -> StudioSession {
    data = json.loads(json.dumps(self.to_dict(), `default=str));
    child = session_from_dict(self.root_dir, data);
    child.id = new_session_id();
    child.parent = self.id;
    child.agent_session_id = "";
    child.created = time.time();
    child.updated = child.created;
    return child;
}

impl new_session_id -> str {
    return time.strftime("%Y%m%d-%H%M%S") + "-" + secrets.token_hex(2);
}

impl sessions_dir(root_dir: str) -> str {
    return os.path.join(root_dir, ".jac", "studio", "sessions");
}

impl new_session(root_dir: str, agent: str = "", title: str = "") -> StudioSession {
    return StudioSession(root_dir=os.path.realpath(root_dir), agent=agent, title=title);
}

impl session_from_dict(root_dir: str, d: dict[str, any]) -> StudioSession {
    return StudioSession(
        id=str(d.get("id", "")),
        root_dir=os.path.realpath(root_dir),
        created=float(d.get("created", 0.0) or 0.0),
        updated=float(d.get("updated", 0.0) or 0.0),
        agent=str(d.get("agent", "")),
        agent_session_id=str(d.get("agent_session_id", "")),
        title=str(d.get("title", "")),
        parent=str(d.get("parent", "")),
        entries=list(d.get("entries") or []),
        tray=[str(k) for k in (d.get("tray") or [])],
        decisions=list(d.get("decisions") or [])
    );
}


impl StudioSession.tool_entry(tool_id: str) -> (dict[str, any] | None) {
    for e in reversed(self.entries) {
        tc = e.get("tool_call");
        if isinstance(tc, dict) and str(tc.get("id", "")) == tool_id {
            return e;
        }
    }
    return None;
}

impl StudioSession.save -> str {
    sess = self;
    def put(top: any) -> str {
        _write(top, sess);
        return sess.id;
    }
    return with_store(self.root_dir, put);
}

impl with_store(root_dir: str, fn: any) -> any {
    base = os.path.join(os.path.realpath(root_dir), ".jac", "studio");
    os.makedirs(base, exist_ok=True);
    for cls in [SessionRec, EntryRec, DecisionRec, HasEntry, HasDecision, ForkedFrom] {
        Serializer.register(cls);
    }
    ctx = JacRuntime.create_j_context(
        None, base_path_dir=base, full_target_path=os.path.join(base, "sessions.jac")
    );
    token = JacRuntime.push_request_context(ctx);
    try {
        top = ctx.get_root();
        _import_json(root_dir, top);
        out = fn(top);
        ctx.mem.commit();
        return out;
    } finally {
        JacRuntime.reset_request_context(token);
        ctx.close();
    }
}

impl _import_json(root_dir: str, top: any) -> None {
    d = sessions_dir(root_dir);
    if not os.path.isdir(d) {
        return;
    }
    for f in sorted(os.listdir(d)) {
        if not f.endswith(".json") {
            continue;
        }
        path = os.path.join(d, f);
        try {
            with open(path, encoding="utf-8") as fh {
                data = json.load(fh);
            }
        } except (OSError, ValueError) {
            continue;
        }
        if isinstance(data, dict) and _find(top, str(data.get("id", ""))) is None {
            _write(top, session_from_dict(root_dir, data));
        }
        os.replace(path, path + ".imported");
    }
}

impl _find(top: any, session_id: str) -> (SessionRec | None) {
    if not session_id {
        return None;
    }
    recs = [top-->[?:SessionRec]];
    for r in recs {
        if r.sid == session_id {
            return r;
        }
    }
    hits = [
        r
        for r in recs
        if r.sid.startswith(session_id)
    ];
    return hits[0] if len(hits) == 1 else None;
}

impl _write(top: any, sess: StudioSession) -> SessionRec {
    rec = _find(top, sess.id);
    if rec is None or rec.sid != sess.id {
        rec = SessionRec(sid=sess.id);
        home: Root = top;
        home ++> rec;
        if sess.parent {
            parent = _find(top, sess.parent);
            if parent is not None {
                rec +>:ForkedFrom():+> parent;
            }
        }
    }
    rec.title = sess.title;
    rec.agent = sess.agent;
    rec.agent_session_id = sess.agent_session_id;
    rec.parent = sess.parent;
    rec.created = sess.created;
    rec.updated = sess.updated;
    rec.tray = list(sess.tray);
    old: dict[int, EntryRec] = {};
    for er in [rec->:HasEntry:->] {
        old[er.seq] = er;
    }
    for (seq, er) in old.items() {
        if seq >= len(sess.entries) {
            del er;
        }
    }
    for (i, ent) in enumerate(sess.entries) {
        extra = {
            k: v
            for (k, v) in ent.items()
            if k not in ["role", "text", "time"]
        };
        prev = old.get(i);
        if prev is not None {
            if prev.text == str(ent.get("text", "")) and prev.extra == extra {
                continue;
            }
            del prev;
        }
        rec +>:HasEntry():+> EntryRec(
            seq=i,
            role=str(ent.get("role", "")),
            text=str(ent.get("text", "")),
            time=float(ent.get("time", 0.0) or 0.0),
            extra=extra
        );
    }
    for dr in [rec->:HasDecision:->] {
        del dr;
    }
    for (i, dec) in enumerate(sess.decisions) {
        rec +>:HasDecision():+> DecisionRec(
            seq=i,
            kind=str(dec.get("kind", "")),
            accepted=bool(dec.get("accepted", False)),
            path=str(dec.get("path", "")),
            message=str(dec.get("message", "")),
            detail=str(dec.get("detail", "")),
            time=float(dec.get("time", 0.0) or 0.0)
        );
    }
    return rec;
}

impl _read(root_dir: str, rec: SessionRec) -> StudioSession {
    by_seq: dict[int, EntryRec] = {};
    for er in [rec->:HasEntry:->] {
        by_seq[er.seq] = er;
    }
    entries: list[dict[str, any]] = [];
    for i in sorted(by_seq) {
        er = by_seq[i];
        ent: dict[str, any] = {"role": er.role, "text": er.text, "time": er.time};
        ent.update(er.extra or {});
        entries.append(ent);
    }
    decisions = [
        {
            "kind": dr.kind,
            "accepted": dr.accepted,
            "path": dr.path,
            "message": dr.message,
            "detail": dr.detail,
            "time": dr.time
        } for dr in sorted([rec->:HasDecision:->], key=lambda (x: any) -> int { x.seq })
    ];
    return StudioSession(
        id=rec.sid,
        root_dir=os.path.realpath(root_dir),
        created=rec.created,
        updated=rec.updated,
        agent=rec.agent,
        agent_session_id=rec.agent_session_id,
        title=rec.title,
        parent=rec.parent,
        entries=entries,
        tray=list(rec.tray),
        decisions=decisions
    );
}

impl load_session(root_dir: str, session_id: str) -> (StudioSession | None) {
    def get(top: any) -> (StudioSession | None) {
        rec = _find(top, session_id);
        return _read(root_dir, rec) if rec is not None else None;
    }
    return with_store(root_dir, get);
}

impl list_sessions(root_dir: str) -> list[dict[str, any]] {
    def collect(top: any) -> list[dict[str, any]] {
        out: list[dict[str, any]] = [];
        for rec in [top-->[?:SessionRec]] {
            out.append(
                {
                    "id": rec.sid,
                    "title": rec.title,
                    "agent": rec.agent,
                    "created": rec.created,
                    "updated": rec.updated,
                    "entries": len([rec->:HasEntry:->]),
                    "tray": list(rec.tray),
                    "parent": rec.parent
                }
            );
        }
        out.sort(
            key=lambda (x: dict[str, any]) -> float { -float(x.get("updated", 0.0)) }
        );
        return out;
    }
    return with_store(root_dir, collect);
}

impl fork_session(root_dir: str, session_id: str) -> (StudioSession | None) {
    src = load_session(root_dir, session_id);
    if src is None {
        return None;
    }
    child = src.fork();
    child.save();
    return child;
}

impl transcript_of(entries: list[dict[str, any]]) -> str {
    said: list[str] = [];
    for en in entries {
        role = str(en.get("role", ""));
        text = str(en.get("text", "")).strip();
        if role not in ["user", "agent"] or not text {
            continue;
        }
        if len(text) > 1500 {
            text = text[:1500] + " …";
        }
        said.append(("User: " if role == "user" else "Assistant: ") + text);
    }
    if not said {
        return "";
    }
    kept: list[str] = [];
    size = 0;
    for line in reversed(said[-40:]) {
        if size + len(line) > 15000 {
            break;
        }
        kept.insert(0, line);
        size += len(line);
    }
    return "This conversation continues an earlier jac studio session. You do not have its history, so here is what was said, oldest first:\n\n"
        + "\n\n".join(kept)
        + "\n\nThe new request follows.";
}
