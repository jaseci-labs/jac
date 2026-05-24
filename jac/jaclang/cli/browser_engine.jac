"""Browser-automation engine backing the `jac browser` subcommand.

Zero third-party dependencies: drives Chrome/Chromium over the Chrome
DevTools Protocol (CDP), which is JSON-RPC over a WebSocket. The Python
stdlib lacks a WebSocket *client*, so a minimal RFC 6455 client is built here
over a raw socket. Everything else (launching Chrome, HTTP target discovery,
JSON, base64) is stdlib.

Features:
  - real CDP input events (Input.dispatchMouseEvent / dispatchKeyEvent /
    insertText) rather than JS .click()/value= injection
  - an accessibility `snapshot` that assigns @e1/@e2 refs to interactive
    nodes; refs persist across CLI calls and resolve back to real input
  - auto-wait/actionability: CSS targets wait until visible + position-stable
  - cookie + localStorage save/restore, and isolated multi-session browsers

Persistence model: "Chrome is the daemon." A launched Chrome stays alive
between CLI invocations; its port is recorded in a per-session state file and
each command reconnects a fresh WebSocket to it. The `cmd_*` functions are the
public API consumed by cli/commands/browser.jac; `main()` enables standalone
`jac run browser_engine.jac -- ...` use.
"""

import base64;
import hashlib;
import json;
import os;
import re;
import socket;
import struct;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from urllib.request { urlopen }

# --- WebSocket opcodes (RFC 6455) ---
glob OP_TEXT: int = 0x1,
     OP_CLOSE: int = 0x8,
     OP_PING: int = 0x9,
     OP_PONG: int = 0xA;

"""Accessibility roles worth assigning a @ref to in a snapshot."""
glob INTERACTIVE_ROLES: set = {"button","link","textbox","checkbox","radio","combobox","menuitem","tab","switch","searchbox","slider","option","menuitemcheckbox",};


# ===========================================================================
# Minimal RFC 6455 WebSocket client (the one piece the stdlib doesn't provide)
# ===========================================================================
"""Synchronous WebSocket client over a raw TCP socket.

Implements only what CDP needs: the client handshake, masked client->server
frames, fragmented-message reassembly, and automatic ping/pong handling.
"""
obj WebSocket {
    has url: str,
        timeout: float = 30.0,
        sock: socket.socket by postinit,
        _buf: bytearray by postinit,
        path: str by postinit;

    def postinit {
        if not self.url.startswith("ws://") {
            raise ValueError(f"only ws:// supported, got {self.url}");
        }
        rest = self.url[len("ws://"):];
        (host_port, _, tail) = rest.partition("/");
        (host, _, port) = host_port.partition(":");
        self.path = "/" + tail;
        port_num = int(port) if port else 80;
        self.sock = socket.create_connection((host, port_num), timeout=self.timeout);
        self.sock.settimeout(self.timeout);
        self._buf = bytearray();
        self._handshake(host, port_num);
    }

    def _handshake(host: str, port: int) {
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
        # Validate the server's accept token per the RFC.
        guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        expected = base64.b64encode(
            hashlib.sha1((key + guid).encode()).digest()
        ).decode();
        if expected.encode() not in header {
            raise ConnectionError("WebSocket Sec-WebSocket-Accept mismatch");
        }
    }

    def _read_until(delim: bytes) -> bytes {
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

    def _recv_exact(n: int) -> bytes {
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

    def send(data: (str | bytes), opcode: int = OP_TEXT) {
        payload = data.encode() if isinstance(data, str) else data;
        b0 = 0x80 | opcode;  # FIN + opcode
        header = bytearray([b0]);
        ln = len(payload);
        if ln < 126 {
            header.append(0x80 | ln);  # mask bit + length
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

    def _read_frame -> tuple {
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

    """Return one complete application message, handling control frames."""
    def recv -> (str | bytes) {
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
            if opcode != 0 {  # start of a new data message
                op_started = opcode;
            }
            chunks.extend(payload);
            if fin {
                return chunks.decode() if op_started == OP_TEXT else bytes(chunks);
            }
        }
    }

    def close {
        try {
            self.send(bytes(), opcode=OP_CLOSE);
        } except OSError {
        # socket already gone; nothing to flush
        }
        self.sock.close();
    }
}


# ===========================================================================
# CDP client: JSON-RPC over the WebSocket
# ===========================================================================
"""Talks the Chrome DevTools Protocol over a single WebSocket connection."""
obj CDP {
    has ws_url: str,
        _id: int = 0,
        ws: WebSocket by postinit;

    def postinit {
        self.ws = WebSocket(url=self.ws_url);
    }

    def call(method: str, params: (dict | None) = None, timeout: float = 30.0) -> dict {
        self._id += 1;
        msg_id = self._id;
        self.ws.send(
            json.dumps({"id": msg_id, "method": method, "params": params or {}})
        );
        deadline = time.time() + timeout;
        while time.time() < deadline {
            msg = json.loads(self.ws.recv());
            if msg.get("id") == msg_id {
                if "error" in msg {
                    raise RuntimeError(f"{method}: {msg['error']}");
                }
                return msg.get("result", {});
            }
            # else: an event for a domain we enabled; ignore in this tier.
        }
        raise TimeoutError(f"CDP call timed out: {method}");
    }

    def close {
        self.ws.close();
    }
}


# ===========================================================================
# Chrome process management + target discovery
# ===========================================================================
def get_cache_dir -> Path {
    env = os.environ.get("JACBROWSER_CACHE");
    return Path(env) if env else (Path.home() / ".cache" / "jacbrowser");
}

def _find_chrome -> str {
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
    # Playwright-managed Chromium (any installed version), newest first.
    pw = Path.home() / ".cache" / "ms-playwright";
    if pw.exists() {
        for d in sorted(pw.glob("chromium-*"), reverse=True) {
            exe = d / "chrome-linux64" / "chrome";
            if exe.exists() {
                return str(exe);
            }
        }
    }
    if Path("/opt/google/chrome/chrome").exists() {
        return "/opt/google/chrome/chrome";
    }
    raise FileNotFoundError("no Chrome/Chromium found; set JACBROWSER_CHROME");
}

def _state_path(session: str) -> Path {
    return get_cache_dir() / f"session-{session}.json";
}

def _refs_path(session: str) -> Path {
    return get_cache_dir() / f"refs-{session}.json";
}

def _pid_alive(pid: int) -> bool {
    try {
        os.kill(pid, 0);
        return True;
    } except OSError {
        return False;
    }
}

def _http_json(port: int, path: str) -> any {
    url = f"http://127.0.0.1:{port}{path}";
    with urlopen(url, timeout=5) as r {
        return json.loads(r.read());
    }
}

"""Return a page target's WebSocket URL, creating one if none exist."""
def _page_ws(port: int) -> str {
    for t in _http_json(port, "/json") {
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl") {
            return t["webSocketDebuggerUrl"];
        }
    }
    # No page target yet: mint one via the browser-level Target domain.
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

def load_state(session: str) -> (dict | None) {
    p = _state_path(session);
    if p.exists() {
        return json.loads(p.read_text());
    }
    return None;
}

"""Launch headless Chrome and record session state. Idempotent if alive."""
def launch(session: str = "default") -> dict {
    st = load_state(session);
    if st and _pid_alive(st["pid"]) {
        try {
            _http_json(st["port"], "/json/version");
            return st;
        } except OSError {
        # stale endpoint; fall through and relaunch below
        }
    }
    cache = get_cache_dir();
    cache.mkdir(parents=True, exist_ok=True);
    profile = cache / f"profile-{session}";
    chrome = _find_chrome();
    proc = subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--remote-debugging-port=0",
            f"--user-data-dir={profile}",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-gpu",
            "--no-sandbox",
            "about:blank",

        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    );
    # Chrome writes the chosen port to DevToolsActivePort. Clear any stale file
    # first so we don't read a dead port from a prior run.
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
    st = {"session": session, "pid": proc.pid, "port": port};
    _state_path(session).write_text(json.dumps(st));
    return st;
}

"""Reconnect a fresh CDP session to the persistent Chrome for `session`."""
def connect(session: str = "default") -> CDP {
    st = load_state(session);
    if (not st) or (not _pid_alive(st["pid"])) {
        raise RuntimeError(
            f"no live browser for session '{session}'; run `open` first"
        );
    }
    return CDP(ws_url=_page_ws(st["port"]));
}


# ===========================================================================
# Shared helpers
# ===========================================================================
def _eval(cdp: CDP, expr: str) -> any {
    res = cdp.call(
        "Runtime.evaluate",
        {"expression": expr, "returnByValue": True, "awaitPromise": True,}
    );
    details = res.get("exceptionDetails");
    if details {
        desc = (details.get("exception") or {}).get("description");
        raise RuntimeError(desc or details.get("text", "JS exception"));
    }
    return res.get("result", {}).get("value");
}

def _load_refs(session: str) -> dict {
    p = _refs_path(session);
    if p.exists() {
        return json.loads(p.read_text());
    }
    return {};
}

"""Resolve a selector to viewport coordinates, waiting for actionability.

`@e3` resolves via the saved accessibility snapshot -> backend node -> box
model. A CSS selector auto-waits until the element is present, visible, and
has a position-stable bounding box, then returns its center.
"""
def _locate(cdp: CDP, session: str, selector: str, timeout: float = 10.0) -> tuple {
    deadline = time.time() + timeout;
    if selector.startswith("@") {
        ref = selector[1:];
        backend = _load_refs(session).get(ref);
        if backend is None {
            raise RuntimeError(f"unknown ref '{selector}'; run `snapshot` first");
        }
        cdp.call("DOM.enable");
        last_err = "";
        while time.time() < deadline {
            try {
                box = cdp.call("DOM.getBoxModel", {"backendNodeId": backend});
                quad = box["model"]["content"];
                return ((quad[0] + quad[4]) / 2, (quad[1] + quad[5]) / 2);
            } except Exception as e {
                last_err = str(e);  # node not yet laid out; retry
                time.sleep(0.1);
            }
        }
        raise RuntimeError(f"ref '{selector}' not actionable: {last_err}");
    }
    # CSS selector: poll for a visible element whose box is stable across samples.
    js = (
        f"(()=>{{const el=document.querySelector({json.dumps(selector)});"
        "if(!el)return null;const r=el.getBoundingClientRect();"
        "const ok=r.width>0&&r.height>0&&getComputedStyle(el).visibility!=='hidden';"
        "return ok?[r.x+r.width/2, r.y+r.height/2]:null;})()"
    );
    prev = None;
    while time.time() < deadline {
        val = _eval(cdp, js);
        if val is not None {
            if prev is not None
            and abs(val[0] - prev[0]) < 1
            and abs(val[1] - prev[1]) < 1 {
                return (val[0], val[1]);
            }
            prev = val;
        }
        time.sleep(0.1);
    }
    raise RuntimeError(f"element not found or not stable: {selector}");
}

"""Real mouse click via the Input domain (trusted events, unlike el.click())."""
def _real_click(cdp: CDP, x: float, y: float) {
    cdp.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y});
    base = {"x": x, "y": y, "button": "left", "clickCount": 1};
    cdp.call("Input.dispatchMouseEvent", {"type": "mousePressed"} | base);
    cdp.call("Input.dispatchMouseEvent", {"type": "mouseReleased"} | base);
}

"""Type text as real per-character key events into the focused element."""
def _type_text(cdp: CDP, text: str) {
    for ch in text {
        cdp.call("Input.dispatchKeyEvent", {"type": "keyDown", "text": ch});
        cdp.call("Input.dispatchKeyEvent", {"type": "keyUp"});
    }
}

glob KEY_CODES: dict = {
         "Enter": 13,
         "Tab": 9,
         "Escape": 27,
         "Backspace": 8,
         "Delete": 46,
         "ArrowLeft": 37,
         "ArrowUp": 38,
         "ArrowRight": 39,
         "ArrowDown": 40,

     };

"""Insert text in one shot (like a paste) as a trusted input event."""
def _insert_text(cdp: CDP, text: str) {
    cdp.call("Input.insertText", {"text": text});
}

"""DOM `code` for a printable char (KeyA, Digit1, ...) so combos register."""
def _key_code(ch: str) -> str {
    if ch.isalpha() {
        return "Key" + ch.upper();
    }
    if ch.isdigit() {
        return "Digit" + ch;
    }
    return ch;
}

"""Press a single named key (Enter, Tab, ...) or printable char as real events.

A printable char with no modifiers emits `text` (so it types); with a modifier
(e.g. Ctrl+A) it emits the virtual key code only, so the browser treats it as a
shortcut rather than inserting the character.
"""
def _press(cdp: CDP, key: str, modifiers: int = 0) {
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


# ===========================================================================
# Command surface
# ===========================================================================
def cmd_open(session: str, url: (str | None)) -> str {
    launch(session);
    if url {
        return cmd_navigate(session, url);
    }
    return "browser ready (about:blank)";
}

def cmd_navigate(session: str, url: str) -> str {
    # Add a scheme only to bare hosts (example.com); leave data:, file:, etc.
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url) {
        url = "https://" + url;
    }
    cdp = connect(session);
    cdp.call("Page.enable");
    cdp.call("Page.navigate", {"url": url});
    # Tier-0/1 load wait: poll readyState rather than wiring load events.
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

def cmd_eval(session: str, expr: str) -> any {
    cdp = connect(session);
    out = _eval(cdp, expr);
    cdp.close();
    return out;
}

def cmd_click(session: str, selector: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    cdp.close();
    return f"clicked {selector} at ({int(x)},{int(y)})";
}

def cmd_type(session: str, selector: str, text: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);  # focus first
    _type_text(cdp, text);
    cdp.close();
    return f"typed into {selector}";
}

def cmd_fill(session: str, selector: str, text: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    _press(cdp, "a", modifiers=2);  # Ctrl+A (modifiers bit 2 = Ctrl)
    _press(cdp, "Delete");
    _insert_text(cdp, text);  # fast, paste-like insertion
    cdp.close();
    return f"filled {selector}";
}

def cmd_press(session: str, key: str) -> str {
    cdp = connect(session);
    _press(cdp, key);
    cdp.close();
    return f"pressed {key}";
}

def cmd_get(session: str, what: str, selector: (str | None)) -> any {
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

def cmd_screenshot(session: str, path: (str | None)) -> str {
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

"""Walk the accessibility tree, printing an indented view and assigning @refs."""
def _walk_ax(ax: dict, by_id: dict, depth: int, lines: list, refs: dict) {
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

def cmd_snapshot(session: str) -> str {
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

"""Project a CDP Cookie down to the fields Network.setCookies accepts."""
def _cookie_param(ck: dict) -> dict {
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

"""Save or load cookies + localStorage for a session: state <save|load> <path>."""
def cmd_state(session: str, sub: str, path: str) -> str {
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

"""List known sessions and whether each session's browser is still alive."""
def cmd_sessions(session: str) -> str {
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
        } except Exception {
        # skip unreadable/partial state file
        }
    }
    return "\n".join(lines) if lines else "(no sessions)";
}

def cmd_close(session: str) -> str {
    st = load_state(session);
    if st and _pid_alive(st["pid"]) {
        try {
            os.kill(st["pid"], 15);
        } except OSError {
        # process already dead
        }
    }
    _state_path(session).unlink(missing_ok=True);
    _refs_path(session).unlink(missing_ok=True);
    return "closed";
}


# ===========================================================================
# Standalone CLI dispatch (stands in for jac subcommand wiring)
# ===========================================================================
def main(argv: list) -> int {
    session = os.environ.get("JACBROWSER_SESSION", "default");
    if not argv {
        sys.stdout.write(
            "usage: browser_engine.jac <open|navigate|eval|click|type|fill|press|get|snapshot|screenshot|state|sessions|close> ...\n"
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

with entry:__main__ {
    sys.exit(main(sys.argv[1:]));
}
