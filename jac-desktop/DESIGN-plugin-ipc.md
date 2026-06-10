# Desktop Plugin IPC -- Design Document

## Problem

The desktop shell has exactly one bridge mechanism: `webview.bind()` registers a JS
function whose return value is a Promise resolved by `webview_return()` on the native
side. This is used once for `oauth_broker.jac` (OAuth SSO). There is no general-purpose
IPC, no plugin registry, and no OS capability APIs.

JS code running in the webview cannot read files, show native dialogs, send
notifications, or access any OS capability. Every app that needs these must build its
own ad-hoc bridge.

## Solution

A plugin host + built-in capability plugins, exposed to JS as `window.__jac.invoke()`
and `window.__jac.on()`. Plugins are transpiled to Python at build time and run inside
the embedded CPython (same model as `oauth_broker.jac`). A thin native shim bridges
the webview callback into CPython.

## Architecture

```
┌─────────────────────── Webview (JS world) ───────────────────────┐
│  window.__jac.invoke("fs", "read_file", { path: "~/foo.txt" })  │
│  window.__jac.on("window:focus", handler)                        │
│                                                                   │
│  [single bound function: window.__jac_invoke(jsonStr)]           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ webview_bind / webview_return
┌──────────────────────────▼──────────────────────────────────────┐
│  plugin_bridge.na.jac (~20 lines, native shim)                  │
│    _jac_invoke_handler(id, req_ptr, wv_handle)                  │
│      req_str: str = req_ptr   # inttoptr i64 → i8*              │
│      gstate = PyGILState_Ensure()                               │
│      result = PyObject_CallOneArg(dispatch_fn, py_req_str)      │
│      PyGILState_Release(gstate)                                 │
│      webview_return(wv_handle, id, 0, result)                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ PyObject_CallOneArg (GIL-protected)
┌──────────────────────────▼──────────────────────────────────────┐
│  Plugin Host + Plugins (embedded CPython, transpiled from .jac) │
│                                                                  │
│  plugin_host.py:                                                 │
│    dispatch(req_json) → json.loads → plugins[name].handle()     │
│    emit(event, payload) → ctypes → webview_eval()               │
│                                                                  │
│  plugins registry:                                               │
│    "jac.window"       → WindowPlugin   (ctypes → libwebview)    │
│    "jac.path"         → PathPlugin     (os, pathlib)            │
│    "jac.fs"           → FsPlugin       (pathlib + allow-list)   │
│    "jac.notification" → NotificationPlugin (subprocess)         │
│    "jac.clipboard"    → ClipboardPlugin    (subprocess)         │
│    "jac.dialog"       → DialogPlugin        (subprocess)        │
│    "jac.shell"        → ShellPlugin  (subprocess, deny-all)     │
│                                                                  │
│  oauth_broker.py ← UNCHANGED                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Why Two Layers?

The native backend has no `json.loads` / `json.dumps`. Dispatch requires parsing
`{"plugin":"fs","command":"read_file","args":{...}}` -- impossible with string ops
alone. The embedded CPython already runs alongside the webview (for the OAuth broker
and HTTP server), so dispatch lives there too. This is the exact same model
`oauth_broker.jac` already uses: `.jac` source → `jac2py` at build time → pure-stdlib
Python staged beside the binary.

The native shim (`plugin_bridge.na.jac`) is the minimum viable bridge: ~20 lines that
handle the `inttoptr` coercion (C string pointer → Jac `str`), GIL management, and
the CPython function call.

## IPC Protocol

### JS → Native

The single bound function receives a JSON string:

```json
{ "plugin": "fs", "command": "read_file", "args": { "path": "~/notes.txt" } }
```

### Native → JS (response)

`webview_return` resolves the JS promise with a JSON string:

```json
{ "ok": true,  "data": "file contents" }
{ "ok": false, "error": { "code": "NOT_FOUND", "message": "No such file" } }
```

### Native → JS (push events)

```js
window.__jac.__emit__("window:focus-changed", { "focused": true })
```

Pushed via `webview_eval()` from CPython through ctypes into libwebview.

## JS SDK

Injected via `wv.on_load()` before any page script runs. Replaces the existing
bootstrap (`window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac'`) with a
backward-compatible superset:

```js
(function() {
  var _listeners = {};
  window.__jac = {
    invoke: function(plugin, command, args) {
      return window.__jac_invoke(JSON.stringify({
        plugin: plugin, command: command, args: args || {}
      })).then(function(json) {
        var r = JSON.parse(json);
        if (r.ok) return r.data;
        var e = new Error(r.error.message);
        e.code = r.error.code;
        throw e;
      });
    },
    on: function(event, cb) {
      (_listeners[event] = _listeners[event] || []).push(cb);
      return function() {
        var a = _listeners[event] || [];
        var i = a.indexOf(cb);
        if (i !== -1) a.splice(i, 1);
      };
    },
    __emit__: function(event, payload) {
      (_listeners[event] || []).forEach(function(h) {
        try { h(payload); } catch(_) {}
      });
    }
  };
  window.__JAC_DESKTOP__ = true;
  window.__JAC_BROKER__ = '/__jac';
})();
```

## Native Shim: `plugin_bridge.na.jac`

> **Implementation note**: The bridge is now **inlined** directly into the generated
> host source (see `_generate_host_source()`). The standalone file is kept for
> documentation. `nacompile` does not support `import from "file.na.jac"` for
> native code -- string-literal imports only work for client `.cl.jac` files.

~20 lines. Originally designed as a separate native file. Now inlined into the
generated host at build time.

```jac
import from webview { Webview, respond }

import from "<libpy>" {
    def PyGILState_Ensure() -> int;
    def PyGILState_Release(state: int) -> None;
    def PyObject_CallOneArg(fn: int, arg: int) -> int;
    def PyUnicode_FromString(s: str) -> int;
    def PyUnicode_AsUTF8(obj: int) -> str;
    def Py_DecRef(obj: int) -> None;
}

# PyObject* to plugin_host.dispatch, set during CPython bootstrap
glob _PH_DISPATCH: int = 0;

def _jac_invoke_handler(id: int, req: int, wv_handle: int) -> None {
    req_str: str = req;   # inttoptr i64 → i8*, valid for callback lifetime
    gstate = PyGILState_Ensure();
    py_req = PyUnicode_FromString(req_str);
    py_result = PyObject_CallOneArg(_PH_DISPATCH, py_req);
    result_str = PyUnicode_AsUTF8(py_result);
    Py_DecRef(py_req);
    Py_DecRef(py_result);
    PyGILState_Release(gstate);
    respond(wv_handle, id, result_str);
}
```

### Key Details

- **`req_str: str = req`** -- The `inttoptr` coercion from `int` to `str` (i8*) is
  confirmed by `fix_ptr_int_coerce.na.jac` in the test fixtures. The C library owns
  the string memory; it is valid for the duration of the callback.

- **Free function, not a bound method** -- `test_binding.jac` proves free functions
  work as `webview_bind` callbacks. Bound methods (`self._on_invoke`) are untested
  and may not lower correctly to a C-compatible function pointer.

- **`PyGILState_Ensure` / `Release`** -- The host calls `PyEval_SaveThread()` before
  `wv.run()`, releasing the GIL so the HTTP server thread can run. When the webview
  callback fires on the main thread, the GIL is not held. `PyGILState_Ensure` is the
  correct API for acquiring the GIL from any context without needing the original
  `PyEval_SaveThread` return value. `PyEval_RestoreThread(ts)` is not re-entrant.

- **`_PH_DISPATCH`** -- A global `int` holding a `PyObject*` pointer to the Python
  `plugin_host.dispatch` function. Set during the CPython bootstrap (same
  `PyRun_SimpleString` block that sets up the HTTP server today).

## Plugin Host: `plugin_host.jac` → `plugin_host.py`

Transpiled at build time. Runs in the embedded CPython. Has full stdlib access
(`json`, `os`, `pathlib`, `subprocess`, `ctypes`, etc.).

### Core Shape

```jac
"""Error raised by a plugin when a command fails."""
obj PluginError {
    has code: str,
        message: str;
}

"""Abstract base for capability plugins."""
obj DesktopPlugin {
    has plugin_name: str;
    :can:handle(command: str, args: dict) -> dict;  # raises PluginError
}

"""Plugin host: registry, dispatch, emit."""
obj PluginHost {
    has plugins: dict = {};
    has _wv_handle: int = 0;
    has _wv_lib = None;  # ctypes.CDLL

    :can:register(name: str, plugin: DesktopPlugin) -> None;
    :can:setup(wv_handle: int) -> None;  # loads libwebview via ctypes
    :can:dispatch(req_json: str) -> str;  # entry point called from native shim
    :can:emit(event: str, payload: dict) -> None;
}
```

### Dispatch Logic

```python
def dispatch(self, req_json: str) -> str:
    try:
        req = json.loads(req_json)
        name = req.get("plugin", "")
        command = req.get("command", "")
        args = req.get("args", {})
        if name not in self.plugins:
            return json.dumps({"ok": False, "error": {
                "code": "PLUGIN_NOT_FOUND",
                "message": f"Plugin '{name}' is not registered"
            }})
        result = self.plugins[name].handle(command, args)
        return json.dumps({"ok": True, "data": result})
    except PluginError as e:
        return json.dumps({"ok": False, "error": {
            "code": e.code, "message": e.message
        }})
    except Exception as e:
        return json.dumps({"ok": False, "error": {
            "code": "INTERNAL_ERROR", "message": str(e)
        }})
```

### Emit (push events to JS)

```python
def emit(self, event: str, payload: dict) -> None:
    js = f"window.__jac.__emit__({json.dumps(event)}, {json.dumps(payload)})"
    self._wv_lib.webview_eval(self._wv_handle, js.encode())
```

Uses `ctypes.CDLL("./libwebview.so")` -- returns the already-loaded DSO (dlopen
returns the same handle). The `wv_handle` (opaque int pointer) is valid across both
native and CPython contexts.

## Built-in Plugins

Each plugin is a `.jac` file transpiled to `.py` at build time. All use the Python
stdlib only (no jaclang dependency at runtime).

### `window_plugin.jac`

Controls the native window. Calls back into libwebview via ctypes:

```python
class WindowPlugin(DesktopPlugin):
    def __init__(self, wv_handle, wv_lib):
        self._wv = wv_lib
        self._handle = wv_handle

    def handle(self, command, args):
        if command == "set_title":
            self._wv.webview_set_title(self._handle, args["title"].encode())
            return {}
        if command == "set_size":
            self._wv.webview_set_size(
                self._handle, args["width"], args["height"], args.get("hint", 0)
            )
            return {}
        # minimize, maximize, fullscreen, close...
```

### `path_plugin.jac`

Resolves standard OS paths using `os` / `pathlib`. No native callback needed.

```python
class PathPlugin(DesktopPlugin):
    def handle(self, command, args):
        if command == "home":
            return {"path": str(Path.home())}
        if command == "data":
            return {"path": self._resolve_xdg("XDG_DATA_HOME", ".local/share")}
        # config, cache, downloads, temp...
```

Also resolves `$APP_DATA`, `$HOME` etc. used by `FsPlugin` allow-lists.

### `fs_plugin.jac`

File operations gated by allow-lists from `jac.toml`.

```python
class FsPlugin(DesktopPlugin):
    def __init__(self, config, path_plugin):
        self._allow_read = config.get("allow_read", [])
        self._allow_write = config.get("allow_write", [])
        self._path_plugin = path_plugin

    def handle(self, command, args):
        path = Path(args["path"]).expanduser().resolve()
        if command == "read_file":
            self._check_allowed(path, "read")
            return {"content": path.read_text(encoding=args.get("encoding", "utf-8"))}
        # write_file, list_dir, mkdir, remove, exists, stat...
```

Allow-list enforcement: canonicalize + `resolve()` before checking. Paths outside
the allow-list raise `PluginError("FORBIDDEN", ...)`.

### `notification_plugin.jac`, `clipboard_plugin.jac`, `dialog_plugin.jac`

Platform tooling via `subprocess.run`:

| Plugin | Linux | macOS | Windows |
|---|---|---|---|
| Notification | `notify-send` | `osascript` | PowerShell toast |
| Clipboard read/write | `xclip` | `pbcopy`/`pbpaste` | `clip.exe`/`Get-Clipboard` |
| Dialog (open/save/message) | `zenity` | `osascript` | PowerShell |

### `shell_plugin.jac`

`subprocess.run` with deny-all default. Must list explicit command patterns in
`jac.toml`:

```toml
[plugins.desktop.plugins.shell]
allow = ["git *", "jac *"]
```

Glob matching against the command string before execution.

## Security Model

### TOML Gating (build time + runtime)

```toml
[plugins.desktop.plugins]
window = true
path = true
notification = true

clipboard = { allow_read = true, allow_write = true }
dialog = true

fs = { allow_read = ["$APP_DATA", "$HOME/Documents"],
       allow_write = ["$APP_DATA"] }

# shell = { allow = ["git *", "jac *"] }  # uncommented = not registered
```

- **Built-ins are opt-in**: unlisted = not registered, `handle()` never called.
- **Allow-lists are baked at build time**: `_generate_host_source()` reads the TOML
  and emits Python config literals (same pattern as `pref_port` today). No runtime
  TOML parsing.
- **Each plugin validates its own config**: the host passes the config dict to each
  plugin's constructor. Plugins enforce their own allow/deny rules.

### Why Not Runtime TOML?

The native binary has no TOML parser. The generated Python source inlines the config
as string literals -- identical to how `pref_port` is computed at build time and
injected into the CPython bootstrap today.

## Files to Create

```
jac_desktop/
├── native/
│   └── plugin_bridge.na.jac                # ~20 lines, native shim
├── plugin/
│   ├── desktop_plugin.jac                  # PluginError + DesktopPlugin base
│   ├── plugin_host.jac                     # registry, dispatch, emit
│   └── built_in/
│       ├── window_plugin.jac               # ctypes → libwebview
│       ├── path_plugin.jac                 # os, pathlib
│       ├── fs_plugin.jac                   # pathlib + allow-list
│       ├── notification_plugin.jac         # subprocess
│       ├── clipboard_plugin.jac            # subprocess
│       ├── dialog_plugin.jac               # subprocess
│       └── shell_plugin.jac                # subprocess + deny-all
└── tests/
    └── test_plugin_host.jac                # dispatch unit tests
```

## Files to Modify

| File | Change |
|---|---|
| `plugin_config.jac` | Add `plugins` dict option to schema |
| `config_loader.jac` + impl | Add `get_plugin_configs() -> dict` |
| `targets/impl/native_desktop_target.impl.jac` | Extend build pipeline: transpile plugin `.jac` → `.py`, extend CPython bootstrap to load plugin host + set `_PH_DISPATCH`, extend host generator to import `plugin_bridge.na.jac` + bind `__jac_invoke` + inject JS SDK |
| `tests/test_binding.jac` | Add compile test for `plugin_bridge.na.jac` |
| `jac.toml` | Add `plugin_bridge.na.jac` to `[project.include.data]` |

### What's NOT Changing

- `webview.na.jac` -- untouched
- `oauth_broker.jac` -- untouched
- The CPython HTTP server that serves `dist/` -- untouched
- The `window.__JAC_DESKTOP__` / `__JAC_BROKER__` flags -- backward compatible

## Build Pipeline Changes

In `native_desktop_target.impl.jac`, extend the build step:

### 1. Transpile all plugin `.jac` → `.py`

```python
plugin_dir = webview_dir.parent.parent / "plugin"
for jac_file in plugin_dir.rglob("*.jac"):
    rel = jac_file.relative_to(plugin_dir)
    py_name = str(rel.with_suffix(".py"))
    result = subprocess.run([jac_bin, "jac2py", str(jac_file)], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Plugin transpile failed: {rel}\n{result.stderr}")
    (out_dir / py_name).parent.mkdir(parents=True, exist_ok=True)
    (out_dir / py_name).write_text(result.stdout)
```

### 2. Stage `plugin_bridge.na.jac` beside `webview.na.jac`

```python
shutil.copy2(webview_dir / "plugin_bridge.na.jac", out_dir / "plugin_bridge.na.jac")
```

### 3. Extend CPython bootstrap

The `serve_py` string in `_generate_host_source()` gains:

```python
# After the HTTP server setup, before the webview is created:
import importlib.util
for mod_name in ["desktop_plugin", "plugin_host",
                 "built_in.window_plugin", "built_in.path_plugin",
                 "built_in.fs_plugin", ...]:
    _spec = importlib.util.spec_from_file_location(mod_name, f"{mod_name.replace('.', '/')}.py")
    _mod = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    sys.modules[mod_name] = _mod

# Read plugin config (baked at build time as Python literals)
_plugin_cfg = {...}  # generated from jac.toml

# Build plugin host
_host = sys.modules["plugin_host"].PluginHost()
_host.setup(wv_handle)  # wv_handle set after webview creation

# Register enabled plugins
if _plugin_cfg.get("window"):
    _host.register("jac.window", sys.modules["built_in.window_plugin"].WindowPlugin(...))
# ... etc

# Expose dispatch function pointer for the native shim
_dispatch_fn = _host.dispatch  # Python callable
# The native shim reads _PH_DISPATCH as a PyObject*
```

### 4. Extend generated host source

The generated `host.na.jac` gains the libpython FFI imports, `plugin_bridge.na.jac`
import, and the `wv.bind("__jac_invoke", _jac_invoke_handler)` call:

```jac
import from webview { Webview, new_webview, respond }
import from "plugin_bridge.na.jac" { _jac_invoke_handler, _PH_DISPATCH }

# ... existing libpython imports ...

with entry {
    Py_Initialize();
    PyRun_SimpleString(SERVE_PY);
    # ... read _port, create wv ...
    wv.bind("__jac_invoke", _jac_invoke_handler);
    wv.on_load(BOOTSTRAP_JS);  # now includes the full JS SDK
    wv.navigate(url);
    ts = PyEval_SaveThread();
    wv.run();
    PyEval_RestoreThread(ts);
    Py_Finalize();
}
```

## Implementation Order

### Step 1 -- Native shim prototype (`plugin_bridge.na.jac`)

Highest risk. Must compile and link correctly. Validates:

- `inttoptr` coercion (`req_str: str = req`)
- GIL management (`PyGILState_Ensure` / `Release`)
- CPython function call (`PyObject_CallOneArg`)
- `webview_return` with the result

If this doesn't work, nothing else matters. Test: extend `test_binding.jac` to
compile a host that uses the shim.

### Step 2 -- Core types (`desktop_plugin.jac` + `plugin_host.jac`)

Pure Python types. `PluginError`, `DesktopPlugin`, `PluginHost` with dispatch.
Testable without webview -- unit test the dispatch routing with a mock plugin.

### Step 3 -- Config extension (`plugin_config.jac` + `config_loader`)

Add `plugins` schema option. `get_plugin_configs()` returns the raw dict.
Build-time inlining of config into generated Python source.

### Step 4 -- `path_plugin.jac`

Simplest plugin. No native callback, no security sensitivity. Validates the
constructor pattern and `handle()` dispatch.

### Step 5 -- `window_plugin.jac`

First plugin that calls back into native via ctypes. Validates the ctypes →
libwebview round-trip pattern that `emit()` also uses.

### Step 6 -- `fs_plugin.jac`

First security-sensitive plugin. Validates allow-list enforcement. `path_plugin`
provides path resolution used by allow-lists.

### Step 7 -- Remaining built-ins

`notification_plugin.jac`, `clipboard_plugin.jac`, `dialog_plugin.jac`,
`shell_plugin.jac`. All follow the subprocess pattern.

### Step 8 -- Build pipeline (`native_desktop_target.impl.jac`)

Wire the transpile loop, CPython bootstrap extension, and host generator changes.

### Step 9 -- Tests

- `test_plugin_host.jac` -- dispatch unit tests with mock plugins
- Extend `test_binding.jac` -- plugin_bridge compile test
- Config loading tests for `[plugins.desktop.plugins]`
- Security tests: unregistered plugin → `PLUGIN_NOT_FOUND`, path outside allow-list → `FORBIDDEN`

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| `inttoptr` + GIL + `PyObject_CallOneArg` in native shim | **High** | Step 1 prototypes this first. Existing `fix_ptr_int_coerce.na.jac` confirms inttoptr works. |
| Plugin transpile pipeline (N new `.jac` → `.py`) | **Medium** | Loop in build step, fail fast on transpile errors. Same as `oauth_broker.jac`. |
| ctypes → libwebview for WindowPlugin + emit | **Medium** | Already-loaded DSO, opaque handle valid across contexts. Test early (Step 5). |
| Path traversal in FsPlugin | **Medium** | Canonicalize + `resolve()` before allow-list check. Test with symlinks. |
| JSON injection in `emit()` | **Low** | Use `json.dumps()` for event name and payload, never string concat. |
| Generated host complexity growth | **Low** | Native shim stays thin (~20 lines). All logic in Python. |
| Regression: existing bootstrap flags | **Low** | JS SDK sets `window.__JAC_DESKTOP__` and `window.__JAC_BROKER__`. Test it. |
