 How OS/File System Functionality Works in the Desktop Target

 ### Short answer: No, you do not need to write C or any OS-level code. The architecture gives you three layers of access, none requiring native code.

 ### Native vs CEF renderer (FFI note)

 Both `jac build --client desktop` and `jac build --client desktop-cef` share the
 same embedded-Python loopback server (`oauth_broker.py`, `/__jac/*` routes,
 stable port strategy). They differ only in how the shell renders
 `http://127.0.0.1:<port>/`:

 | | Native (`desktop`) | CEF (`desktop-cef`) |
 |--|-------------------|---------------------|
 | Window engine | OS webview (`libwebview.so`) | Chromium (`libcef.so` via `libcef_shim.so`) |
 | Host binary | Jac `na` (`jac nacompile`) | Jac `na` (`jac nacompile`) |
 | libpython | AOT-linked via Jac FFI | AOT-linked via Jac FFI |

 libpython is embedded in both targets **only** to run the loopback HTTP server —
 it is not the Chromium/webview FFI. See
 [`jac_desktop/native/cef/README.md`](jac-desktop/jac_desktop/native/cef/README.md)
 for the CEF-specific layer diagram.

 ### The Three Channels

 ```
   ┌──────────────────────────────────────────────────────────┐
   │                   Your SPA (cl codespace)                 │
   │         JavaScript running in the webview                 │
   │                                                          │
   │  1. Web APIs (limited)   fetch(), localStorage, etc.     │
   │  2. /__jac/* HTTP routes  ← talks to embedded CPython    │
   │  3. window.<name>()       ← JS↔native bridge (webview_bind)│
   └──────────┬──────────────────────┬────────────────────────┘
              │ HTTP (loopback)      │ direct C callback
              ▼                      ▼
   ┌──────────────────────┐  ┌───────────────────────┐
   │  Embedded CPython     │  │  Native binary (na)   │
   │  (Python stdlib)      │  │  (Jac-compiled)       │
   │  • os, json, pathlib  │  │  • C FFI to libwebview│
   │  • http.server        │  │  • C FFI to libpython │
   │  • oauth_broker.py    │  │  • Could link any .so │
   │  • FUTURE: sv walkers │  │                       │
   └──────────────────────┘  └───────────────────────┘
 ```

 ### Channel 1: Web APIs (no setup needed)

 The SPA runs in a real browser engine (WebKitGTK/WKWebView/WebView2). You get standard web APIs:

 - fetch() for HTTP
 - localStorage / sessionStorage (persisted to disk by WebKit per-origin — that's why the stable deterministic port matters)
 - IndexedDB, Canvas, WebGL, etc.
 - Whatever the OS web engine supports

 Limitation: No direct file system, shell, or OS access (same sandbox as any web page).

 ### Channel 2: HTTP routes via the embedded loopback server (how it works today)

 This is the primary channel currently in use. The embedded CPython runs a socketserver.TCPServer on 127.0.0.1:<port> that:
 - Serves your static SPA bundle from dist/
 - Routes /__jac/* to Python handlers (today: the OAuth broker)

 To add file system access, you'd add HTTP route handlers to the broker:

 ```python
   # In oauth_broker.jac (or a new companion module)
   def do_GET(self):
       route = urlparse(self.path).path
       if route == "/__jac/fs/read":
           # Read a file and return it
           path = parse_qs(urlparse(self.path).query).get("path", [""])[0]
           with open(path) as f:
               content = f.read()
           self._json({"ok": True, "content": content})
           return
       if route == "/__jac/fs/write":
           # Write a file
           ...
       super.do_GET()  # fall through to static serving
 ```

 Then from your SPA:

 ```js
   const res = await fetch('/__jac/fs/read?path=/tmp/hello.txt');
   const data = await res.json();
 ```

 No native code required — the handler is just Python (std lib), transpiled from Jac at build time.

 ### Channel 3: JS↔Native bridge via webview_bind (the direct path)

 The webview binding already exposes wv.bind(name, handler) which registers window.<name>() in JavaScript and dispatches to a native (Jac na) handler:

 ```jac
   # In the generated host.na.jac
   def on_read_file(id: int, req: int, arg: int) -> None {
       # req is a raw C string pointer carrying JSON args
       # Parse it, do file I/O via the CPython FFI, respond
       respond(arg, id, "{\"content\": \"hello\"}");
   }

   wv.bind("readFile", on_read_file);
 ```

 Then from JS:

 ```js
   const result = await window.readFile('{"path": "/tmp/hello.txt"}');
 ```

 This is the most powerful channel (no HTTP round-trip, direct C-level callback) but currently the generated host only uses bind in the test suite — the real host doesn't register any bound functions yet.

 ### What's Coming: sv walkers in-process

 The README calls this out as the remaining work:

 │ "Remaining: wiring the sv codespace/walkers onto the embedded interpreter"

 The architecture is designed for this: the embedded CPython is already there, it just doesn't have jaclang loaded yet. Once wired:

 ```
   ┌──────────────────────────────────────────┐
   │         Your SPA (cl codespace)          │
   │     sv import from backend { read_file } │
   └─────────────┬────────────────────────────┘
                 │  HTTP POST /function/read_file
                 │  (same loopback server)
                 ▼
   ┌──────────────────────────────────────────┐
   │       Embedded CPython + jaclang          │
   │       sv walkers run IN-PROCESS           │
   │       • Full Python stdlib (os, shutil)   │
   │       • Full jaclang runtime              │
   │       • Database, network, everything     │
   └──────────────────────────────────────────┘
 ```

 Your cl code already uses sv import from backend { func } for server calls. In the desktop target, instead of calling a remote server over the network, the compiler will route those calls to the in-process
 embedded interpreter. From your perspective as a developer, the same code works:

 ```jac
   # In your cl file
   sv import from my_backend { read_file, write_file, list_dir };

   data = await read_file(path="/tmp/hello.txt");
 ```

 On the web target → HTTP to remote server.
 On the desktop target → in-process Python call. Same code, same import.

 ### Summary

 ┌──────────────────────────────────────────────────────────────────┬────────────────────┬───────────────────────────────────────────────────────┐
 │ Approach                                                         │ Write native code? │ Status                                                │
 ├──────────────────────────────────────────────────────────────────┼────────────────────┼───────────────────────────────────────────────────────┤
 │ Web APIs (fetch, localStorage)                                   │ No                 │ ✅ Works today                                        │
 ├──────────────────────────────────────────────────────────────────┼────────────────────┼───────────────────────────────────────────────────────┤
 │ HTTP routes on /__jac/* (Python handlers in the loopback server) │ No (Python/Jac)    │ ✅ Works today (OAuth broker is the pattern)          │
 ├──────────────────────────────────────────────────────────────────┼────────────────────┼───────────────────────────────────────────────────────┤
 │ sv import → in-process walkers                                   │ No (Jac/Python)    │ 🚧 Coming (the embedded CPython is already there)     │
 ├──────────────────────────────────────────────────────────────────┼────────────────────┼───────────────────────────────────────────────────────┤
 │ window.<name>() JS↔native bridge                                 │ Yes (Jac na)       │ ✅ Binding exists, not yet used by the generated host │
 └──────────────────────────────────────────────────────────────────┴────────────────────┴───────────────────────────────────────────────────────┘

 The intended developer experience is sv import: you write your OS-level logic as Jac sv functions (file I/O, shell commands, whatever), and the desktop target runs them in-process. No C, no native code, just
 Jac.
