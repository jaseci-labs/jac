# Desktop Plugin IPC -- Progress Tracker

## Overview

Adding a plugin host + built-in capability plugins to the Jac desktop shell,
exposed to JS as `window.__jac.invoke()` / `window.__jac.on()`.

Design doc: [`DESIGN-plugin-ipc.md`](./DESIGN-plugin-ipc.md)

---

## Status: Integration tests pass ✅

| Area | Status | Notes |
|------|--------|-------|
| Core framework | ✅ Done | `desktop_plugin.jac`, `plugin_host.jac` |
| Plugin bridge (inlined) | ✅ Done | Inlined into generated host; standalone file kept for docs |
| Built-in plugins (7) | ✅ Done | path, window, fs, notification, clipboard, dialog, shell |
| JS SDK (`window.__jac`) | ✅ Done | invoke + on/emit event system |
| Build pipeline integration | ✅ Done | transpile, stage, register in generated host |
| Config wiring (TOML → plugins) | ✅ Done | `config_loader` → `plugin_configs` |
| Companion `.py` fallbacks | ✅ Done | fs, shell, dialog (upstream jac2py bugs) |
| Config `True` vs `{}` fix | ✅ Done | all plugins handle `notification = true` correctly |
| Tests (unit + binding) | ✅ Done | `test_plugin_host.jac`, `test_binding.jac` |
| Integration tests | ✅ Done | `test_integration.jac` -- 27 tests covering full pipeline |
| Upstream bug filed | ✅ Done | [jaseci-labs/jaseci#6564](https://github.com/jaseci-labs/jaseci/issues/6564) |

---

## Completed Work

### Core Framework

- `jac_desktop/plugin/desktop_plugin.jac` -- `PluginError`, `DesktopPlugin` base class
- `jac_desktop/plugin/plugin_host.jac` -- `PluginHost` registry + dispatch
- `jac_desktop/native/plugin_bridge.na.jac` -- standalone bridge (kept for docs;
  bridge is inlined into generated host at build time)

### Bridge Architecture Change

Originally the bridge was a separate `.na.jac` file imported via
`import from "plugin_bridge.na.jac"`. This doesn't work because `nacompile`
doesn't support string-literal imports between `.na.jac` files. The bridge
code (~20 lines) is now inlined directly into `_generate_host_source()`.

The standalone `plugin_bridge.na.jac` file is kept for documentation purposes
and is still referenced by the design doc.

### Built-in Plugins (`jac_desktop/plugin/built_in/`)

| Plugin | File | Capability |
|--------|------|------------|
| path | `path_plugin.jac` | OS path resolution (home, data, config, cache, etc.) |
| window | `window_plugin.jac` | Native window control via ctypes → libwebview |
| fs | `fs_plugin.jac` + `fs_plugin.py` | File ops gated by allow-lists |
| notification | `notification_plugin.jac` | Desktop notifications via platform tools |
| clipboard | `clipboard_plugin.jac` | System clipboard read/write |
| dialog | `dialog_plugin.jac` + `dialog_plugin.py` | Native OS dialogs (open/save/message) |
| shell | `shell_plugin.jac` + `shell_plugin.py` | Subprocess exec with glob allow-list |

### JS SDK (injected at document-start)

- `window.__jac.invoke(plugin, command, args)` → Promise
- `window.__jac.on(event, callback)` / `window.__jac.__emit__(event, payload)`
- Sets `window.__JAC_DESKTOP__=true` and `window.__JAC_BROKER__='/__jac'` for backward compat

### Build Pipeline (`native_desktop_target.impl.jac`)

- Step 5: Transpile `oauth_broker.jac` → `.py` (unchanged)
- **Step 6**: Transpile all `plugin/*.jac` → `.py` for embedded CPython
  - Falls back to companion `.py` when `jac2py` fails (upstream bugs)
  - Warns on fallback, errors if no companion exists
- **Step 7**: Bridge code is inlined into generated host (no separate staging needed)
- Step 8: Generated host includes:
  - Inlined plugin bridge (GIL management, CPython dispatch, webview_return)
  - CPython bootstrap: import plugin modules, register enabled plugins
  - JS SDK injection via `wv.on_load()`
  - `wv.bind("__jac_invoke", _jac_invoke_handler)` registration

### Config Wiring

- `plugin_config.jac` -- `DesktopDefaultConfig` dataclass
- `config_loader.impl.jac` -- `get_plugin_configs()` reads `[plugins.desktop.plugins]`
- Plugin configs baked as Python literals into the generated host source

### Integration Tests (`test_integration.jac` -- 27 tests)

| Category | Tests | What's Covered |
|----------|-------|---------------|
| Transpilation | 2 | All plugins transpile or have companion fallback; imports work |
| PathPlugin dispatch | 5 | home, separator, resolve, temp, data commands |
| ShellPlugin security | 2 | Deny-all default; glob allow-list matching |
| FsPlugin security | 6 | Empty allow-list; read/write within/outside allowed paths; exists; list_dir |
| NotificationPlugin | 1 | Accepts `True` config, sends (or gracefully fails UNAVAILABLE) |
| ClipboardPlugin | 2 | Accepts `True` config; blocks read when `allow_read=false` |
| Generated host source | 2 | Required elements present; empty plugin_configs works |
| JS SDK | 2 | Parseable JavaScript; invoke produces correct request format |
| Config loading | 2 | TOML → plugin configs; empty plugins section |
| Native bridge | 2 | Source contains expected elements; compiles with full native stack |
| Build pipeline | 1 | Transpile all plugins + generate host + verify all artifacts |

---

## Bugs Fixed

### Issue 1: `jac2py` silently fails / crashes on plugin files

**Root cause**: Upstream Jac transpiler bugs (3 distinct bugs).
**Filed**: [jaseci-labs/jaseci#6564](https://github.com/jaseci-labs/jaseci/issues/6564)

**Mitigation**: Companion `.py` fallbacks for `fs_plugin`, `shell_plugin`, `dialog_plugin`.

### Issue 2: Config `True` vs `{}` disabling plugins

**Fix**: Plugins use `config is not False` for enabled state; non-dict configs normalized to `{}`.

### Issue 3: `obj` keyword collision in native bridge

**Root cause**: `obj` is a reserved keyword in Jac (node type), but the native bridge
used it as a parameter name for `PyUnicode_AsUTF8(obj: int)` and `Py_DecRef(obj: int)`.
**Fix**: Renamed parameter to `pyobj` in all FFI declarations.

### Issue 4: String-literal imports don't work in nacompile

**Root cause**: `import from "plugin_bridge.na.jac"` is not supported by `nacompile`
(string literal imports only work for client `.cl.jac` imports).
**Fix**: Inlined the ~20-line bridge code directly into the generated host source.
Standalone `plugin_bridge.na.jac` kept for documentation only.

---

## Remaining Work

- [ ] **Full end-to-end build test**: `jac build` → `jac start` → JS↔plugin roundtrip (requires display)
- [ ] **HMR dev mode**: Native window pointed at Vite dev server (noted as follow-up)
- [ ] **Remove companion `.py` files** once upstream jac2py bugs are fixed
- [ ] **macOS / Windows testing**: Platform-specific code paths in notification, dialog, clipboard
- [ ] **WindowPlugin runtime test**: ctypes → libwebview roundtrip (needs running webview)
