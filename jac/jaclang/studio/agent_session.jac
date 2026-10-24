import os;
import queue;
import threading;
import time;

glob STUDIO_DIR: str = os.path.join(".jac", "studio"),
     REJECTED_WRITE: str = "The user rejected this write.",
     CANCELLED_WRITE: str = "The turn was cancelled before this write was approved.";

obj AgentEvent {
    has kind: str,
        data: dict[str, any] = {};

    def to_dict -> dict[str, any];
}

obj AgentSession {
    has name: str = "",
        root_dir: str = "",
        cwd: str = "",
        events: queue.Queue = queue.Queue(),
        write_gate: any = None,
        read_hook: any = None,
        agent_session_id: str = "",
        log_path: str = "",
        _busy: bool = False,
        _stopped: bool = False,
        _lock: any = None,
        _waits: dict[str, any] = {},
        _answers: dict[str, any] = {},
        _wait_kinds: dict[str, str] = {},
        _seq: int = 0;

    def postinit;
    def emit(kind: str, data: (dict[str, any] | None) = None) -> AgentEvent;
    def start(cwd: str, mcp_servers: list[dict[str, any]]) -> None;
    def prompt(blocks: list[dict[str, any]]) -> None;
    def cancel -> None;
    def respond_permission(request_id: any, option_id: (str | None)) -> None;
    def resolve_write(request_id: any, accept: bool, message: str = "") -> None;
    def busy -> bool;
    def stop -> None;
    def next_request_id(prefix: str) -> str;
    def expect(request_id: any, kind: str) -> None;
    def wait_answer(request_id: any) -> any;
    def answer(request_id: any, value: any) -> bool;
    def cancel_waits -> None;
    def pending_requests -> list[str];
    def resolve_path(path: str) -> str;
    def read_text(path: str) -> str;
    def gate_write(path: str, content: str) -> (str | None);
    def log(text: str) -> None;
}

def studio_dir(root_dir: str, sub: str = "") -> str;

def blocks_text(blocks: list[dict[str, any]]) -> str;

impl AgentEvent.to_dict -> dict[str, any] {
    return {"kind": self.kind, "data": self.data};
}

impl AgentSession.postinit {
    self.events = queue.Queue();
    self._lock = threading.RLock();
    self._waits = {};
    self._answers = {};
    self._wait_kinds = {};
    if self.root_dir {
        self.root_dir = os.path.realpath(self.root_dir);
    }
    if not self.log_path and self.root_dir {
        self.log_path = os.path.join(
            studio_dir(self.root_dir, "logs"), f"{self.name or 'agent'}.log"
        );
    }
}

impl AgentSession.emit(kind: str, data: (dict[str, any] | None) = None) -> AgentEvent {
    ev = AgentEvent(kind=kind, data=data if data is not None else {});
    self.events.put(ev);
    return ev;
}

impl AgentSession.start(cwd: str, mcp_servers: list[dict[str, any]]) -> None {
    raise NotImplementedError("start");
}

impl AgentSession.prompt(blocks: list[dict[str, any]]) -> None {
    raise NotImplementedError("prompt");
}

impl AgentSession.cancel -> None {
    self.cancel_waits();
}

impl AgentSession.respond_permission(request_id: any, option_id: (str | None)) -> None {
    self.answer(request_id, option_id);
}

impl AgentSession.resolve_write(
    request_id: any, accept: bool, message: str = ""
) -> None {
    self.answer(request_id, (bool(accept), message));
}

impl AgentSession.busy -> bool {
    return self._busy;
}

impl AgentSession.stop -> None {
    self._stopped = True;
    self.cancel_waits();
}

impl AgentSession.next_request_id(prefix: str) -> str {
    with self._lock {
        self._seq += 1;
        return f"{prefix}-{self._seq}";
    }
}

impl AgentSession.expect(request_id: any, kind: str) -> None {
    key = str(request_id);
    with self._lock {
        self._waits[key] = threading.Event();
        self._wait_kinds[key] = kind;
    }
}

impl AgentSession.wait_answer(request_id: any) -> any {
    key = str(request_id);
    with self._lock {
        ev = self._waits.get(key);
    }
    if ev is None {
        return None;
    }
    while not ev.wait(0.25) {
        if self._stopped {
            break;
        }
    }
    with self._lock {
        self._waits.pop(key, None);
        kind = self._wait_kinds.pop(key, "");
        if key in self._answers {
            return self._answers.pop(key);
        }
    }
    if kind == "write" {
        return (False, CANCELLED_WRITE);
    }
    return None;
}

impl AgentSession.answer(request_id: any, value: any) -> bool {
    key = str(request_id);
    ev: any = None;
    with self._lock {
        ev = self._waits.get(key);
        if ev is not None {
            self._answers[key] = value;
        }
    }
    if ev is None {
        return False;
    }
    ev.set();
    return True;
}

impl AgentSession.cancel_waits -> None {
    with self._lock {
        keys = list(self._waits.keys());
    }
    for key in keys {
        with self._lock {
            kind = self._wait_kinds.get(key, "");
        }
        self.answer(key, (False, CANCELLED_WRITE) if kind == "write" else None);
    }
}

impl AgentSession.pending_requests -> list[str] {
    with self._lock {
        return list(self._waits.keys());
    }
}

impl AgentSession.resolve_path(path: str) -> str {
    base = self.cwd or self.root_dir or os.getcwd();
    full = path if os.path.isabs(path) else os.path.join(base, path);
    return os.path.normpath(full);
}

impl AgentSession.read_text(path: str) -> str {
    full = self.resolve_path(path);
    if self.read_hook is not None {
        overlay = self.read_hook(full);
        if overlay is not None {
            return str(overlay);
        }
    }
    with open(full, encoding="utf-8", errors="replace") as f {
        return f.read();
    }
}

impl AgentSession.gate_write(path: str, content: str) -> (str | None) {
    full = self.resolve_path(path);
    if self.write_gate is not None {
        try {
            verdict = self.write_gate(full, content);
        } except Exception as e {
            verdict = f"The write gate failed: {e}";
        }
        if verdict is not None {
            return str(verdict) or REJECTED_WRITE;
        }
    } else {
        old = "";
        try {
            old = self.read_text(full);
        } except OSError {}
        rid = self.next_request_id("write");
        self.expect(rid, "write");
        self.emit(
            "write",
            {"request_id": rid, "path": full, "content": content, "old_content": old}
        );
        ans = self.wait_answer(rid);
        accept = False;
        msg = "";
        if isinstance(ans, tuple) and len(ans) == 2 {
            accept = bool(ans[0]);
            msg = str(ans[1] or "");
        }
        if not accept {
            return msg or REJECTED_WRITE;
        }
    }
    try {
        parent = os.path.dirname(full);
        if parent {
            os.makedirs(parent, exist_ok=True);
        }
        with open(full, "w", encoding="utf-8") as f {
            f.write(content);
        }
    } except OSError as e {
        return f"Could not write {full}: {e}";
    }
    return None;
}

impl AgentSession.log(text: str) -> None {
    if not self.log_path {
        return;
    }
    try {
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True);
        with self._lock {
            with open(self.log_path, "a", encoding="utf-8") as f {
                f.write(time.strftime("%H:%M:%S ") + text.rstrip("\n") + "\n");
            }
        }
    } except OSError {}
}

impl studio_dir(root_dir: str, sub: str = "") -> str {
    base = os.path.join(root_dir, STUDIO_DIR);
    return os.path.join(base, sub) if sub else base;
}

impl blocks_text(blocks: list[dict[str, any]]) -> str {
    parts: list[str] = [];
    for b in blocks {
        kind = b.get("type", "");
        if kind == "text" {
            parts.append(str(b.get("text", "")));
        } elif kind == "resource" {
            res = b.get("resource", {}) or {};
            uri = res.get("uri", "");
            parts.append(f"<context uri=\"{uri}\">\n{res.get('text', '')}\n</context>");
        } elif kind == "resource_link" {
            parts.append(f"[{b.get('name', '')}]({b.get('uri', '')})");
        }
    }
    return "\n\n".join(parts);
}
