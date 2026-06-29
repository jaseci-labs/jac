import socket;
import sys;
import from pathlib { Path }

glob OP_TEXT: int = 0x1,
     OP_CLOSE: int = 0x8,
     OP_PING: int = 0x9,
     OP_PONG: int = 0xA;

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
    def recv -> (str | bytes);
    def close;
}


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
    def drain_events(idle: float = 0.25) -> list;
    def close;
}


def get_cache_dir -> Path;
def _find_chrome -> str;
def _state_path(session: str) -> Path;
def _refs_path(session: str) -> Path;
def _pid_alive(pid: int) -> bool;
def _http_json(port: int, path: str) -> any;

def _page_ws(port: int) -> str;

def load_state(session: str) -> (dict | None);

def _parse_viewport(spec: str) -> tuple;

def _chrome_args(chrome: str, profile: Path, viewport: str) -> list;

def _calibrate_viewport(port: int, w: int, h: int);

def launch(session: str = "default", viewport: str = "1280x720") -> dict;

def connect(session: str = "default") -> CDP;


def _eval(cdp: CDP, expr: str) -> any;
def _load_refs(session: str) -> dict;

def _resolve_object_id(cdp: CDP, session: str, selector: str) -> (str | None);

def _locate(cdp: CDP, session: str, selector: str, timeout: float = 10.0) -> tuple;

def _real_click(cdp: CDP, x: float, y: float);

def _type_text(cdp: CDP, text: str);

def _insert_text(cdp: CDP, text: str);

def _key_code(ch: str) -> str;

def _press(cdp: CDP, key: str, modifiers: int = 0);


def cmd_open(session: str, url: (str | None), viewport: str = "1280x720") -> str;
def cmd_navigate(session: str, url: str) -> str;
def cmd_eval(session: str, expr: str) -> any;
def cmd_click(session: str, selector: str) -> str;
def cmd_type(session: str, selector: str, text: str) -> str;
def cmd_fill(session: str, selector: str, text: str) -> str;
def cmd_press(session: str, key: str) -> str;
def cmd_get(session: str, what: str, selector: (str | None)) -> any;
def cmd_screenshot(session: str, path: (str | None)) -> str;

def _format_console_event(method: str, params: dict) -> (str | None);

def _remote_obj_str(ro: dict) -> str;

def cmd_console(session: str, clear: bool = False) -> str;

def cmd_wait(session: str, arg: str, timeout: float = 30.0) -> str;

def cmd_scroll(session: str, target: str, amount: (int | None) = None) -> str;

def _walk_ax(ax: dict, by_id: dict, depth: int, lines: list, refs: dict);

def cmd_snapshot(session: str) -> str;

def _cookie_param(ck: dict) -> dict;

def cmd_state(session: str, sub: str, path: str) -> str;

def cmd_sessions(session: str) -> str;

def cmd_close(session: str) -> str;


def main(argv: list) -> int;

with entry:__main__ {
    sys.exit(main(sys.argv[1:]));
}
