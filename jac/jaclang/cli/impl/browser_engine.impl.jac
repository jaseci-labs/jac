import base64;
import hashlib;
import json;
import os;
import re;
import struct;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from urllib.request { urlopen }


impl WebSocket._handshake(host: str, port: int) {
    key = base64.b64encode(os.urandom(16)).decode();
    req = (
        f"GET {self.path} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    );
    self.sock.sendall(req.encode());
    header = self._read_until("\r\n\r\n".encode());
    status = header.split("\r\n".encode(), 1)[0];
    if "101".encode() not in status {
        raise ConnectionError(f"WebSocket upgrade failed: {status}");
    }

    guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    expected = base64.b64encode(hashlib.sha1((key + guid).encode()).digest()).decode();
    if expected.encode() not in header {
        raise ConnectionError("WebSocket Sec-WebSocket-Accept mismatch");
    }
}

impl WebSocket._read_until(delim: bytes) -> bytes {
    while delim not in self._buf {
        chunk = self.sock.recv(4096);
        if not chunk {
            raise ConnectionError("connection closed during handshake");
        }
        self._buf.extend(chunk);
    }
    idx = self._buf.index(delim) + len(delim);
    head = bytes(self._buf[:idx]);
    self._buf = self._buf[idx:];
    return head;
}

impl WebSocket._recv_exact(n: int) -> bytes {
    while len(self._buf) < n {
        chunk = self.sock.recv(65536);
        if not chunk {
            raise ConnectionError("connection closed mid-frame");
        }
        self._buf.extend(chunk);
    }
    out = bytes(self._buf[:n]);
    self._buf = self._buf[n:];
    return out;
}

impl WebSocket.send(data: (str | bytes), opcode: int = OP_TEXT) {
    payload = data.encode() if isinstance(data, str) else data;
    b0 = 0x80 | opcode;
    header = bytearray([b0]);
    ln = len(payload);
    if ln < 126 {
        header.append(0x80 | ln);
    } elif ln < 65536 {
        header.append(0x80 | 126);
        header.extend(struct.pack("!H", ln));
    } else {
        header.append(0x80 | 127);
        header.extend(struct.pack("!Q", ln));
    }
    mask = os.urandom(4);
    header.extend(mask);
    masked = bytes([payload[i] ^ mask[i % 4] for i in range(ln)]);
    self.sock.sendall(bytes(header) + masked);
}

impl WebSocket._read_frame -> tuple {
    (b0, b1) = self._recv_exact(2);
    fin = (b0 & 0x80) != 0;
    opcode = b0 & 0x0F;
    masked = (b1 & 0x80) != 0;
    ln = b1 & 0x7F;
    if ln == 126 {
        ln = struct.unpack("!H", self._recv_exact(2))[0];
    } elif ln == 127 {
        ln = struct.unpack("!Q", self._recv_exact(8))[0];
    }
    mask = self._recv_exact(4) if masked else bytes();
    payload = self._recv_exact(ln);
    if masked {
        payload = bytes([payload[i] ^ mask[i % 4] for i in range(ln)]);
    }
    return (fin, opcode, payload);
}

impl WebSocket.recv -> (str | bytes) {
    chunks = bytearray();
    op_started = 0;
    while True {
        (fin, opcode, payload) = self._read_frame();
        if opcode == OP_PING {
            self.send(payload, opcode=OP_PONG);
            continue;
        }
        if opcode == OP_PONG {
            continue;
        }
        if opcode == OP_CLOSE {
            raise ConnectionError("server closed WebSocket");
        }
        if opcode != 0 {
            op_started = opcode;
        }
        chunks.extend(payload);
        if fin {
            return chunks.decode() if op_started == OP_TEXT else bytes(chunks);
        }
    }
}

impl WebSocket.close{
    try {
        self.send(bytes(), opcode=OP_CLOSE);
    } except OSError { }
    self.sock.close();
}


impl CDP.call(
    method: str, params: (dict | None) = None, timeout: float = 30.0
) -> dict {
    self._id += 1;
    msg_id = self._id;
    self.ws.send(json.dumps({"id": msg_id, "method": method, "params": params or {}}));
    deadline = time.time() + timeout;
    while time.time() < deadline {
        msg = json.loads(self.ws.recv());
        if msg.get("id") == msg_id {
            if "error" in msg {
                raise RuntimeError(f"{method}: {msg['error']}");
            }
            return msg.get("result", {});
        }
        if "method" in msg {
            self.events.append(msg);
        }
    }
    raise TimeoutError(f"CDP call timed out: {method}");
}

impl CDP.drain_events(idle: float = 0.25) -> list {
    self.ws.sock.settimeout(idle);
    try {
        while True {
            try {
                msg = json.loads(self.ws.recv());
            } except OSError {
                break;
            }
            if "method" in msg {
                self.events.append(msg);
            }
        }
    } finally {
        self.ws.sock.settimeout(self.ws.timeout);
    }
    out = self.events;
    self.events = [];
    return out;
}

impl CDP.close{
    self.ws.close();
}


impl get_cache_dir -> Path {
    env = os.environ.get("JACBROWSER_CACHE");
    return Path(env) if env else (Path.home() / ".cache" / "jacbrowser");
}

impl _find_chrome -> str {
    env = os.environ.get("JACBROWSER_CHROME");
    if env {
        return env;
    }
    import from shutil { which }
    for name in [
        "google-chrome",
        "google-chrome-stable",
        "chromium",
        "chromium-browser"
    ] {
        path = which(name);
        if path {
            return path;
        }
    }
    for app in [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        str(
            Path.home() / "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        ),
        "/opt/google/chrome/chrome",

    ] {
        if Path(app).exists() {
            return app;
        }
    }

    for pw in [
        Path.home() / ".cache" / "ms-playwright",
        Path.home() / "Library" / "Caches" / "ms-playwright",

    ] {
        if not pw.exists() {
            continue;
        }
        for d in sorted(pw.glob("chromium-*"), reverse=True) {
            for rel in [
                "chrome-linux64/chrome",
                "chrome-linux/chrome",
                "chrome-mac/Chromium.app/Contents/MacOS/Chromium"
            ] {
                exe = d / rel;
                if exe.exists() {
                    return str(exe);
                }
            }
        }
    }
    raise FileNotFoundError("no Chrome/Chromium found; set JACBROWSER_CHROME");
}

impl _state_path(session: str) -> Path {
    return get_cache_dir() / f"session-{session}.json";
}

impl _refs_path(session: str) -> Path {
    return get_cache_dir() / f"refs-{session}.json";
}

impl _pid_alive(pid: int) -> bool {
    try {
        os.kill(pid, 0);
        return True;
    } except OSError {
        return False;
    }
}

impl _http_json(port: int, path: str) -> any {
    url = f"http://127.0.0.1:{port}{path}";
    with urlopen(url, timeout=5) as r {
        return json.loads(r.read());
    }
}

impl _page_ws(port: int) -> str {
    for t in _http_json(port, "/json") {
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl") {
            return t["webSocketDebuggerUrl"];
        }
    }

    browser_ws = _http_json(port, "/json/version")["webSocketDebuggerUrl"];
    cdp = CDP(ws_url=browser_ws);
    cdp.call("Target.createTarget", {"url": "about:blank"});
    cdp.close();
    for t in _http_json(port, "/json") {
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl") {
            return t["webSocketDebuggerUrl"];
        }
    }
    raise RuntimeError("could not obtain a page target");
}

impl load_state(session: str) -> (dict | None) {
    p = _state_path(session);
    if p.exists() {
        return json.loads(p.read_text());
    }
    return None;
}

impl _parse_viewport(spec: str) -> tuple {
    m = re.fullmatch(r"(\d+)\s*[xX,]\s*(\d+)", spec.strip());
    if not m {
        raise ValueError(f"invalid viewport '{spec}' (expected WIDTHxHEIGHT)");
    }
    return (int(m.group(1)), int(m.group(2)));
}

impl _chrome_args(chrome: str, profile: Path, viewport: str) -> list {
    (w, h) = _parse_viewport(viewport);
    return [
        chrome,
        "--headless=new",
        "--remote-debugging-port=0",
        f"--user-data-dir={profile}",
        "--no-first-run",
        "--no-default-browser-check",
        f"--window-size={w},{h}",
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
        "--no-sandbox",
        "about:blank",

    ];
}

impl _calibrate_viewport(port: int, w: int, h: int) {
    try {
        cdp = CDP(ws_url=_page_ws(port));
        iw = _eval(cdp, "window.innerWidth");
        ih = _eval(cdp, "window.innerHeight");
        cdp.close();
        if iw == w and ih == h {
            return;
        }
        tid = None;
        for t in _http_json(port, "/json") {
            if t.get("type") == "page" {
                tid = t.get("id");
                break;
            }
        }
        if tid is None {
            return;
        }
        bws = _http_json(port, "/json/version")["webSocketDebuggerUrl"];
        bcdp = CDP(ws_url=bws);
        win = bcdp.call("Browser.getWindowForTarget", {"targetId": tid});
        b = win["bounds"];
        bcdp.call(
            "Browser.setWindowBounds",
            {
                "windowId": win["windowId"],
                "bounds": {
                    "width": b["width"] + (w - iw),
                    "height": b["height"] + (h - ih)
                }
            }
        );
        bcdp.close();
    } except Exception { }
}

impl launch(session: str = "default", viewport: str = "1280x720") -> dict {
    st = load_state(session);
    if st and _pid_alive(st["pid"]) {
        try {
            _http_json(st["port"], "/json/version");
            return st;
        } except OSError { }
    }
    cache = get_cache_dir();
    cache.mkdir(parents=True, exist_ok=True);
    profile = cache / f"profile-{session}";
    chrome = _find_chrome();
    proc = subprocess.Popen(
        _chrome_args(chrome, profile, viewport),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    );

    port_file = profile / "DevToolsActivePort";
    port_file.unlink(missing_ok=True);
    port = None;
    for _ in range(100) {
        if port_file.exists() {
            port = int(port_file.read_text().splitlines()[0]);
            break;
        }
        time.sleep(0.1);
    }
    if port is None {
        proc.kill();
        raise RuntimeError("Chrome failed to start (no DevToolsActivePort)");
    }
    (vw, vh) = _parse_viewport(viewport);
    _calibrate_viewport(port, vw, vh);
    st = {"session": session, "pid": proc.pid, "port": port};
    _state_path(session).write_text(json.dumps(st));
    return st;
}

impl connect(session: str = "default") -> CDP {
    st = load_state(session);
    if (not st) or (not _pid_alive(st["pid"])) {
        raise RuntimeError(
            f"no live browser for session '{session}'; run `open` first"
        );
    }
    return CDP(ws_url=_page_ws(st["port"]));
}


impl _eval(cdp: CDP, expr: str) -> any {
    res = cdp.call(
        "Runtime.evaluate",
        {"expression": expr, "returnByValue": True, "awaitPromise": True}
    );
    details = res.get("exceptionDetails");
    if details {
        desc = (details.get("exception") or {}).get("description");
        raise RuntimeError(desc or details.get("text", "JS exception"));
    }
    return res.get("result", {}).get("value");
}

impl _load_refs(session: str) -> dict {
    p = _refs_path(session);
    if p.exists() {
        return json.loads(p.read_text());
    }
    return {};
}

impl _resolve_object_id(cdp: CDP, session: str, selector: str) -> (str | None) {
    if selector.startswith("@") {
        backend = _load_refs(session).get(selector[1:]);
        if backend is None {
            raise RuntimeError(f"unknown ref '{selector}'; run `snapshot` first");
        }
        try {
            res = cdp.call("DOM.resolveNode", {"backendNodeId": backend});
            return res["object"]["objectId"];
        } except Exception {
            return None;
        }
    }
    res = cdp.call(
        "Runtime.evaluate",
        {"expression": f"document.querySelector({json.dumps(selector)})"}
    );
    return res.get("result", {}).get("objectId");
}

impl _locate(cdp: CDP, session: str, selector: str, timeout: float = 10.0) -> tuple {
    cdp.call("DOM.enable");
    deadline = time.time() + timeout;
    prev = None;
    last_err = "element not found";

    while time.time() < deadline {
        oid = _resolve_object_id(cdp, session, selector);
        if oid is None {
            last_err = "element not found";
            prev = None;
            time.sleep(0.1);
            continue;
        }
        try {
            res = cdp.call(
                "Runtime.callFunctionOn",
                {
                    "functionDeclaration": ACTIONABILITY_JS,
                    "objectId": oid,
                    "returnByValue": True
                }
            );
        } except RuntimeError as e {
            last_err = str(e);
            prev = None;
            time.sleep(0.1);
            continue;
        }
        st = res.get("result", {}).get("value") or {};
        if not st.get("ok") {
            last_err = st.get("reason", "not actionable");
            prev = None;
            time.sleep(0.1);
            continue;
        }
        if not st.get("hitOk", True) {
            last_err = (
                f"point ({int(st['x'])},{int(st['y'])}) is covered by {st.get('hit')}"
            );
            prev = None;
            time.sleep(0.1);
            continue;
        }
        if prev is not None
        and abs(st["x"] - prev[0]) < 1
        and abs(st["y"] - prev[1]) < 1 {
            return (st["x"], st["y"]);
        }
        prev = (st["x"], st["y"]);
        time.sleep(0.05);
    }
    raise RuntimeError(f"{selector} not actionable: {last_err}");
}

impl _real_click(cdp: CDP, x: float, y: float) {
    cdp.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y});
    base = {"x": x, "y": y, "button": "left", "clickCount": 1};
    cdp.call("Input.dispatchMouseEvent", {"type": "mousePressed"} | base);
    cdp.call("Input.dispatchMouseEvent", {"type": "mouseReleased"} | base);
}

impl _type_text(cdp: CDP, text: str) {
    for ch in text {
        cdp.call("Input.dispatchKeyEvent", {"type": "keyDown", "text": ch});
        cdp.call("Input.dispatchKeyEvent", {"type": "keyUp"});
    }
}

impl _insert_text(cdp: CDP, text: str) {
    cdp.call("Input.insertText", {"text": text});
}

impl _key_code(ch: str) -> str {
    if ch.isalpha() {
        return "Key" + ch.upper();
    }
    if ch.isdigit() {
        return "Digit" + ch;
    }
    return ch;
}

impl _press(cdp: CDP, key: str, modifiers: int = 0) {
    vk = KEY_CODES.get(key, 0);
    code = key;
    down = {"type": "keyDown", "key": key, "modifiers": modifiers};
    if vk {
        down["windowsVirtualKeyCode"] = vk;
    } elif len(key) == 1 {
        code = _key_code(key);
        down["windowsVirtualKeyCode"] = ord(key.upper());
        if modifiers == 0 {
            down["text"] = key;
        }
    }
    down["code"] = code;
    cdp.call("Input.dispatchKeyEvent", down);
    cdp.call(
        "Input.dispatchKeyEvent",
        {"type": "keyUp", "key": key, "code": code, "modifiers": modifiers}
    );
}


impl cmd_open(session: str, url: (str | None), viewport: str = "1280x720") -> str {
    launch(session, viewport);
    if url {
        return cmd_navigate(session, url);
    }
    return "browser ready (about:blank)";
}

impl cmd_navigate(session: str, url: str) -> str {
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url) {
        url = "https://" + url;
    }
    cdp = connect(session);
    cdp.call("Page.enable");
    cdp.call("Page.navigate", {"url": url});

    deadline = time.time() + 30;
    while time.time() < deadline {
        if _eval(cdp, "document.readyState") == "complete" {
            break;
        }
        time.sleep(0.1);
    }
    href = _eval(cdp, "location.href");
    cdp.close();
    return f"navigated to {href}";
}

impl cmd_eval(session: str, expr: str) -> any {
    cdp = connect(session);
    out = _eval(cdp, expr);
    cdp.close();
    return out;
}

impl cmd_click(session: str, selector: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    cdp.close();
    return f"clicked {selector} at ({int(x)},{int(y)})";
}

impl cmd_type(session: str, selector: str, text: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    _type_text(cdp, text);
    cdp.close();
    return f"typed into {selector}";
}

impl cmd_fill(session: str, selector: str, text: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    _press(cdp, "a", modifiers=2);
    _press(cdp, "Delete");
    _insert_text(cdp, text);
    cdp.close();
    return f"filled {selector}";
}

impl cmd_press(session: str, key: str) -> str {
    cdp = connect(session);
    _press(cdp, key);
    cdp.close();
    return f"pressed {key}";
}

impl cmd_get(session: str, what: str, selector: (str | None)) -> any {
    if what == "url" {
        return cmd_eval(session, "location.href");
    }
    if what == "title" {
        return cmd_eval(session, "document.title");
    }
    if what == "text" {
        js = (
            f"(()=>{{const el=document.querySelector({json.dumps(selector)});"
            "return el?el.innerText:null;})()"
        );
        return cmd_eval(session, js);
    }
    raise ValueError(f"unknown get target: {what}");
}

impl cmd_screenshot(session: str, path: (str | None)) -> str {
    cdp = connect(session);
    res = cdp.call("Page.captureScreenshot", {"format": "png"});
    data = base64.b64decode(res["data"]);
    cdp.close();
    out_path = path;
    if not out_path {
        cache = get_cache_dir();
        cache.mkdir(parents=True, exist_ok=True);
        out_path = str(cache / f"screenshot-{int(time.time())}.png");
    }
    Path(out_path).write_bytes(data);
    return f"screenshot saved to {out_path} ({len(data)} bytes)";
}

impl _remote_obj_str(ro: dict) -> str {
    if "value" in ro {
        v = ro["value"];
        return v if isinstance(v, str) else json.dumps(v);
    }
    if ro.get("unserializableValue") {
        return ro["unserializableValue"];
    }
    if ro.get("description") {
        return ro["description"];
    }
    return ro.get("type", "?");
}

impl _format_console_event(method: str, params: dict) -> (str | None) {
    if method == "Runtime.consoleAPICalled" {
        kind = params.get("type", "log");
        parts = [_remote_obj_str(a) for a in params.get("args", [])];
        return f"[{kind}] " + " ".join(parts);
    }
    if method == "Runtime.exceptionThrown" {
        d = params.get("exceptionDetails", {});
        desc = (d.get("exception") or {}).get("description")
        or d.get("text", "uncaught exception");
        return f"[error] {desc}";
    }
    if method == "Log.entryAdded" {
        e = params.get("entry", {});
        if e.get("source") == "console-api" {
            return None;
        }
        url = e.get("url", "");
        loc = f" ({url}:{e.get('lineNumber')})" if url else "";
        return f"[{e.get('level', 'info')}] {e.get('text', '')}{loc}";
    }
    return None;
}

impl cmd_console(session: str, clear: bool = False) -> str {
    cdp = connect(session);

    cdp.call("Runtime.enable");
    cdp.call("Log.enable");
    events = cdp.drain_events();
    if clear {
        cdp.call("Runtime.discardConsoleEntries");
        cdp.call("Log.clear");
    }
    cdp.close();
    lines = [];
    for ev in events {
        line = _format_console_event(ev.get("method", ""), ev.get("params", {}));
        if line is not None {
            lines.append(line);
        }
    }
    return "\n".join(lines) if lines else "(no console output)";
}

impl cmd_wait(session: str, arg: str, timeout: float = 30.0) -> str {
    if re.fullmatch(r"\d+", arg) {
        ms = int(arg);
        time.sleep(ms / 1000);
        return f"waited {ms}ms";
    }
    cdp = connect(session);
    try {
        _locate(cdp, session, arg, timeout=timeout);
    } finally {
        cdp.close();
    }
    return f"waited for {arg}";
}

impl cmd_scroll(session: str, target: str, amount: (int | None) = None) -> str {
    cdp = connect(session);
    try {
        deltas = {"down": (0, 1), "up": (0, -1), "right": (1, 0), "left": (-1, 0)};
        if target in deltas {
            (sx, sy) = deltas[target];

            amt = str(amount)
                if amount is not None
                else ("innerWidth * 0.8" if sx else "innerHeight * 0.8");
            _eval(
                cdp,
                f"window.scrollBy({{left: {sx} * ({amt}), top: {sy} * ({amt}),"
                " behavior: 'instant'})"
            );
        } elif target == "top" {
            _eval(cdp, "window.scrollTo(0, 0)");
        } elif target == "bottom" {
            _eval(cdp, "window.scrollTo(0, document.documentElement.scrollHeight)");
        } else {
            (x, y) = _locate(cdp, session, target);
            return f"scrolled {target} into view at ({int(x)},{int(y)})";
        }
        pos = _eval(cdp, "JSON.stringify([Math.round(scrollX), Math.round(scrollY)])");
    } finally {
        cdp.close();
    }
    return f"scrolled to {pos}";
}

impl _walk_ax(ax: dict, by_id: dict, depth: int, lines: list, refs: dict) {
    role = (ax.get("role") or {}).get("value", "");
    name = (ax.get("name") or {}).get("value", "");
    ignored = ax.get("ignored", False);
    next_depth = depth;
    if (not ignored) and role {
        ref_str = "";
        backend = ax.get("backendDOMNodeId");
        if (role in INTERACTIVE_ROLES or name) and backend is not None {
            rid = f"e{len(refs) + 1}";
            refs[rid] = backend;
            ref_str = f"@{rid} ";
        }
        label = f' "{name}"' if name else "";
        lines.append("  " * depth + f"{ref_str}{role}{label}");
        next_depth = depth + 1;
    }
    for cid in ax.get("childIds", []) {
        child = by_id.get(cid);
        if child {
            _walk_ax(child, by_id, next_depth, lines, refs);
        }
    }
}

impl cmd_snapshot(session: str) -> str {
    cdp = connect(session);
    cdp.call("DOM.enable");
    cdp.call("Accessibility.enable");
    nodes = cdp.call("Accessibility.getFullAXTree").get("nodes", []);
    cdp.close();
    by_id = {};
    for n in nodes {
        by_id[n["nodeId"]] = n;
    }
    child_ids = set();
    for n in nodes {
        for c in n.get("childIds", []) {
            child_ids.add(c);
        }
    }
    roots = [
        n
        for n in nodes
        if n["nodeId"] not in child_ids
    ];
    lines = [];
    refs = {};
    for r in roots {
        _walk_ax(r, by_id, 0, lines, refs);
    }
    _refs_path(session).write_text(json.dumps(refs));
    return "\n".join(lines);
}

impl _cookie_param(ck: dict) -> dict {
    c = {
        "name": ck["name"],
        "value": ck["value"],
        "domain": ck.get("domain", ""),
        "path": ck.get("path", "/"),
        "httpOnly": ck.get("httpOnly", False),
        "secure": ck.get("secure", False),

    };
    if ck.get("expires", -1) >= 0 {
        c["expires"] = ck["expires"];
    }
    if ck.get("sameSite") {
        c["sameSite"] = ck["sameSite"];
    }
    return c;
}

impl cmd_state(session: str, sub: str, path: str) -> str {
    cdp = connect(session);
    cdp.call("Network.enable");
    if sub == "save" {
        cookies = cdp.call("Network.getAllCookies").get("cookies", []);
        local = _eval(cdp, "JSON.stringify(window.localStorage)");
        url = _eval(cdp, "location.href");
        cdp.close();
        Path(path).write_text(
            json.dumps({"url": url, "cookies": cookies, "localStorage": local})
        );
        return f"saved {len(cookies)} cookies to {path}";
    } elif sub == "load" {
        data = json.loads(Path(path).read_text());
        cookies = data.get("cookies", []);
        if cookies {
            cdp.call(
                "Network.setCookies", {"cookies": [_cookie_param(ck) for ck in cookies]}
            );
        }
        local = data.get("localStorage");
        if local and local != "{}" {
            _eval(
                cdp,
                f"(()=>{{const o={local};for(const k in o)localStorage.setItem(k,o[k]);}})()"
            );
        }
        cdp.close();
        return f"loaded {len(cookies)} cookies from {path}";
    }
    cdp.close();
    raise ValueError(f"unknown state subcommand '{sub}' (use save|load)");
}

impl cmd_sessions(session: str) -> str {
    cache = get_cache_dir();
    if not cache.exists() {
        return "(no sessions)";
    }
    lines = [];
    for f in sorted(cache.glob("session-*.json")) {
        try {
            st = json.loads(f.read_text());
            status = "alive" if _pid_alive(st["pid"]) else "dead";
            marker = "*" if st.get("session") == session else " ";
            lines.append(
                f"{marker} {st.get('session')}  pid={st['pid']} port={st['port']} [{status}]"
            );
        } except Exception { }
    }
    return "\n".join(lines) if lines else "(no sessions)";
}

impl cmd_close(session: str) -> str {
    st = load_state(session);
    if st and _pid_alive(st["pid"]) {
        try {
            os.kill(st["pid"], 15);
        } except OSError { }
    }
    _state_path(session).unlink(missing_ok=True);
    _refs_path(session).unlink(missing_ok=True);
    return "closed";
}


impl main(argv: list) -> int {
    session = os.environ.get("JACBROWSER_SESSION", "default");
    if not argv {
        sys.stdout.write(
            "usage: browser_engine.jac <open|navigate|eval|click|type|fill|press|get|wait|scroll|console|snapshot|screenshot|state|sessions|close> ...\n"
        );
        return 1;
    }
    cmd = argv[0];
    rest = argv[1:];
    out: any = "";
    try {
        if cmd == "open" {
            out = cmd_open(session, rest[0] if rest else None);
        } elif cmd == "navigate" or cmd == "goto" {
            out = cmd_navigate(session, rest[0]);
        } elif cmd == "eval" {
            out = cmd_eval(session, rest[0]);
        } elif cmd == "click" {
            out = cmd_click(session, rest[0]);
        } elif cmd == "type" {
            out = cmd_type(session, rest[0], rest[1]);
        } elif cmd == "fill" {
            out = cmd_fill(session, rest[0], rest[1]);
        } elif cmd == "press" {
            out = cmd_press(session, rest[0]);
        } elif cmd == "get" {
            out = cmd_get(session, rest[0], rest[1] if len(rest) > 1 else None);
        } elif cmd == "wait" {
            out = cmd_wait(session, rest[0]);
        } elif cmd == "scroll" {
            out = cmd_scroll(session, rest[0], int(rest[1]) if len(rest) > 1 else None);
        } elif cmd == "scrollintoview" {
            out = cmd_scroll(session, rest[0]);
        } elif cmd == "console" {
            out = cmd_console(session, "--clear" in rest or "clear" in rest);
        } elif cmd == "snapshot" {
            out = cmd_snapshot(session);
        } elif cmd == "screenshot" {
            out = cmd_screenshot(session, rest[0] if rest else None);
        } elif cmd == "state" {
            out = cmd_state(session, rest[0], rest[1]);
        } elif cmd == "sessions" {
            out = cmd_sessions(session);
        } elif cmd == "close" {
            out = cmd_close(session);
        } else {
            sys.stdout.write(f"unknown command: {cmd}\n");
            return 1;
        }
    } except Exception as e {
        sys.stderr.write(f"error: {e}\n");
        return 1;
    }
    sys.stdout.write((out if isinstance(out, str) else json.dumps(out)) + "\n");
    return 0;
}
