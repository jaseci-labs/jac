import os;
import json;
import time;
import queue;
import socket;
import hashlib;
import tempfile;
import threading;

glob SOCKET_ENV: str = "JAC_STUDIO_SOCKET",
     MAX_SOCK_PATH: int = 100,
     QUERY_METHODS: list[str] = [
         "wiring",
         "rules",
         "graph",
         "symbol",
         "search",
         "locate"
     ],
     UI_METHODS: list[str] = ["selection", "focus", "link_plan"],
     MAX_SLICE_LINES: int = 400;

class BridgeUnavailable(Exception) {}

class BridgeError(Exception) {}

obj BridgeConn {
    has sock: any,
        lock: any postinit,
        alive: bool = True;

    def postinit;
    def send(payload: dict[str, any]) -> bool;
    def close;
}

obj BridgeRequest {
    has id: any,
        method: str,
        params: dict[str, any] = {},
        conn: (BridgeConn | None) = None,
        answered: bool = False;

    def reply(result: any) -> None;
    def fail(message: str) -> None;
}

obj BridgeServer {
    has root_dir: str,
        session: str = "",
        path: str = "",
        queries: any = None,
        requests: queue.Queue postinit,
        lock: any postinit,
        sock: any = None,
        running: bool = False,
        conns: list[BridgeConn] = [],
        pointer: str = "",
        started: float = 0.0;

    def postinit;
    def run_dir -> str;
    def slug -> str;
    def socket_path -> str;
    def start -> str;
    def stop;
    def drain(handler: any, limit: int = 16) -> int;
    def answer_with(handler: any) -> any;
    def _accept_loop;
    def _serve(conn: BridgeConn);
    def _dispatch(conn: BridgeConn, line: bytes);
}

obj BridgeClient {
    has path: str,
        timeout: float = 20.0,
        seq: int = 0;

    def call(
        method: str, params: (dict[str, any] | None) = None, timeout: float = 0.0
    ) -> any;

    def alive -> bool;
}

obj StudioQueries {
    has model: ProjectModel,
        read_text: any = None;

    def handle(method: str, params: dict[str, any]) -> any;
    def resolve(key: str) -> (StNode | None);
    def require(key: str) -> StNode;
    def symbol_at(path: str, line: int) -> (StNode | None);
    def module_key_of(key: str) -> str;
    def local_name(key: str) -> str;
    def brief(nd: StNode) -> dict[str, any];
    def brief_key(key: str) -> dict[str, any];
    def wire_dict(w: any, side: str) -> dict[str, any];
    def module_wiring(key: str, with_symbols: bool = True) -> dict[str, any];
    def neighbourhood(key: str) -> dict[str, any];
    def rule_coverage -> dict[str, any];
    def symbol(key: str) -> dict[str, any];
    def search(query: str, limit: int = 20) -> dict[str, any];
    def locate(key: str, line: int = 0) -> dict[str, any];
    def link_plan(entries: list[dict[str, any]]) -> list[dict[str, any]];
    def selection(
        tray: list[str],
        code_path: str = "",
        cursor: tuple[int, int] = (0, 0),
        cursor_symbol: str = "",
        wiring_module: str = "",
        extra: (dict[str, any] | None) = None
    ) -> dict[str, any];

    def source(path: str, start: int, end: int) -> dict[str, any];
}

def socket_alive(path: str) -> bool;

def find_studio_socket(root_dir: str) -> str;

def pattern_matches(text: str, local: str) -> bool;

impl BridgeConn.postinit {
    self.lock = threading.Lock();
}

impl BridgeConn.send(payload: dict[str, any]) -> bool {
    if not self.alive {
        return False;
    }
    data = (json.dumps(payload, `default=str) + "\n").encode("utf-8");
    with self.lock {
        try {
            self.sock.sendall(data);
        } except OSError {
            self.alive = False;
            return False;
        }
    }
    return True;
}

impl BridgeConn.close {
    self.alive = False;
    try {
        self.sock.shutdown(socket.SHUT_RDWR);
    } except OSError {}
    try {
        self.sock.close();
    } except OSError {}
}

impl BridgeRequest.reply(result: any) -> None {
    if self.answered {
        return;
    }
    self.answered = True;
    if self.conn is not None {
        self.conn.send({"id": self.id, "result": result});
    }
}

impl BridgeRequest.fail(message: str) -> None {
    if self.answered {
        return;
    }
    self.answered = True;
    if self.conn is not None {
        self.conn.send({"id": self.id, "error": {"message": message}});
    }
}

impl BridgeServer.postinit {
    self.requests = queue.Queue();
    self.lock = threading.Lock();
    self.root_dir = os.path.realpath(self.root_dir);
}

impl BridgeServer.run_dir -> str {
    return os.path.join(self.root_dir, ".jac", "studio", "run");
}

impl BridgeServer.slug -> str {
    sess = self.session or f"pid{os.getpid()}";
    return "".join([(c if c.isalnum() or c in "-_." else "_") for c in sess])[:64];
}

impl BridgeServer.socket_path -> str {
    path = os.path.join(self.run_dir(), self.slug() + ".sock");
    if len(path.encode("utf-8")) <= MAX_SOCK_PATH {
        return path;
    }
    digest = hashlib.sha1(path.encode("utf-8")).hexdigest()[:16];
    tmp = "/tmp" if os.path.isdir("/tmp") else tempfile.gettempdir();
    return os.path.join(tmp, f"jac-hack-{os.getuid()}-{digest}.sock");
}

impl BridgeServer.start -> str {
    if self.running {
        return self.path;
    }
    self.path = self.path or self.socket_path();
    if os.path.exists(self.path) {
        if socket_alive(self.path) {
            (base, ext) = os.path.splitext(self.path);
            self.path = f"{base}-{os.getpid()}{ext}";
        }
        try {
            os.unlink(self.path);
        } except OSError {}
    }
    os.makedirs(self.run_dir(), mode=0o700, exist_ok=True);
    os.makedirs(os.path.dirname(self.path), exist_ok=True);
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM);
    s.bind(self.path);
    os.chmod(self.path, 0o600);
    s.listen(8);
    s.settimeout(0.5);
    self.sock = s;
    self.running = True;
    self.started = time.time();
    self.pointer = os.path.join(self.run_dir(), self.slug() + ".json");
    try {
        with open(self.pointer, "w") as fh {
            json.dump(
                {
                    "socket": self.path,
                    "pid": os.getpid(),
                    "session": self.session,
                    "root": self.root_dir,
                    "started": self.started
                },
                fh
            );
        }
    } except OSError {
        self.pointer = "";
    }
    threading.Thread(
        target=self._accept_loop, name="studio-bridge", daemon=True
    ).start();
    return self.path;
}

impl BridgeServer.stop {
    if not self.running {
        return;
    }
    self.running = False;
    try {
        self.sock.close();
    } except OSError {}
    with self.lock {
        conns = list(self.conns);
        self.conns = [];
    }
    while True {
        try {
            req = self.requests.get_nowait();
        } except queue.Empty {
            break;
        }
        req.fail("jac hack is shutting down");
    }
    for c in conns {
        c.close();
    }
    for p in [self.path, self.pointer] {
        if p {
            try {
                os.unlink(p);
            } except OSError {}
        }
    }
}

impl BridgeServer.drain(handler: any, limit: int = 16) -> int {
    n = 0;
    while n < limit {
        try {
            req = self.requests.get_nowait();
        } except queue.Empty {
            break;
        }
        n += 1;
        try {
            req.reply(handler(req.method, req.params));
        } except Exception as e {
            req.fail(str(e) or type(e).__name__);
        }
    }
    return n;
}

impl BridgeServer.answer_with(handler: any) -> any {
    def pump {
        while self.running {
            try {
                req = self.requests.get(timeout=0.2);
            } except queue.Empty {
                continue;
            }
            try {
                req.reply(handler(req.method, req.params));
            } except Exception as e {
                req.fail(str(e) or type(e).__name__);
            }
        }
    }
    t = threading.Thread(target=pump, name="studio-bridge-answer", daemon=True);
    t.start();
    return t;
}

impl BridgeServer._accept_loop {
    while self.running {
        try {
            (raw, _) = self.sock.accept();
        } except socket.timeout {
            continue;
        } except OSError {
            break;
        }
        raw.settimeout(None);
        conn = BridgeConn(sock=raw);
        with self.lock {
            self.conns.append(conn);
        }
        threading.Thread(
            target=self._serve, args=(conn, ), name="studio-bridge-conn", daemon=True
        ).start();
    }
}

impl BridgeServer._serve(conn: BridgeConn) {
    try {
        reader = conn.sock.makefile("rb");
        while self.running and conn.alive {
            line = reader.readline();
            if not line {
                break;
            }
            if line.strip() {
                self._dispatch(conn, line);
            }
        }
    } except (OSError, ValueError) {} finally {
        with self.lock {
            if conn in self.conns {
                self.conns.remove(conn);
            }
        }
        conn.close();
    }
}

impl BridgeServer._dispatch(conn: BridgeConn, line: bytes) {
    try {
        msg = json.loads(line.decode("utf-8", "replace"));
    } except ValueError {
        conn.send({"id": None, "error": {"message": "malformed request"}});
        return;
    }
    if not isinstance(msg, dict) or not isinstance(msg.get("method"), str) {
        conn.send({"id": None, "error": {"message": "request needs a method"}});
        return;
    }
    params = msg.get("params");
    req = BridgeRequest(
        id=msg.get("id"),
        method=msg["method"],
        params=params if isinstance(params, dict) else {},
        conn=conn
    );
    if req.method == "ping" {
        req.reply(
            {
                "ok": True,
                "root": self.root_dir,
                "session": self.session,
                "pid": os.getpid(),
                "started": self.started
            }
        );
        return;
    }
    if self.queries is not None and req.method in QUERY_METHODS {
        try {
            req.reply(self.queries.handle(req.method, req.params));
        } except Exception as e {
            req.fail(str(e) or type(e).__name__);
        }
        return;
    }
    self.requests.put(req);
}

impl BridgeClient.call(
    method: str, params: (dict[str, any] | None) = None, timeout: float = 0.0
) -> any {
    if not self.path or not os.path.exists(self.path) {
        where = f" (no socket at {self.path})" if self.path else "";
        raise BridgeUnavailable(
            f"jac hack is not running{where}. These tools only work while the user has `jac hack` open on this project."
        );
    }
    limit = timeout or self.timeout;
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM);
    s.settimeout(limit);
    try {
        s.connect(self.path);
    } except OSError as e {
        s.close();
        raise BridgeUnavailable(
            f"jac hack is not answering on {self.path} ({e}). It was probably closed; these tools only work while `jac hack` is open."
        ) from None;
    }
    self.seq += 1;
    rid = self.seq;
    buf = b"";
    try {
        s.sendall(
            (
                json.dumps({"id": rid, "method": method, "params": params or {}}) + "\n"
            ).encode(
                "utf-8"
            )
        );
        while b"\n" not in buf {
            chunk = s.recv(65536);
            if not chunk {
                raise BridgeUnavailable(
                    "jac hack closed the connection before answering (it may have exited)."
                );
            }
            buf += chunk;
        }
    } except socket.timeout {
        raise BridgeError(
            f"jac hack did not answer '{method}' within {limit:g}s (the UI may be busy). Try again."
        ) from None;
    } finally {
        s.close();
    }
    msg = json.loads(buf.split(b"\n", 1)[0].decode("utf-8", "replace"));
    if "error" in msg and msg["error"] is not None {
        e = msg["error"];
        raise BridgeError(str(e.get("message", e)) if isinstance(e, dict) else str(e));
    }
    return msg.get("result");
}

impl BridgeClient.alive -> bool {
    return bool(self.path) and socket_alive(self.path);
}

impl socket_alive(path: str) -> bool {
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM);
    s.settimeout(1.0);
    try {
        s.connect(path);
        return True;
    } except OSError {
        return False;
    } finally {
        s.close();
    }
}

impl find_studio_socket(root_dir: str) -> str {
    run = os.path.join(os.path.realpath(root_dir), ".jac", "studio", "run");
    if not os.path.isdir(run) {
        return "";
    }
    found: list[tuple[float, str]] = [];
    for name in os.listdir(run) {
        full = os.path.join(run, name);
        if name.endswith(".json") {
            try {
                with open(full) as fh {
                    info = json.load(fh);
                }
                found.append(
                    (float(info.get("started", 0.0)), str(info.get("socket", "")))
                );
            } except (OSError, ValueError) {}
        } elif name.endswith(".sock") {
            try {
                found.append((os.path.getmtime(full), full));
            } except OSError {}
        }
    }
    found.sort(reverse=True);
    for (_, path) in found {
        if path and socket_alive(path) {
            return path;
        }
    }
    return "";
}

impl pattern_matches(text: str, local: str) -> bool {
    pat = text.strip().strip("\"'");
    if pat in ["*", ".*"] {
        return True;
    }
    if pat.endswith(".*") {
        base = pat[:-2];
        return local == base or local.startswith(base + ".");
    }
    return local == pat;
}

impl StudioQueries.handle(method: str, params: dict[str, any]) -> any {
    key = str(params.get("key", "") or "");
    with self.model.lock {
        if method == "wiring" {
            return self.neighbourhood(key);
        }
        if method == "rules" {
            return self.rule_coverage();
        }
        if method == "insight" {
            return {
                "view": params.get("view", ""),
                "key": key,
                "text": insight_run(
                    self.model, str(params.get("view", "") or ""), key, True
                )
            };
        }
        if method == "graph" {
            scope = scope_for(self.model, str(params.get("scope", "") or key));
            return level_dict(graph_level(self.model, scope), self.model);
        }
        if method == "symbol" {
            return self.symbol(key);
        }
        if method == "search" {
            return self.search(
                str(params.get("query", "") or ""), int(params.get("limit", 20) or 20)
            );
        }
        if method == "locate" {
            return self.locate(key, int(params.get("line", 0) or 0));
        }
    }
    raise ValueError(f"unknown studio query '{method}'");
}

impl StudioQueries.resolve(key: str) -> (StNode | None) {
    k = key.strip();
    if k.startswith(SYM_SCHEME) {
        k = k[len(SYM_SCHEME):];
    }
    if not k {
        return None;
    }
    nd = self.model.node_for(k);
    if nd is not None {
        return nd;
    }
    if "/" in k or k.endswith(".jac") or ".jac:" in k {
        path = k;
        line = 0;
        (head, sep, tail) = k.rpartition(":");
        if sep and tail.isdigit() {
            (path, line) = (head, int(tail));
        }
        if not os.path.isabs(path) {
            path = os.path.join(self.model.root_dir, path);
        }
        path = os.path.realpath(path);
        if line {
            hit = self.symbol_at(path, line);
            if hit is not None {
                return hit;
            }
        }
        return self.model.module_for_file(path);
    }
    hits = self.model.search(k, limit=1);
    return hits[0] if hits else None;
}

impl StudioQueries.require(key: str) -> StNode {
    nd = self.resolve(key);
    if nd is None {
        raise ValueError(
            f"nothing in the project model matches '{key}'. Use studio_search to find the right key."
        );
    }
    return nd;
}

impl StudioQueries.symbol_at(path: str, line: int) -> (StNode | None) {
    best: (StNode | None) = None;
    span = 10 ** 9;
    for s in list(self.model.symbols.values()) {
        (lo, hi) = (0, -1);
        if s.file == path {
            (lo, hi) = (s.line, max(s.end_line, s.line));
        }
        if isinstance(s, StAbility)
            and s.impl_file == path
            and not (lo <= line <= hi) {
            (lo, hi) = (s.impl_line, max(s.impl_end_line, s.impl_line));
        }
        if lo <= line <= hi and (hi - lo) < span {
            (best, span) = (s, hi - lo);
        }
    }
    if isinstance(best, StImpl) {
        decl = self.model.symbols.get(self.module_key_of(best.key) + "." + best.target);
        if decl is not None {
            return decl;
        }
    }
    return best;
}

impl StudioQueries.module_key_of(key: str) -> str {
    if key in self.model.modules {
        return key;
    }
    head = key.split("::", 1)[0];
    if head in self.model.modules {
        return head;
    }
    parts = head.split(".");
    for i in range(len(parts) - 1, 0, -1) {
        cand = ".".join(parts[:i]);
        if cand in self.model.modules {
            return cand;
        }
    }
    return "";
}

impl StudioQueries.local_name(key: str) -> str {
    mod = self.model.modules.get(key);
    if mod is not None and mod.local_name {
        return mod.local_name;
    }
    return key;
}

impl StudioQueries.brief(nd: StNode) -> dict[str, any] {
    d: dict[str, any] = {"key": nd.key, "kind": nd.kind, "name": nd.name};
    if nd.file {
        d["file"] = nd.file;
    }
    if nd.line {
        d["line"] = nd.line;
    }
    sig = getattr(nd, "signature", "") or getattr(nd, "type_str", "");
    if sig {
        d["signature"] = sig;
    }
    if not isinstance(nd, StModule) and nd.key not in self.model.packages {
        d["module"] = self.module_key_of(nd.key);
    }
    return d;
}

impl StudioQueries.brief_key(key: str) -> dict[str, any] {
    if key.startswith("wire:") and "->" in key {
        (prov, cons) = key[5:].split("->", 1);
        names: list[str] = [];
        for w in self.model.wires {
            if w.provider == prov and w.consumer == cons {
                names.extend(w.names);
            }
        }
        return {
            "key": key,
            "kind": "wire",
            "provider": prov,
            "consumer": cons,
            "names": names
        };
    }
    nd = self.resolve(key);
    if nd is None {
        return {"key": key, "kind": "unknown"};
    }
    d = self.brief(nd);
    if nd.key != key {
        d["requested"] = key;
    }
    return d;
}

impl StudioQueries.wire_dict(w: any, side: str) -> dict[str, any] {
    d: dict[str, any] = {
        "module": w.provider if side == "provider" else w.consumer,
        "names": w.names or ["(whole module)"],
        "form": w.form,
        "archwire_line": w.line
    };
    if w.scope {
        d["scope"] = w.scope;
    }
    if not w.injected {
        d["injected"] = False;
    }
    if getattr(w, "violation", "") {
        d["violation"] = w.violation;
    }
    return d;
}

impl StudioQueries.module_wiring(
    key: str, with_symbols: bool = True
) -> dict[str, any] {
    mod = self.model.modules[key];
    d: dict[str, any] = {"key": key, "kind": mod.kind, "file": mod.file};
    if len(mod.files) > 1 {
        d["files"] = mod.files;
    }
    if mod.archwire {
        d["archwire"] = mod.archwire;
    }
    if mod.doc {
        d["doc"] = mod.doc;
    }
    d["rules"] = [
        {"name": r.name, "sources": r.sources, "targets": r.targets, "names": r.names}
        for r in self.model.rules_for(key)
    ];
    d["providers"] = [self.wire_dict(w, "provider") for w in self.model.providers(key)];
    d["consumers"] = [self.wire_dict(w, "consumer") for w in self.model.consumers(key)];
    if with_symbols {
        syms: list[dict[str, any]] = [];
        for kid in self.model.children(key) {
            b = self.brief(kid);
            b.pop("file", None);
            b.pop("module", None);
            members = [m.name for m in self.model.children(kid.key)];
            if members {
                b["members"] = members;
            }
            syms.append(b);
        }
        d["symbols"] = syms;
    }
    return d;
}

impl StudioQueries.neighbourhood(key: str) -> dict[str, any] {
    nd = self.require(key);
    if isinstance(nd, StModule) {
        return self.module_wiring(nd.key);
    }
    if nd.key in self.model.packages {
        mods = sorted(
            [
                k
                for k in self.model.modules
                if k.startswith(nd.key + ".")
            ]
        );
        return {
            "key": nd.key,
            "kind": "package",
            "modules": mods,
            "hint": "Pass one of these module keys for its wiring."
        };
    }
    modkey = self.module_key_of(nd.key);
    d = self.model.node_dict(nd);
    d["module"] = modkey;
    rest = nd.key[len(modkey) + 1:] if modkey else nd.name;
    top = rest.split(".")[0];
    top_key = f"{modkey}.{top}" if modkey else nd.key;
    importers: list[dict[str, any]] = [];
    if modkey {
        for w in self.model.consumers(modkey) {
            hit = [
                n
                for n in w.names
                if n.split(" as ")[0].strip() == top
            ];
            if hit or not w.names {
                e: dict[str, any] = {
                    "module": w.consumer,
                    "via": hit[0] if hit else "(whole module)"
                };
                if w.scope {
                    e["scope"] = w.scope;
                }
                importers.append(e);
            }
        }
    }
    d["imported_by"] = importers;
    impls = [
        {"file": i.file, "line": i.line, "end_line": i.end_line}
        for i in self.model.implementations(nd.key)
    ];
    if impls {
        d["impl_blocks"] = impls;
    }
    if isinstance(nd, StArchetype) and nd.kind == "walker" {
        d["traverses"] = [t.key for t in self.model.traversals(nd.key)];
    }
    walkers = [w.key for w in self.model.walkers_of(top_key)];
    if walkers {
        d["walkers"] = walkers;
    }
    members = [self.brief(m) for m in self.model.children(nd.key)];
    if members {
        for m in members {
            m.pop("file", None);
            m.pop("module", None);
        }
        d["members"] = members;
    }
    if modkey {
        d["module_wiring"] = self.module_wiring(modkey, with_symbols=False);
    }
    return d;
}

impl StudioQueries.rule_coverage -> dict[str, any] {
    out: list[dict[str, any]] = [];
    for r in self.model.rules {
        mods = [
            m.key
            for m in self.model.modules.values()
            if m.archwire == r.file
                and any([pattern_matches(p, self.local_name(m.key)) for p in r.sources])
        ];
        n_wires = 0;
        for w in self.model.wires {
            if w.archwire != r.file {
                continue;
            }
            if any([pattern_matches(p, self.local_name(w.provider)) for p in r.sources])
                and any(
                    [pattern_matches(p, self.local_name(w.consumer)) for p in r.targets]
                ) {
                n_wires += 1;
            }
        }
        out.append(
            {
                "name": r.name,
                "archwire": r.file,
                "sources": r.sources,
                "targets": r.targets,
                "names": r.names or "any",
                "modules": len(mods),
                "wires": n_wires,
                "example_modules": mods[:5]
            }
        );
    }
    unruled: list[dict[str, any]] = [];
    with_rules = set([r.file for r in self.model.rules]);
    for w in self.model.wires {
        if w.archwire not in with_rules {
            continue;
        }
        (pl, cl) = (self.local_name(w.provider), self.local_name(w.consumer));
        if pl.split(".")[0] == cl.split(".")[0] {
            continue;
        }
        ok = any(
            [
                r.file == w.archwire
                    and any([pattern_matches(p, pl) for p in r.sources])
                    and any([pattern_matches(p, cl) for p in r.targets])
                for r in self.model.rules
            ]
        );
        if not ok {
            unruled.append(
                {
                    "provider": w.provider,
                    "consumer": w.consumer,
                    "names": w.names,
                    "archwire": w.archwire,
                    "archwire_line": w.line
                }
            );
        }
    }
    return {
        "archwires": self.model.archwires,
        "rules": out,
        "unruled_cross_package_wires": unruled,
        "archwires_without_rules": [
            a
            for a in self.model.archwires
            if a not in with_rules
        ],
        "note": "A wire between different top-level packages needs a rule whose sources match the provider and whose targets match the consumer; a rule with names only admits those names. `jac check` enforces this."
    };
}

impl StudioQueries.symbol(key: str) -> dict[str, any] {
    nd = self.require(key);
    d = self.model.node_dict(nd);
    if isinstance(nd, StModule) {
        d["wiring"] = {
            "providers": len(self.model.providers(nd.key)),
            "consumers": len(self.model.consumers(nd.key)),
            "rules": [r.name for r in self.model.rules_for(nd.key)]
        };
        d["symbols"] = [self.brief(k) for k in self.model.children(nd.key)];
        for s in d["symbols"] {
            s.pop("file", None);
            s.pop("module", None);
        }
        return d;
    }
    d["module"] = self.module_key_of(nd.key);
    if nd.file and nd.line {
        d["source"] = self.source(nd.file, nd.line, max(nd.end_line, nd.line));
    }
    hood = self.model.neighbourhood(nd.key);
    if hood is not None {
        d["used_by"] = [u.key for u in hood.users][:40];
        d["uses"] = [u.key for u in hood.uses][:40];
        if hood.walkers {
            d["walkers_over"] = [u.key for u in hood.walkers];
        }
        if hood.targets {
            d["traverses"] = [u.key for u in hood.targets];
        }
    }
    if isinstance(nd, StImpl) {
        d["target"] = nd.target;
        return d;
    }
    impl_src: list[dict[str, any]] = [];
    for i in self.model.implementations(nd.key) {
        if i.file and i.line {
            impl_src.append(self.source(i.file, i.line, max(i.end_line, i.line)));
        }
    }
    if impl_src {
        d["impl_source"] = impl_src;
    }
    members = [self.brief(m) for m in self.model.children(nd.key)];
    if members {
        for m in members {
            m.pop("file", None);
            m.pop("module", None);
        }
        d["members"] = members;
    }
    return d;
}

impl StudioQueries.search(query: str, limit: int = 20) -> dict[str, any] {
    n = max(1, min(int(limit), 200));
    words = query.split();
    found = self.model.search(query, limit=n);
    if not found and len(words) > 1 {
        rank: dict[str, int] = {};
        nodes: dict[str, StNode] = {};
        for (i, w) in enumerate(words) {
            hits = self.model.search(w, limit=5000);
            seen: dict[str, int] = {};
            for (pos, nd) in enumerate(hits) {
                seen[nd.key] = pos;
                nodes[nd.key] = nd;
            }
            if i == 0 {
                rank = seen;
            } else {
                rank = {
                    k: rank[k] + seen[k]
                    for k in rank
                    if k in seen
                };
            }
        }
        order = sorted(
            rank.keys(), key=lambda (k: str) -> tuple[int, int] { (rank[k], len(k)) }
        );
        found = [nodes[k] for k in order[:n]];
    }
    results = [self.brief(nd) for nd in found];
    return {"query": query, "count": len(results), "results": results};
}

impl StudioQueries.locate(key: str, line: int = 0) -> dict[str, any] {
    nd = self.require(key);
    if nd.key in self.model.packages {
        raise ValueError(f"'{key}' is a package; pass a module or symbol");
    }
    modkey = self.module_key_of(nd.key);
    at = line or nd.line or 1;
    path = nd.file;
    if isinstance(nd, StAbility) and nd.impl_file and not line {
        d = {
            "key": nd.key,
            "kind": nd.kind,
            "file": path,
            "line": at,
            "module": modkey,
            "impl_file": nd.impl_file,
            "impl_line": nd.impl_line
        };
        return d;
    }
    return {"key": nd.key, "kind": nd.kind, "file": path, "line": at, "module": modkey};
}

impl StudioQueries.link_plan(entries: list[dict[str, any]]) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    for e in entries {
        keys: list[str] = [];
        unknown: list[str] = [];
        for k in e.get("keys", []) or [] {
            nd = self.resolve(str(k));
            if nd is None {
                unknown.append(str(k));
            } elif nd.key not in keys {
                keys.append(nd.key);
            }
        }
        out.append({"step": e.get("step"), "keys": keys, "unknown": unknown});
    }
    return out;
}

impl StudioQueries.selection(
    tray: list[str],
    code_path: str = "",
    cursor: tuple[int, int] = (0, 0),
    cursor_symbol: str = "",
    wiring_module: str = "",
    extra: (dict[str, any] | None) = None
) -> dict[str, any] {
    with self.model.lock {
        d: dict[str, any] = {"tray": [self.brief_key(k) for k in tray]};
        if code_path {
            cur: dict[str, any] = {
                "file": code_path,
                "line": cursor[0],
                "column": cursor[1]
            };
            mod = self.model.module_for_file(code_path);
            if mod is not None {
                cur["module"] = mod.key;
            }
            if cursor_symbol {
                cur["symbol"] = self.brief_key(cursor_symbol);
            }
            d["code"] = cur;
        }
        if wiring_module {
            d["wiring_module"] = wiring_module;
        }
        if extra {
            d.update(extra);
        }
        return d;
    }
}

impl StudioQueries.source(path: str, start: int, end: int) -> dict[str, any] {
    text: (str | None) = None;
    if self.read_text is not None {
        try {
            text = self.read_text(path);
        } except Exception {
            text = None;
        }
    }
    if text is None {
        try {
            with open(path, encoding="utf-8", errors="replace") as fh {
                text = fh.read();
            }
        } except OSError as e {
            return {"file": path, "line": start, "error": str(e)};
        }
    }
    lines = text.split("\n");
    stop = min(end, start + MAX_SLICE_LINES - 1, len(lines));
    d: dict[str, any] = {
        "file": path,
        "line": start,
        "end_line": stop,
        "text": "\n".join(lines[start - 1:stop])
    };
    if stop < end {
        d["truncated"] = True;
        d["full_end_line"] = end;
    }
    return d;
}
