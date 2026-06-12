# Plugin architecture - long-term proposal (DRAFT)

> Status: **proposal + stubs**. Nothing here is wired into the build yet. The
> stub `.jac` files in this folder live *outside* `jac_desktop/plugin/` on
> purpose - the build transpiles every `*.jac` under `plugin/`, so drafts kept
> there would be force-compiled. Promote files into the package one at a time.

This addresses the four findings from the IPC review:

1. **Registration is stringly-typed codegen in 3 places** → a data-driven
   **plugin registry** + a real `bootstrap_plugins()` in Jac.
2. **No consumer SDK** (users hand-write `window.__jac.invoke("jac.fs", …)`) →
   a typed **client facade**, generatable from the same registry.
3. **Shell allow-list silently widens** (`"git log"` allows all git) → a
   token-aware matcher.
4. **Bridge duplicated** (reference file vs. inlined strings) → single source,
   inlined by marker extraction.

The through-line: **one manifest per plugin becomes the single source of truth**
for host registration, module loading, *and* the client SDK. "Add plugin #8"
goes from "edit a 250-line string generator in three spots" to "add one file +
one registry line."

---

## 1. Plugin registry + `bootstrap_plugins()` (finding #1, the big one)

### Today

`_generate_host_source()` builds registration as concatenated Python *source
strings* (`native_desktop_target.impl.jac:131-218`). Adding a plugin touches
three places, two of them inside string literals with no type checking:

- the `_plugin_mods` list,
- a bespoke `plugin_py += ("if _pc.get('X'): … register …")` block (one of seven
  near-identical copies),
- the plugin file itself.

### Proposed

Each plugin declares a `PluginManifest` and a uniform `build()` factory. A
single ordered `BUILTIN_PLUGINS` list is the registry. Registration becomes a
real, unit-testable function - `bootstrap_plugins()` - that lives in
`plugin_host.jac` and runs in the embedded CPython, instead of being emitted as
strings.

```jac
# manifest.jac  (new module, transpiled like the rest)
obj PluginManifest {
    has name: str,             # IPC name, e.g. "jac.fs"
        config_key: str,       # key under [plugins.desktop.plugins], e.g. "fs"
        module: str,           # import path, e.g. "built_in.fs_plugin"
        class_name: str,       # e.g. "FsPlugin"
        commands: list = [],   # CommandSpec[] - drives SDK gen + validation
        default_on: bool = False;
}
```

```jac
# Each plugin gains a manifest + a uniform factory. Construction differences
# (path dep, late-bound webview handle, config shape) hide behind build().
obj FsPlugin(DesktopPlugin) {
    static def manifest() -> PluginManifest {
        return PluginManifest(
            name="jac.fs", config_key="fs",
            module="built_in.fs_plugin", class_name="FsPlugin",
            commands=FS_COMMANDS
        );
    }
    static def build(ctx: PluginContext, config: any) -> DesktopPlugin {
        return FsPlugin(DesktopPlugin._coerce_config(config), ctx.path_plugin);
    }
    # ... existing handle()/_read_file()/etc. unchanged ...
}
```

`PluginContext` carries the always-on shared services (the `PathPlugin`
instance, the webview handle/lib placeholders) so factories have a uniform
signature:

```jac
obj PluginContext {
    has path_plugin: PathPlugin | None = None,
        wv_handle: int = 0,
        wv_lib: ctypes.CDLL | None = None;
}
```

The registry is just data - and it's also the module-load list, so the
`_plugin_mods` array disappears:

```jac
# registry.jac
glob BUILTIN_PLUGINS: list = [
    PathPlugin.manifest(),
    WindowPlugin.manifest(),
    FsPlugin.manifest(),
    NotificationPlugin.manifest(),
    ClipboardPlugin.manifest(),
    DialogPlugin.manifest(),
    ShellPlugin.manifest(),
];
```

Registration moves out of the codegen string and into real Jac:

```jac
# plugin_host.jac  (new function)
def bootstrap_plugins(configs: dict, modules: dict) -> PluginHost {
    ctx = PluginContext();
    # PathPlugin is a foundational *service* (fs needs it even if jac.path IPC
    # is off), so it is always constructed; registration is still gated below.
    ctx.path_plugin = PathPlugin();
    host = PluginHost();
    for m in BUILTIN_PLUGINS {
        cfg = configs.get(m.config_key, m.default_on);
        if not _config_enables(cfg) {
            continue;
        }
        cls = getattr(modules[m.module], m.class_name);
        host.register(m.name, cls.build(ctx, cfg));
    }
    return host;
}
```

`modules` is `sys.modules` (passed in so the function stays testable with a fake
map). The generated host shrinks to a single call:

```python
# what _generate_host_source now emits instead of 7 string blocks:
_host = sys.modules['plugin_host'].bootstrap_plugins(_pc, sys.modules)
_dispatch_fn = _host.dispatch
```

**Net:** the seven `plugin_py += (...)` blocks and the `_plugin_mods` list (≈70
lines of stringly-typed codegen) collapse to ~2 emitted lines. Registration
logic becomes ordinary Jac with real tests. Adding a plugin = new file + one
line in `BUILTIN_PLUGINS`.

> Migration note: the module-import loop in `_generate_host_source`
> (lines 146-168) still needs to run as bootstrap strings (embedded CPython has
> no jaclang to resolve imports), but it now iterates `[m.module for m in
> BUILTIN_PLUGINS]` derived from the registry rather than a hand-kept list.

---

## 2. Typed client SDK (finding #2 - the headline for "simple to use")

### Today

The only consumer surface is the raw JS shim. From `cl` code a user writes:

```jac
content = (await window.__jac.invoke("jac.fs", "read_file", {"path": p}))["content"];
```

Magic strings for plugin, command, and arg keys; no autocomplete; no
compile-time check; errors only at runtime. The README never even shows this.

### Proposed

Ship a typed facade importable from `cl` code. One thin `_invoke` wraps the
ambient `window.__jac`; each capability is a namespaced set of typed functions.

```jac
# desktop_api.cl.jac  - staged into the user's project (importable from cl)
obj fs {
    static async def read_file(path: str, encoding: str = "utf-8") -> str {
        r = await _invoke("jac.fs", "read_file",
                          {"path": path, "encoding": encoding});
        return r["content"];
    }
    static async def write_file(path: str, content: str) -> None {
        await _invoke("jac.fs", "write_file", {"path": path, "content": content});
    }
}
```

Consumer code becomes discoverable and typed:

```jac
import from "@jac/desktop" { fs, dialog, clipboard }

async def save() -> None {
    picked = await dialog.save_file(title="Export");
    if not picked.canceled {
        await fs.write_file(picked.path, contents);
    }
}
```

**Generate it from the registry.** Because each `PluginManifest.commands`
carries `CommandSpec`s (name, params, return), the same build step that emits
`host.na.jac` can emit `desktop_api.cl.jac` and stage it beside the user's
client code. That closes the loop: the manifest is the one source of truth for
the host *and* the SDK, so they can never drift. Short term: hand-write the
facade (stub included here). Long term: generate it.

> Binding detail to confirm: the stub treats `window.__jac` as an ambient
> browser global (the host injects it via `BOOTSTRAP_JS`). If the jac-client
> compiler doesn't resolve a bare `window`, a ~3-line ambient/`extern` shim
> declares it - that's the one open item for this piece.

---

## 3. Shell allow-list: token-aware matcher (finding #3)

`shell_plugin.jac:57-65` matches only `pattern_argv[0]`, so everything after the
executable in a pattern is silently ignored - `allow = ["git log"]` permits
**all** git subcommands. Fix: match each pattern token against the
corresponding argv token, with a trailing `*` meaning "any remaining args."
Backward compatible (`"echo *"`, `"git *"` keep working); `"git log"` now
restricts to exactly `git log`, and `"git log *"` allows `git log …`.

```jac
def _pattern_matches(pattern_argv: list, argv: list) -> bool {
    for (i, ptok) in enumerate(pattern_argv) {
        # trailing "*" = allow any remaining args
        if ptok == "*" and i == len(pattern_argv) - 1 {
            return True;
        }
        if i >= len(argv) {
            return False;
        }
        if not fnmatch.fnmatch(argv[i], ptok) {
            return False;
        }
    }
    return len(argv) == len(pattern_argv);   # no trailing "*": exact length
}
```

Add a test for the surprising case (`allow=["git log"]` must reject
`git push`) - the current suite only exercises the `echo *` form, which is why
the gap slipped through.

---

## 4. Bridge de-duplication (finding #4)

`native/plugin_bridge.na.jac` is a hand-synced copy of the bridge that's also
inlined as strings at `native_desktop_target.impl.jac:276-301`, with a comment
saying "keep in sync." Make the reference file the **single source** and inline
it by marker extraction at build time:

```jac
# native/plugin_bridge.na.jac
# --- BRIDGE START ---
glob _PH_DISPATCH: int = 0;
def _jac_invoke_handler(id: int, req: int, wv_handle: int) -> None { ... }
def _stash_wv_in_python(h: int) -> None { ... }
# --- BRIDGE END ---
```

```jac
# in _generate_host_source(), replacing the inlined string block:
bridge = _read_between(webview_dir / "plugin_bridge.na.jac",
                       "# --- BRIDGE START ---", "# --- BRIDGE END ---");
```

Now the bridge is real `na.jac` (so it parses/typechecks as part of the source
tree) *and* the only copy. No more manual sync.

---

## Smaller cleanups (fold in while touching these files)

- **`_coerce_config` on the base.** `if not isinstance(config, dict): config = {}`
  (fs, shell, clipboard) and `_enabled = config is not False`
  (dialog, notification) repeat. One static helper on `DesktopPlugin`.
- **Platform dispatch skeleton.** `clipboard`/`dialog`/`notification` repeat the
  same `if platform == linux/darwin/windows` ladder wrapped in identical
  `except FileNotFoundError/TimeoutExpired → PluginError` mapping. An
  `OsPlugin._run_platform(handlers: dict, ...)` helper lets each plugin supply
  just the three platform bodies. (`OsPlugin` already centralizes escaping.)
- **`handle()` if-chains → command map.** A `commands: dict[str, callable]`
  registry on the base removes the per-plugin if-ladder and makes commands
  enumerable - which the SDK generator can consume directly.
- **exe-path resolution dup.** `plugin_host._binary_dir()` and the
  `/proc/self/exe` block in `serve_py` compute the same thing in the same
  `__main__`; reuse `_root`.
- **Trim `_parse_invoke`.** It accepts three wire shapes for back-compat with
  "older hosts." This protocol is unreleased - collapse to the one canonical
  array form before shipping.

---

## Suggested sequencing

1. **#3 shell matcher** + **#4 bridge** - small, self-contained, low risk; land first.
2. **#1 registry + `bootstrap_plugins`** - foundational; unlocks the SDK generator.
3. **#2 client SDK** - hand-written facade first, then generate from manifests.
4. Smaller cleanups folded in opportunistically.

Stub files in this folder:

| File | Shows |
|------|-------|
| `manifest.jac` | `PluginManifest`, `CommandSpec`, `PluginContext` |
| `registry.jac` | `BUILTIN_PLUGINS` + `bootstrap_plugins()` |
| `fs_plugin.refactored.jac` | a plugin gaining `manifest()` + `build()` |
| `desktop_api.cl.jac` | the typed client facade |
| `shell_matcher.jac` | token-aware allow-list matcher + the missing test |
