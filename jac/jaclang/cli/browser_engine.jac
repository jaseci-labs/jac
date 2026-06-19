"""Browser-automation engine backing the `jac browse` subcommand.

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
  - auto-wait/actionability: targets (CSS and @ref) are scrolled into view
    and must be visible, position-stable, inside the viewport, and the top
    element at their action point — otherwise the action hard-errors instead
    of silently no-opping offscreen
  - `console` reads buffered console/log/exception output (Chrome replays
    its per-context buffers to a newly attached session on enable)
  - software WebGL (SwiftShader) and a real 1280x720 default viewport
  - `wait <ms|selector>` and `scroll <dir|top|bottom|selector>` helpers
  - cookie + localStorage save/restore, and isolated multi-session browsers

Persistence model: "Chrome is the daemon." A launched Chrome stays alive
between CLI invocations; its port is recorded in a per-session state file and
each command reconnects a fresh WebSocket to it. The `cmd_*` functions are the
public API consumed by cli/commands/browser.jac; `main()` enables standalone
`jac run browser_engine.jac -- ...` use.

This module holds declarations only; method/function bodies live in
cli/impl/browser_engine.impl.jac.
"""

import socket;
import sys;
import from pathlib { Path }

# --- WebSocket opcodes (RFC 6455) ---
glob OP_TEXT: int = 0x1,
     OP_CLOSE: int = 0x8,
     OP_PING: int = 0x9,
     OP_PONG: int = 0xA;

"""Accessibility roles worth assigning a @ref to in a snapshot."""
glob INTERACTIVE_ROLES: set = {
         "button",
         "link",
         "textbox",
         "checkbox",
         "radio",
         "combobox",
         "menuitem",
         "tab",
         "switch",
         "searchbox",
         "slider",
         "option",
         "menuitemcheckbox",

     };

"""In-page actionability check run on a resolved element via
Runtime.callFunctionOn (`this` is the element).

Scrolls the element into view, requires a visible non-empty box, translates
the box center into top-frame viewport coordinates (walking up same-origin
iframes), rejects points outside the viewport, and hit-tests
`elementFromPoint` so a covering element fails loudly instead of swallowing
the click. Returns {ok, reason} or {ok, x, y, hitOk, hit}.
"""
glob ACTIONABILITY_JS: str = """
function() {
  const el = this;
  if (el.scrollIntoViewIfNeeded) { el.scrollIntoViewIfNeeded(true); }
  else { el.scrollIntoView({block: 'center', inline: 'center'}); }
  const r = el.getBoundingClientRect();
  const cs = getComputedStyle(el);
  if (!(r.width > 0 && r.height > 0)
      || cs.visibility === 'hidden' || cs.display === 'none') {
    return {ok: false, reason: 'element is not visible'};
  }
  let x = r.x + r.width / 2, y = r.y + r.height / 2;
  const hit = el.ownerDocument.elementFromPoint(x, y);
  const hitOk = !!hit && (hit === el || el.contains(hit) || hit.contains(el));
  const hitDesc = hit
    ? hit.tagName.toLowerCase() + (hit.id ? '#' + hit.id : '') : 'nothing';
  let win = el.ownerDocument.defaultView;
  try {
    while (win && win.frameElement) {
      const fr = win.frameElement.getBoundingClientRect();
      x += fr.x; y += fr.y;
      win = win.parent;
    }
  } catch (e) { /* cross-origin frame: keep best-effort coords */ }
  const vw = win.innerWidth, vh = win.innerHeight;
  if (x < 0 || y < 0 || x >= vw || y >= vh) {
    return {ok: false, reason: 'point (' + Math.round(x) + ',' + Math.round(y)
            + ') is outside the ' + vw + 'x' + vh + ' viewport'};
  }
  return {ok: true, x: x, y: y, hitOk: hitOk, hit: hitDesc};
}
""";

"""Virtual key codes for the named keys `press` understands."""
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

    def _handshake(host: str, port: int);
    def _read_until(delim: bytes) -> bytes;
    def _recv_exact(n: int) -> bytes;
    def send(data: (str | bytes), opcode: int = OP_TEXT);
    def _read_frame -> tuple;
    """Return one complete application message, handling control frames."""
    def recv -> (str | bytes);

    def close;
}


# ===========================================================================
# CDP client: JSON-RPC over the WebSocket
# ===========================================================================
"""Talks the Chrome DevTools Protocol over a single WebSocket connection."""
obj CDP {
    has ws_url: str,
        _id: int = 0,
        ws: WebSocket by postinit,
        events: list by postinit;

    def postinit {
        self.ws = WebSocket(url=self.ws_url);
        self.events = [];
    }

    def call(method: str, params: (dict | None) = None, timeout: float = 30.0) -> dict;
    """Drain buffered + in-flight CDP events until `idle` seconds of quiet."""
    def drain_events(idle: float = 0.25) -> list;

    def close;
}


# ===========================================================================
# Chrome process management + target discovery
# ===========================================================================
def get_cache_dir -> Path;
def _find_chrome -> str;
def _state_path(session: str) -> Path;
def _refs_path(session: str) -> Path;
def _pid_alive(pid: int) -> bool;
def _http_json(port: int, path: str) -> any;

"""Return a page target's WebSocket URL, creating one if none exist."""
def _page_ws(port: int) -> str;

def load_state(session: str) -> (dict | None);

"""Parse a WIDTHxHEIGHT (or WIDTH,HEIGHT) viewport spec into (w, h)."""
def _parse_viewport(spec: str) -> tuple;

"""Build the headless-Chrome launch argv for a session profile + viewport."""
def _chrome_args(chrome: str, profile: Path, viewport: str) -> list;

"""Grow the window by the measured chrome delta so the page viewport matches
the requested size exactly (--window-size includes window decorations).
Best-effort: uses Browser.setWindowBounds, which persists browser-side.
"""
def _calibrate_viewport(port: int, w: int, h: int);

"""Launch headless Chrome and record session state. Idempotent if alive."""
def launch(session: str = "default", viewport: str = "1280x720") -> dict;

"""Reconnect a fresh CDP session to the persistent Chrome for `session`."""
def connect(session: str = "default") -> CDP;


# ===========================================================================
# Shared helpers
# ===========================================================================
def _eval(cdp: CDP, expr: str) -> any;
def _load_refs(session: str) -> dict;

"""Resolve a selector (CSS or @ref) to a Runtime objectId, or None if absent.

`@e3` resolves via the saved accessibility snapshot -> backend node; a CSS
selector resolves via document.querySelector. Raises on an unknown @ref.
"""
def _resolve_object_id(cdp: CDP, session: str, selector: str) -> (str | None);

"""Resolve a selector to viewport coordinates, waiting for actionability.

Both `@e3` refs and CSS selectors funnel through ACTIONABILITY_JS on the
resolved element: it is scrolled into view and must be visible,
position-stable across samples, inside the viewport, and the top element at
its center. Anything else raises (a wrong error beats a wrong success).
"""
def _locate(cdp: CDP, session: str, selector: str, timeout: float = 10.0) -> tuple;

"""Real mouse click via the Input domain (trusted events, unlike el.click())."""
def _real_click(cdp: CDP, x: float, y: float);

"""Type text as real per-character key events into the focused element."""
def _type_text(cdp: CDP, text: str);

"""Insert text in one shot (like a paste) as a trusted input event."""
def _insert_text(cdp: CDP, text: str);

"""DOM `code` for a printable char (KeyA, Digit1, ...) so combos register."""
def _key_code(ch: str) -> str;

"""Press a single named key (Enter, Tab, ...) or printable char as real events.

A printable char with no modifiers emits `text` (so it types); with a modifier
(e.g. Ctrl+A) it emits the virtual key code only, so the browser treats it as a
shortcut rather than inserting the character.
"""
def _press(cdp: CDP, key: str, modifiers: int = 0);


# ===========================================================================
# Command surface
# ===========================================================================
def cmd_open(session: str, url: (str | None), viewport: str = "1280x720") -> str;
def cmd_navigate(session: str, url: str) -> str;
def cmd_eval(session: str, expr: str) -> any;
def cmd_click(session: str, selector: str) -> str;
def cmd_type(session: str, selector: str, text: str) -> str;
def cmd_fill(session: str, selector: str, text: str) -> str;
def cmd_press(session: str, key: str) -> str;
def cmd_get(session: str, what: str, selector: (str | None)) -> any;
def cmd_screenshot(session: str, path: (str | None)) -> str;

"""Render one CDP console/log/exception event as a console line, else None."""
def _format_console_event(method: str, params: dict) -> (str | None);

"""Best-effort one-token rendering of a CDP RemoteObject."""
def _remote_obj_str(ro: dict) -> str;

"""Read buffered console/log output; `clear` discards it after reading.

Chrome buffers console API calls, log entries, and uncaught exceptions per
context and replays them to a newly attached session on Runtime/Log enable,
so no resident listener process is needed: connect, enable, drain, format.
"""
def cmd_console(session: str, clear: bool = False) -> str;

"""Wait for a duration in ms (digits) or for a selector to become actionable."""
def cmd_wait(session: str, arg: str, timeout: float = 30.0) -> str;

"""Scroll the page (up/down/left/right/top/bottom) or an element into view."""
def cmd_scroll(session: str, target: str, amount: (int | None) = None) -> str;

"""Walk the accessibility tree, printing an indented view and assigning @refs."""
def _walk_ax(ax: dict, by_id: dict, depth: int, lines: list, refs: dict);

def cmd_snapshot(session: str) -> str;

"""Project a CDP Cookie down to the fields Network.setCookies accepts."""
def _cookie_param(ck: dict) -> dict;

"""Save or load cookies + localStorage for a session: state <save|load> <path>."""
def cmd_state(session: str, sub: str, path: str) -> str;

"""List known sessions and whether each session's browser is still alive."""
def cmd_sessions(session: str) -> str;

def cmd_close(session: str) -> str;


# ===========================================================================
# Standalone CLI dispatch (stands in for jac subcommand wiring)
# ===========================================================================
def main(argv: list) -> int;

with entry:__main__ {
    sys.exit(main(sys.argv[1:]));
}
