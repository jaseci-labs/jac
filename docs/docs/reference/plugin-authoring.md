# Plugins

Jaclang uses a **limited** plugin surface: built-in subsystems (byLLM, scale,
client/desktop, MCP, shadcn) ship inside `jaclang` core and register through the
internal hook layer, while **external** plugins may still be discovered via the
`jac` setuptools entry-point group.

## What was removed vs what remains

| Removed | Still available |
|---------|-----------------|
| `[plugins.<name>]` nested config namespace | Top-level `[byllm]`, `[scale]`, `[client]`, `[mcp]`, `[desktop]`, `[jac-shadcn]` |
| `[plugins].enabled` / `[plugins].discovery` | `[plugins].disabled` - list of entry points to skip |
| `JAC_DISABLED_PLUGINS` env var | `jac plugins list/disable/enable/disabled` |
| Third-party hook plugins replacing core verbs | External plugins extending runtime hooks only |

Built-in features are always present; `[plugins].disabled` and `jac plugins
disable` only affect **external** entry-point plugins (not jaclang built-ins).

## Disabling external plugins

In `jac.toml`:

```toml
[plugins]
disabled = ["my-dist:my-plugin", "other-dist:*"]
```

Or via CLI (persists to `jac.toml`):

```bash
jac plugins list
jac plugins disable my-dist:my-plugin
jac plugins disabled
jac plugins enable my-dist:my-plugin
```

If an entry point fails to import (missing dependency), `jac plugins list` still
shows it under **Failed to load** with the qualified name you can pass to
`jac plugins disable`.

## Configuration

Feature configuration lives in top-level `jac.toml` tables (`[byllm]`,
`[scale]`, `[scale.database]`, `[client]`, `[client.pwa]`, `[mcp]`, `[desktop]`,
`[jac-shadcn]`), not under the former `[plugins.<name>]` namespace.

## Authoring an external plugin

Register a class with `@hookimpl`-decorated static methods on the `jac` hook
spec namespace (see `jaclang.jac0core.runtime.JacRuntimeInterface`). Publish a
setuptools entry point:

```toml
[project.entry-points.jac]
my_plugin = "my_pkg.plugin:MyPlugin"
```

Heavy imports should stay inside hook bodies so a missing optional dependency
degrades gracefully until the hook is actually invoked.

## Custom persistence backends

`TieredMemory` resolves its L3 store through
`JacRuntime.get_persistent_memory(config)`, which returns `None` by default (so
core falls back to `SqliteMemory`). To supply a custom backend (for example in
an ejected standalone backend), call
`JacRuntime.set_persistent_memory_provider(fn)` with a callable that takes the
config dict and returns a `PersistentMemory` implementation.
