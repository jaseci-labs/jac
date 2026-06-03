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
  - auto-wait/actionability: CSS targets wait until visible + position-stable
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
        ws: WebSocket by postinit;

    def postinit {
        self.ws = WebSocket(url=self.ws_url);
    }

    def call(method: str, params: (dict | None) = None, timeout: float = 30.0) -> dict;
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

"""Launch headless Chrome and record session state. Idempotent if alive."""
def launch(session: str = "default") -> dict;

"""Reconnect a fresh CDP session to the persistent Chrome for `session`."""
def connect(session: str = "default") -> CDP;


# ===========================================================================
# Shared helpers
# ===========================================================================
def _eval(cdp: CDP, expr: str) -> any;
def _load_refs(session: str) -> dict;

"""Resolve a selector to viewport coordinates, waiting for actionability.

`@e3` resolves via the saved accessibility snapshot -> backend node -> box
model. A CSS selector auto-waits until the element is present, visible, and
has a position-stable bounding box, then returns its center.
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
def cmd_open(session: str, url: (str | None)) -> str;
def cmd_navigate(session: str, url: str) -> str;
def cmd_eval(session: str, expr: str) -> any;
def cmd_click(session: str, selector: str) -> str;
def cmd_type(session: str, selector: str, text: str) -> str;
def cmd_fill(session: str, selector: str, text: str) -> str;
def cmd_press(session: str, key: str) -> str;
def cmd_get(session: str, what: str, selector: (str | None)) -> any;
def cmd_screenshot(session: str, path: (str | None)) -> str;

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
